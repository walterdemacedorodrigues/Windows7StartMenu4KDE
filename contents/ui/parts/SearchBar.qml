/*
 *  SPDX-FileCopyrightText: 2025 Walter Rodrigues <wmr2@cin.ufpe.br>
 *  SPDX-License-Identifier: AGPL-3.0-or-later
 */

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

/**
 * Search bar component for the Windows 7 Start Menu
 * Provides text input for searching applications and files
 */
Rectangle {
    id: searchBar

    // Layout properties
    Layout.fillWidth: true
    Layout.preferredHeight: Kirigami.Units.gridUnit * 2.5
    Layout.minimumHeight: Kirigami.Units.gridUnit * 2.5
    Layout.maximumHeight: Kirigami.Units.gridUnit * 2.5

    color: "transparent"

    // Properties
    property alias text: searchField.text
    property bool isSearching: text !== ""
    property var menuContentRef: null
    property var runnerModelRef: null
    property int currentShowApps: 0

    // Signals
    signal searchTextChanged(string text)
    signal escapePressed()
    signal navigateToResults()
    signal keyNavDown()
    signal contextMenuRequested(real x, real y)

    MouseArea {
        anchors.fill: parent
        z: -1
        acceptedButtons: Qt.RightButton
        onClicked: mouse => searchBar.contextMenuRequested(mouse.x, mouse.y)
    }

    // Public functions
    function clear() {
        searchField.clear();
    }

    function backspace() {
        searchField.backspace();
    }

    function appendText(newText) {
        searchField.appendText(newText);
    }

    function focusSearchField() {
        searchField.forceActiveFocus();
    }

    // Search field
    PlasmaComponents3.TextField {
        id: searchField

        width: parent.width * 0.6 * 0.9
        height: Kirigami.Units.gridUnit * 1.8

        anchors {
            left: parent.left
            leftMargin: parent.width * 0.6 * 0.05
            verticalCenter: parent.verticalCenter
        }

        placeholderText: "🔍 " + i18n("Type here to search…")

        onTextChanged: {
            searchBar.isSearching = (text !== "");

            // Update runner model query
            if (searchBar.runnerModelRef) {
                searchBar.runnerModelRef.query = text;
            }

            searchBar.searchTextChanged(text);
        }

        function backspace() {
            if (!visible) return;
            focus = true;
            text = text.slice(0, -1);
        }

        function appendText(newText) {
            if (!visible) return;
            focus = true;
            text = text + newText;
        }

        function clear() {
            text = "";
        }

        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape) {
                event.accepted = true;
                if (searchBar.isSearching) {
                    clear();
                } else {
                    searchBar.escapePressed();
                }
            } else if (event.key === Qt.Key_Up) {
                event.accepted = true;
                const recents = searchBar.menuContentRef ? searchBar.menuContentRef.recentsGrid : null;
                if (recents && recents.visible && recents.count > 0) {
                    recents.forceActiveFocus();
                    recents.currentIndex = recents.count - 1;
                }
            } else if (event.key === Qt.Key_Down) {
                event.accepted = true;
                searchBar.keyNavDown();
            } else if (event.key === Qt.Key_Tab) {
                event.accepted = true;
                searchBar.keyNavDown();
            } else if (event.key === Qt.Key_Backtab) {
                event.accepted = true;
                searchBar.navigateToResults();
            }
        }
    }
}
