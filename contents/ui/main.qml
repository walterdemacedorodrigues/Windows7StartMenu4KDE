/*
 *  SPDX-FileCopyrightText: 2025 Walter Rodrigues <wmr2@cin.ufpe.br>
 *  SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.private.kicker 0.1 as Kicker
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami
import org.kde.ksvg 1.0 as KSvg
import org.kde.coreaddons 1.0 as KCoreAddons
import Qt5Compat.GraphicalEffects
import "parts" as Parts

PlasmoidItem {
    id: kicker

    signal reset

    property Item dragSource: null

    clip: false

    function action_menuedit() {
        processRunner.runMenuEditor();
    }

    property QtObject globalFavorites: rootModel ? rootModel.favoritesModel : null
    property QtObject systemFavorites: rootModel ? rootModel.systemFavoritesModel : null

    KCoreAddons.KUser {
        id: kuser
    }

    Plasmoid.icon: Plasmoid.configuration.useCustomButtonImage ? Plasmoid.configuration.customButtonImage : Plasmoid.configuration.icon

    onSystemFavoritesChanged: {
        if (systemFavorites) {
            systemFavorites.favorites = Plasmoid.configuration.favoriteSystemActions;
        }
    }

    compactRepresentation: Item {
        Kirigami.Icon {
            id: buttonIcon
            anchors.fill: parent
            source: Plasmoid.configuration.useCustomButtonImage ?
                   Plasmoid.configuration.customButtonImage :
                   Plasmoid.configuration.icon
            active: mouseArea.containsMouse
            smooth: true
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
                kicker.expanded = !kicker.expanded;
            }
        }
    }

    fullRepresentation: Item {
        id: root

        Layout.minimumWidth: Kirigami.Units.gridUnit * 28
        Layout.minimumHeight: Kirigami.Units.gridUnit * 36
        Layout.preferredWidth: Kirigami.Units.gridUnit * 36
        Layout.preferredHeight: Kirigami.Units.gridUnit * 34

        property int showApps: 0
        property bool searching: searchBar.text !== ""
        property bool systemActionInProgress: false
        property string currentAction: ""

        function toggle() {
            kicker.expanded = false;
        }

        function executeSystemAction(command, actionType) {
            if (systemActionInProgress) {
                return;
            }

            systemActionInProgress = true;
            currentAction = actionType;

            var executable = kicker.executable;
            if (executable) {
                executable.exited.connect(onSystemActionCompleted);
                executable.exec(command);
            } else {
                systemActionInProgress = false;
                currentAction = "";
            }

            root.toggle();
        }

        function onSystemActionCompleted(cmd, exitCode, exitStatus, stdout, stderr) {
            var executable = kicker.executable;
            if (executable) {
                executable.exited.disconnect(onSystemActionCompleted);
            }

            if (exitCode !== 0) {
                // Fallbacks para ações que podem falhar
                if (currentAction === "logout" && exitCode !== 0) {
                    if (executable) {
                        executable.exec("qdbus org.kde.ksmserver /KSMServer logout 1 0 0");
                    }
                } else if (currentAction === "suspend" && exitCode !== 0) {
                    if (executable) {
                        executable.exec("dbus-send --system --print-reply --dest=org.freedesktop.UPower /org/freedesktop/UPower org.freedesktop.UPower.Suspend");
                    }
                } else if (currentAction === "lock" && exitCode !== 0) {
                    if (executable) {
                        executable.exec("qdbus org.kde.screensaver /ScreenSaver Lock");
                    }
                }
            }

            systemActionInProgress = false;
            currentAction = "";
        }

        onSearchingChanged: {
            if (typeof menuContent !== "undefined" && menuContent) {
                menuContent.searching = searching;
            }
        }

        clip: false

        Parts.Avatar {
            id: floatingAvatar

            userFaceIconUrl: kuser.faceIconUrl
            isExpanded: kicker.expanded
            executable: kicker.executable

            onClicked: {
                root.toggle();
            }
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Item {
                id: topSpacer
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * 1.5
                Layout.minimumHeight: Kirigami.Units.gridUnit * 1.5
                Layout.maximumHeight: Kirigami.Units.gridUnit * 1.5
            }

            Item {
                id: contentArea
                Layout.fillWidth: true
                Layout.fillHeight: true

                MenuContent {
                    id: menuContent
                    anchors.fill: parent
                    showApps: root.showApps
                    searching: root.searching
                    cellHeight: 48
                    iconSize: 32
                    executable: kicker.executable

                    function onSearchTextChanged(text) {
                        root.searching = (text !== "");

                        if (typeof runnerModel !== "undefined") {
                            runnerModel.query = text;
                        }
                    }

                    Component.onCompleted: {
                        if (typeof menuContent !== "undefined" && menuContent && menuContent.searchField) {
                            menuContent.searchField.visible = false;
                        }

                        if (typeof menuContent !== "undefined" && menuContent && menuContent.favoritesComponent && kicker.globalFavorites) {
                            menuContent.favoritesComponent.model = kicker.globalFavorites;
                        }
                        if (typeof menuContent !== "undefined" && menuContent && menuContent.allAppsGrid && rootModel) {
                            menuContent.allAppsGrid.model = rootModel.modelForRow(0);
                        }
                        if (typeof menuContent !== "undefined" && menuContent && menuContent.runnerGrid && runnerModel) {
                            menuContent.runnerGrid.model = runnerModel;
                        }

                        if (typeof menuContent !== "undefined" && menuContent && menuContent.searchTextChanged) {
                            menuContent.searchTextChanged.connect(menuContent.onSearchTextChanged);
                        }
                    }
                }
            }

            Parts.Search {
                id: searchBar

                menuContentRef: menuContent
                runnerModelRef: runnerModel
                currentShowApps: root.showApps

                onSearchTextChanged: (text) => {
                    root.searching = (text !== "");
                }

                onEscapePressed: {
                    root.toggle();
                }

                onNavigateToResults: {
                    if (root.searching && typeof menuContent !== "undefined" && menuContent && menuContent.runnerGrid) {
                        if (menuContent.runnerGrid.tryActivate) {
                            menuContent.runnerGrid.tryActivate(0, 0);
                        }
                    } else if (root.showApps === 0 && typeof menuContent !== "undefined" && menuContent && menuContent.favoritesComponent) {
                        if (menuContent.favoritesComponent.tryActivate) {
                            menuContent.favoritesComponent.tryActivate(0, 0);
                        }
                    } else if (typeof menuContent !== "undefined" && menuContent && menuContent.allAppsGrid) {
                        if (menuContent.allAppsGrid.tryActivate) {
                            menuContent.allAppsGrid.tryActivate(0, 0);
                        }
                    }
                }
            }

            Rectangle {
                id: bottomBar
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * 2
                Layout.minimumHeight: Kirigami.Units.gridUnit * 2
                Layout.maximumHeight: Kirigami.Units.gridUnit * 2
                color: "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.smallSpacing

                    PlasmaComponents3.Button {
                        Layout.preferredWidth: parent.width * 0.6
                        Layout.fillHeight: true
                        text: root.showApps === 0 ? i18n("All Applications") : i18n("Favorites")
                        icon.name: root.showApps === 0 ? "applications-all" : "bookmarks"

                        onClicked: {
                            var newValue = root.showApps === 0 ? 1 : 0;

                            root.showApps = newValue;
                            if (menuContent) {
                                menuContent.showApps = newValue;
                            }

                            if (newValue === 1) {
                                if (menuContent.allAppsGrid && rootModel) {
                                    var appModel = rootModel.modelForRow(0);
                                    if (appModel) {
                                        menuContent.allAppsGrid.model = appModel;
                                    }
                                }
                            } else {
                                if (menuContent.favoritesComponent && kicker.globalFavorites) {
                                    menuContent.favoritesComponent.model = kicker.globalFavorites;
                                }
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Parts.Power {
                        id: powerButtons

                        actionInProgress: root.systemActionInProgress

                        onExecuteAction: (command, actionType) => {
                            root.executeSystemAction(command, actionType);
                        }
                    }
                }
            }
        }

        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape) {
                event.accepted = true;
                if (root.searching) {
                    searchBar.clear();
                } else {
                    kicker.expanded = false;
                }
                return;
            }

            if (event.key === Qt.Key_Backspace) {
                event.accepted = true;
                searchBar.backspace();
            } else if (event.text !== "" && event.text.trim() !== "") {
                event.accepted = true;
                searchBar.focusSearchField();
                searchBar.appendText(event.text);
            }
        }

        focus: true
    }

    Kicker.RootModel {
        id: rootModel
        autoPopulate: true
        appNameFormat: 0
        flat: true
        sorted: true
        showSeparators: true
        appletInterface: kicker
        showAllApps: true
        showRecentApps: false
        showRecentDocs: false
        showPowerSession: false

        onShowRecentAppsChanged: {
            Plasmoid.configuration.showRecentApps = showRecentApps;
        }

        onShowRecentDocsChanged: {
            Plasmoid.configuration.showRecentDocs = showRecentDocs;
        }

        onRecentOrderingChanged: {
            Plasmoid.configuration.recentOrdering = recentOrdering;
        }

        Component.onCompleted: {
            favoritesModel.initForClient("org.kde.plasma.kicker.favorites.instance-" + Plasmoid.id)

            if (!Plasmoid.configuration.favoritesPortedToKAstats) {
                if (favoritesModel.count < 1) {
                    favoritesModel.portOldFavorites(Plasmoid.configuration.favoriteApps);
                }
                Plasmoid.configuration.favoritesPortedToKAstats = true;
            }

            refreshed.connect(function() {
                if (typeof menuContent !== "undefined" && menuContent && menuContent.favoritesComponent) {
                    menuContent.favoritesComponent.model = kicker.globalFavorites;
                }
                if (typeof menuContent !== "undefined" && menuContent && menuContent.allAppsGrid) {
                    menuContent.allAppsGrid.model = rootModel.modelForRow(0);
                }
                if (typeof menuContent !== "undefined" && menuContent && menuContent.runnerGrid) {
                    menuContent.runnerGrid.model = runnerModel;
                }
            });

            refresh();
        }
    }

    Connections {
        target: globalFavorites
        function onFavoritesChanged() {
            if (target) {
                Plasmoid.configuration.favoriteApps = target.favorites;
            }
        }
    }

    Connections {
        target: systemFavorites
        function onFavoritesChanged() {
            if (target) {
                Plasmoid.configuration.favoriteSystemActions = target.favorites;
            }
        }
    }

    Connections {
        target: Plasmoid.configuration
        function onFavoriteAppsChanged() {
            if (globalFavorites) {
                globalFavorites.favorites = Plasmoid.configuration.favoriteApps;
            }
        }

        function onFavoriteSystemActionsChanged() {
            if (systemFavorites) {
                systemFavorites.favorites = Plasmoid.configuration.favoriteSystemActions;
            }
        }

        function onHiddenApplicationsChanged() {
            if (rootModel) {
                rootModel.refresh();
            }
        }
    }

    Kicker.RunnerModel {
        id: runnerModel
        appletInterface: kicker
        favoritesModel: globalFavorites
        runners: {
            const results = ["krunner_services",
                           "krunner_systemsettings",
                           "krunner_sessions",
                           "krunner_powerdevil",
                           "calculator",
                           "unitconverter"];

            if (Plasmoid.configuration.useExtraRunners) {
                results.push(...Plasmoid.configuration.extraRunners);
            }
            return results;
        }
    }

    property P5Support.DataSource executable: P5Support.DataSource {
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            var exitCode = data["exit code"]
            var exitStatus = data["exit status"]
            var stdout = data["stdout"]
            var stderr = data["stderr"]
            exited(sourceName, exitCode, exitStatus, stdout, stderr)
            disconnectSource(sourceName)
        }
        function exec(cmd) {
            if (cmd) {
                connectSource(cmd)
            }
        }
        signal exited(string cmd, int exitCode, int exitStatus, string stdout, string stderr)
    }

    Kicker.DragHelper {
        id: dragHelper
    }

    Kicker.ProcessRunner {
        id: processRunner
    }

    Kicker.WindowSystem {
        id: windowSystem
    }

    KSvg.FrameSvgItem {
        id: highlightItemSvg
        visible: false
        imagePath: "widgets/viewitem"
        prefix: "hover"
    }

    KSvg.FrameSvgItem {
        id: panelSvg
        visible: false
        imagePath: "widgets/panel-background"
    }

    KSvg.FrameSvgItem {
        id: scrollbarSvg
        visible: false
        imagePath: "widgets/scrollbar"
    }

    KSvg.FrameSvgItem {
        id: backgroundSvg
        visible: false
        imagePath: "dialogs/background"
    }

    PlasmaComponents3.Label {
        id: toolTipDelegate
        width: contentWidth
        height: undefined
        property Item toolTip
        text: toolTip ? toolTip.text : ""
        textFormat: Text.PlainText
    }

    function resetDragSource() {
        dragSource = null;
    }

    function enableHideOnWindowDeactivate() {
        kicker.hideOnWindowDeactivate = true;
    }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18n("Edit Applications…")
            icon.name: "kmenuedit"
            visible: Plasmoid.immutability !== PlasmaCore.Types.SystemImmutable
            onTriggered: processRunner.runMenuEditor()
        }
    ]

    Component.onCompleted: {
        if (Plasmoid.hasOwnProperty("activationTogglesExpanded")) {
            Plasmoid.activationTogglesExpanded = !kicker.isDash
        }

        windowSystem.focusIn.connect(enableHideOnWindowDeactivate);
        dragHelper.dropped.connect(resetDragSource);
    }

    Connections {
        target: kicker
        function onExpandedChanged() {
            if (kicker.expanded && fullRepresentation) {
                // Focus será gerenciado automaticamente
            }
        }
    }
}