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

    // Menu builder helper
    Functions.GetRecentFiles {
        id: getRecentFilesHelper
    }

    // Recent file actions extracted from kicker actionList,
    // keyed by local model index. Kept outside the ListModel to avoid
    // VariantMap/List coercion of action.actionArgument.
    property var _recentFileActionsByIndex: ({})

    // Execute favorite app
    function executeItem(index) {
        try {
            if (externalFavoritesModel && typeof externalFavoritesModel.trigger === "function") {
                var item = favoritesWithRecentFiles.get(index);
                if (item && typeof item.originalIndex !== "undefined") {
                    externalFavoritesModel.trigger(item.originalIndex, "", null);
                    return true;
                }
            }
        } catch (e) {
            return false;
        }
        return false;
    }

    // Build local model with recent files data
    function buildFavoritesModel() {
        favoritesWithRecentFiles.clear();
        _recentFileActionsByIndex = {};

        if (!externalFavoritesModel) return;

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

                var iconValue = (typeof decoration === "object" && decoration !== null) ? "" : decoration || "";

                // Get .desktop actions from model (Qt.UserRole + 9 = ActionListRole)
                var desktopActions = externalFavoritesModel.data(favIndex, Qt.UserRole + 9) || [];

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

                // Build right-click action list: Remove from Favorites + separator + filtered actions
                var mergedActions = [];
                mergedActions.push({
                    "text": i18n("Remove from Favorites"),
                    "icon": "bookmark-remove",
                    "actionId": "_kicker_favorite_remove",
                    "actionArgument": {
                        "favoriteModel": externalFavoritesModel,
                        "favoriteId": launcherUrl || favoriteId
                    }
                });
                if (filteredActions.length > 0) {
                    mergedActions.push({"type": "separator"});
                    for (var j = 0; j < filteredActions.length; j++) {
                        mergedActions.push(filteredActions[j]);
                    }
                }

                var localIndex = favoritesWithRecentFiles.count;
                _recentFileActionsByIndex[localIndex] = recentFileActions;

                favoritesWithRecentFiles.append({
                    "display": display,
                    "decoration": iconValue,
                    "name": display,
                    "icon": iconValue,
                    "url": url,
                    "favoriteId": favoriteId,
                    "launcherUrl": launcherUrl,
                    "actionList": mergedActions,
                    "hasRecentFiles": recentFileActions.length > 0,
                    "recentFilesCount": recentFileActions.length,
                    "hasActionList": true,
                    "originalIndex": i
                });
            } catch (e) {
                continue;
            }
        }
    }

    // Show recent files menu for a favorite item
    function showRecentFilesMenu(index, visualParent) {
        var item = favoritesWithRecentFiles.get(index);
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
                            if (externalFavoritesModel && typeof externalFavoritesModel.trigger === "function") {
                                var closeRequested = externalFavoritesModel.trigger(originalIndex, "_kicker_recentDocument", srcAction.actionArgument);
                                if (closeRequested) favoritesGrid.menuClosed();
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
            console.log("[Favorites] Menu error:", e);
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

            if (!actionId || actionId === "" || actionId === undefined) {
                if (executeItem(index)) {
                    favoritesGrid.menuClosed();
                }
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
                showRecentFilesMenu(index, visualItem || favoritesGrid);
            }
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
            favoritesGrid.forceActiveFocus();
            return;
        }

        if (event.modifiers & Qt.ControlModifier || event.modifiers & Qt.ShiftModifier) {
            event.accepted = true;
            return;
        }

        if (event.key === Qt.Key_Down && currentIndex >= (count - Math.floor(width / cellWidth))) {
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