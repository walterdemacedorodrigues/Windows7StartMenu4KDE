/*
 *  SPDX-FileCopyrightText: 2025 Walter Rodrigues <wmr2@cin.ufpe.br>
 *  SPDX-FileCopyrightText: 2011 Martin Gräßlin <mgraesslin@kde.org>
 *  SPDX-FileCopyrightText: 2015-2018 Eike Hein <hein@kde.org>
 *  SPDX-FileCopyrightText: 2023 WackyIdeas <wackyideas@disroot.org>
 *  SPDX-License-Identifier: AGPL-3.0-or-later
 */

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.plasma.plasmoid 2.0
import org.kde.kirigami as Kirigami

import "code/tools.js" as Tools

// List of applications where a category row expands its children underneath
// itself. Keyboard travel walks parents and expanded children as one sequence.
FocusScope {
    id: view

    property alias model: listView.model
    property alias count: listView.count
    property alias currentIndex: listView.currentIndex
    readonly property alias listView: listView

    signal reset()
    signal exitTop()
    signal exitBottom()
    signal exitLeft()

    // Cursor is either a top level row or one child of an expanded row.
    property Item currentRow: null
    property int childCursor: -1

    // Name of the category currently opened, empty when the tree is collapsed.
    property string expandedLabel: ""

    function hoverIndex(item) {
        if (item.isChild) {
            currentRow = item.parentRow;
            childCursor = item.itemIndex;
            listView.currentIndex = item.parentRow ? item.parentRow.itemIndex : -1;
        } else {
            currentRow = item;
            childCursor = -1;
            listView.currentIndex = item.itemIndex;
        }
    }

    function rowAt(index) {
        const layout = listView.itemAtIndex(index);
        return layout ? layout.rowItem : null;
    }

    function collapseAll() {
        for (let i = 0; i < listView.count; i++) {
            const row = rowAt(i);
            if (row) row.expanded = false;
        }
        childCursor = -1;
        currentRow = null;
        expandedLabel = "";
        listView.currentIndex = -1;
    }

    function activateCurrent() {
        const row = rowAt(listView.currentIndex);
        if (!row) return;
        if (row.expanded && childCursor !== -1) {
            const layout = listView.itemAtIndex(listView.currentIndex);
            const child = layout ? layout.childAt_(childCursor) : null;
            if (child) child.activate();
            return;
        }
        row.activate();
    }

    function openCurrentContextMenu() {
        const row = rowAt(listView.currentIndex);
        if (!row) return;
        if (row.expanded && childCursor !== -1) {
            const layout = listView.itemAtIndex(listView.currentIndex);
            const child = layout ? layout.childAt_(childCursor) : null;
            if (child) child.openActionMenu();
            return;
        }
        row.openActionMenu();
    }

    function incrementCurrentIndex() {
        const layout = listView.itemAtIndex(listView.currentIndex);
        const row = layout ? layout.rowItem : null;
        if (row && row.expanded) {
            const next = childCursor + 1;
            if (next < layout.childCount) {
                childCursor = next;
                listView.positionViewAtIndex(listView.currentIndex, ListView.Contain);
                return;
            }
            childCursor = -1;
        }
        if (listView.currentIndex + 1 >= listView.count) {
            view.exitBottom();
            return;
        }
        listView.currentIndex++;
        listView.positionViewAtIndex(listView.currentIndex, ListView.Contain);
    }

    function decrementCurrentIndex() {
        const layout = listView.itemAtIndex(listView.currentIndex);
        const row = layout ? layout.rowItem : null;
        if (row && row.expanded && childCursor > -1) {
            childCursor--;
            listView.positionViewAtIndex(listView.currentIndex, ListView.Contain);
            return;
        }
        if (listView.currentIndex <= 0) {
            view.exitTop();
            return;
        }
        listView.currentIndex--;
        const above = listView.itemAtIndex(listView.currentIndex);
        childCursor = (above && above.rowItem && above.rowItem.expanded) ? above.childCount - 1 : -1;
        listView.positionViewAtIndex(listView.currentIndex, ListView.Contain);
    }

    onActiveFocusChanged: {
        if (activeFocus && listView.currentIndex === -1 && listView.count > 0) {
            listView.currentIndex = 0;
        } else if (!activeFocus) {
            childCursor = -1;
        }
    }

    Keys.onPressed: event => {
        switch (event.key) {
        case Qt.Key_Up:    event.accepted = true; decrementCurrentIndex(); break;
        case Qt.Key_Down:  event.accepted = true; incrementCurrentIndex(); break;
        case Qt.Key_Left:  event.accepted = true; view.exitLeft(); break;
        case Qt.Key_Return:
        case Qt.Key_Enter: event.accepted = true; activateCurrent(); break;
        case Qt.Key_Menu:  event.accepted = true; openCurrentContextMenu(); break;
        }
    }

    Connections {
        target: kicker
        function onExpandedChanged() {
            if (!kicker.expanded) view.collapseAll();
        }
    }

    // Shared by every row. Giving each delegate its own QMenu made list
    // teardown destroy dozens of them and crash on already cleared focus.
    readonly property alias sharedActionMenu: sharedActionMenu
    property Item actionMenuOwner: null

    function openActionMenuFor(item, actions, x, y) {
        actionMenuOwner = item;
        const favorites = item.triggerModel ? item.triggerModel.favoritesModel : null;
        Tools.fillActionMenu(i18n, sharedActionMenu, actions, favorites, item.itemModel.favoriteId);
        if (!sharedActionMenu.actionList || sharedActionMenu.actionList.length === 0) return;
        sharedActionMenu.visualParent = item;
        sharedActionMenu.open(x, y);
    }

    ActionMenu {
        id: sharedActionMenu
        onActionClicked: (actionId, actionArgument) => {
            if (view.actionMenuOwner) view.actionMenuOwner.triggerActionMenu(actionId, actionArgument);
        }
    }

    QQC2.ScrollView {
        id: scrollView
        anchors.fill: parent

        ListView {
            id: listView
            clip: true
            currentIndex: -1
            focus: true
            keyNavigationEnabled: false
            highlightFollowsCurrentItem: false
            boundsBehavior: Flickable.StopAtBounds
            cacheBuffer: 2000
            spacing: 0

            delegate: ColumnLayout {
                id: delegateLayout

                required property var model
                required property int index

                readonly property alias rowItem: rowItem
                readonly property int childCount: childRepeater.count

                function childAt_(i) { return childRepeater.itemAt(i); }

                width: listView.width
                spacing: 0

                AppsListItem {
                    id: rowItem
                    Layout.fillWidth: true
                    Layout.preferredHeight: implicitHeight
                    itemModel: delegateLayout.model
                    itemIndex: delegateLayout.index
                    listView: view
                    isCurrent: listView.currentIndex === delegateLayout.index && view.childCursor === -1
                    onReset: view.reset()
                    onExpandedChanged: {
                        if (expanded) {
                            view.expandedLabel = itemModel ? itemModel.display : "";
                        } else if (view.expandedLabel === (itemModel ? itemModel.display : "")) {
                            view.expandedLabel = "";
                        }
                    }
                    onActivated: {
                        view.model.trigger(delegateLayout.index, "", null);
                        view.reset();
                        kicker.expanded = false;
                    }
                }

                Column {
                    Layout.fillWidth: true
                    Layout.preferredHeight: rowItem.expanded ? implicitHeight : 0
                    visible: rowItem.expanded
                    clip: true

                    Behavior on Layout.preferredHeight {
                        NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutQuad }
                    }

                    Repeater {
                        id: childRepeater
                        model: rowItem.expanded ? rowItem.childModel : null

                        delegate: AppsListItem {
                            required property var model
                            required property int index

                            property Item parentRow: rowItem

                            width: listView.width
                            itemModel: model
                            itemIndex: index
                            listView: view
                            triggerModel: rowItem.childModel
                            isChild: true
                            indented: true
                            isCurrent: listView.currentIndex === delegateLayout.index && view.childCursor === index
                            onReset: view.reset()
                            onActivated: {
                                rowItem.childModel.trigger(index, "", null);
                                view.reset();
                                kicker.expanded = false;
                            }
                        }
                    }
                }
            }
        }
    }
}
