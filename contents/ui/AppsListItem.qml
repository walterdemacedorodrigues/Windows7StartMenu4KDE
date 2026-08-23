/*
 *  SPDX-FileCopyrightText: 2025 Walter Rodrigues <wmr2@cin.ufpe.br>
 *  SPDX-FileCopyrightText: 2011 Martin Gräßlin <mgraesslin@kde.org>
 *  SPDX-FileCopyrightText: 2015-2018 Eike Hein <hein@kde.org>
 *  SPDX-FileCopyrightText: 2023 WackyIdeas <wackyideas@disroot.org>
 *  SPDX-License-Identifier: AGPL-3.0-or-later
 */

import QtQuick
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami

import "code/tools.js" as Tools

// Row of the All Programs tree. A row backed by a category expands its children
// in place instead of replacing the view, which is how Windows 7 browses menus.
Item {
    id: listItem

    property var itemModel: null
    property int itemIndex: -1
    property var listView: null
    property var childModel: null
    // Children are triggered against their own category model, not the root one.
    property var triggerModel: listView ? listView.model : null
    property bool expanded: false
    property bool isChild: false
    property bool indented: false
    property bool isCurrent: false

    signal reset()
    signal activated()

    readonly property bool modelChildren: itemModel ? (itemModel.hasChildren === true) : false
    readonly property bool isNew: (itemModel && itemModel.isNewlyInstalled === true) && Plasmoid.configuration.highlightNewApps
    readonly property bool hasActionList: itemModel
        ? (itemModel.favoriteId !== null || (("hasActionList" in itemModel) && itemModel.hasActionList))
        : false

    enabled: itemModel ? (!itemModel.disabled && itemModel.display !== "") : false
    visible: itemModel ? itemModel.display !== "" : false
    implicitHeight: visible ? Kirigami.Units.iconSizes.small + Kirigami.Units.smallSpacing * 2 : 0

    function activate() {
        if (modelChildren) {
            childModel = listView.model.modelForRow(itemIndex);
            expanded = !expanded;
        } else {
            listItem.activated();
        }
    }

    function openActionMenu(x, y) {
        if (!listView || !listView.sharedActionMenu) return;
        const actions = hasActionList ? itemModel.actionList : [];
        listView.openActionMenuFor(listItem, actions, x, y);
    }

    function triggerActionMenu(actionId, actionArgument) {
        if (Tools.triggerAction(triggerModel, itemIndex, actionId, actionArgument) === true) {
            listItem.reset();
        }
    }

    PlasmaExtras.Highlight {
        anchors.fill: parent
        hovered: mouseArea.containsMouse || listItem.isCurrent
        pressed: mouseArea.containsPress
        visible: hovered || pressed
    }

    // Freshly installed entries keep the Windows 7 tint until they are opened.
    Rectangle {
        anchors.fill: parent
        color: Kirigami.Theme.positiveTextColor
        opacity: 0.18
        visible: listItem.isNew
    }

    Kirigami.Icon {
        id: elementIcon
        anchors.left: parent.left
        anchors.leftMargin: (listItem.indented ? Kirigami.Units.gridUnit : 0) + Kirigami.Units.smallSpacing * 2
        anchors.verticalCenter: parent.verticalCenter
        width: Kirigami.Units.iconSizes.small
        height: width
        animated: false
        source: {
            if (!listItem.itemModel) return "";
            if (Plasmoid.configuration.useGenericIcons && listItem.modelChildren) return "folder";
            return listItem.itemModel.decoration;
        }
    }

    Kirigami.Icon {
        id: expander
        anchors.right: parent.right
        anchors.rightMargin: Kirigami.Units.smallSpacing * 2
        anchors.verticalCenter: parent.verticalCenter
        width: Kirigami.Units.iconSizes.small
        height: width
        visible: listItem.modelChildren
        source: listItem.expanded ? "arrow-up" : "arrow-down"
        opacity: 0.7
    }

    PlasmaComponents.Label {
        id: titleElement
        anchors.left: elementIcon.right
        anchors.right: expander.visible ? expander.left : parent.right
        anchors.leftMargin: Kirigami.Units.smallSpacing * 2
        anchors.rightMargin: Kirigami.Units.smallSpacing * 2
        anchors.verticalCenter: parent.verticalCenter
        text: listItem.itemModel ? listItem.itemModel.display : ""
        elide: Text.ElideRight
        maximumLineCount: 1
    }

    PlasmaCore.ToolTipArea {
        id: toolTip
        anchors.fill: parent
        active: titleElement.truncated
        interactive: false
        mainText: titleElement.text
    }

    Timer {
        id: toolTipTimer
        interval: Kirigami.Units.longDuration * 2
        onTriggered: toolTip.showToolTip()
    }

    onIsCurrentChanged: {
        if (isCurrent && !mouseArea.containsMouse && toolTip.active) {
            toolTipTimer.start();
        } else {
            toolTipTimer.stop();
            toolTip.hideImmediately();
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        property int pressX: -1
        property int pressY: -1

        onEntered: {
            if (listItem.listView) listItem.listView.hoverIndex(listItem);
        }
        onExited: {
            toolTipTimer.stop();
            toolTip.hideToolTip();
            pressX = -1;
            pressY = -1;
        }
        onPressed: mouse => {
            if (mouse.button === Qt.LeftButton) { pressX = mouse.x; pressY = mouse.y; }
        }
        onPositionChanged: mouse => {
            if (pressX !== -1 && listItem.itemModel && listItem.itemModel.url
                && dragHelper.isDrag(pressX, pressY, mouse.x, mouse.y)) {
                kicker.dragSource = listItem;
                dragHelper.dragIconSize = Kirigami.Units.iconSizes.small;
                dragHelper.startDrag(kicker, listItem.itemModel.url, listItem.itemModel.decoration);
                pressX = -1;
                pressY = -1;
            }
        }
        onReleased: { pressX = -1; pressY = -1; }
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton) {
                listItem.activate();
            } else if (listItem.hasActionList) {
                listItem.openActionMenu(mouse.x, mouse.y);
            }
        }
    }
}
