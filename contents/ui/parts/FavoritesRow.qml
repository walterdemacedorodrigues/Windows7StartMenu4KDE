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

    // Get Recent Files Helper
    Functions.GetRecentFiles {
        id: getRecentFilesHelper
    }

    // Show recent files menu for a favorite item
    function showRecentFilesMenu(favoriteUrl, visualParent) {
        if (!favoriteUrl) return;

        // Destroy previous menu
        if (currentMenu) {
            currentMenu.destroy();
            currentMenu = null;
        }

        try {
            var result = getRecentFilesHelper.getRecentFilesActions(favoriteUrl, favoritesGrid);

            if (result.count > 0) {
                currentMenu = getRecentFilesHelper.createMenuFromActions(result.actions, visualParent, result.title);
                if (currentMenu) {
                    currentMenu.visualParent = visualParent;
                    currentMenu.placement = PlasmaExtras.Menu.RightPosedTopAlignedPopup;
                    currentMenu.openRelative();
                }
            }
        } catch (e) {
            // Handle errors silently
        }
    }


    // Update recent files count for favorites
    function updateRecentFilesCount() {
        console.log("[Favorites.updateRecentFilesCount] ===== START =====");
        if (!model) {
            console.log("[Favorites.updateRecentFilesCount] No model!");
            return;
        }

        console.log("[Favorites.updateRecentFilesCount] Processing", model.count, "favorites");

        for (var f = 0; f < model.count; f++) {
            try {
                var favoriteUrl = getRecentFilesHelper.extractFavoriteLauncherUrl(model, f);
                var favoriteDisplay = model.data(model.index(f, 0), Qt.DisplayRole) || "";

                console.log("[Favorites.updateRecentFilesCount] [" + f + "]", favoriteDisplay, "URL:", favoriteUrl);

                if (favoriteUrl) {
                    var totalCount = getRecentFilesHelper.getRecentFilesCount(favoriteUrl, favoritesGrid);
                    var hasRecentFiles = totalCount > 0;

                    console.log("[Favorites.updateRecentFilesCount] [" + f + "]", favoriteDisplay, "→ hasRecentFiles:", hasRecentFiles, "count:", totalCount);

                    if (typeof model.setData === "function") {
                        var favIndex = model.index(f, 0);
                        var setResult1 = model.setData(favIndex, hasRecentFiles, Qt.UserRole + 10);
                        var setResult2 = model.setData(favIndex, totalCount, Qt.UserRole + 11);
                        console.log("[Favorites.updateRecentFilesCount] [" + f + "] setData results:", setResult1, setResult2);

                        // Verify it was set
                        var verifyHasRecent = model.data(favIndex, Qt.UserRole + 10);
                        console.log("[Favorites.updateRecentFilesCount] [" + f + "] Verify hasRecentFiles after setData:", verifyHasRecent);
                    } else {
                        console.log("[Favorites.updateRecentFilesCount] model.setData is NOT a function!");
                    }
                } else {
                    console.log("[Favorites.updateRecentFilesCount] [" + f + "] No valid URL found for", favoriteDisplay);
                }
            } catch (e) {
                console.log("[Favorites.updateRecentFilesCount] Exception:", e);
                continue;
            }
        }

        console.log("[Favorites.updateRecentFilesCount] ===== END =====");
    }

    // Grid configuration
    focus: true
    width: parent.width

    // Handle item activation
    Connections {
        target: favoritesGrid
        function onItemActivated(index, actionId, argument) {
            if (!actionId || actionId === "") {
                favoritesGrid.menuClosed();
            }
        }

        function onSubmenuRequested(index, x, y) {
            if (model) {
                var favoriteUrl = getRecentFilesHelper.extractFavoriteLauncherUrl(model, index);

                if (favoriteUrl) {
                    var visualItem = null;
                    for (var i = 0; i < favoritesGrid.contentItem.children.length; i++) {
                        var child = favoritesGrid.contentItem.children[i];
                        if (child.itemIndex === index) {
                            visualItem = child;
                            break;
                        }
                    }

                    console.log("[Favorites] ✓ Opening submenu for index:", index);
                    showRecentFilesMenu(favoriteUrl, visualItem || favoritesGrid);
                }
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

    // Update recent files when model changes
    onModelChanged: {
        if (model) {
            Qt.callLater(updateRecentFilesCount);
        }
    }

    Component.onCompleted: {
        updateRecentFilesCount();
    }
}
