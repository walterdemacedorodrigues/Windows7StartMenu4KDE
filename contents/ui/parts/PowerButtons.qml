/*
 *  SPDX-FileCopyrightText: 2025 Walter Rodrigues <wmr2@cin.ufpe.br>
 *  SPDX-License-Identifier: AGPL-3.0-or-later
 */

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami

/**
 * Power management buttons for the Windows 7 Start Menu
 * Shutdown split button plus a dropdown with the remaining session actions.
 */
FocusScope {
    id: powerButtons

    property bool actionInProgress: false

    signal executeAction(string command, string actionType)
    signal keyNavUp()
    signal keyNavDown()
    signal keyNavLeft()
    signal closeRequested()

    activeFocusOnTab: true

    readonly property var actions: [
        { text: i18n("Restart"),        icon: "system-reboot",            type: "restart",
          command: "qdbus6 org.kde.Shutdown /Shutdown logoutAndReboot || systemctl reboot" },
        { text: i18n("Turn Off Screen"), icon: "video-display",           type: "screen_off",
          command: "kscreen-doctor --dpms off" },
        { text: i18n("Lock Screen"),    icon: "system-lock-screen",       type: "lock",
          command: "loginctl lock-session || qdbus org.kde.kscreenlocker /ScreenSaver Lock" },
        { text: i18n("Sleep"),          icon: "system-suspend",           type: "suspend",
          command: "systemctl suspend" },
        { text: i18n("Hibernate"),      icon: "system-suspend-hibernate", type: "hibernate",
          command: "systemctl hibernate" },
        { text: i18n("Log Out"),        icon: "system-log-out",           type: "logout",
          command: "qdbus6 org.kde.Shutdown /Shutdown logout || qdbus org.kde.ksmserver /KSMServer logout 1 0 0" }
    ]

    // -1 means the dropdown is closed.
    property int menuIndex: -1
    readonly property bool menuOpen: menuIndex >= 0

    function openMenu() {
        menuIndex = actions.length - 1;   // nearest entry, the list opens upwards
        forceActiveFocus();
    }

    function closeMenu() {
        menuIndex = -1;
        forceActiveFocus();
    }

    function runShutdown() {
        powerButtons.executeAction("qdbus6 org.kde.Shutdown /Shutdown logoutAndShutdown || systemctl poweroff", "shutdown");
    }

    function runAction(index) {
        const action = actions[index];
        if (!action) return;
        closeMenu();
        powerButtons.executeAction(action.command, action.type);
    }

    Keys.onPressed: (event) => {
        if (menuOpen) {
            switch (event.key) {
            case Qt.Key_Up:
                event.accepted = true;
                menuIndex = (menuIndex - 1 + actions.length) % actions.length;
                break;
            case Qt.Key_Down:
                event.accepted = true;
                menuIndex = (menuIndex + 1) % actions.length;
                break;
            case Qt.Key_Left:
            case Qt.Key_Escape:
                event.accepted = true;
                closeMenu();
                break;
            case Qt.Key_Return:
            case Qt.Key_Enter:
            case Qt.Key_Space:
                event.accepted = true;
                runAction(menuIndex);
                break;
            }
            return;
        }

        switch (event.key) {
        case Qt.Key_Up:    event.accepted = true; keyNavUp(); break;
        case Qt.Key_Down:  event.accepted = true; keyNavDown(); break;
        case Qt.Key_Left:  event.accepted = true; keyNavLeft(); break;
        case Qt.Key_Right: event.accepted = true; openMenu(); break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_Space: event.accepted = true; runShutdown(); break;
        }
    }

    onActiveFocusChanged: if (!activeFocus) menuIndex = -1

    PlasmaComponents3.Button {
        id: shutdownButton
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: parent.width - dropdownButton.width - 2
        text: i18n("Shutdown")
        icon.name: "system-shutdown"
        enabled: !powerButtons.actionInProgress
        focusPolicy: Qt.NoFocus
        background: Item {}

        onClicked: powerButtons.runShutdown()

        PlasmaCore.ToolTipArea {
            anchors.fill: parent
            interactive: false
            mainText: shutdownButton.text
            subText: i18n("Closes all open programs, shuts down the system and turns off your computer.")
        }
    }

    PlasmaComponents3.Button {
        id: dropdownButton
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: Kirigami.Units.gridUnit * 1.2
        icon.name: powerButtons.menuOpen ? "arrow-down" : "arrow-up"
        focusPolicy: Qt.NoFocus
        background: Item {}

        onClicked: powerButtons.menuOpen ? powerButtons.closeMenu() : powerButtons.openMenu()
    }

    Rectangle {
        id: systemActionsMenu
        visible: powerButtons.menuOpen
        width: Kirigami.Units.gridUnit * 10
        height: systemActionsColumn.height + Kirigami.Units.smallSpacing * 2
        color: Kirigami.Theme.backgroundColor
        border.width: 1
        border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.25)
        radius: 4

        anchors.bottom: parent.top
        anchors.right: parent.right
        anchors.bottomMargin: Kirigami.Units.smallSpacing

        z: 2000

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 2
            anchors.leftMargin: 2
            radius: parent.radius
            color: Qt.rgba(0, 0, 0, 0.3)
            z: -1
        }

        Column {
            id: systemActionsColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Kirigami.Units.smallSpacing
            spacing: 2

            Repeater {
                model: powerButtons.actions

                delegate: Item {
                    required property int index
                    required property var modelData

                    width: systemActionsColumn.width
                    height: Kirigami.Units.gridUnit * 1.8

                    PlasmaExtras.Highlight {
                        anchors.fill: parent
                        hovered: entryMouse.containsMouse || powerButtons.menuIndex === index
                        pressed: entryMouse.containsPress
                        visible: hovered || pressed
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Kirigami.Units.smallSpacing * 2
                        anchors.rightMargin: Kirigami.Units.smallSpacing
                        spacing: Kirigami.Units.smallSpacing * 1.5

                        Kirigami.Icon {
                            source: modelData.icon
                            Layout.preferredWidth: Kirigami.Units.iconSizes.small
                            Layout.preferredHeight: Kirigami.Units.iconSizes.small
                        }

                        PlasmaComponents3.Label {
                            text: modelData.text
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    MouseArea {
                        id: entryMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: !powerButtons.actionInProgress
                        onEntered: powerButtons.menuIndex = index
                        onClicked: powerButtons.runAction(index)
                    }
                }
            }
        }
    }
}
