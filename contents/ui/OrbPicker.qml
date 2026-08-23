/*
 *  SPDX-FileCopyrightText: 2025 Walter Rodrigues <wmr2@cin.ufpe.br>
 *  SPDX-FileCopyrightText: 2023 WackyIdeas <wackyideas@disroot.org>
 *  SPDX-License-Identifier: AGPL-3.0-or-later
 */

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import org.kde.kirigami as Kirigami

// Picks the three frame PNG used for the Windows orb, previewing its top frame.
RowLayout {
    id: orbPicker

    property url currentOrb
    signal orbChanged(url orb)

    spacing: Kirigami.Units.largeSpacing

    FileDialog {
        id: fileDialog
        nameFilters: [i18n("PNG images (*.png)")]
        fileMode: FileDialog.OpenFile
        onAccepted: {
            if (selectedFile.toString().toLowerCase().endsWith(".png")) {
                orbPicker.orbChanged(selectedFile);
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true

        Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: i18n("ClassicShell and OpenShell orb textures are supported. The image must stack the normal, hovered and pressed frames vertically.")
        }

        RowLayout {
            Button {
                text: i18nc("@item:inmenu Open file chooser dialog", "Choose…")
                onClicked: fileDialog.open()
            }
            Button {
                text: i18nc("@item:inmenu Reset to the bundled orb", "Reset")
                onClicked: orbPicker.orbChanged("")
            }
        }
    }

    Rectangle {
        Layout.preferredWidth: Kirigami.Units.iconSizes.huge
        Layout.preferredHeight: Kirigami.Units.iconSizes.large
        color: Kirigami.Theme.alternateBackgroundColor
        radius: Kirigami.Units.smallSpacing

        Image {
            id: sheet
            source: orbPicker.currentOrb.toString() !== "" ? orbPicker.currentOrb : Qt.resolvedUrl("orbs/orb.png")
            visible: false
        }

        Image {
            anchors.centerIn: parent
            source: sheet.source
            sourceClipRect: Qt.rect(0, 0, sheet.implicitWidth, sheet.implicitHeight / 3)
            fillMode: Image.PreserveAspectFit
            width: Math.min(sheet.implicitWidth, parent.width - Kirigami.Units.smallSpacing * 2)
            height: width * (sheet.implicitHeight > 0 ? sheet.implicitHeight / sheet.implicitWidth : 1)
            smooth: true
        }
    }
}
