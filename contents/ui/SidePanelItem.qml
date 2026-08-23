/*
 *  SPDX-FileCopyrightText: 2025 Walter Rodrigues <wmr2@cin.ufpe.br>
 *  SPDX-FileCopyrightText: 2023 WackyIdeas <wackyideas@disroot.org>
 *  SPDX-License-Identifier: AGPL-3.0-or-later
 */

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami

// One entry of the right hand column. Geometry follows the original 33 pixel
// row so the column keeps its Windows 7 proportions. Entries carrying a
// menuModel grow a flyout that opens on hover after a configurable delay.
Item {
    id: sidePanelItem

    objectName: "SidePanelItem"

    property string itemText: ""
    property string itemIcon: ""
    property string itemIconFallback: "unknown"
    property string description: ""
    property string executableString: ""
    property bool executeProgram: false
    property var menuModel: null
    property var executable: null

    signal navigateLeft()
    signal navigateBelow()
    signal navigateAbove()
    signal closeRequested()

    readonly property bool hasFlyout: menuModel !== null
    readonly property bool flyoutOpen: flyout.opened
    readonly property string resolvedIcon: Plasmoid.configuration.useWindowsIcons ? itemIcon : itemIconFallback

    implicitHeight: Math.round(Kirigami.Units.gridUnit * 1.85)
    activeFocusOnTab: true

    // Walks the sibling list so that adding, hiding or reordering entries never
    // breaks the up/down chain the way hardcoded child indices do.
    function siblingAt(step) {
        const siblings = parent ? parent.visibleChildren : [];
        let self = -1;
        for (let i = 0; i < siblings.length; i++) {
            if (siblings[i] === sidePanelItem) { self = i; break; }
        }
        if (self === -1) return null;
        for (let j = self + step; j >= 0 && j < siblings.length; j += step) {
            if (siblings[j] && siblings[j].objectName === "SidePanelItem") return siblings[j];
        }
        return null;
    }

    function activate() {
        closeRequested();
        if (executeProgram) {
            if (executable) executable.exec(executableString);
        } else {
            Qt.callLater(Qt.openUrlExternally, executableString);
        }
    }

    function openFlyout() {
        if (!hasFlyout) return;
        flyout.popup(sidePanelItem, sidePanelItem.width, 0);
    }

    Keys.onPressed: event => {
        switch (event.key) {
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_Space:
            event.accepted = true;
            if (hasFlyout) openFlyout(); else activate();
            break;
        case Qt.Key_Right:
            if (hasFlyout) {
                event.accepted = true;
                openFlyout();
            }
            break;
        case Qt.Key_Left:
            event.accepted = true;
            navigateLeft();
            break;
        case Qt.Key_Down: {
            event.accepted = true;
            const next = siblingAt(1);
            if (next) next.forceActiveFocus(); else navigateBelow();
            break;
        }
        case Qt.Key_Up: {
            event.accepted = true;
            const prev = siblingAt(-1);
            if (prev) prev.forceActiveFocus(); else navigateAbove();
            break;
        }
        }
    }

    PlasmaExtras.Highlight {
        anchors.fill: parent
        hovered: mouseArea.containsMouse || sidePanelItem.activeFocus || flyout.opened
        pressed: mouseArea.containsPress
        visible: hovered || pressed
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Kirigami.Units.smallSpacing * 2
        anchors.rightMargin: Kirigami.Units.smallSpacing * 2
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Icon {
            source: sidePanelItem.resolvedIcon
            fallback: sidePanelItem.itemIconFallback
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            Layout.preferredHeight: Kirigami.Units.iconSizes.small
        }

        PlasmaComponents.Label {
            id: label
            text: sidePanelItem.itemText
            elide: Text.ElideRight
            maximumLineCount: 1
            Layout.fillWidth: true
        }

        // Matches the 6x10 group expander of the original side panel.
        Kirigami.Icon {
            source: "arrow-right"
            visible: sidePanelItem.hasFlyout
            Layout.preferredWidth: Math.round(Kirigami.Units.iconSizes.small * 0.4)
            Layout.preferredHeight: Math.round(Kirigami.Units.iconSizes.small * 0.66)
            opacity: 0.7
        }
    }

    PlasmaCore.ToolTipArea {
        anchors.fill: parent
        active: sidePanelItem.description !== "" && !sidePanelItem.hasFlyout
        interactive: false
        mainText: sidePanelItem.itemText
        subText: sidePanelItem.description
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton

        onEntered: {
            sidePanelItem.forceActiveFocus();
            if (sidePanelItem.hasFlyout) flyoutTimer.restart();
        }
        onExited: flyoutTimer.stop()
        onClicked: {
            flyoutTimer.stop();
            if (sidePanelItem.hasFlyout) openFlyout(); else sidePanelItem.activate();
        }
    }

    Timer {
        id: flyoutTimer
        interval: Plasmoid.configuration.submenuHoverDelay
        onTriggered: sidePanelItem.openFlyout()
    }

    // A QtQuick menu rather than the QMenu wrapper, so the left arrow can walk
    // back out of the flyout instead of forcing the user to press Escape.
    PlasmaComponents.Menu {
        id: flyout

        onClosed: if (sidePanelItem.visible) sidePanelItem.forceActiveFocus()

        // Second route out, in case the popup is a window of its own and the
        // entry never sees the key. Only live while this flyout is open.
        Shortcut {
            sequence: "Left"
            enabled: flyout.opened
            context: Qt.ApplicationShortcut
            onActivated: flyout.close()
        }

        Instantiator {
            model: sidePanelItem.menuModel
            delegate: PlasmaComponents.MenuItem {
                required property int index
                required property var model

                visible: index < Plasmoid.configuration.numberRecentFiles
                height: visible ? implicitHeight : 0
                text: model.display
                // The decoration role is a name for some models and a QIcon for others.
                icon.name: typeof model.decoration === "string" ? model.decoration : ""
                onTriggered: {
                    sidePanelItem.menuModel.trigger(index, "", null);
                    sidePanelItem.closeRequested();
                }
                // Keys cannot attach to the Menu itself, so the focused entry
                // is what walks the user back out to the side panel.
                Keys.priority: Keys.BeforeItem
                Keys.onLeftPressed: event => { event.accepted = true; flyout.close(); }
            }
            onObjectAdded: (index, object) => flyout.insertItem(index, object)
            onObjectRemoved: (index, object) => flyout.removeItem(object)
        }
    }
}
