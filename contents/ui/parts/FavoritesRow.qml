/*
 *  SPDX-FileCopyrightText: 2025 Walter Rodrigues <wmr2@cin.ufpe.br>
 *  SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick 2.4
import org.kde.plasma.extras 2.0 as PlasmaExtras
import ".."
import "../functions" as Functions

/**
 * Favorites grid component for the Windows 7 Start Menu
 * Displays user's favorite applications with recent files support
 */
FavoritesGridView {
    id: favoritesGrid

    // Properties
    property bool dragEnabled: true
    property bool dropEnabled: true
    // cellWidth and cellHeight are aliases in FavoritesGridView - don't override them
    property int iconSize: 32

    // Signals (keyNavDown already defined in FavoritesGridView)
    signal menuClosed()

    // Current menu reference
    property QtObject currentMenu: null

    // External model reference (set by parent)
    property var externalFavoritesModel: null

    // Local model with recent files data
    ListModel {
        id: favoritesWithRecentFiles
    }

    // Get Recent Files Helper
    Functions.GetRecentFiles {
        id: getRecentFilesHelper
    }

    // Build local model with recent files data
    function buildFavoritesModel() {
        favoritesWithRecentFiles.clear();

        if (!externalFavoritesModel) {
            console.log("[Favorites] No external model");
            return;
        }

        console.log("[Favorites] Building model from", externalFavoritesModel.count, "favorites");

        for (var i = 0; i < externalFavoritesModel.count; i++) {
            try {
                var favIndex = externalFavoritesModel.index(i, 0);

                // Extract data from external model
                var display = externalFavoritesModel.data(favIndex, Qt.DisplayRole) || "";
                var decoration = externalFavoritesModel.data(favIndex, Qt.DecorationRole);
                var favoriteId = externalFavoritesModel.data(favIndex, Qt.UserRole + 2) || "";
                var url = externalFavoritesModel.data(favIndex, Qt.UserRole + 1) || "";

                // Extract launcher URL (with "applications:" prefix)
                var desktopFile = externalFavoritesModel.data(favIndex, Qt.UserRole + 3) || "";
                var launcherUrl = "";

                if (desktopFile && desktopFile.indexOf(".desktop") !== -1) {
                    launcherUrl = "applications:" + desktopFile;
                } else if (url && url.indexOf(".desktop") !== -1) {
                    launcherUrl = url;
                } else if (favoriteId && favoriteId.indexOf(".desktop") !== -1) {
                    launcherUrl = favoriteId.indexOf("applications:") === 0 ? favoriteId : "applications:" + favoriteId;
                }

                // Get recent files info
                var recentFilesCount = 0;
                var hasRecentFiles = false;
                if (launcherUrl) {
                    recentFilesCount = getRecentFilesHelper.getRecentFilesCount(launcherUrl, favoritesGrid);
                    hasRecentFiles = recentFilesCount > 0;
                }

                var iconValue = (typeof decoration === "object" && decoration !== null) ? "" : decoration || "";

                // Get .desktop actions from model (Qt.UserRole + 9 = ActionListRole)
                var desktopActions = externalFavoritesModel.data(favIndex, Qt.UserRole + 9) || [];

                // Append to local model
                favoritesWithRecentFiles.append({
                    "display": display,
                    "decoration": iconValue,
                    "name": display,
                    "icon": iconValue,
                    "url": url,
                    "favoriteId": favoriteId,
                    "launcherUrl": launcherUrl,
                    "actionList": desktopActions,
                    "hasRecentFiles": hasRecentFiles,
                    "recentFilesCount": recentFilesCount,
                    "hasActionList": true,
                    "originalIndex": i
                });

                console.log("[Favorites] [" + i + "]", display, "→ hasRecentFiles:", hasRecentFiles, "count:", recentFilesCount);
            } catch (e) {
                console.log("[Favorites] Error processing favorite", i, ":", e);
                continue;
            }
        }

        console.log("[Favorites] Model built with", favoritesWithRecentFiles.count, "items");
    }

    // Show recent files menu for a favorite item
    function showRecentFilesMenu(index, visualParent) {
        var item = favoritesWithRecentFiles.get(index);
        if (!item || !item.launcherUrl) return;

        // Destroy previous menu
        if (currentMenu) {
            currentMenu.destroy();
            currentMenu = null;
        }

        try {
            var result = getRecentFilesHelper.getRecentFilesActions(item.launcherUrl, favoritesGrid);

            if (result.count > 0) {
                currentMenu = getRecentFilesHelper.createMenuFromActions(result.actions, visualParent, result.title);
                if (currentMenu) {
                    currentMenu.visualParent = visualParent;
                    currentMenu.placement = PlasmaExtras.Menu.RightPosedTopAlignedPopup;
                    currentMenu.openRelative();
                    console.log("[Favorites] ✓ Menu opened for", item.display, "with", result.count, "items");
                }
            }
        } catch (e) {
            console.log("[Favorites] ✗ Menu error:", e);
        }
    }

    // Grid configuration
    focus: true
    width: parent.width
    model: favoritesWithRecentFiles

    // Handle item activation
    Connections {
        target: favoritesGrid
        function onItemActivated(index, actionId, argument) {
            if (actionId && actionId.indexOf("_kicker_favorite_") === 0) {
                var item = favoritesWithRecentFiles.get(index);
                if (item && argument && argument.favoriteModel && argument.favoriteId) {
                    var favoriteModel = argument.favoriteModel;
                    var favoriteId = argument.favoriteId;

                    if (actionId === "_kicker_favorite_remove" && typeof favoriteModel.removeFavorite === "function") {
                        favoriteModel.removeFavorite(favoriteId);
                        buildFavoritesModel();
                        return;
                    }
                }
            }

            if (!actionId || actionId === "") {
                favoritesGrid.menuClosed();
            }
        }

        function onSubmenuRequested(index, x, y) {
            var item = favoritesWithRecentFiles.get(index);
            if (item && item.hasRecentFiles) {
                var visualItem = null;
                for (var i = 0; i < favoritesGrid.contentItem.children.length; i++) {
                    var child = favoritesGrid.contentItem.children[i];
                    if (child.itemIndex === index) {
                        visualItem = child;
                        break;
                    }
                }

                console.log("[Favorites] ✓ Opening submenu for index:", index);
                showRecentFilesMenu(index, visualItem || favoritesGrid);
            }
        }
    }

    // Keyboard navigation
    Keys.onPressed: (event) => {
        console.log("[Favorites] Key pressed:", event.key, "Qt.Key_Right:", Qt.Key_Right, "currentMenu:", currentMenu);

        // Close submenu with Left or Escape
        if ((event.key === Qt.Key_Left || event.key === Qt.Key_Escape) && currentMenu) {
            console.log("[Favorites] Closing submenu");
            event.accepted = true;
            currentMenu.close();
            currentMenu.destroy();
            currentMenu = null;
            favoritesGrid.forceActiveFocus();
            return;
        }

        if (event.modifiers & Qt.ControlModifier || event.modifiers & Qt.ShiftModifier) {
            event.accepted = true;
            return;
        }

        // DON'T capture Key_Right here - let delegate handle it for submenus
        // DON'T capture Key_Up here - let FavoritesGridView keyNavUp signal handle it

        if (event.key === Qt.Key_Down && currentIndex >= (count - Math.floor(width / cellWidth))) {
            console.log("[Favorites] KeyNavDown to Recents");
            event.accepted = true;
            favoritesGrid.keyNavDown();
        }
    }

    // Watch external model for changes
    onExternalFavoritesModelChanged: {
        if (externalFavoritesModel) {
            Qt.callLater(buildFavoritesModel);
        }
    }

    // Watch for external model count changes
    Connections {
        target: externalFavoritesModel
        function onCountChanged() {
            Qt.callLater(buildFavoritesModel);
        }
        function onDataChanged() {
            Qt.callLater(buildFavoritesModel);
        }
    }

    Component.onCompleted: {
        if (externalFavoritesModel) {
            buildFavoritesModel();
        }
    }
}
