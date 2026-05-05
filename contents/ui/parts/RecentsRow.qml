/*
 *  SPDX-FileCopyrightText: 2025 Walter Rodrigues <wmr2@cin.ufpe.br>
 *  SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick 2.4
import org.kde.plasma.extras 2.0 as PlasmaExtras
import org.kde.plasma.private.kicker 0.1 as Kicker
import ".."
import "../functions" as Functions

/**
 * Recent/Frequent apps grid component for the Windows 7 Start Menu
 * Displays most used applications with recent files support
 */
FavoritesGridView {
    id: recentsGrid

    // Properties
    // cellWidth and cellHeight are aliases in FavoritesGridView - don't override them
    property int iconSize: 32
    property var favoritesModel: null

    // Signals (keyNavUp already defined in FavoritesGridView)
    signal menuClosed()

    // Models
    Kicker.RecentUsageModel {
        id: frequentAppsModel
        ordering: 1 // Popular / Frequently Used
    }

    ListModel {
        id: appsWithRecentFiles
    }

    // Get Recent Files Helper
    Functions.GetRecentFiles {
        id: getRecentFilesHelper
    }

    // State
    property bool modelsProcessed: false
    property var lastFavoritesSnapshot: []
    property QtObject currentMenu: null

    // Grid configuration
    width: parent.width
    model: appsWithRecentFiles

    // Get favorites snapshot for change detection
    function getFavoritesSnapshot() {
        var snapshot = [];
        if (favoritesModel) {
            for (var f = 0; f < favoritesModel.count; f++) {
                try {
                    var favIndex = favoritesModel.index(f, 0);
                    var favoriteUrl = favoritesModel.data(favIndex, Qt.UserRole + 1) || "";
                    if (favoriteUrl) snapshot.push(favoriteUrl);
                } catch (e) {
                    continue;
                }
            }
        }
        return snapshot;
    }

    // Check if favorites changed
    function favoritesChanged() {
        var currentSnapshot = getFavoritesSnapshot();
        if (currentSnapshot.length !== lastFavoritesSnapshot.length) return true;

        for (var i = 0; i < currentSnapshot.length; i++) {
            if (lastFavoritesSnapshot.indexOf(currentSnapshot[i]) === -1) return true;
        }
        return false;
    }

    // Extract launcher URL from model item
    function extractLauncherUrl(modelItem, originalIndex) {
        if (!modelItem) return "";

        try {
            var modelIndex = frequentAppsModel.index(originalIndex, 0);
            var desktopFile = frequentAppsModel.data(modelIndex, Qt.UserRole + 3);

            if (desktopFile && desktopFile.indexOf(".desktop") !== -1) {
                return "applications:" + desktopFile;
            }
        } catch (e) {
            return "";
        }

        var url = modelItem.url || "";
        if (url && url.indexOf(".desktop") !== -1) return url;

        var favoriteId = modelItem.favoriteId || "";
        if (favoriteId && favoriteId.indexOf(".desktop") !== -1) {
            return "applications:" + favoriteId;
        }

        return "";
    }

    // Get recent files count for app
    function getRecentFilesForApp(launcherUrl) {
        return getRecentFilesHelper.getRecentFilesCount(launcherUrl, recentsGrid);
    }

    // Validate application item
    function isValidApplication(modelItem) {
        if (!modelItem) return false;

        var display = modelItem.display || "";
        var url = modelItem.url || "";
        var favoriteId = modelItem.favoriteId || "";

        if (!display || display.trim() === "") return false;
        if (favoriteId === "Pastas" || favoriteId === "Folders" || favoriteId === "Arquivos") return false;
        if (favoriteId === "Aplicativos") return true;
        if (url && url.toLowerCase().indexOf(".desktop") !== -1) return true;
        if (display.length < 2) return false;
        if (/^[0-9\W]+$/.test(display)) return false;
        if (display.length >= 8 && /^[0-9A-F]+$/i.test(display)) return false;

        return true;
    }

    // ==== DIAGNOSTIC HELPERS (one-shot probe of the upstream model) ====
    function _probeRecentModel() {
        try {
            console.log("[Probe.Recents] === RecentUsageModel introspection ===");
            console.log("[Probe.Recents] count:", frequentAppsModel.count);
            // roleNames()
            if (typeof frequentAppsModel.roleNames === "function") {
                try {
                    var names = frequentAppsModel.roleNames();
                    var keys = Object.keys(names);
                    console.log("[Probe.Recents] roleNames keys count:", keys.length);
                    for (var k = 0; k < keys.length; k++) {
                        var rk = keys[k];
                        var rv = names[rk];
                        var rs = (rv && rv.toString) ? rv.toString() : String(rv);
                        console.log("[Probe.Recents]   role", rk, "->", rs);
                    }
                } catch (e) {
                    console.log("[Probe.Recents] roleNames() threw:", e);
                }
            } else {
                console.log("[Probe.Recents] roleNames is not callable from QML");
            }
            // Probe roles for first row
            if (frequentAppsModel.count > 0) {
                var idx0 = frequentAppsModel.index(0, 0);
                var disp = frequentAppsModel.data(idx0, Qt.DisplayRole);
                console.log("[Probe.Recents] row 0 display:", disp);
                for (var p = 1; p <= 12; p++) {
                    var v = frequentAppsModel.data(idx0, Qt.UserRole + p);
                    console.log("[Probe.Recents]   +" + p + " =>", _summariseValue(v));
                }
            }
        } catch (e) {
            console.log("[Probe.Recents] error:", e);
        }
    }

    function _summariseValue(v) {
        if (v === null) return "null";
        if (v === undefined) return "undefined";
        if (typeof v === "string") return "string(\"" + v.substring(0, 60) + "\")";
        if (typeof v === "number") return "number(" + v + ")";
        if (typeof v === "boolean") return "bool(" + v + ")";
        if (Array.isArray(v)) {
            var s = "array(len=" + v.length + ")";
            if (v.length > 0 && typeof v[0] === "object") {
                var first = v[0] || {};
                var keys = [];
                for (var k in first) keys.push(k + "=" + JSON.stringify(first[k]).substring(0, 30));
                s += " first{" + keys.join(", ") + "}";
            }
            return s;
        }
        if (typeof v === "object") {
            var s2 = "object";
            if (typeof v.count === "number") s2 += " .count=" + v.count;
            if (typeof v.length === "number") s2 += " .length=" + v.length;
            return s2;
        }
        return typeof v;
    }

    function _logActionIds(label, actions) {
        try {
            var n = (actions && (actions.length !== undefined ? actions.length : actions.count)) || 0;
            var ids = [];
            for (var i = 0; i < n && i < 8; i++) {
                var a = (typeof actions.get === "function") ? actions.get(i) : actions[i];
                ids.push((a && a.actionId) ? String(a.actionId) : (a && a.text ? "txt:" + a.text : "<no-id>"));
            }
            console.log(label, "n=" + n, "ids=[" + ids.join(", ") + "]");
        } catch (e) {
            console.log(label, "log error:", e);
        }
    }
    // ==== END DIAGNOSTIC HELPERS ====

    // Build segregated model with apps and recent files
    function buildSegregatedModel() {
        appsWithRecentFiles.clear();
        lastFavoritesSnapshot = getFavoritesSnapshot();
        if (!modelsProcessed) {
            _probeRecentModel();
        }

        // Collect favorite IDs to avoid duplicates
        var favoriteIds = new Set();
        if (favoritesModel) {
            for (var f = 0; f < favoritesModel.count; f++) {
                try {
                    var favIndex = favoritesModel.index(f, 0);
                    var favoriteId = favoritesModel.data(favIndex, Qt.UserRole + 2) || "";
                    var favoriteUrl = favoritesModel.data(favIndex, Qt.UserRole + 1) || "";
                    var favoriteDisplay = favoritesModel.data(favIndex, Qt.DisplayRole) || "";

                    if (favoriteId) favoriteIds.add(favoriteId);
                    if (favoriteUrl) favoriteIds.add(favoriteUrl);
                    if (favoriteDisplay) favoriteIds.add(favoriteDisplay.toLowerCase());

                    if (favoriteUrl && favoriteUrl.indexOf(".desktop") !== -1) {
                        var parts = favoriteUrl.split("/");
                        var desktopFile = parts[parts.length - 1];
                        favoriteIds.add(desktopFile);
                        favoriteIds.add("applications:" + desktopFile);
                    }
                } catch (e) {
                    continue;
                }
            }
        }

        // Collect valid apps excluding favorites
        var totalApps = frequentAppsModel.count;
        var targetAppsCount = 10;
        var addedAppsCount = 0;
        var maxSearchApps = Math.min(totalApps, 50);

        for (var i = 0; i < maxSearchApps && addedAppsCount < targetAppsCount; i++) {
            try {
                var modelIndex = frequentAppsModel.index(i, 0);
                var item = {
                    display: frequentAppsModel.data(modelIndex, Qt.DisplayRole) || "",
                    decoration: frequentAppsModel.data(modelIndex, Qt.DecorationRole),
                    url: frequentAppsModel.data(modelIndex, Qt.UserRole + 1) || "",
                    favoriteId: frequentAppsModel.data(modelIndex, Qt.UserRole + 2) || "",
                    originalIndex: i
                };

                if (!isValidApplication(item)) continue;

                var launcherUrl = extractLauncherUrl(item, i);
                if (!launcherUrl) continue;

                // Check if duplicate
                var isDuplicate = false;
                if (favoriteIds.has(launcherUrl)) isDuplicate = true;
                if (!isDuplicate && item.favoriteId && favoriteIds.has(item.favoriteId)) isDuplicate = true;
                if (!isDuplicate && item.url && favoriteIds.has(item.url)) isDuplicate = true;
                if (!isDuplicate && item.display && favoriteIds.has(item.display.toLowerCase())) isDuplicate = true;

                if (!isDuplicate && item.url && item.url.indexOf(".desktop") !== -1) {
                    var parts = item.url.split("/");
                    var desktopFile = parts[parts.length - 1];
                    if (favoriteIds.has(desktopFile) || favoriteIds.has("applications:" + desktopFile)) {
                        isDuplicate = true;
                    }
                }

                if (isDuplicate) continue;

                var recentFilesCount = getRecentFilesForApp(launcherUrl);
                var hasRecentFiles = recentFilesCount > 0;
                var iconValue = (typeof item.decoration === "object" && item.decoration !== null) ? "" : item.decoration || "";

                // Get .desktop actions from model (Qt.UserRole + 9 = ActionListRole)
                var desktopActions = frequentAppsModel.data(modelIndex, Qt.UserRole + 9) || [];
                _logActionIds("[Probe.Recents.+9] " + item.display, desktopActions);
                // Also probe +2 in case actionList lives at standard AbstractModel offset
                var probeStd = frequentAppsModel.data(modelIndex, Qt.UserRole + 2);
                if (probeStd) _logActionIds("[Probe.Recents.+2] " + item.display, probeStd);

                // Merge: Add to Favorites first, then desktop actions
                var mergedActions = [];
                mergedActions.push({
                    "text": i18n("Add to Favorites"),
                    "icon": "bookmark-new",
                    "actionId": "_kicker_favorite_add",
                    "actionArgument": {
                        "favoriteModel": favoritesModel,
                        "favoriteId": launcherUrl
                    }
                });
                // Keep only real .desktop file actions; drop kicker model actions
                // (forget/forgetAll/etc.) which belong to the menu, not the app
                var filteredActions = [];
                for (var k = 0; k < desktopActions.length; k++) {
                    var act = desktopActions[k];
                    var aid = (act && act.actionId) ? String(act.actionId) : "";
                    if (aid.indexOf("forget") === -1 && aid.indexOf("_kicker_") !== 0) {
                        filteredActions.push(act);
                    }
                }
                if (filteredActions.length > 0) {
                    mergedActions.push({"type": "separator"});
                    for (var j = 0; j < filteredActions.length; j++) {
                        mergedActions.push(filteredActions[j]);
                    }
                }

                console.log("[Recents.Merge]", item.display, "→ desktop:", desktopActions.length, "merged:", mergedActions.length);

                appsWithRecentFiles.append({
                    "display": item.display,
                    "decoration": iconValue,
                    "name": item.display,
                    "icon": iconValue,
                    "url": item.url,
                    "favoriteId": item.favoriteId,
                    "launcherUrl": launcherUrl,
                    "actionList": mergedActions,
                    "originalIndex": item.originalIndex,
                    "hasActionList": true,
                    "hasRecentFiles": hasRecentFiles,
                    "recentFilesCount": recentFilesCount
                });

                addedAppsCount++;
            } catch (e) {
                continue;
            }
        }

        modelsProcessed = true;
    }

    // Execute app
    function executeItem(index) {
        try {
            if (frequentAppsModel && typeof frequentAppsModel.trigger === "function") {
                var item = appsWithRecentFiles.get(index);
                if (item && typeof item.originalIndex !== "undefined") {
                    frequentAppsModel.trigger(item.originalIndex, "", null);
                    return true;
                }
            }
        } catch (e) {
            return false;
        }
        return false;
    }


    // Show recent files menu
    function showRecentFilesMenu(index, visualParent) {
        var item = appsWithRecentFiles.get(index);
        if (!item || !item.launcherUrl) return;

        if (currentMenu) {
            currentMenu.destroy();
            currentMenu = null;
        }

        try {
            var result = getRecentFilesHelper.getRecentFilesActions(item.launcherUrl, recentsGrid);

            if (result.count > 0) {
                currentMenu = getRecentFilesHelper.createMenuFromActions(result.actions, visualParent, result.title);
                if (currentMenu) {
                    currentMenu.visualParent = visualParent;
                    currentMenu.placement = PlasmaExtras.Menu.RightPosedTopAlignedPopup;
                    currentMenu.openRelative();
                    console.log("[Recents] ✓ Menu opened for", item.display, "with", result.count, "items");
                }
            }
        } catch (e) {
            console.log("[Recents] ✗ Menu error:", e);
        }
    }

    // Handle item activation
    Connections {
        target: recentsGrid
        function onItemActivated(index, actionId, argument) {
            if (actionId && actionId.indexOf("_kicker_favorite_") === 0) {
                var item = appsWithRecentFiles.get(index);
                if (item && argument && argument.favoriteModel && argument.favoriteId) {
                    var favoriteModel = argument.favoriteModel;
                    var favoriteId = argument.favoriteId;

                    if (actionId === "_kicker_favorite_add" && typeof favoriteModel.addFavorite === "function") {
                        favoriteModel.addFavorite(favoriteId);
                        modelsProcessed = false;
                        buildSegregatedModel();
                        return;
                    }
                }
            }

            if (!actionId || actionId === "" || actionId === undefined) {
                if (executeItem(index)) {
                    recentsGrid.menuClosed();
                }
            }
        }
    }

    onSubmenuRequested: function (index, x, y) {
        var item = appsWithRecentFiles.get(index);
        if (item && item.hasRecentFiles) {
            var visualItem = null;
            for (var i = 0; i < recentsGrid.contentItem.children.length; i++) {
                var child = recentsGrid.contentItem.children[i];
                if (child.itemIndex === index) {
                    visualItem = child;
                    break;
                }
            }
            showRecentFilesMenu(index, visualItem || recentsGrid);
        }
    }

    // Keyboard navigation
    Keys.onPressed: (event) => {
        console.log("[Recents] Key pressed:", event.key, "Qt.Key_Right:", Qt.Key_Right, "currentMenu:", currentMenu);

        // Close submenu with Left or Escape
        if ((event.key === Qt.Key_Left || event.key === Qt.Key_Escape) && currentMenu) {
            console.log("[Recents] Closing submenu");
            event.accepted = true;
            currentMenu.close();
            currentMenu.destroy();
            currentMenu = null;
            recentsGrid.forceActiveFocus();
            return;
        }

        if (event.modifiers & Qt.ControlModifier || event.modifiers & Qt.ShiftModifier) {
            event.accepted = true;
            return;
        }

        // DON'T capture Key_Right here - let delegate handle it for submenus
        // DON'T capture Key_Up here - let FavoritesGridView keyNavUp signal handle it

        if (event.key === Qt.Key_Up && currentIndex < Math.floor(width / cellWidth)) {
            console.log("[Recents] KeyNavUp to Favorites");
            event.accepted = true;
            recentsGrid.keyNavUp();
        }
    }

    // Update when models change
    Connections {
        target: frequentAppsModel
        function onCountChanged() {
            modelsProcessed = false;
            Qt.callLater(buildSegregatedModel);
        }
        function onDataChanged() {
            modelsProcessed = false;
            Qt.callLater(buildSegregatedModel);
        }
    }

    // Check for favorites changes periodically
    Timer {
        id: favoritesWatcher
        interval: 1000
        running: recentsGrid.visible
        repeat: true
        onTriggered: {
            if (favoritesChanged()) {
                modelsProcessed = false;
                buildSegregatedModel();
            }
        }
    }

    Component.onCompleted: {
        buildSegregatedModel();
    }

    onVisibleChanged: {
        if (visible && favoritesChanged()) {
            modelsProcessed = false;
            Qt.callLater(buildSegregatedModel);
        }
    }
}
