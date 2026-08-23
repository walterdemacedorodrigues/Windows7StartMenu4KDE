/*
 *  SPDX-FileCopyrightText: 2025 Walter Rodrigues <wmr2@cin.ufpe.br>
 *  SPDX-License-Identifier: AGPL-3.0-or-later
 */

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import org.kde.draganddrop as DragDrop
import org.kde.kirigami as Kirigami
import org.kde.iconthemes as KIconThemes
import org.kde.plasma.core as PlasmaCore
import org.kde.ksvg as KSvg
import org.kde.plasma.plasmoid 2.0
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: configGeneral

    property string cfg_icon: Plasmoid.configuration.icon
    property bool cfg_useCustomButtonImage: Plasmoid.configuration.useCustomButtonImage
    property string cfg_customButtonImage: Plasmoid.configuration.customButtonImage
    property string cfg_orbImage: Plasmoid.configuration.orbImage

    property alias cfg_useWindowsOrb: useWindowsOrb.checked
    property alias cfg_orbWidth: orbWidth.value
    property alias cfg_useWindowsIcons: useWindowsIcons.checked
    property alias cfg_useGenericIcons: useGenericIcons.checked

    property alias cfg_hierarchicalAllPrograms: hierarchicalAllPrograms.checked
    property alias cfg_highlightNewApps: highlightNewApps.checked
    property alias cfg_showFavoritesFirst: showFavoritesFirst.checked

    property alias cfg_showRecentsView: showRecentsView.checked
    property alias cfg_numberRecentApps: numberRecentApps.value
    property alias cfg_numberRecentFiles: numberRecentFiles.value
    property alias cfg_submenuHoverDelay: submenuHoverDelay.value
    property alias cfg_useFullName: useFullName.checked

    property alias cfg_useExtraRunners: useExtraRunners.checked

    Kirigami.FormLayout {
        anchors.left: parent.left
        anchors.right: parent.right

        // ---- Start button -------------------------------------------------

        Button {
            id: iconButton

            Kirigami.FormData.label: i18n("System icon:")
            enabled: !useWindowsOrb.checked

            implicitWidth: previewFrame.width + Kirigami.Units.smallSpacing * 2
            implicitHeight: previewFrame.height + Kirigami.Units.smallSpacing * 2

            checkable: true
            checked: dropArea.containsAcceptableDrag

            onPressed: iconMenu.opened ? iconMenu.close() : iconMenu.open()

            DragDrop.DropArea {
                id: dropArea

                property bool containsAcceptableDrag: false

                anchors.fill: parent

                onDragEnter: event => {
                    const urlString = event.mimeData.url.toString();
                    const extensions = [".png", ".xpm", ".svg", ".svgz"];
                    containsAcceptableDrag = urlString.indexOf("file:///") === 0 && extensions.some(function (extension) {
                        return urlString.indexOf(extension) === urlString.length - extension.length;
                    });
                    if (!containsAcceptableDrag) event.ignore();
                }
                onDragLeave: containsAcceptableDrag = false
                onDrop: event => {
                    if (containsAcceptableDrag) {
                        iconDialog.setCustomButtonImage(event.mimeData.url.toString().substr("file://".length));
                    }
                    containsAcceptableDrag = false;
                }
            }

            KIconThemes.IconDialog {
                id: iconDialog

                function setCustomButtonImage(image) {
                    configGeneral.cfg_customButtonImage = image || configGeneral.cfg_icon || "start-here-kde";
                    configGeneral.cfg_useCustomButtonImage = true;
                }

                onIconNameChanged: setCustomButtonImage(iconName)
            }

            KSvg.FrameSvgItem {
                id: previewFrame
                anchors.centerIn: parent
                imagePath: Plasmoid.location === PlasmaCore.Types.Vertical || Plasmoid.location === PlasmaCore.Types.Horizontal
                           ? "widgets/panel-background" : "widgets/background"
                width: Kirigami.Units.iconSizes.large + fixedMargins.left + fixedMargins.right
                height: Kirigami.Units.iconSizes.large + fixedMargins.top + fixedMargins.bottom

                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: Kirigami.Units.iconSizes.large
                    height: width
                    source: configGeneral.cfg_useCustomButtonImage ? configGeneral.cfg_customButtonImage : configGeneral.cfg_icon
                }
            }

            Menu {
                id: iconMenu
                y: parent.height
                onClosed: iconButton.checked = false

                MenuItem {
                    text: i18nc("@item:inmenu Open icon chooser dialog", "Choose…")
                    icon.name: "document-open-folder"
                    onClicked: iconDialog.open()
                }
                MenuItem {
                    text: i18nc("@item:inmenu Reset icon to default", "Clear Icon")
                    icon.name: "edit-clear"
                    onClicked: {
                        configGeneral.cfg_icon = "start-here-kde";
                        configGeneral.cfg_useCustomButtonImage = false;
                    }
                }
            }
        }

        CheckBox {
            id: useWindowsOrb
            text: i18n("Use the Windows orb instead of a system icon")
        }

        OrbPicker {
            Kirigami.FormData.label: i18n("Orb texture:")
            enabled: useWindowsOrb.checked
            currentOrb: configGeneral.cfg_orbImage
            onOrbChanged: orb => configGeneral.cfg_orbImage = orb
        }

        SpinBox {
            id: orbWidth
            Kirigami.FormData.label: i18n("Orb width:")
            enabled: useWindowsOrb.checked
            from: 0
            to: 256
            textFromValue: (value) => value === 0 ? i18n("Texture size") : value + " px"
        }

        Item { Kirigami.FormData.isSection: true }

        // ---- Icons --------------------------------------------------------

        CheckBox {
            id: useWindowsIcons
            Kirigami.FormData.label: i18n("Icons:")
            text: i18n("Prefer Windows style icons in the side panel")
        }

        CheckBox {
            id: useGenericIcons
            text: i18n("Draw application categories with a plain folder icon")
        }

        Item { Kirigami.FormData.isSection: true }

        // ---- All Programs -------------------------------------------------

        CheckBox {
            id: hierarchicalAllPrograms
            Kirigami.FormData.label: i18n("All Programs:")
            text: i18n("Browse categories as an expandable tree")
        }

        CheckBox {
            id: highlightNewApps
            text: i18n("Highlight newly installed applications")
        }

        CheckBox {
            id: showFavoritesFirst
            text: i18n("Show favorites before recently used applications")
        }

        Item { Kirigami.FormData.isSection: true }

        // ---- Recents ------------------------------------------------------

        CheckBox {
            id: showRecentsView
            Kirigami.FormData.label: i18n("Recents:")
            text: i18n("Show recently used applications")
        }

        SpinBox {
            id: numberRecentApps
            Kirigami.FormData.label: i18n("Applications listed:")
            enabled: showRecentsView.checked
            from: 0
            to: 20
        }

        SpinBox {
            id: numberRecentFiles
            Kirigami.FormData.label: i18n("Documents per jump list:")
            from: 1
            to: 30
        }

        Item { Kirigami.FormData.isSection: true }

        // ---- Side panel ---------------------------------------------------

        SpinBox {
            id: submenuHoverDelay
            Kirigami.FormData.label: i18n("Flyout hover delay:")
            from: 0
            to: 2000
            stepSize: 50
            textFromValue: (value) => value + " ms"
        }

        CheckBox {
            id: useFullName
            text: i18n("Label the home entry with the full user name")
        }

        Item { Kirigami.FormData.isSection: true }

        // ---- Behaviour ----------------------------------------------------

        CheckBox {
            id: useExtraRunners
            text: i18n("Search bookmarks and files as well as applications")
        }

        Button {
            text: i18n("Unhide all hidden applications")
            onClicked: {
                Plasmoid.configuration.hiddenApplications = [""];
                unhideFeedback.text = i18n("All applications are visible again.");
            }
        }

        Label {
            id: unhideFeedback
        }
    }
}
