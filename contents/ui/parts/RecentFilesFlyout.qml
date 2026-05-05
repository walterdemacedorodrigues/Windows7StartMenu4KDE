/*
 *  SPDX-FileCopyrightText: 2025 Walter Rodrigues <wmr2@cin.ufpe.br>
 *  SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick 2.4
import org.kde.plasma.extras 2.0 as PlasmaExtras

/*
 * Recent Files flyout menu.
 *
 * Mirrors the canonical Plasma Kickoff ActionMenu pattern: an outer
 * Item holds a PlasmaExtras.Menu as a property; sibling Instantiators
 * populate the menu via addMenuItem(). PlasmaExtras.Menus default
 * 'content' property only accepts QMenuItem, so the Instantiator must
 * live outside the Menu.
 *
 * Reference: applets/kickoff/ActionMenu.qml in plasma-desktop.
 */
Item {
    id: flyout

    // JS array of kicker action items (QVariantMaps from UserRole+9)
    property var actionList: []

    // Model used to dispatch the click (frequentAppsModel or favoritesModel)
    property var triggerModel: null

    // Row index in triggerModel for the originating app
    property int triggerIndex: -1

    // Optional header text shown as a disabled top item
    property string title: ""

    // Forwarded API
    property alias visualParent: _menu.visualParent

    visible: false

    readonly property PlasmaExtras.Menu menu: PlasmaExtras.Menu {
        id: _menu
        placement: PlasmaExtras.Menu.RightPosedTopAlignedPopup
    }

    function openRelative() { _menu.openRelative(); }
    function open(x, y) { _menu.open(x, y); }
    function close() { _menu.close(); }

    // Header (only when title is set)
    Instantiator {
        active: flyout.title !== ""
        model: 1
        delegate: PlasmaExtras.MenuItem {
            enabled: false
            text: flyout.title
        }
        onObjectAdded: (idx, obj) => _menu.addMenuItem(obj)
        onObjectRemoved: (idx, obj) => _menu.removeMenuItem(obj)
    }

    // Separator after header
    Instantiator {
        active: flyout.title !== ""
        model: 1
        delegate: PlasmaExtras.MenuItem {
            separator: true
        }
        onObjectAdded: (idx, obj) => _menu.addMenuItem(obj)
        onObjectRemoved: (idx, obj) => _menu.removeMenuItem(obj)
    }

    // Action items, bound declaratively to the JS array
    Instantiator {
        model: flyout.actionList
        delegate: PlasmaExtras.MenuItem {
            required property var modelData
            text: modelData ? (modelData.text || "") : ""
            icon: modelData ? (modelData.icon || "") : ""
            onClicked: {
                if (flyout.triggerModel
                    && typeof flyout.triggerModel.trigger === "function"
                    && modelData) {
                    flyout.triggerModel.trigger(flyout.triggerIndex,
                                                modelData.actionId,
                                                modelData.actionArgument);
                }
            }
        }
        onObjectAdded: (idx, obj) => _menu.addMenuItem(obj)
        onObjectRemoved: (idx, obj) => _menu.removeMenuItem(obj)
    }
}
