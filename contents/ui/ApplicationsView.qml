/*
 *  SPDX-FileCopyrightText: 2025 Walter Rodrigues <wmr2@cin.ufpe.br>
 *  SPDX-FileCopyrightText: 2023 WackyIdeas <wackyideas@disroot.org>
 *  SPDX-License-Identifier: AGPL-3.0-or-later
 */

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid 2.0
import org.kde.kirigami as Kirigami

// All Programs. Hierarchical mode browses the category tree in place, flat mode
// keeps the single alphabetical list the menu used before.
Item {
    id: appsView

    property bool hierarchical: Plasmoid.configuration.hierarchicalAllPrograms
    property var flatModel: null
    property var treeModel: null
    property int iconSize: 32
    property int cellHeight: 48

    signal exitTop()
    signal exitBottom()
    signal exitLeft()

    readonly property Item activeView: hierarchical ? treeView : flatView

    function reset() {
        if (hierarchical) treeView.collapseAll();
    }

    function focusFirst() {
        if (hierarchical) {
            treeView.currentIndex = 0;
            treeView.forceActiveFocus();
        } else {
            flatView.currentIndex = 0;
            flatView.forceActiveFocus();
        }
    }

    onHierarchicalChanged: reset()

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Only present while a category is open, as the way back out of it.
        Breadcrumb {
            id: breadcrumb
            Layout.fillWidth: true
            text: treeView.expandedLabel
            visible: appsView.hierarchical && text !== ""
            onClicked: appsView.reset()
        }

        AppsListView {
            id: treeView
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: appsView.hierarchical
            enabled: visible
            model: appsView.treeModel

            onExitTop: appsView.exitTop()
            onExitBottom: appsView.exitBottom()
            onExitLeft: appsView.exitLeft()
        }

        ItemGridView {
            id: flatView
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !appsView.hierarchical
            enabled: visible
            model: appsView.flatModel
            cellWidth: width
            cellHeight: appsView.cellHeight
            iconSize: appsView.iconSize

            onKeyNavUp: appsView.exitTop()
            onKeyNavDown: appsView.exitBottom()
            onKeyNavLeft: appsView.exitLeft()
        }
    }
}
