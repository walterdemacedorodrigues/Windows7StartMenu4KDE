/*
 *  SPDX-FileCopyrightText: 2025 Walter Rodrigues <wmr2@cin.ufpe.br>
 *  SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick 2.4
import org.kde.plasma.extras 2.0 as PlasmaExtras
import org.kde.plasma.private.taskmanager as TaskManagerApplet

/**
 * Get Recent Files Helper Component
 * Centralizes all logic for managing recent files/places per application
 */
QtObject {
    id: getRecentFilesHelper

    // Required: TaskManager backend for accessing recent files
    property var taskManagerBackend: TaskManagerApplet.Backend {}

    /**
     * Get the count of recent files/places for an application
     * @param launcherUrl - Application launcher URL (e.g., "applications:firefox.desktop")
     * @param parentItem - Parent QML item for context
     * @return Number of recent files/places available
     */
    function getRecentFilesCount(launcherUrl, parentItem) {
        if (!launcherUrl || !taskManagerBackend) return 0;

        try {
            var recentActions = taskManagerBackend.recentDocumentActions(launcherUrl, parentItem);
            var placesActions = taskManagerBackend.placesActions(launcherUrl, false, parentItem);

            var totalCount = 0;
            if (recentActions && recentActions.length > 0) totalCount += recentActions.length;
            if (placesActions && placesActions.length > 0) totalCount += placesActions.length;

            return totalCount;
        } catch (e) {
            return 0;
        }
    }

    /**
     * Get recent files/places actions for an application
     * @param launcherUrl - Application launcher URL
     * @param parentItem - Parent QML item for context
     * @return Object with { actions: [], title: "", count: 0 }
     */
    function getRecentFilesActions(launcherUrl, parentItem) {
        var result = {
            actions: [],
            title: "",
            count: 0
        };

        if (!launcherUrl || !taskManagerBackend) return result;

        try {
            var recentActions = taskManagerBackend.recentDocumentActions(launcherUrl, parentItem);
            var placesActions = taskManagerBackend.placesActions(launcherUrl, false, parentItem);

            // Prioritize places for apps like Dolphin, otherwise use recent documents
            if (placesActions && placesActions.length > 0) {
                result.actions = placesActions;
                result.title = i18n("Recent Places");
                result.count = placesActions.length;
            } else if (recentActions && recentActions.length > 0) {
                result.actions = recentActions;
                result.title = i18n("Recent Files");
                result.count = recentActions.length;
            }

            return result;
        } catch (e) {
            return result;
        }
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

    /**
     * Extract the correct launcher URL from a favorites model item
     * @param favoritesModel - The favorites model
     * @param index - Model index
     * @return Launcher URL string or empty string
     */
    function extractFavoriteLauncherUrl(favoritesModel, index) {
        if (!favoritesModel) return "";

        try {
            var favIndex = favoritesModel.index(index, 0);

            // Try different UserRoles to find the correct URL
            var url1 = favoritesModel.data(favIndex, Qt.UserRole + 1) || "";
            var url2 = favoritesModel.data(favIndex, Qt.UserRole + 2) || "";
            var url3 = favoritesModel.data(favIndex, Qt.UserRole + 3) || "";

            // Return the one that looks like a valid application URL
            if (url2 && url2.indexOf("applications:") === 0) {
                return url2;
            } else if (url1 && url1.indexOf("applications:") === 0) {
                return url1;
            } else if (url3 && url3.indexOf("applications:") === 0) {
                return url3;
            }

            return "";
        } catch (e) {
            return "";
        }
    }
}
