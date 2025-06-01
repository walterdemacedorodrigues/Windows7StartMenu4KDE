/*
    SPDX-FileCopyrightText: 2025 Walter Rodrigues <wmr2@cin.ufpe.br>
    SPDX-FileCopyrightText: 2015 Eike Hein <hein@kde.org>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

import org.kde.ksvg 1.0 as KSvg
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras 2.0 as PlasmaExtras
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.private.kicker 0.1 as Kicker
import org.kde.plasma.plasmoid

PlasmaComponents.ScrollView {
    id: itemMultiGrid

    anchors {
        top: parent.top
    }

    width: parent.width
    implicitHeight: itemColumn.implicitHeight

    signal keyNavLeft(int subGridIndex)
    signal keyNavRight(int subGridIndex)
    signal keyNavUp()
    signal keyNavDown()

    property bool grabFocus: false
    property alias model: repeater.model
    property alias count: repeater.count
    property alias flickableItem: flickable

    property int cellWidth
    property int cellHeight

    // CORREÇÃO: Adicionar dummyHeading para referência
    Kirigami.Heading {
        id: dummyHeading
        visible: false
        level: 4
        text: "Dummy"
    }

    function subGridAt(index) {
        return repeater.itemAt(index).itemGrid;
    }

    function tryActivate(row, col) {
        if (flickable.contentY > 0) {
            row = 0;
        }

        var target = null;
        var rows = 0;

        for (var i = 0; i < repeater.count; i++) {
            var grid = subGridAt(i);

            if (rows <= row) {
                target = grid;
                rows += grid.lastRow() + 2; // Header counts as one.
            } else {
                break;
            }
        }

        if (target) {
            rows -= (target.lastRow() + 2);
            target.tryActivate(row - rows, col);
        }
    }

    onFocusChanged: {
        if (!focus) {
            for (var i = 0; i < repeater.count; i++) {
                subGridAt(i).focus = false;
            }
        }
    }

    Flickable {
        id: flickable
        flickableDirection: Flickable.VerticalFlick
        contentHeight: itemColumn.implicitHeight

        Column {
            id: itemColumn
            width: itemMultiGrid.width - Kirigami.Units.gridUnit

            Repeater {
                id: repeater

                delegate: Item {
                    width: itemColumn.width
                    height: gridView.height + gridViewLabel.height + Kirigami.Units.largeSpacing * 2
                    visible: gridView.count > 0

                    property Item itemGrid: gridView

                    Kirigami.Heading {
                        id: gridViewLabel
                        anchors.top: parent.top
                        x: Kirigami.Units.smallSpacing
                        width: parent.width - x
                        height: dummyHeading.height // CORREÇÃO: Usar dummyHeading

                        elide: Text.ElideRight
                        wrapMode: Text.NoWrap
                        opacity: 1.0
                        color: Kirigami.Theme.textColor
                        level: 4

                        // CORREÇÃO: Verificar se o modelo existe antes de acessar
                        text: {
                            if (repeater.model && typeof repeater.model.modelForRow === "function") {
                                var rowModel = repeater.model.modelForRow(index);
                                if (rowModel && rowModel.description) {
                                    return rowModel.description;
                                }
                            }
                            return "Search Results";
                        }
                        textFormat: Text.PlainText
                    }

                    MouseArea {
                        width: parent.width
                        height: parent.height
                        onClicked: {
                            // CORREÇÃO: Verificar se root existe
                            if (typeof root !== "undefined" && root.toggle) {
                                root.toggle();
                            } else if (typeof kicker !== "undefined") {
                                kicker.expanded = false;
                            }
                        }
                    }

                    ItemGridView {
                        id: gridView

                        anchors {
                            top: gridViewLabel.bottom
                            topMargin: Kirigami.Units.largeSpacing
                        }

                        width: parent.width
                        // CORREÇÃO: Calcular altura com segurança
                        height: {
                            var columns = 1; // Default fallback
                            if (typeof Plasmoid !== "undefined" &&
                                Plasmoid.configuration &&
                                Plasmoid.configuration.numberColumns) {
                                columns = Plasmoid.configuration.numberColumns;
                            } else {
                                // Calcular baseado na largura se não tiver configuração
                                columns = Math.max(1, Math.floor(width / itemMultiGrid.cellWidth));
                            }
                            return Math.ceil(count / columns) * itemMultiGrid.cellHeight;
                        }

                        cellWidth: itemMultiGrid.cellWidth
                        cellHeight: itemMultiGrid.cellHeight
                        // CORREÇÃO: Verificar se root existe antes de acessar iconSize
                        iconSize: {
                            if (typeof root !== "undefined" && root.iconSize) {
                                return root.iconSize;
                            }
                            return Kirigami.Units.iconSizes.huge; // Fallback
                        }

                        verticalScrollBarPolicy: PlasmaComponents.ScrollBar.AlwaysOff

                        // CORREÇÃO: Verificar se o modelo existe antes de atribuir
                        model: {
                            if (repeater.model && typeof repeater.model.modelForRow === "function") {
                                return repeater.model.modelForRow(index);
                            }
                            return null;
                        }

                        onFocusChanged: {
                            if (focus) {
                                itemMultiGrid.focus = true;
                            }
                        }

                        onCountChanged: {
                            if (itemMultiGrid.grabFocus && index == 0 && count > 0) {
                                currentIndex = 0;
                                focus = true;
                            }
                        }

                        onCurrentItemChanged: {
                            if (!currentItem) {
                                return;
                            }

                            if (index == 0 && currentRow() === 0) {
                                flickable.contentY = 0;
                                return;
                            }

                            var y = currentItem.y;
                            y = contentItem.mapToItem(flickable.contentItem, 0, y).y;

                            if (y < flickable.contentY) {
                                flickable.contentY = y;
                            } else {
                                y += itemMultiGrid.cellHeight;
                                y -= flickable.contentY;
                                y -= itemMultiGrid.height;

                                if (y > 0) {
                                    flickable.contentY += y;
                                }
                            }
                        }

                        onKeyNavLeft: {
                            itemMultiGrid.keyNavLeft(index);
                        }

                        onKeyNavRight: {
                            itemMultiGrid.keyNavRight(index);
                        }

                        onKeyNavUp: {
                            if (index > 0) {
                                var prevGrid = subGridAt(index - 1);
                                prevGrid.tryActivate(prevGrid.lastRow(), currentCol());
                            } else {
                                itemMultiGrid.keyNavUp();
                            }
                        }

                        onKeyNavDown: {
                            if (index < repeater.count - 1) {
                                subGridAt(index + 1).tryActivate(0, currentCol());
                            } else {
                                itemMultiGrid.keyNavDown();
                            }
                        }
                    }

                    // HACK: Steal wheel events from the nested grid view and forward them to
                    // the ScrollView's internal WheelArea.
                    Kicker.WheelInterceptor {
                        anchors.fill: gridView
                        z: 1

                        destination: findWheelArea(itemMultiGrid)
                    }
                }
            }
        }
    }
}