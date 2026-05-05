/*
 *  SPDX-FileCopyrightText: 2025 Walter Rodrigues <wmr2@cin.ufpe.br>
 *  SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick 2.4
import org.kde.plasma.extras 2.0 as PlasmaExtras

/*
 * Recent Files flyout menu.
 *
 * Mirrors the canonical Plasma Kickoff ActionMenu pattern: bind an
 * Instantiator directly to the JS array of kicker action items.
 * Never copies actions into a ListModel (which would corrupt the
 * heterogeneous actionArgument types — QStringList for recent docs,
 * KServiceAction for jumplist, etc.).
 *
 * Reference: applets/kickoff/ActionMenu.qml in plasma-desktop.
 *
 * Expected action item shape (from kicker C++ at
 * applets/kicker/actionlist.cpp:319):
 *   { text: "filename.ext",
 *     icon: "mime-icon-name",
 *     actionId: "_kicker_recentDocument",
 *     actionArgument: [resource_url, mime_type] }   // QStringList
 */
PlasmaExtras.Menu {
    id: flyout

    // JS array of kicker action items (QVariantMaps from UserRole+9)
    property var actionList: []

    // Model used to dispatch the click (frequentAppsModel or favoritesModel)
    property var triggerModel: null

    // Row index in triggerModel for the originating app
    property int triggerIndex: -1

    // Optional header text shown as a disabled top item
    property string title: ""

    placement: PlasmaExtras.Menu.RightPosedTopAlignedPopup

    // Header (only when title is set)
    Instantiator {
        active: flyout.title !== ""
        model: 1
        delegate: PlasmaExtras.MenuItem {
            enabled: false
            text: flyout.title
        }
        onObjectAdded: (idx, obj) => flyout.addMenuItem(obj)
    }

    // Separator after header
    Instantiator {
        active: flyout.title !== ""
        model: 1
        delegate: PlasmaExtras.MenuItem {
            separator: true
        }
        onObjectAdded: (idx, obj) => flyout.addMenuItem(obj)
    }

    // The actual action items, bound declaratively to the JS array
    Instantiator {
        model: flyout.actionList
        delegate: PlasmaExtras.MenuItem {
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
        onObjectAdded: (idx, obj) => flyout.addMenuItem(obj)
    }
}
