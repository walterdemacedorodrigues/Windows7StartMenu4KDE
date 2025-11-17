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

    // Recent Files Helper
    Functions.RecentFiles {
        id: recentFilesHelper
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
            var result = recentFilesHelper.getRecentFilesActions(favoriteUrl, favoritesGrid);

            if (result.count > 0) {
                currentMenu = recentFilesHelper.createMenuFromActions(result.actions, visualParent, result.title);
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
        if (!model) return;

        for (var f = 0; f < model.count; f++) {
            try {
                var favoriteUrl = recentFilesHelper.extractFavoriteLauncherUrl(model, f);
                var favoriteDisplay = model.data(model.index(f, 0), Qt.DisplayRole) || "";

                if (favoriteUrl) {
                    var totalCount = recentFilesHelper.getRecentFilesCount(favoriteUrl, favoritesGrid);
                    var hasRecentFiles = totalCount > 0;

                    if (hasRecentFiles) {
                        console.log("[Favorites] ✓", favoriteDisplay, "has", totalCount, "recent files");
                    }

                    if (typeof model.setData === "function") {
                        var favIndex = model.index(f, 0);
                        model.setData(favIndex, hasRecentFiles, Qt.UserRole + 10);
                        model.setData(favIndex, totalCount, Qt.UserRole + 11);
                    }
                }
            } catch (e) {
                continue;
            }
        }
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
                var favIndex = model.index(index, 0);
                var favoriteUrl = model.data(favIndex, Qt.UserRole + 1) || "";

                if (favoriteUrl) {
                    var visualItem = null;
                    for (var i = 0; i < favoritesGrid.contentItem.children.length; i++) {
                        var child = favoritesGrid.contentItem.children[i];
                        if (child.itemIndex === index) {
                            visualItem = child;
                            break;
                        }
                    }

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
