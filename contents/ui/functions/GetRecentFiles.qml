/*
 *  SPDX-FileCopyrightText: 2025 Walter Rodrigues <wmr2@cin.ufpe.br>
 *  SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick 2.4
import org.kde.plasma.extras 2.0 as PlasmaExtras

/**
 * Helper that builds a PlasmaExtras.Menu from a list of action objects.
 * Each action must expose: text, icon (icon name string), trigger (function).
 */
QtObject {
    id: getRecentFilesHelper

    function createMenuFromActions(actions, parentItem, title) {
        var menu = Qt.createQmlObject(`
            import org.kde.plasma.extras 2.0 as PlasmaExtras
            PlasmaExtras.Menu {
                placement: PlasmaExtras.Menu.RightPosedTopAlignedPopup
            }
        `, parentItem);

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
}
