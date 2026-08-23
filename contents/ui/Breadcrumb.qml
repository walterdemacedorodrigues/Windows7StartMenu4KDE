/*
 *  SPDX-FileCopyrightText: 2025 Walter Rodrigues <wmr2@cin.ufpe.br>
 *  SPDX-FileCopyrightText: 2011 Martin Gräßlin <mgraesslin@kde.org>
 *  SPDX-License-Identifier: AGPL-3.0-or-later
 */

import QtQuick
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami

// Back affordance shown above the application tree once a category is open.
Item {
    id: crumb

    property alias text: heading.text

    signal clicked()

    implicitHeight: heading.implicitHeight + Kirigami.Units.smallSpacing * 2

    Kirigami.Icon {
        id: arrow
        anchors.left: parent.left
        anchors.leftMargin: Kirigami.Units.smallSpacing * 2
        anchors.verticalCenter: parent.verticalCenter
        width: Kirigami.Units.iconSizes.small
        height: width
        source: LayoutMirroring.enabled ? "arrow-right" : "arrow-left"
    }

    PlasmaExtras.Heading {
        id: heading
        anchors.left: arrow.right
        anchors.leftMargin: Kirigami.Units.smallSpacing
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        level: 5
        elide: Text.ElideRight
        font.underline: mouseArea.containsMouse
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: crumb.clicked()
    }
}
