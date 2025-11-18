/*
 *  SPDX-FileCopyrightText: 2025 Walter Rodrigues <wmr2@cin.ufpe.br>
 *  SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

/**
 * Power management buttons for the Windows 7 Start Menu
 * Includes shutdown button and dropdown menu with system actions
 */
Item {
    id: powerButtons

    // Properties
    property bool actionInProgress: false

    // Signals
    signal executeAction(string command, string actionType)
    signal keyNavUp()
    signal keyNavDown()
    signal keyNavLeft()

    // Keyboard navigation
    focus: true
    activeFocusOnTab: true

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Up) {
            event.accepted = true;
            keyNavUp();
        } else if (event.key === Qt.Key_Down) {
            event.accepted = true;
            keyNavDown();
        } else if (event.key === Qt.Key_Left) {
            event.accepted = true;
            keyNavLeft();
        } else if (event.key === Qt.Key_Right) {
            event.accepted = true;
            systemActionsMenu.visible = !systemActionsMenu.visible;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            event.accepted = true;
            shutdownButton.clicked();
        }
    }

    // Main shutdown button
    PlasmaComponents3.Button {
        id: shutdownButton
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: parent.width - dropdownButton.width - 2
        text: i18n("Shutdown")
        icon.name: "system-shutdown"
        enabled: !powerButtons.actionInProgress

        // Make background transparent so highlight shows through
        background: Item {}

        onClicked: {
            powerButtons.executeAction("qdbus6 org.kde.Shutdown /Shutdown logoutAndShutdown || systemctl poweroff", "shutdown");
        }
    }

    // Dropdown toggle button
    PlasmaComponents3.Button {
        id: dropdownButton
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.leftMargin: -2
        width: Kirigami.Units.gridUnit * 1.2
        icon.name: "arrow-down"

        // Make background transparent so highlight shows through
        background: Item {}

        onClicked: {
            systemActionsMenu.visible = !systemActionsMenu.visible;
        }
    }

    // Dropdown menu with system actions
    Rectangle {
        id: systemActionsMenu
        visible: false
        width: Kirigami.Units.gridUnit * 10
        height: systemActionsColumn.height + (Kirigami.Units.smallSpacing * 2)
        color: Kirigami.Theme.backgroundColor
        border.width: 1
        border.color: Kirigami.Theme.separatorColor
        radius: 4

        anchors.bottom: parent.top
        anchors.right: parent.right
        anchors.bottomMargin: Kirigami.Units.smallSpacing

        z: 2000

        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape) {
                event.accepted = true;
                visible = false;
            }
        }

        // Shadow effect
        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 2
            anchors.leftMargin: 2
            radius: parent.radius
            color: Qt.rgba(0, 0, 0, 0.3)
            z: -1
        }

        // System actions column
        Column {
            id: systemActionsColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Kirigami.Units.smallSpacing
            spacing: 2

            // Restart
            PlasmaComponents3.Button {
                width: parent.width
                height: Kirigami.Units.gridUnit * 1.8
                text: i18n("Restart")
                icon.name: "system-reboot"
                flat: true
                enabled: !powerButtons.actionInProgress

                onClicked: {
                    // Try Plasma 6 first, fallback to systemctl
                    powerButtons.executeAction("qdbus6 org.kde.Shutdown /Shutdown logoutAndReboot || systemctl reboot", "restart");
                }
            }

            // Turn Off Screen
            PlasmaComponents3.Button {
                width: parent.width
                height: Kirigami.Units.gridUnit * 1.8
                text: i18n("Turn Off Screen")
                icon.name: "video-display"
                flat: true
                enabled: !powerButtons.actionInProgress

                onClicked: {
                    powerButtons.executeAction("kscreen-doctor --dpms off", "screen_off");
                }
            }

            // Lock Screen
            PlasmaComponents3.Button {
                width: parent.width
                height: Kirigami.Units.gridUnit * 1.8
                text: i18n("Lock Screen")
                icon.name: "system-lock-screen"
                flat: true
                enabled: !powerButtons.actionInProgress

                onClicked: {
                    // Try Plasma 6 first, fallback to Plasma 5
                    powerButtons.executeAction("loginctl lock-session || qdbus org.kde.kscreenlocker /ScreenSaver Lock", "lock");
                }
            }

            // Sleep
            PlasmaComponents3.Button {
                width: parent.width
                height: Kirigami.Units.gridUnit * 1.8
                text: i18n("Sleep")
                icon.name: "system-suspend"
                flat: true
                enabled: !powerButtons.actionInProgress

                onClicked: {
                    powerButtons.executeAction("systemctl suspend", "suspend");
                }
            }

            // Hibernate
            PlasmaComponents3.Button {
                width: parent.width
                height: Kirigami.Units.gridUnit * 1.8
                text: i18n("Hibernate")
                icon.name: "system-suspend-hibernate"
                flat: true
                enabled: !powerButtons.actionInProgress

                onClicked: {
                    powerButtons.executeAction("systemctl hibernate", "hibernate");
                }
            }

            // Log Out
            PlasmaComponents3.Button {
                width: parent.width
                height: Kirigami.Units.gridUnit * 1.8
                text: i18n("Log Out")
                icon.name: "system-log-out"
                flat: true
                enabled: !powerButtons.actionInProgress

                onClicked: {
                    // Try Plasma 6 first, fallback to Plasma 5
                    var logoutCmd = "qdbus6 org.kde.Shutdown /Shutdown logout || qdbus org.kde.ksmserver /KSMServer logout 1 0 0";
                    powerButtons.executeAction(logoutCmd, "logout");
                }
            }
        }

        // Transparent mouse area to prevent clicks from closing menu
        MouseArea {
            anchors.fill: parent
            propagateComposedEvents: true
            onPressed: {
                mouse.accepted = false;
            }
        }
    }
}
