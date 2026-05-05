/*
 *  SPDX-FileCopyrightText: 2025 Walter Rodrigues <wmr2@cin.ufpe.br>
 *  SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick 2.4
import org.kde.plasma.extras 2.0 as PlasmaExtras
import "../functions" as Functions

/**
 * Recent File Flyout Component
 * Displays a flyout menu with recent files/places for an application
 */
QtObject {
    id: recentFileFlyout

    // Properties
    property var parentItem: null
    property QtObject currentMenu: null

    // Get Recent Files Helper
    Functions.GetRecentFiles {
        id: getRecentFilesHelper
    }

    /**
     * Show recent files menu for an application
     * @param launcherUrl - Application launcher URL (e.g., "applications:firefox.desktop")
     * @param visualParent - Visual parent item for menu positioning
     */
    function show(launcherUrl, visualParent) {
        if (!launcherUrl) return;

        // Destroy previous menu
        if (currentMenu) {
            currentMenu.destroy();
            currentMenu = null;
        }

        try {
            var result = getRecentFilesHelper.getRecentFilesActions(launcherUrl, visualParent);

            if (result.count > 0) {
                currentMenu = getRecentFilesHelper.createMenuFromActions(result.actions, visualParent, result.title);
                if (currentMenu) {
                    currentMenu.visualParent = visualParent;
                    currentMenu.placement = PlasmaExtras.Menu.RightPosedTopAlignedPopup;
                    currentMenu.openRelative();
                    return true;
                }
            }
            return false;
        } catch (e) {
            console.log("[RecentFileFlyout] ✗ Error:", e);
            return false;
        }
    }

    /**
     * Close the current menu
     */
    function close() {
        if (currentMenu) {
            currentMenu.close();
            currentMenu.destroy();
            currentMenu = null;
        }
    }

    /**
     * Check if menu is currently open
     */
    function isOpen() {
        return currentMenu !== null;
    }
}
