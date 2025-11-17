//ui/FavoritesGridView.qml

/*
    SPDX-FileCopyrightText: 2025 Walter Rodrigues <wmr2@cin.ufpe.br>
    SPDX-FileCopyrightText: 2015 Eike Hein <hein@kde.org>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick 2.15

import org.kde.kquickcontrolsaddons 2.0
import org.kde.ksvg 1.0 as KSvg
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras 2.0 as PlasmaExtras
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.core as PlasmaCore

import "code/tools.js" as Tools

FocusScope {
    id: itemGrid

    signal keyNavLeft
    signal keyNavRight
    signal keyNavUp
    signal keyNavDown

    signal itemActivated(int index, string actionId, string argument)
    signal submenuRequested(int index, real x, real y)

    property bool dragEnabled: true
    property bool dropEnabled: false
    property bool showLabels: true

    property alias currentIndex: gridView.currentIndex
    property alias currentItem: gridView.currentItem
    property alias contentItem: gridView.contentItem
    property alias count: gridView.count
    property alias model: gridView.model

    property alias cellWidth: gridView.cellWidth
    property alias cellHeight: gridView.cellHeight
    property alias iconSize: gridView.iconSize

    // Propriedades de scroll removidas/desabilitadas para favoritos
    property var horizontalScrollBarPolicy: PlasmaComponents.ScrollBar.AlwaysOff
    property var verticalScrollBarPolicy: PlasmaComponents.ScrollBar.AlwaysOff

    onDropEnabledChanged: {
        if (!dropEnabled && "dropPlaceHolderIndex" in model) {
            model.dropPlaceHolderIndex = -1;
        }
    }

    onFocusChanged: {
        if (!focus) {
            currentIndex = -1;
        }
    }

    function currentRow() {
        if (currentIndex === -1) {
            return -1;
        }

        return Math.floor(currentIndex / Math.floor(width / itemGrid.cellWidth));
    }

    function currentCol() {
        if (currentIndex === -1) {
            return -1;
        }

        return currentIndex - (currentRow() * Math.floor(width / itemGrid.cellWidth));
    }

    function lastRow() {
        var columns = Math.floor(width / itemGrid.cellWidth);
        return Math.ceil(count / columns) - 1;
    }

    function tryActivate(row, col) {
        if (count) {
            var columns = Math.floor(width / itemGrid.cellWidth);
            var rows = Math.ceil(count / columns);
            row = Math.min(row, rows - 1);
            col = Math.min(col, columns - 1);
            currentIndex = Math.min(row ? ((Math.max(1, row) * columns) + col)
                                        : col,
                                    count - 1);

            focus = true;
        }
    }

    function forceLayout() {
        gridView.forceLayout();
    }

    ActionMenu {
        id: actionMenu

        onActionClicked: {
            visualParent.actionTriggered(actionId, actionArgument);
        }
    }

    DropArea {
        id: dropArea

        anchors.fill: parent

        onPositionChanged: event => {
                               if (!itemGrid.dropEnabled || gridView.animating || !kicker.dragSource) {
                                   return;
                               }

                               var x = Math.max(0, event.x - (width % itemGrid.cellWidth));
                               var cPos = mapToItem(gridView.contentItem, x, event.y);
                               var item = gridView.itemAt(cPos.x, cPos.y);

                               if (item) {
                                   if (kicker.dragSource.parent === gridView.contentItem) {
                                       if (item !== kicker.dragSource) {
                                           item.GridView.view.model.moveRow(dragSource.itemIndex, item.itemIndex);
                                       }
                                   } else if (kicker.dragSource.GridView.view.model.favoritesModel === itemGrid.model
                                              && !itemGrid.model.isFavorite(kicker.dragSource.favoriteId)) {
                                       var hasPlaceholder = (itemGrid.model.dropPlaceholderIndex !== -1);

                                       itemGrid.model.dropPlaceholderIndex = item.itemIndex;

                                       if (!hasPlaceholder) {
                                           gridView.currentIndex = (item.itemIndex - 1);
                                       }
                                   }
                               } else if (kicker.dragSource.parent !== gridView.contentItem
                                          && kicker.dragSource.GridView.view.model.favoritesModel === itemGrid.model
                                          && !itemGrid.model.isFavorite(kicker.dragSource.favoriteId)) {
                                   var hasPlaceholder = (itemGrid.model.dropPlaceholderIndex !== -1);

                                   itemGrid.model.dropPlaceholderIndex = hasPlaceholder ? itemGrid.model.count - 1 : itemGrid.model.count;

                                   if (!hasPlaceholder) {
                                       gridView.currentIndex = (itemGrid.model.count - 1);
                                   }
                               } else {
                                   itemGrid.model.dropPlaceholderIndex = -1;
                                   gridView.currentIndex = -1;
                               }
                           }

        onExited: {
            if ("dropPlaceholderIndex" in itemGrid.model) {
                itemGrid.model.dropPlaceholderIndex = -1;
                gridView.currentIndex = -1;
            }
        }

        onDropped: {
            if (kicker.dragSource && kicker.dragSource.parent !== gridView.contentItem && kicker.dragSource.GridView.view.model.favoritesModel === itemGrid.model) {
                itemGrid.model.addFavorite(kicker.dragSource.favoriteId, itemGrid.model.dropPlaceholderIndex);
                gridView.currentIndex = -1;
            }
        }

        Timer {
            id: resetAnimationDurationTimer

            interval: 120
            repeat: false

            onTriggered: {
                gridView.animationDuration = interval - 20;
            }
        }

        // MODIFICADO: GridView direto sem ScrollView para favoritos
        GridView {
            id: gridView

            // ALTURA DINÂMICA: Calcula automaticamente baseado no número de itens
            width: parent.width
            height: count > 0 ? Math.ceil(count / Math.floor(width / cellWidth)) * cellHeight : 0

            signal itemContainsMouseChanged(bool containsMouse)

            property int iconSize: Kirigami.Units.iconSizes.huge

            property bool animating: false
            property int animationDuration: itemGrid.dropEnabled ? resetAnimationDurationTimer.interval : 0

            focus: true

            // SEM SCROLL: Desabilitado para favoritos
            interactive: false
            flickableDirection: Flickable.AutoFlickIfNeeded
            boundsBehavior: Flickable.StopAtBounds

            currentIndex: -1

            move: Transition {
                enabled: itemGrid.dropEnabled

                SequentialAnimation {
                    PropertyAction { target: gridView; property: "animating"; value: true }

                    NumberAnimation {
                        duration: gridView.animationDuration
                        properties: "x, y"
                        easing.type: Easing.OutQuad
                    }

                    PropertyAction { target: gridView; property: "animating"; value: false }
                }
            }

            moveDisplaced: Transition {
                enabled: itemGrid.dropEnabled

                SequentialAnimation {
                    PropertyAction { target: gridView; property: "animating"; value: true }

                    NumberAnimation {
                        duration: gridView.animationDuration
                        properties: "x, y"
                        easing.type: Easing.OutQuad
                    }

                    PropertyAction { target: gridView; property: "animating"; value: false }
                }
            }

            keyNavigationWraps: false

            delegate: Item {
                id: delegateItem
                width: GridView.view.cellWidth
                height: GridView.view.cellHeight
                enabled: !model.disabled

                property bool showLabel: itemGrid.showLabels
                property int itemIndex: model.index
                property string favoriteId: model.favoriteId !== undefined ? model.favoriteId : ""
                property string launcherUrl: model.launcherUrl !== undefined ? model.launcherUrl : ""
                property url url: model.url !== undefined ? model.url : ""
                property variant icon: model.decoration !== undefined ? model.decoration : ""
                property var m: model
                property bool hasActionList: ((model.favoriteId !== null) || (("hasActionList" in model) && (model.hasActionList === true)))
                property bool hasRecentFiles: model.hasRecentFiles !== undefined ? model.hasRecentFiles : false

                Component.onCompleted: {
                    console.log("[FavGridView.Delegate] Created:", model.display, "hasRecentFiles:", hasRecentFiles, "from model.hasRecentFiles:", model.hasRecentFiles);
                }

                Accessible.role: Accessible.MenuItem
                Accessible.name: model.display

                function openActionMenu(x, y) {
                    var actionList = hasActionList ? model.actionList : [];
                    var favModel = GridView.view.model.favoritesModel;

                    console.log("[TEST.openActionMenu]", model.display, "→ hasActionList:", hasActionList, "actionList type:", typeof model.actionList, "count:", model.actionList ? model.actionList.count : "null");

                    // fillActionMenu already adds "Remove from Favorites" or "Add to Favorites" automatically
                    Tools.fillActionMenu(i18n, actionMenu, actionList, favModel, favoriteId);

                    actionMenu.visualParent = delegateItem;
                    actionMenu.open(x, y);
                }

                function actionTriggered(actionId, actionArgument) {
                    // Tools.triggerAction handles all actions including favorites automatically
                    var close = (Tools.triggerAction(GridView.view.model, model.index, actionId, actionArgument) === true);

                    // Don't close menu for favorite actions
                    if (actionId && (actionId.indexOf("_kicker_favorite_") === 0)) {
                        return;
                    }

                    if (close) {
                        var rootItem = delegateItem;
                        while (rootItem.parent && rootItem.parent.toString().indexOf("PlasmoidItem") === -1) {
                            rootItem = rootItem.parent;
                            if (rootItem.toggle) {
                                rootItem.toggle();
                                return;
                            }
                        }
                        if (typeof kicker !== "undefined" && kicker) {
                            kicker.expanded = false;
                        }
                    }
                }

                // Main item content
                Row {
                    id: mainRow
                    anchors.fill: parent
                    spacing: 0

                    // Icon and label area
                    Item {
                        width: parent.width - (delegateItem.hasRecentFiles ? submenuButton.width : 0)
                        height: parent.height

                        Kirigami.Icon {
                            id: iconItem
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 15

                            width: 32
                            height: width
                            animated: false
                            source: model.decoration
                        }

                        PlasmaComponents.Label {
                            id: labelItem
                            height: 48
                            visible: delegateItem.showLabel

                            anchors {
                                left: parent.left
                                leftMargin: iconItem.width * 1.5 + iconItem.anchors.leftMargin
                                right: parent.right
                                rightMargin: 5
                            }

                            verticalAlignment: Text.AlignVCenter
                            maximumLineCount: 1
                            elide: Text.ElideMiddle
                            wrapMode: Text.Wrap

                            color: Kirigami.Theme.textColor
                            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.9
                            text: ("name" in model ? model.name : model.display)
                            textFormat: Text.PlainText
                        }
                    }

                    // Submenu arrow button (only shown if app has recent files)
                    Item {
                        id: submenuButton
                        width: delegateItem.hasRecentFiles ? 30 : 0
                        height: parent.height
                        visible: delegateItem.hasRecentFiles

                        Component.onCompleted: {
                            if (delegateItem.hasRecentFiles) {
                                console.log("[Button] ✓ VISIBLE for", model.display, "- width:", width, "x:", x, "y:", y, "opacity:", opacity);
                            }
                        }

                        Kirigami.Icon {
                            id: arrowIcon
                            anchors.centerIn: parent
                            width: 16
                            height: 16
                            source: "arrow-right"
                            color: Kirigami.Theme.textColor
                            opacity: submenuMouseArea.containsMouse ? 1.0 : 0.7
                        }

                        MouseArea {
                            id: submenuMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                console.log("[Button] ✓ CLICKED:", model.display);
                                itemGrid.submenuRequested(delegateItem.itemIndex, 0, 0);
                            }
                        }
                    }
                }

                PlasmaCore.ToolTipArea {
                    id: toolTip
                    property string text: model.display
                    anchors.fill: parent
                    anchors.rightMargin: delegateItem.hasRecentFiles ? submenuButton.width : 0
                    active: delegateItem.visible && labelItem.truncated

                    onContainsMouseChanged: {
                        gridView.itemContainsMouseChanged(containsMouse);
                        if (containsMouse) {
                            gridView.currentIndex = delegateItem.itemIndex;
                        }
                    }
                }

                Keys.onPressed: event => {
                    console.log("[FavGridView.Delegate] Key pressed:", event.key, "hasRecentFiles:", hasRecentFiles, "Qt.Key_Right:", Qt.Key_Right);

                    if (event.key === Qt.Key_Menu && hasActionList) {
                        console.log("[FavGridView.Delegate] Opening action menu");
                        event.accepted = true;
                        openActionMenu(delegateItem);
                    } else if ((event.key === Qt.Key_Enter || event.key === Qt.Key_Return)) {
                        console.log("[FavGridView.Delegate] Enter/Return pressed");
                        event.accepted = true;
                        if ("trigger" in GridView.view.model) {
                            GridView.view.model.trigger(index, "", null);
                            if (typeof kicker !== "undefined") {
                                kicker.expanded = false;
                            }
                        }
                        itemGrid.itemActivated(index, "", null);
                    } else if (event.key === Qt.Key_Right && hasRecentFiles) {
                        console.log("[FavGridView.Delegate] Right arrow pressed - opening submenu, index:", delegateItem.itemIndex);
                        event.accepted = true;
                        // Passar a referência do próprio delegateItem
                        itemGrid.submenuRequested(delegateItem.itemIndex, 0, 0);
                    } else if (event.key === Qt.Key_Right && !hasRecentFiles) {
                        console.log("[FavGridView.Delegate] Right arrow but no recent files - emit keyNavRight");
                        event.accepted = false; // Let parent handle it
                        itemGrid.keyNavRight();
                    }
                }
            }

            highlight: Item {
                property bool isDropPlaceHolder: "dropPlaceholderIndex" in itemGrid.model && itemGrid.currentIndex === itemGrid.model.dropPlaceholderIndex

                PlasmaExtras.Highlight {
                    visible: gridView.currentItem && !isDropPlaceHolder
                    hovered: true
                    pressed: hoverArea.pressed

                    anchors.fill: parent
                }

                KSvg.FrameSvgItem {
                    visible: gridView.currentItem && isDropPlaceHolder

                    anchors.fill: parent

                    imagePath: "widgets/viewitem"
                    prefix: "selected"

                    opacity: 0.5

                    Kirigami.Icon {
                        anchors {
                            right: parent.right
                            rightMargin: parent.margins.right
                            bottom: parent.bottom
                            bottomMargin: parent.margins.bottom
                        }

                        width: Kirigami.Units.iconSizes.smallMedium
                        height: width

                        source: "list-add"
                        active: false
                    }
                }
            }

            highlightFollowsCurrentItem: true
            highlightMoveDuration: 0

            onCurrentIndexChanged: {
                if (currentIndex !== -1) {
                    hoverArea.hoverEnabled = false
                    focus = true;
                }
            }

            onCountChanged: {
                animationDuration = 0;
                resetAnimationDurationTimer.start();
            }

            onModelChanged: {
                currentIndex = -1;
            }

            Keys.onLeftPressed: event => {
                                    if (itemGrid.currentCol() !== 0) {
                                        event.accepted = true;
                                        moveCurrentIndexLeft();
                                    } else {
                                        itemGrid.keyNavLeft();
                                    }
                                }

            Keys.onRightPressed: event => {
                                     var columns = Math.floor(width / cellWidth);

                                     if (itemGrid.currentCol() !== columns - 1 && currentIndex !== count -1) {
                                         event.accepted = true;
                                         moveCurrentIndexRight();
                                     } else {
                                         itemGrid.keyNavRight();
                                     }
                                 }

            Keys.onUpPressed: event => {
                                  if (itemGrid.currentRow() !== 0) {
                                      event.accepted = true;
                                      moveCurrentIndexUp();
                                  } else {
                                      itemGrid.keyNavUp();
                                  }
                              }

            Keys.onDownPressed: event => {
                                    if (itemGrid.currentRow() < itemGrid.lastRow()) {
                                        event.accepted = true;
                                        var columns = Math.floor(width / cellWidth);
                                        var newIndex = currentIndex + columns;
                                        currentIndex = Math.min(newIndex, count - 1);
                                    } else {
                                        itemGrid.keyNavDown();
                                    }
                                }

            onItemContainsMouseChanged: containsMouse => {
                                            if (!containsMouse) {
                                                if (!actionMenu.opened) {
                                                    gridView.currentIndex = -1;
                                                }

                                                hoverArea.pressX = -1;
                                                hoverArea.pressY = -1;
                                                hoverArea.lastX = -1;
                                                hoverArea.lastY = -1;
                                                hoverArea.pressedItem = null;
                                                hoverArea.hoverEnabled = true;
                                            }
                                        }
        }

        MouseArea {
            id: hoverArea

            width:  itemGrid.width - Kirigami.Units.gridUnit
            height: itemGrid.height

            property int pressX: -1
            property int pressY: -1
            property int lastX: -1
            property int lastY: -1
            property Item pressedItem: null

            acceptedButtons: Qt.LeftButton | Qt.RightButton

            hoverEnabled: true

            function updatePositionProperties(x, y) {
                if (lastX === x && lastY === y) {
                    return;
                }

                lastX = x;
                lastY = y;

                var cPos = mapToItem(gridView.contentItem, x, y);
                var item = gridView.itemAt(cPos.x, cPos.y);

                if (!item) {
                    gridView.currentIndex = -1;
                    pressedItem = null;
                } else {
                    itemGrid.focus = (item.itemIndex !== -1)
                    gridView.currentIndex = item.itemIndex;
                }

                return item;
            }

            onPressed: mouse => {
                           mouse.accepted = true;

                           updatePositionProperties(mouse.x, mouse.y);

                           pressX = mouse.x;
                           pressY = mouse.y;

                           if (mouse.button === Qt.RightButton) {
                               if (gridView.currentItem) {
                                   if (gridView.currentItem.hasActionList) {
                                       var mapped = mapToItem(gridView.currentItem, mouse.x, mouse.y);
                                       gridView.currentItem.openActionMenu(mapped.x, mapped.y);
                                   }
                               }
                           } else {
                               pressedItem = gridView.currentItem;
                           }
                       }

            onReleased: mouse => {
                            mouse.accepted = true;
                            updatePositionProperties(mouse.x, mouse.y);

                            if (!dragHelper.dragging) {
                                if (pressedItem) {
                                    if ("trigger" in gridView.model) {
                                        gridView.model.trigger(pressedItem.itemIndex, "", null);
                                        if (typeof kicker !== "undefined") {
                                            kicker.expanded = false;
                                        }
                                    }

                                    itemGrid.itemActivated(pressedItem.itemIndex, "", null);
                                } else if (mouse.button === Qt.LeftButton) {
                                    if (typeof kicker !== "undefined") {
                                        kicker.expanded = false;
                                    }
                                }
                            }

                            pressX = pressY = -1;
                            pressedItem = null;
                        }

            onPositionChanged: mouse => {
                                   var item = pressedItem? pressedItem : updatePositionProperties(mouse.x, mouse.y);

                                   if (gridView.currentIndex !== -1) {
                                       if (itemGrid.dragEnabled && pressX !== -1 && dragHelper.isDrag(pressX, pressY, mouse.x, mouse.y)) {
                                           if ("pluginName" in item.m) {
                                               dragHelper.startDrag(kicker, item.url, item.icon,
                                                                    "text/x-plasmoidservicename", item.m.pluginName);
                                           } else {
                                               dragHelper.startDrag(kicker,item.url);
                                           }
                                           kicker.dragSource = item;
                                           pressX = -1;
                                           pressY = -1;
                                       }
                                   }
                               }
        }
    }
}