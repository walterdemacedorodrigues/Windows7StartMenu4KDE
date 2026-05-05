/*
 *  SPDX-FileCopyrightText: 2025 Walter Rodrigues <wmr2@cin.ufpe.br>
 *  SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick 2.4
import QtCore
import org.kde.plasma.extras 2.0 as PlasmaExtras

/**
 * Get Recent Files Helper Component
 * Reads per-application recent files from ~/.local/share/recently-used.xbel
 * Replaces the removed org.kde.plasma.private.taskmanager.Backend dependency.
 */
QtObject {
    id: getRecentFilesHelper

    // Emitted once the XBEL file has been parsed and the cache is ready.
    // FavoritesRow listens to this to rebuild its model.
    signal cacheLoaded()

    property var _xbelCache: ({})
    property bool _cacheReady: false

    Component.onCompleted: {
        _loadXbel();
    }

    // "applications:org.kde.okular.desktop" -> ["org.kde.okular", "okular"]
    function _getPossibleAppNames(launcherUrl) {
        if (!launcherUrl) return [];
        var name = launcherUrl.replace(/^applications:/, "").replace(/\.desktop$/, "").toLowerCase();
        var names = [name];
        var parts = name.split(".");
        if (parts.length > 1) {
            names.push(parts[parts.length - 1]);
        }
        return names;
    }

    function _iconFromHref(href) {
        var ext = href.toLowerCase().split(".").pop().split("?")[0];
        if (ext === "pdf") return "application-pdf";
        if (["jpg","jpeg","png","gif","bmp","svg","webp","tiff"].indexOf(ext) !== -1) return "image-x-generic";
        if (["mp3","wav","ogg","flac","m4a","opus","aac"].indexOf(ext) !== -1) return "audio-x-generic";
        if (["mp4","avi","mkv","mov","webm","ogv"].indexOf(ext) !== -1) return "video-x-generic";
        if (["doc","docx","odt","rtf"].indexOf(ext) !== -1) return "application-msword";
        if (["xls","xlsx","ods","csv"].indexOf(ext) !== -1) return "application-vnd.ms-excel";
        if (["ppt","pptx","odp"].indexOf(ext) !== -1) return "application-vnd.ms-powerpoint";
        if (["zip","tar","gz","bz2","xz","7z","rar"].indexOf(ext) !== -1) return "application-zip";
        return "text-x-generic";
    }

    function _loadXbel() {
        var dataPath = StandardPaths.writableLocation(StandardPaths.GenericDataLocation);
        var url = "file://" + dataPath + "/recently-used.xbel";
        console.log("[Probe.XBEL] (1) GET:", url);
        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            var textLen = (xhr.responseText && xhr.responseText.length) || 0;
            console.log("[Probe.XBEL] (2) DONE status=", xhr.status,
                        "responseText.length=", textLen,
                        "responseXML=", (xhr.responseXML ? "non-null" : "NULL"));
            var newCache = {};
            if (xhr.responseXML) {
                _parseXbel(xhr.responseXML, newCache);
            } else if (xhr.responseText) {
                console.log("[Probe.XBEL] (2b) responseXML is null. First 200 chars of text:",
                            xhr.responseText.substring(0, 200).replace(/\n/g, "\\n"));
            }
            _xbelCache = newCache;
            _cacheReady = true;
            console.log("[Probe.XBEL] (5) cache keys (n=" + Object.keys(newCache).length + "):",
                        Object.keys(newCache).slice(0, 20).join(", "));
            getRecentFilesHelper.cacheLoaded();
        };
        xhr.open("GET", url);
        xhr.send();
    }

    function _parseXbel(doc, cache) {
        var BOOKMARK_NS = "http://www.freedesktop.org/standards/desktop-bookmarks";
        var bookmarks = doc.getElementsByTagName("bookmark");
        console.log("[Probe.XBEL] (3) bookmarks.length =", bookmarks.length);

        var probeFirstBookmarkLogged = false;
        for (var i = 0; i < bookmarks.length; i++) {
            var bm = bookmarks[i];
            var href = bm.getAttribute("href") || "";

            if (!probeFirstBookmarkLogged) {
                var nsTry = bm.getElementsByTagNameNS(BOOKMARK_NS, "application");
                var prefixTry = bm.getElementsByTagName("bookmark:application");
                var plainTry = bm.getElementsByTagName("application");
                console.log("[Probe.XBEL] (4) first bookmark href=", href.substring(0, 80),
                            "| getElementsByTagNameNS(NS,'application').length=", nsTry.length,
                            "| getElementsByTagName('bookmark:application').length=", prefixTry.length,
                            "| getElementsByTagName('application').length=", plainTry.length);
                if (nsTry.length > 0) {
                    console.log("[Probe.XBEL] (4b) NS app[0] name=", nsTry[0].getAttribute("name"),
                                "exec=", (nsTry[0].getAttribute("exec") || "").substring(0, 60));
                } else if (prefixTry.length > 0) {
                    console.log("[Probe.XBEL] (4b) prefix app[0] name=", prefixTry[0].getAttribute("name"),
                                "exec=", (prefixTry[0].getAttribute("exec") || "").substring(0, 60));
                } else if (plainTry.length > 0) {
                    console.log("[Probe.XBEL] (4b) plain app[0] name=", plainTry[0].getAttribute("name"),
                                "exec=", (plainTry[0].getAttribute("exec") || "").substring(0, 60));
                }
                probeFirstBookmarkLogged = true;
            }

            if (!href.startsWith("file://")) continue;

            // Extract title
            var titleNodes = bm.getElementsByTagName("title");
            var rawTitle = (titleNodes.length > 0 ? titleNodes[0].textContent : "").trim();
            if (!rawTitle) {
                var hrefParts = href.split("/");
                rawTitle = decodeURIComponent(hrefParts[hrefParts.length - 1]);
            }
            // Skip entries without a file extension (likely directories)
            if (rawTitle.indexOf(".") === -1) continue;

            var visited = bm.getAttribute("visited") || bm.getAttribute("modified") || "";

            // Find which apps opened this file
            var appNodes = bm.getElementsByTagNameNS(BOOKMARK_NS, "application");
            for (var j = 0; j < appNodes.length; j++) {
                var appName = (appNodes[j].getAttribute("name") || "").toLowerCase();
                if (!appName) continue;
                if (!cache[appName]) cache[appName] = [];

                // Avoid duplicates
                var dup = false;
                for (var k = 0; k < cache[appName].length; k++) {
                    if (cache[appName][k].href === href) { dup = true; break; }
                }
                if (!dup) {
                    cache[appName].push({
                        text: rawTitle,
                        href: href,
                        icon: _iconFromHref(href),
                        visited: visited
                    });
                }
            }
        }

        // Sort each app's list: most recently visited first
        for (var app in cache) {
            cache[app].sort(function(a, b) { return (b.visited > a.visited) ? 1 : -1; });
        }
    }

    // Try all possible app names derived from launcherUrl against the cache
    function _getCachedFiles(launcherUrl) {
        var names = _getPossibleAppNames(launcherUrl);
        for (var i = 0; i < names.length; i++) {
            var files = _xbelCache[names[i]];
            if (files && files.length > 0) return files;
        }
        return [];
    }

    /**
     * Get the count of recent files for an application
     * @param launcherUrl - Application launcher URL (e.g., "applications:firefox.desktop")
     * @param parentItem - Unused, kept for API compatibility
     * @return Number of recent files available (max 10)
     */
    function getRecentFilesCount(launcherUrl, parentItem) {
        if (!_cacheReady || !launcherUrl) return 0;
        return Math.min(_getCachedFiles(launcherUrl).length, 10);
    }

    /**
     * Get recent files actions for an application
     * @param launcherUrl - Application launcher URL
     * @param parentItem - Unused, kept for API compatibility
     * @return Object with { actions: [], title: "", count: 0 }
     */
    function getRecentFilesActions(launcherUrl, parentItem) {
        var result = { actions: [], title: "", count: 0 };
        if (!_cacheReady || !launcherUrl) return result;

        var files = _getCachedFiles(launcherUrl);
        if (files.length === 0) return result;

        var actions = [];
        for (var i = 0; i < Math.min(files.length, 10); i++) {
            actions.push((function(f) {
                return {
                    text: f.text,
                    icon: f.icon,
                    trigger: function() { Qt.openUrlExternally(f.href); }
                };
            })(files[i]));
        }

        result.actions = actions;
        result.title = i18n("Recent Files");
        result.count = actions.length;
        return result;
    }

    /**
     * Create a PlasmaExtras.Menu from actions
     * @param actions - Array of action objects
     * @param parentItem - Parent QML item for the menu
     * @param title - Optional menu title
     * @return PlasmaExtras.Menu object or null
     */
    function createMenuFromActions(actions, parentItem, title) {
        var menu = Qt.createQmlObject(`
            import org.kde.plasma.extras 2.0 as PlasmaExtras
            PlasmaExtras.Menu {
                placement: PlasmaExtras.Menu.RightPosedTopAlignedPopup
            }
        `, parentItem);

        if (!menu) return null;

        // Add title if provided
        if (title && title !== "") {
            var headerItem = Qt.createQmlObject(`
                import org.kde.plasma.extras 2.0 as PlasmaExtras
                PlasmaExtras.MenuItem { enabled: false }
            `, menu);
            headerItem.text = title;
            menu.addMenuItem(headerItem);

            var separatorItem = Qt.createQmlObject(`
                import org.kde.plasma.extras 2.0 as PlasmaExtras
                PlasmaExtras.MenuItem { separator: true }
            `, menu);
            menu.addMenuItem(separatorItem);
        }

        // Add action items
        if (actions && actions.length > 0) {
            for (var i = 0; i < actions.length; i++) {
                var action = actions[i];
                if (!action || typeof action !== "object") continue;

                var menuItem = Qt.createQmlObject(`
                    import org.kde.plasma.extras 2.0 as PlasmaExtras
                    PlasmaExtras.MenuItem {}
                `, menu);

                menuItem.text = action.text || "";
                menuItem.icon = action.icon || "";

                if (action.trigger && typeof action.trigger === "function") {
                    menuItem.clicked.connect(action.trigger);
                }

                menu.addMenuItem(menuItem);
            }
        } else {
            var noItemsItem = Qt.createQmlObject(`
                import org.kde.plasma.extras 2.0 as PlasmaExtras
                PlasmaExtras.MenuItem { enabled: false }
            `, menu);
            noItemsItem.text = i18n("No recent items");
            menu.addMenuItem(noItemsItem);
        }

        return menu;
    }

    /**
     * Extract the correct launcher URL from a favorites model item
     * @param favoritesModel - The favorites model
     * @param index - Model index
     * @return Launcher URL string or empty string
     */
    function extractFavoriteLauncherUrl(favoritesModel, index) {
        if (!favoritesModel) return "";

        try {
            var favIndex = favoritesModel.index(index, 0);
            for (var i = 0; i <= 10; i++) {
                var urlTest = favoritesModel.data(favIndex, Qt.UserRole + i);
                if (urlTest && typeof urlTest === "string" && urlTest.indexOf("applications:") === 0) {
                    return urlTest;
                }
            }
            return "";
        } catch (e) {
            return "";
        }
    }
}
