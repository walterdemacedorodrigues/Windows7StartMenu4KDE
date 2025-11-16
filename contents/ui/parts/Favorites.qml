/*
 *  SPDX-FileCopyrightText: 2025 Walter Rodrigues <wmr2@cin.ufpe.br>
 *  SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick 2.4
import org.kde.plasma.extras 2.0 as PlasmaExtras
import org.kde.plasma.private.taskmanager as TaskManagerApplet
import ".."

/**
 * Favorites grid component for the Windows 7 Start Menu
 * Displays user's favorite applications with recent files support
 */
FavoritesGridView {
    id: favoritesGrid

    // Properties
    property bool dragEnabled: true
    property bool dropEnabled: true
    property int cellHeight: 48
    property int cellWidth: width
    property int iconSize: 32
    property alias taskManagerBackend: taskManagerBackend

    // Signals
    signal keyNavDown()
    signal menuClosed()

    // Current menu reference
    property QtObject currentMenu: null

    // TaskManager backend for recent files
    TaskManagerApplet.Backend {
        id: taskManagerBackend
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
            var recentActions = taskManagerBackend.recentDocumentActions(favoriteUrl, favoritesGrid);
            var placesActions = taskManagerBackend.placesActions(favoriteUrl, false, favoritesGrid);

            var allActions = [];
            var menuTitle = "";

            if (placesActions && placesActions.length > 0) {
                allActions = placesActions;
                menuTitle = i18n("Recent Places");
            } else if (recentActions && recentActions.length > 0) {
                allActions = recentActions;
                menuTitle = i18n("Recent Files");
            }

            if (allActions.length > 0) {
                currentMenu = createMenuFromActions(allActions, visualParent, menuTitle);
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

    // Create menu from actions
    function createMenuFromActions(actions, parent, title) {
        var menu = Qt.createQmlObject(`
            import org.kde.plasma.extras 2.0 as PlasmaExtras
            PlasmaExtras.Menu {
                placement: PlasmaExtras.Menu.RightPosedTopAlignedPopup
            }
        `, parent);

        if (!menu) return null;

        // Add title
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

    // Update recent files count for favorites
    function updateRecentFilesCount() {
        if (!model) return;

        for (var f = 0; f < model.count; f++) {
            try {
                var favIndex = model.index(f, 0);
                var favoriteUrl = model.data(favIndex, Qt.UserRole + 1) || "";

                if (favoriteUrl) {
                    var recentActions = taskManagerBackend.recentDocumentActions(favoriteUrl, favoritesGrid);
                    var placesActions = taskManagerBackend.placesActions(favoriteUrl, false, favoritesGrid);

                    var totalCount = 0;
                    if (recentActions) totalCount += recentActions.length;
                    if (placesActions) totalCount += placesActions.length;

                    var hasRecentFiles = totalCount > 0;

                    if (typeof model.setData === "function") {
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
        if (event.modifiers & Qt.ControlModifier || event.modifiers & Qt.ShiftModifier) {
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Down && currentIndex >= (count - Math.floor(width / cellWidth))) {
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
