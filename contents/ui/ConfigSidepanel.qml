/*
 *  SPDX-FileCopyrightText: 2025 Walter Rodrigues <wmr2@cin.ufpe.br>
 *  SPDX-FileCopyrightText: 2023 WackyIdeas <wackyideas@disroot.org>
 *  SPDX-License-Identifier: AGPL-3.0-or-later
 */

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import org.kde.kcmutils as KCM
import org.kde.plasma.plasmoid 2.0
import org.kde.kirigami as Kirigami

// Chooses which entries the right hand column shows. The selection is stored as
// a JSON object keyed by the stable entry name, so reordering never loses it.
KCM.SimpleKCM {
    id: configSidepanel

    property alias cfg_sidePanelVisibility: visibilityField.text

    TextField {
        id: visibilityField
        visible: false
    }

    SidePanelModels { id: sidePanelModels }

    QtObject {
        id: visibility

        property var entries: ({})

        function isShown(name) { return typeof entries[name] !== "undefined"; }
        function setShown(name, shown) {
            const next = JSON.parse(JSON.stringify(entries));
            if (shown) next[name] = 1; else delete next[name];
            entries = next;
            visibilityField.text = JSON.stringify(next);
        }
    }

    component EntryBox: CheckBox {
        property var entry: null
        text: entry ? entry.itemText : ""
        icon.name: entry ? (Plasmoid.configuration.useWindowsIcons ? entry.itemIcon : entry.itemIconFallback) : ""
        checked: entry ? visibility.isShown(entry.name) : false
        onToggled: visibility.setShown(entry.name, checked)
    }

    ColumnLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Heading { level: 4; text: i18n("Places") }
        Repeater {
            model: sidePanelModels.firstCategory.length
            delegate: EntryBox {
                required property int index
                entry: sidePanelModels.firstCategory[index]
            }
        }

        Kirigami.Heading { level: 4; text: i18n("Libraries"); Layout.topMargin: Kirigami.Units.largeSpacing }
        Repeater {
            model: sidePanelModels.secondCategory.length
            delegate: EntryBox {
                required property int index
                entry: sidePanelModels.secondCategory[index]
            }
        }

        Kirigami.Heading { level: 4; text: i18n("System"); Layout.topMargin: Kirigami.Units.largeSpacing }
        Repeater {
            model: sidePanelModels.thirdCategory.length
            delegate: EntryBox {
                required property int index
                entry: sidePanelModels.thirdCategory[index]
            }
        }
    }

    Component.onCompleted: {
        const stored = Plasmoid.configuration.sidePanelVisibility;
        visibility.entries = (stored && stored !== "") ? JSON.parse(stored) : {};
    }
}
