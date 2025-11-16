/*
 *  SPDX-FileCopyrightText: 2025 Walter Rodrigues <wmr2@cin.ufpe.br>
 *  SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick 2.4
import org.kde.plasma.extras 2.0 as PlasmaExtras
import org.kde.plasma.private.kicker 0.1 as Kicker
import org.kde.plasma.private.taskmanager as TaskManagerApplet
import ".."

/**
 * Recent/Frequent apps grid component for the Windows 7 Start Menu
 * Displays most used applications with recent files support
 */
FavoritesGridView {
    id: recentsGrid

    // Properties
    property int cellHeight: 48
    property int cellWidth: width
    property int iconSize: 32
    property var favoritesModel: null
    property alias taskManagerBackend: taskManagerBackend

    // Signals (keyNavUp already defined in FavoritesGridView)
    signal menuClosed()

    // Debug logging
    onWidthChanged: {
        console.log("[Recents] width changed:", width, "cellWidth:", cellWidth, "columns:", Math.floor(width / cellWidth));
    }
    onCellWidthChanged: {
        console.log("[Recents] cellWidth changed:", cellWidth, "width:", width, "columns:", Math.floor(width / cellWidth));
    }

    // Models
    Kicker.RecentUsageModel {
        id: frequentAppsModel
        ordering: 1 // Popular / Frequently Used
    }

    ListModel {
        id: appsWithRecentFiles
    }

    TaskManagerApplet.Backend {
        id: taskManagerBackend
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
        if (!launcherUrl || !taskManagerBackend) return 0;

        try {
            var recentActions = taskManagerBackend.recentDocumentActions(launcherUrl, recentsGrid);
            var placesActions = taskManagerBackend.placesActions(launcherUrl, false, recentsGrid);

            var totalCount = 0;
            if (recentActions && recentActions.length > 0) totalCount += recentActions.length;
            if (placesActions && placesActions.length > 0) totalCount += placesActions.length;

            return totalCount;
        } catch (e) {
            return 0;
        }
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

                var recentFilesCount = getRecentFilesForApp(launcherUrl);
                var hasRecentFiles = recentFilesCount > 0;
                var iconValue = (typeof item.decoration === "object" && item.decoration !== null) ? "" : item.decoration || "";

                appsWithRecentFiles.append({
                    "display": item.display,
                    "decoration": iconValue,
                    "name": item.display,
                    "icon": iconValue,
                    "url": item.url,
                    "favoriteId": item.favoriteId,
                    "launcherUrl": launcherUrl,
                    "actionList": [
                        {
                            "text": i18n("Add to Favorites"),
                            "icon": "bookmark-new",
                            "actionId": "_kicker_favorite_add",
                            "actionArgument": {
                                "favoriteModel": favoritesModel,
                                "favoriteId": launcherUrl
                            }
                        }
                    ],
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

    // Create menu from actions
    function createMenuFromActions(actions, parent, title) {
        var menu = Qt.createQmlObject(`
            import org.kde.plasma.extras 2.0 as PlasmaExtras
            PlasmaExtras.Menu {
                placement: PlasmaExtras.Menu.RightPosedTopAlignedPopup
            }
        `, parent);

        if (!menu) return null;

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

    // Show recent files menu
    function showRecentFilesMenu(index, visualParent) {
        var item = appsWithRecentFiles.get(index);
        if (!item || !item.launcherUrl) return;

        if (currentMenu) {
            currentMenu.destroy();
            currentMenu = null;
        }

        try {
            var recentActions = taskManagerBackend.recentDocumentActions(item.launcherUrl, recentsGrid);
            var placesActions = taskManagerBackend.placesActions(item.launcherUrl, false, recentsGrid);

            var allActions = [];
            var menuTitle = "";

            if (placesActions && placesActions.length > 0) {
                allActions = placesActions;
                menuTitle = i18n("Recent Places");
            } else if (recentActions && recentActions.length > 0) {
                allActions = recentActions;
                menuTitle = i18n("Recent Files");
            }

            currentMenu = createMenuFromActions(allActions, visualParent, menuTitle);
            if (currentMenu) {
                currentMenu.visualParent = visualParent;
                currentMenu.placement = PlasmaExtras.Menu.RightPosedTopAlignedPopup;
                currentMenu.openRelative();
            }
        } catch (e) {
            // Handle errors silently
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
