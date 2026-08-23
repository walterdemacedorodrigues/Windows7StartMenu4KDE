/*
 *  SPDX-FileCopyrightText: 2025 Walter Rodrigues <wmr2@cin.ufpe.br>
 *  SPDX-FileCopyrightText: 2023 WackyIdeas <wackyideas@disroot.org>
 *  SPDX-License-Identifier: AGPL-3.0-or-later
 */

import QtQuick
import org.kde.plasma.plasmoid 2.0
import org.kde.kirigami as Kirigami

// Panel button. It draws a plain system icon unless the Windows orb is turned
// on, in which case it slices a ClassicShell style three frame PNG.
Item {
    id: orbButton

    property bool hovered: false
    property bool pressed: false
    readonly property bool useOrb: Plasmoid.configuration.useWindowsOrb

    readonly property url orbTexture: {
        const custom = Plasmoid.configuration.orbImage;
        return (custom && custom.toString() !== "") ? custom : Qt.resolvedUrl("orbs/orb.png");
    }

    // The sheet stacks normal, hover and pressed frames vertically.
    readonly property real aspectRatio: sheet.implicitHeight > 0 ? sheet.implicitWidth / sheet.implicitHeight : 1
    readonly property int frameWidth: Plasmoid.configuration.orbWidth > 0
        ? Plasmoid.configuration.orbWidth
        : (sheet.implicitWidth > 0 ? sheet.implicitWidth : Kirigami.Units.iconSizes.medium)
    readonly property int frameHeight: aspectRatio > 0 ? Math.round(frameWidth / aspectRatio) : frameWidth

    implicitWidth: useOrb ? frameWidth : Kirigami.Units.iconSizes.medium
    implicitHeight: useOrb ? Math.round(frameHeight / 3) : Kirigami.Units.iconSizes.medium

    Image {
        id: sheet
        source: orbButton.useOrb ? orbButton.orbTexture : ""
        visible: false
        cache: true
    }

    Kirigami.Icon {
        anchors.fill: parent
        visible: !orbButton.useOrb
        active: orbButton.hovered
        smooth: true
        source: Plasmoid.configuration.useCustomButtonImage
                ? Plasmoid.configuration.customButtonImage
                : Plasmoid.configuration.icon
    }

    component OrbFrame: Image {
        anchors.centerIn: parent
        smooth: true
        visible: orbButton.useOrb
        fillMode: Image.PreserveAspectFit
        source: orbButton.orbTexture
        width: orbButton.frameWidth
        height: orbButton.frameHeight
    }

    OrbFrame {
        sourceClipRect: Qt.rect(0, 0, sheet.implicitWidth, sheet.implicitHeight / 3)
    }

    OrbFrame {
        id: hoverFrame
        sourceClipRect: Qt.rect(0, sheet.implicitHeight / 3, sheet.implicitWidth, sheet.implicitHeight / 3)
        opacity: orbButton.hovered && !orbButton.pressed ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.Linear }
        }
    }

    OrbFrame {
        sourceClipRect: Qt.rect(0, 2 * sheet.implicitHeight / 3, sheet.implicitWidth, sheet.implicitHeight / 3)
        opacity: orbButton.pressed ? 1 : 0
    }
}
