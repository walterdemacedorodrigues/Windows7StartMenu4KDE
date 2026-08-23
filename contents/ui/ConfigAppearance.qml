/*
 *  SPDX-FileCopyrightText: 2025 Walter Rodrigues <wmr2@cin.ufpe.br>
 *  SPDX-License-Identifier: AGPL-3.0-or-later
 */

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kquickcontrols as KQuickControls
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: configAppearance

    property alias cfg_menuFrameUseThemeColor: menuFrameUseThemeColor.checked
    property alias cfg_menuFrameColor: menuFrameColor.color
    property alias cfg_menuFrameOpacity: menuFrameOpacity.value

    property alias cfg_listPanelUseThemeColor: listPanelUseThemeColor.checked
    property alias cfg_listPanelColor: listPanelColor.color
    property alias cfg_listPanelOpacity: listPanelOpacity.value

    property alias cfg_sidePanelUseThemeColor: sidePanelUseThemeColor.checked
    property alias cfg_sidePanelColor: sidePanelColor.color
    property alias cfg_sidePanelOpacity: sidePanelOpacity.value

    Kirigami.FormLayout {
        anchors.left: parent.left
        anchors.right: parent.right

        Label {
            text: i18n("A tint is painted over the theme background. At zero the theme is left untouched, and at one hundred the area is solid.")
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            Layout.maximumWidth: configAppearance.width - Kirigami.Units.gridUnit * 2
        }

        // ---- Whole menu -----------------------------------------------------

        Slider {
            id: menuFrameOpacity
            Kirigami.FormData.label: i18n("Whole menu opacity:")
            from: 0
            to: 100
            stepSize: 1
            snapMode: Slider.SnapAlways
        }

        Label {
            text: menuFrameOpacity.value === 0 ? i18n("Theme default") : menuFrameOpacity.value + "%"
        }

        CheckBox {
            id: menuFrameUseThemeColor
            text: i18n("Use the theme background colour")
            enabled: menuFrameOpacity.value > 0
        }

        KQuickControls.ColorButton {
            id: menuFrameColor
            Kirigami.FormData.label: i18n("Menu colour:")
            enabled: menuFrameOpacity.value > 0 && !menuFrameUseThemeColor.checked
            showAlphaChannel: false
        }

        Item { Kirigami.FormData.isSection: true }

        // ---- Application list ------------------------------------------------

        Slider {
            id: listPanelOpacity
            Kirigami.FormData.label: i18n("Application list opacity:")
            from: 0
            to: 100
            stepSize: 1
            snapMode: Slider.SnapAlways
        }

        Label {
            text: listPanelOpacity.value === 0 ? i18n("Theme default") : listPanelOpacity.value + "%"
        }

        CheckBox {
            id: listPanelUseThemeColor
            text: i18n("Use the theme background colour")
            enabled: listPanelOpacity.value > 0
        }

        KQuickControls.ColorButton {
            id: listPanelColor
            Kirigami.FormData.label: i18n("Application list colour:")
            enabled: listPanelOpacity.value > 0 && !listPanelUseThemeColor.checked
            showAlphaChannel: false
        }

        Item { Kirigami.FormData.isSection: true }

        // ---- Side panel --------------------------------------------------------

        Slider {
            id: sidePanelOpacity
            Kirigami.FormData.label: i18n("Side panel opacity:")
            from: 0
            to: 100
            stepSize: 1
            snapMode: Slider.SnapAlways
        }

        Label {
            text: sidePanelOpacity.value === 0 ? i18n("Theme default") : sidePanelOpacity.value + "%"
        }

        CheckBox {
            id: sidePanelUseThemeColor
            text: i18n("Use the theme background colour")
            enabled: sidePanelOpacity.value > 0
        }

        KQuickControls.ColorButton {
            id: sidePanelColor
            Kirigami.FormData.label: i18n("Side panel colour:")
            enabled: sidePanelOpacity.value > 0 && !sidePanelUseThemeColor.checked
            showAlphaChannel: false
        }
    }
}
