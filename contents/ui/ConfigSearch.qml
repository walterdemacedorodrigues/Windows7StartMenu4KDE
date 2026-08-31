/*
 *  SPDX-FileCopyrightText: 2025 Walter Rodrigues <wmr2@cin.ufpe.br>
 *  SPDX-License-Identifier: AGPL-3.0-or-later
 */

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Dialogs as Dialogs
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid 2.0
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: configSearch

    property alias cfg_searchRecentDocuments: searchRecentDocuments.checked
    property alias cfg_extendedSearch: extendedSearch.checked
    property alias cfg_extendedSearchMax: extendedSearchMax.value
    property alias cfg_extendedSearchTimeout: extendedSearchTimeout.value
    property string cfg_extendedSearchEngine: Plasmoid.configuration.extendedSearchEngine
    property var cfg_extendedSearchPaths: Plasmoid.configuration.extendedSearchPaths

    // The external engines walk the roots below; Baloo has its own index and
    // ignores them, so the path editor goes dim instead of lying about scope.
    readonly property bool usesRoots: cfg_extendedSearchEngine !== "kde"

    Kirigami.FormLayout {
        anchors.left: parent.left
        anchors.right: parent.right

        CheckBox {
            id: searchRecentDocuments
            Kirigami.FormData.label: i18n("Sections:")
            text: i18n("Show recently opened documents that match")
        }

        CheckBox {
            id: extendedSearch
            text: i18n("Show an extended search section for files")
        }

        Item { Kirigami.FormData.isSection: true }

        ComboBox {
            id: engineBox
            Kirigami.FormData.label: i18n("Engine:")
            enabled: extendedSearch.checked
            textRole: "label"
            valueRole: "value"
            model: [
                { value: "script", label: i18n("Same tool as Dolphin (kio-filenamesearch-grep)") },
                { value: "fd", label: i18n("fd") },
                { value: "find", label: i18n("find") },
                { value: "plocate", label: i18n("plocate index") },
                { value: "kde", label: i18n("KDE default (Baloo file search)") },
            ]
            onActivated: configSearch.cfg_extendedSearchEngine = currentValue
            Component.onCompleted: currentIndex = indexOfValue(configSearch.cfg_extendedSearchEngine)
        }

        Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.Wrap
            text: engineBox.currentValue === "kde"
                ? i18n("Uses the baloosearch runner, which needs file indexing enabled in System Settings.")
                : i18n("Type \"fd\", \"find\" or \"pl\" before the query to override the engine for a single search.")
            font: Kirigami.Theme.smallFont
        }

        Item { Kirigami.FormData.isSection: true }

        ColumnLayout {
            Kirigami.FormData.label: i18n("Search in:")
            Kirigami.FormData.labelAlignment: Qt.AlignTop
            enabled: extendedSearch.checked && configSearch.usesRoots
            spacing: Kirigami.Units.smallSpacing

            Frame {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 22
                Layout.preferredHeight: Kirigami.Units.gridUnit * 8

                ListView {
                    id: pathList
                    anchors.fill: parent
                    clip: true
                    model: configSearch.cfg_extendedSearchPaths

                    delegate: ItemDelegate {
                        width: pathList.width
                        highlighted: ListView.isCurrentItem
                        onClicked: pathList.currentIndex = index

                        contentItem: RowLayout {
                            Label {
                                Layout.fillWidth: true
                                text: modelData
                                elide: Text.ElideMiddle
                            }
                            ToolButton {
                                icon.name: "list-remove"
                                onClicked: configSearch.removePath(index)
                            }
                        }
                    }

                    Label {
                        anchors.centerIn: parent
                        width: parent.width - Kirigami.Units.gridUnit
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        visible: pathList.count === 0
                        text: i18n("No folder added: the home directory is searched.")
                        opacity: 0.6
                    }
                }
            }

            Button {
                text: i18n("Add folder…")
                icon.name: "list-add"
                onClicked: folderDialog.open()
            }

            Label {
                Layout.maximumWidth: Kirigami.Units.gridUnit * 22
                wrapMode: Text.Wrap
                text: i18n("Order matters: the time budget is spent from the top down, so put fast disks first.")
                font: Kirigami.Theme.smallFont
            }
        }

        Item { Kirigami.FormData.isSection: true }

        SpinBox {
            id: extendedSearchMax
            Kirigami.FormData.label: i18n("Result limit:")
            enabled: extendedSearch.checked
            from: 1
            to: 200
        }

        SpinBox {
            id: extendedSearchTimeout
            Kirigami.FormData.label: i18n("Time budget:")
            enabled: extendedSearch.checked
            from: 1
            to: 60
            textFromValue: (value, locale) => i18np("%1 second", "%1 seconds", value)
            valueFromText: text => parseInt(text, 10)
        }

        Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.Wrap
            text: i18n("Whatever the tool has already found when the budget runs out is shown; the rest is dropped.")
            font: Kirigami.Theme.smallFont
        }
    }

    Dialogs.FolderDialog {
        id: folderDialog
        title: i18n("Add a folder to search")
        onAccepted: configSearch.addPath(selectedFolder)
    }

    function addPath(folderUrl) {
        const path = folderUrl.toString().replace(/^file:\/\//, "");
        const paths = (cfg_extendedSearchPaths || []).slice();
        if (paths.indexOf(path) === -1) {
            paths.push(path);
            cfg_extendedSearchPaths = paths;
        }
    }

    function removePath(index) {
        const paths = (cfg_extendedSearchPaths || []).slice();
        paths.splice(index, 1);
        cfg_extendedSearchPaths = paths;
    }
}
