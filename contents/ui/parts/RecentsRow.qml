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

    // Menu builder helper
    Functions.GetRecentFiles {
        id: getRecentFilesHelper
    }

    // Action lists kept outside the ListModel to avoid VariantMap/List
    // coercion of action.actionArgument (kicker doc actions use List/QUrl
    // arguments, our favorite actions use VariantMap).
    property var _actionListsByIndex: ({})
    property var _recentFileActionsByIndex: ({})

    function actionListForIndex(index) {
        return _actionListsByIndex[index] || [];
    }

    // State
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

    // Build segregated model with apps and recent files
    function buildSegregatedModel() {
        appsWithRecentFiles.clear();
        _actionListsByIndex = {};
        _recentFileActionsByIndex = {};
        lastFavoritesSnapshot = getFavoritesSnapshot();

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

                var iconValue = (typeof item.decoration === "object" && item.decoration !== null) ? "" : item.decoration || "";

                // Get .desktop actions from model (Qt.UserRole + 9 = ActionListRole)
                var desktopActions = frequentAppsModel.data(modelIndex, Qt.UserRole + 9) || [];

                // Classify actions: forget→drop, _kicker_recentDocument→flyout, rest→right-click
                var filteredActions = [];
                var recentFileActions = [];
                for (var k = 0; k < desktopActions.length; k++) {
                    var act = desktopActions[k];
                    var aid = (act && act.actionId) ? String(act.actionId) : "";
                    if (aid === "forget" || aid === "forgetAll" || aid === "_kicker_forgetRecentDocuments") continue;
                    filteredActions.push(act);
                    if (aid === "_kicker_recentDocument") recentFileActions.push(act);
                }

                // Build right-click action list: Add to Favorites + separator + filtered actions
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
                if (filteredActions.length > 0) {
                    mergedActions.push({"type": "separator"});
                    for (var j = 0; j < filteredActions.length; j++) {
                        mergedActions.push(filteredActions[j]);
                    }
                }

                var localIndex = appsWithRecentFiles.count;
                _actionListsByIndex[localIndex] = mergedActions;
                _recentFileActionsByIndex[localIndex] = recentFileActions;

                appsWithRecentFiles.append({
                    "display": item.display,
                    "decoration": iconValue,
                    "name": item.display,
                    "icon": iconValue,
                    "url": item.url,
                    "favoriteId": item.favoriteId,
                    "launcherUrl": launcherUrl,
                    "originalIndex": item.originalIndex,
                    "hasActionList": true,
                    "hasRecentFiles": recentFileActions.length > 0,
                    "recentFilesCount": recentFileActions.length
                });

                addedAppsCount++;
            } catch (e) {
                continue;
            }
        }
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
        if (!item) return;

        var srcActions = _recentFileActionsByIndex[index] || [];
        if (srcActions.length === 0) return;

        if (currentMenu) {
            currentMenu.destroy();
            currentMenu = null;
        }

        try {
            var originalIndex = item.originalIndex;
            var actions = [];
            for (var i = 0; i < srcActions.length; i++) {
                (function(srcAction) {
                    actions.push({
                        text: srcAction.text || "",
                        icon: srcAction.icon || "document-open-recent",
                        trigger: function() {
                            if (typeof frequentAppsModel.trigger === "function") {
                                var closeRequested = frequentAppsModel.trigger(originalIndex, "_kicker_recentDocument", srcAction.actionArgument);
                                if (closeRequested) recentsGrid.menuClosed();
                            }
                        }
                    });
                })(srcActions[i]);
            }

            currentMenu = getRecentFilesHelper.createMenuFromActions(actions, visualParent, i18n("Recent Files"));
            if (currentMenu) {
                currentMenu.visualParent = visualParent;
                currentMenu.placement = PlasmaExtras.Menu.RightPosedTopAlignedPopup;
                currentMenu.openRelative();
            }
        } catch (e) {
            console.log("[Recents] Menu error:", e);
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
        // Close submenu with Left or Escape
        if ((event.key === Qt.Key_Left || event.key === Qt.Key_Escape) && currentMenu) {
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

        if (event.key === Qt.Key_Up && currentIndex < Math.floor(width / cellWidth)) {
            event.accepted = true;
            recentsGrid.keyNavUp();
        }
    }

    // Update when models change
    Connections {
        target: frequentAppsModel
        function onCountChanged() {
            Qt.callLater(buildSegregatedModel);
        }
        function onDataChanged() {
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
                buildSegregatedModel();
            }
        }
    }

    Component.onCompleted: {
        buildSegregatedModel();
    }

    onVisibleChanged: {
        if (visible && favoritesChanged()) {
            Qt.callLater(buildSegregatedModel);
        }
    }
}
