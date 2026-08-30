/*
 *  SPDX-FileCopyrightText: 2025 Walter Rodrigues <wmr2@cin.ufpe.br>
 *  SPDX-License-Identifier: AGPL-3.0-or-later
 */

import QtQuick 2.4
import org.kde.plasma.plasmoid 2.0
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
        // Without this the query is shared with folders and documents, which
        // crowded the list down to a handful of applications.
        shownItems: Kicker.RecentUsageModel.OnlyApps
    }

    ListModel {
        id: appsWithRecentFiles
        // actionList holds heterogeneous action objects, so role types must stay dynamic.
        dynamicRoles: true
    }

    Functions.ModelRoles {
        id: appsReader
        sourceModel: frequentAppsModel
    }

    Functions.ModelRoles {
        id: favoritesReader
        sourceModel: favoritesModel
    }

    // Get Recent Files Helper
    Functions.GetRecentFiles {
        id: getRecentFilesHelper
    }

    // State
    property var lastFavoritesSnapshot: []

    // Grid configuration
    width: parent.width
    model: appsWithRecentFiles
    actionModel: frequentAppsModel

    // Get favorites snapshot for change detection
    function getFavoritesSnapshot() {
        var snapshot = [];
        if (favoritesModel) {
            for (var f = 0; f < favoritesModel.count; f++) {
                try {
                    var favEntry = favoritesReader.row(f);
                    var favoriteUrl = favEntry ? favEntry.roleUrl : "";
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
    function extractLauncherUrl(modelItem) {
        if (!modelItem) return "";

        var favoriteId = modelItem.favoriteId || "";
        if (favoriteId && favoriteId.indexOf(".desktop") !== -1) {
            return favoriteId.indexOf("applications:") === 0 ? favoriteId : "applications:" + favoriteId;
        }

        var url = modelItem.url || "";
        if (url && url.indexOf(".desktop") !== -1) return url;

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
        // group is the section header Kicker assigns, never an identifier
        var group = modelItem.group || "";

        if (!display || display.trim() === "") return false;
        if (group === "Pastas" || group === "Folders" || group === "Arquivos") return false;
        if (group === "Aplicativos" || group === "Applications") return true;
        if (url && url.toLowerCase().indexOf(".desktop") !== -1) return true;
        if (display.length < 2) return false;
        if (/^[0-9\W]+$/.test(display)) return false;
        if (display.length >= 8 && /^[0-9A-F]+$/i.test(display)) return false;

        return true;
    }

    // Build segregated model with apps and recent files
    function buildSegregatedModel() {
        appsWithRecentFiles.clear();
        lastFavoritesSnapshot = getFavoritesSnapshot();

        // Collect favorite IDs to avoid duplicates
        var favoriteIds = new Set();
        if (favoritesModel) {
            for (var f = 0; f < favoritesModel.count; f++) {
                try {
                    var favEntry = favoritesReader.row(f);
                    if (!favEntry) continue;

                    var favoriteId = favEntry.roleFavoriteId;
                    var favoriteUrl = favEntry.roleUrl;
                    var favoriteDisplay = favEntry.roleDisplay;

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
        var targetAppsCount = Plasmoid.configuration.numberRecentApps;
        var addedAppsCount = 0;
        var maxSearchApps = Math.min(totalApps, 50);

        for (var i = 0; i < maxSearchApps && addedAppsCount < targetAppsCount; i++) {
            try {
                var entry = appsReader.row(i);
                if (!entry) continue;

                var item = {
                    display: entry.roleDisplay,
                    decoration: entry.roleDecoration,
                    url: entry.roleUrl,
                    favoriteId: entry.roleFavoriteId,
                    group: entry.roleGroup,
                    originalIndex: i
                };

                if (!isValidApplication(item)) continue;

                var launcherUrl = extractLauncherUrl(item);
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

                var desktopActions = entry.roleActionList;

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
                // Keep only real .desktop file actions; drop forget-related kicker actions
                var filteredActions = [];
                for (var k = 0; k < desktopActions.length; k++) {
                    var act = desktopActions[k];
                    var aid = (act && act.actionId) ? String(act.actionId) : "";
                    if (aid !== "forget" && aid !== "forgetAll" && aid !== "_kicker_forgetRecentDocuments") {
                        filteredActions.push(act);
                    }
                }
                if (filteredActions.length > 0) {
                    mergedActions.push({"type": "separator"});
                    for (var j = 0; j < filteredActions.length; j++) {
                        mergedActions.push(filteredActions[j]);
                    }
                }


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
    readonly property bool jumpOpen: jumpList.opened
    property int jumpIndex: -1

    JumpListFlyout {
        id: jumpList
        onItemTriggered: recentsGrid.menuClosed()
        onActionRequested: (actionId, actionArgument) => {
            if (recentsGrid.jumpIndex >= 0) recentsGrid.runAction(recentsGrid.jumpIndex, actionId, actionArgument);
        }
    }

    function showRecentFilesMenu(index, visualParent) {
        const item = appsWithRecentFiles.get(index);
        if (!item || !item.launcherUrl) return;
        jumpIndex = index;
        if (jumpList.opened) jumpList.close();
        const result = getRecentFilesHelper.getRecentFilesActions(item.launcherUrl, recentsGrid);
        if (!result || result.count <= 0) return;
        jumpList.openFor(visualParent, result.actions, result.title);
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
        if ((event.key === Qt.Key_Left || event.key === Qt.Key_Escape) && jumpList.opened) {
            event.accepted = true;
            jumpList.close();
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
            event.accepted = true;
            recentsGrid.keyNavUp();
        }
    }

    // Update when models change
    Connections {
        target: Plasmoid.configuration
        function onNumberRecentAppsChanged() { Qt.callLater(buildSegregatedModel); }
    }

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
