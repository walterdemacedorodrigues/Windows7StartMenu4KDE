/*
 *  SPDX-FileCopyrightText: 2025 Walter Rodrigues <wmr2@cin.ufpe.br>
 *  SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick
import Qt5Compat.GraphicalEffects
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami

/**
 * Floating user avatar component for the Windows 7 Start Menu
 * Displays user profile picture with hover effects and click to open settings
 */
Rectangle {
    id: avatar

    // Properties
    property string userFaceIconUrl: ""
    property bool isExpanded: false
    property var executable: null

    // Signals
    signal clicked()
    signal keyNavUp()
    signal keyNavDown()
    signal keyNavLeft()

    // Visual properties
    width: Kirigami.Units.gridUnit * 3
    height: Kirigami.Units.gridUnit * 3
    radius: width / 2

    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: Kirigami.Units.smallSpacing

    color: "transparent"
    border.width: 2
    border.color: Kirigami.Theme.highlightColor || "#3daee9"

    z: 99999
    visible: isExpanded

    // Keyboard navigation
    focus: true
    activeFocusOnTab: true

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Down) {
            console.log("[ProfilePic] DOWN - going to Sidebar");
            event.accepted = true;
            keyNavDown();
        } else if (event.key === Qt.Key_Up) {
            console.log("[ProfilePic] UP - going to PowerButtons");
            event.accepted = true;
            keyNavUp();
        } else if (event.key === Qt.Key_Left) {
            console.log("[ProfilePic] LEFT - going to left side");
            event.accepted = true;
            keyNavLeft();
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            console.log("[ProfilePic] ENTER - activating");
            event.accepted = true;
            if (avatar.executable) {
                avatar.executable.exec("systemsettings5 kcm_users");
            }
            avatar.clicked();
        }
    }

    // Shadow effect
    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 4
        anchors.leftMargin: 2
        radius: parent.radius
        color: Qt.rgba(0, 0, 0, 0.4)
        z: -1
    }

    // Circular mask for user image
    Rectangle {
        id: mask
        width: parent.width - 4
        height: parent.height - 4
        anchors.centerIn: parent
        visible: false
        radius: width / 2
    }

    // User profile image
    Image {
        id: userImage
        width: parent.width - 4
        height: parent.height - 4
        anchors.centerIn: parent
        source: avatar.userFaceIconUrl
        cache: false
        visible: source !== ""
        fillMode: Image.PreserveAspectCrop

        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: mask
        }

        opacity: avatar.isExpanded ? 1.0 : 0.8
        scale: avatar.isExpanded ? 1.0 : 0.95

        Behavior on opacity {
            PropertyAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }

        Behavior on scale {
            PropertyAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }
    }

    // Fallback icon when no user image available
    Kirigami.Icon {
        id: userIcon
        width: parent.width - 8
        height: parent.height - 8
        anchors.centerIn: parent
        source: "user-identity"
        color: Kirigami.Theme.textColor || "#eff0f1"
        visible: avatar.userFaceIconUrl === ""

        opacity: avatar.isExpanded ? 1.0 : 0.8
        scale: avatar.isExpanded ? 1.0 : 0.95

        Behavior on opacity {
            PropertyAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }

        Behavior on scale {
            PropertyAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }
    }

    // Mouse interaction
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            if (avatar.executable) {
                avatar.executable.exec("systemsettings5 kcm_users");
            }
            avatar.clicked();
        }

        onEntered: {
            avatar.scale = 1.1;
            avatar.border.color = Kirigami.Theme.hoverColor || "#93cee9";
        }

        onExited: {
            avatar.scale = 1.0;
            avatar.border.color = Kirigami.Theme.highlightColor || "#3daee9";
        }
    }

    // Hover scale animation
    Behavior on scale {
        PropertyAnimation {
            duration: 150
            easing.type: Easing.OutCubic
        }
    }

    // Border color animation
    Behavior on border.color {
        ColorAnimation {
            duration: 150
        }
    }

    // Tooltip
    PlasmaCore.ToolTipArea {
        anchors.fill: parent
        active: true
        mainText: i18n("User Settings")
        subText: i18n("Click to open user account settings")
    }
}
