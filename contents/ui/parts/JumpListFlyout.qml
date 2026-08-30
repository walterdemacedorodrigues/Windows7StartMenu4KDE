/*
 *  SPDX-FileCopyrightText: 2025 Walter Rodrigues <wmr2@cin.ufpe.br>
 *  SPDX-License-Identifier: AGPL-3.0-or-later
 */

import QtQuick
import org.kde.plasma.components as PlasmaComponents

/**
 * Recent documents flyout for an application row.
 * A QQC2 menu rather than the QMenu wrapper, because only this one lets the
 * left arrow walk back out to the list instead of forcing Escape.
 */
PlasmaComponents.Menu {
    id: flyout

    property var entries: []
    property Item anchorItem: null

    signal itemTriggered()
    // Entries taken from a Kicker actionList carry no closure, only an id to dispatch.
    signal actionRequested(string actionId, var actionArgument)

    function openFor(item, actionList, title) {
        if (!actionList || actionList.length === 0) return false;
        const list = [];
        if (title && title !== "") list.push({ text: title, enabled: false });
        for (let i = 0; i < actionList.length; i++) list.push(actionList[i]);
        entries = list;
        anchorItem = item;
        popup(item, item.width, 0);
        return true;
    }

    onClosed: if (anchorItem) anchorItem.forceActiveFocus()

    // Second route out, for when the menu is a window of its own and the
    // focused entry never sees the key. Only live while this flyout is open.
    Shortcut {
        sequence: "Left"
        enabled: flyout.opened
        context: Qt.ApplicationShortcut
        onActivated: flyout.close()
    }

    Instantiator {
        model: flyout.entries
        delegate: PlasmaComponents.MenuItem {
            required property var modelData

            text: modelData.text || ""
            icon.name: typeof modelData.icon === "string" ? modelData.icon : ""
            enabled: modelData.enabled !== false

            onTriggered: {
                if (typeof modelData.trigger === "function") modelData.trigger();
                else if (modelData.actionId) flyout.actionRequested(String(modelData.actionId), modelData.actionArgument);
                flyout.itemTriggered();
            }

            Keys.priority: Keys.BeforeItem
            Keys.onLeftPressed: event => { event.accepted = true; flyout.close(); }
        }
        onObjectAdded: (index, object) => flyout.insertItem(index, object)
        onObjectRemoved: (index, object) => flyout.removeItem(object)
    }
}
