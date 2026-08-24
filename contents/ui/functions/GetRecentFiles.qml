/*
 *  SPDX-FileCopyrightText: 2025 Walter Rodrigues <wmr2@cin.ufpe.br>
 *  SPDX-License-Identifier: AGPL-3.0-or-later
 */

import QtQuick 2.4
import QtCore
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.extras 2.0 as PlasmaExtras

/**
 * Get Recent Files Helper Component
 * Reads per-application recent files from ~/.local/share/recently-used.xbel
 * Replaces the removed org.kde.plasma.private.taskmanager.Backend dependency.
 */
Item {
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

    // XMLHttpRequest refuses local file URLs, so the bookmark file is read
    // through the executable engine and reparsed from a data URI.
    property P5Support.DataSource _reader: P5Support.DataSource {
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            disconnectSource(sourceName);
            getRecentFilesHelper._ingest(data["stdout"] || "");
        }
    }

    function _loadXbel() {
        var dataPath = StandardPaths.writableLocation(StandardPaths.GenericDataLocation)
                           .toString().replace(/^file:\/\//, "");
        _reader.connectSource("cat " + _shellQuote(dataPath + "/recently-used.xbel"));
    }

    function _shellQuote(path) {
        return "'" + path.replace(/'/g, "'\\''") + "'";
    }

    function _ingest(xmlText) {
        var newCache = {};
        if (xmlText.trim() !== "") {
            var xhr = new XMLHttpRequest();
            xhr.onreadystatechange = function() {
                if (xhr.readyState !== XMLHttpRequest.DONE) return;
                if (xhr.responseXML) _parseXbel(xhr.responseXML, newCache);
            };
            xhr.open("GET", "data:text/xml;charset=utf-8," + encodeURIComponent(xmlText));
            xhr.send();
        }
        _xbelCache = newCache;
        _cacheReady = true;
        getRecentFilesHelper.cacheLoaded();
    }

    // Rereads the bookmark file so freshly opened documents show up.
    function refresh() {
        _loadXbel();
    }

    // Qt's XMLHttpRequest exposes only a read only DOM subset with no
    // getElementsByTagName, so the tree is walked by hand.
    function _localName(nodeName) {
        var colon = nodeName.indexOf(":");
        return colon === -1 ? nodeName : nodeName.substring(colon + 1);
    }

    function _attr(node, name) {
        if (!node || !node.attributes) return "";
        for (var i = 0; i < node.attributes.length; i++) {
            if (_localName(node.attributes[i].nodeName) === name) return node.attributes[i].nodeValue;
        }
        return "";
    }

    function _text(node) {
        if (!node || !node.childNodes) return "";
        var out = "";
        for (var i = 0; i < node.childNodes.length; i++) {
            var child = node.childNodes[i];
            if (child.nodeType === 3 || child.nodeType === 4) out += child.nodeValue;
        }
        return out;
    }

    function _collect(node, name, out) {
        if (!node || !node.childNodes) return out;
        for (var i = 0; i < node.childNodes.length; i++) {
            var child = node.childNodes[i];
            if (child.nodeType !== 1) continue;
            if (_localName(child.nodeName) === name) out.push(child);
            else _collect(child, name, out);
        }
        return out;
    }

    function _parseXbel(doc, cache) {
        var bookmarks = _collect(doc.documentElement, "bookmark", []);

        for (var i = 0; i < bookmarks.length; i++) {
            var bm = bookmarks[i];
            var href = _attr(bm, "href");
            if (href.indexOf("file://") !== 0) continue;

            var titleNodes = _collect(bm, "title", []);
            var rawTitle = (titleNodes.length > 0 ? _text(titleNodes[0]) : "").trim();
            if (!rawTitle) {
                var hrefParts = href.split("/");
                rawTitle = decodeURIComponent(hrefParts[hrefParts.length - 1]);
            }
            // Entries without an extension are almost always directories.
            if (rawTitle.indexOf(".") === -1) continue;

            var visited = _attr(bm, "visited") || _attr(bm, "modified") || "";

            var appNodes = _collect(bm, "application", []);
            for (var j = 0; j < appNodes.length; j++) {
                var appName = _attr(appNodes[j], "name").toLowerCase();
                if (!appName) continue;
                if (!cache[appName]) cache[appName] = [];

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
     * @return Number of recent files available, capped by numberRecentFiles
     */
    function getRecentFilesCount(launcherUrl, parentItem) {
        if (!_cacheReady || !launcherUrl) return 0;
        return Math.min(_getCachedFiles(launcherUrl).length, Plasmoid.configuration.numberRecentFiles);
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
        for (var i = 0; i < Math.min(files.length, Plasmoid.configuration.numberRecentFiles); i++) {
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
}
