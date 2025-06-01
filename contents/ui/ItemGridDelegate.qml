/*
    SPDX-FileCopyrightText: 2025 Walter Rodrigues <wmr2@cin.ufpe.br>
    SPDX-FileCopyrightText: 2015 Eike Hein <hein@kde.org>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick 2.15

import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami 2.20 as Kirigami

import "code/tools.js" as Tools

Item {
    id: item

    width: GridView.view.cellWidth
    height: GridView.view.cellHeight

    enabled: !model.disabled

    property bool showLabel: true

    property int itemIndex: model.index
    property string favoriteId: model.favoriteId !== undefined ? model.favoriteId : ""
    property url url: model.url !== undefined ? model.url : ""
    property variant icon: model.decoration !== undefined ? model.decoration : ""
    property var m: model
    property bool hasActionList: ((model.favoriteId !== null)
        || (("hasActionList" in model) && (model.hasActionList === true)))

    Accessible.role: Accessible.MenuItem
    Accessible.name: model.display

    function openActionMenu(x, y) {
        var actionList = hasActionList ? model.actionList : [];
        Tools.fillActionMenu(i18n, actionMenu, actionList, GridView.view.model.favoritesModel, model.favoriteId);
        actionMenu.visualParent = item;
        actionMenu.open(x, y);
    }

    function actionTriggered(actionId, actionArgument) {
            var close = (Tools.triggerAction(GridView.view.model, model.index, actionId, actionArgument) === true);

            if (close) {
                // Procurar o root na hierarquia
                var rootItem = item;
                while (rootItem.parent && rootItem.parent.toString().indexOf("PlasmoidItem") === -1) {
                    rootItem = rootItem.parent;
                    if (rootItem.toggle) {
                        rootItem.toggle();
                        return;
                    }
                }
                // Fallback: fechar o plasmoid
                if (typeof kicker !== "undefined" && kicker) {
                    kicker.expanded = false;
                }
            }
    }

    Kirigami.Icon {
        id: icon

        y: item.showLabel ? (2 * highlightItemSvg.margins.top) : undefined


        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 15

        width: 32
        height: width

        animated: false

        source: model.decoration
    }

    PlasmaComponents3.Label {
        id: label
        height: 48
        visible: item.showLabel

        anchors {
            left: parent.left
            leftMargin: icon.width*1.5 +  icon.anchors.leftMargin
        }

        verticalAlignment: Text.AlignVCenter

        maximumLineCount: 1
        elide: Text.ElideMiddle
        wrapMode: Text.Wrap

        color: Kirigami.Theme.textColor

        font.pointSize: Kirigami.Theme.defaultFont.pointSize*.9
        text: ("name" in model ? model.name : model.display)
        textFormat: Text.PlainText
    }

    PlasmaCore.ToolTipArea {
        id: toolTip

        property string text: model.display

        anchors.fill: parent
        active: root.visible && label.truncated
        mainItem: toolTipDelegate

        onContainsMouseChanged: item.GridView.view.itemContainsMouseChanged(containsMouse)
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Menu && hasActionList) {
            event.accepted = true;
            openActionMenu(item);
        } else if ((event.key === Qt.Key_Enter || event.key === Qt.Key_Return)) {
            event.accepted = true;

            if ("trigger" in GridView.view.model) {
                GridView.view.model.trigger(index, "", null);
                root.toggle();
            }

            itemGrid.itemActivated(index, "", null);
        }
    }
}
