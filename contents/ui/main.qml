/*
 *  SPDX-FileCopyrightText: 2025 Walter Rodrigues <wmr2@cin.ufpe.br>
 *  SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras 2.0 as PlasmaExtras
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

        // Wrapper item for ProfilePic with highlight
        Item {
            id: profilePicWrapper
            width: Kirigami.Units.gridUnit * 3.5
            height: Kirigami.Units.gridUnit * 3.5
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Kirigami.Units.smallSpacing
            z: 99999
            visible: kicker.expanded

            // Highlight background - visible when ProfilePic has keyboard focus
            PlasmaExtras.Highlight {
                anchors.fill: parent
                visible: floatingAvatar.activeFocus
                hovered: true
                pressed: false
            }

            Parts.PersonalPortrait {
                id: floatingAvatar
                anchors.centerIn: parent

                userFaceIconUrl: kuser.faceIconUrl
                isExpanded: kicker.expanded
                executable: kicker.executable

                onClicked: {
                    root.toggle();
                }

                onKeyNavDown: {
                    if (menuContent && menuContent.sidebar) {
                        menuContent.sidebar.forceActiveFocus();
                    }
                }

                onKeyNavUp: {
                    if (powerButtons) {
                        powerButtons.forceActiveFocus();
                    }
                }

                onKeyNavLeft: {
                    if (menuContent) {
                        if (menuContent.favoritesComponent && menuContent.favoritesComponent.visible) {
                            var recentsGrid = menuContent.favoritesComponent.children[0].children[2];
                            if (recentsGrid && recentsGrid.visible) {
                                recentsGrid.forceActiveFocus();
                                recentsGrid.currentIndex = 0;
                            }
                        } else if (menuContent.allAppsGrid && menuContent.allAppsGrid.visible) {
                            menuContent.allAppsGrid.forceActiveFocus();
                            menuContent.allAppsGrid.currentIndex = 0;
                        }
                    }
                }
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

                // Sidebar navigation connections
                Connections {
                    target: menuContent.sidebar

                    function onKeyNavUp() {
                        console.log("[Main] Sidebar.onKeyNavUp - going to ProfilePic");
                        floatingAvatar.forceActiveFocus();
                    }

                    function onKeyNavDown() {
                        console.log("[Main] Sidebar.onKeyNavDown - going to PowerButtons");
                        powerButtons.forceActiveFocus();
                    }
                }
            }

            Parts.SearchBar {
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

                    // Wrapper item for button with highlight
                    Item {
                        Layout.preferredWidth: parent.width * 0.6
                        Layout.fillHeight: true

                        // Highlight background - visible when button has keyboard focus
                        PlasmaExtras.Highlight {
                            anchors.fill: parent
                            visible: allAppsButton.activeFocus
                            hovered: true
                            pressed: allAppsButton.pressed
                        }

                        PlasmaComponents3.Button {
                            id: allAppsButton
                            anchors.fill: parent
                            text: root.showApps === 0 ? i18n("All Applications") : i18n("Favorites")
                            icon.name: root.showApps === 0 ? "applications-all" : "bookmarks"

                            activeFocusOnTab: true

                            // Make background transparent so highlight shows through
                            background: Item {}

                            Keys.onPressed: (event) => {
                            console.log("[AllAppsButton] Key pressed:", event.key, "showApps:", root.showApps);

                            // UP: go to Search (when in Fav/Rec mode) or last AllApps item (when in AllApps mode)
                            if (event.key === Qt.Key_Up) {
                                event.accepted = true;
                                if (root.showApps === 0) {
                                    // Go to Search
                                    console.log("[AllAppsButton] UP - going to Search");
                                    searchBar.focusSearchField();
                                } else {
                                    // Go to last AllApps item
                                    console.log("[AllAppsButton] UP - going to last AllApps item");
                                    if (menuContent.allAppsGrid) {
                                        menuContent.allAppsGrid.currentIndex = menuContent.allAppsGrid.count - 1;
                                        menuContent.allAppsGrid.forceActiveFocus();
                                    }
                                }
                                return;
                            }

                            // DOWN: go to first Favorites item (when in Fav/Rec mode) or first AllApps item (when in AllApps mode)
                            if (event.key === Qt.Key_Down) {
                                event.accepted = true;
                                if (root.showApps === 0) {
                                    // Go to first Favorites item
                                    console.log("[AllAppsButton] DOWN - going to first Favorites item");
                                    if (menuContent.favoritesComponent) {
                                        var favGrid = menuContent.favoritesComponent.children[0].children[0]; // Column > Favorites
                                        if (favGrid) {
                                            favGrid.currentIndex = 0;
                                            favGrid.forceActiveFocus();
                                        }
                                    }
                                } else {
                                    // Go to first AllApps item
                                    console.log("[AllAppsButton] DOWN - going to first AllApps item");
                                    if (menuContent.allAppsGrid) {
                                        menuContent.allAppsGrid.currentIndex = 0;
                                        menuContent.allAppsGrid.forceActiveFocus();
                                    }
                                }
                                return;
                            }

                            // RIGHT: open AllApps when in Fav/Rec mode
                            if (event.key === Qt.Key_Right) {
                                event.accepted = true;
                                if (root.showApps === 0) {
                                    console.log("[AllAppsButton] RIGHT - opening AllApps");
                                    root.showApps = 1;
                                    if (menuContent) {
                                        menuContent.showApps = 1;
                                    }
                                    if (menuContent.allAppsGrid && rootModel) {
                                        var appModel = rootModel.modelForRow(0);
                                        if (appModel) {
                                            menuContent.allAppsGrid.model = appModel;
                                        }
                                    }
                                    Qt.callLater(function() {
                                        menuContent.allAppsGrid.currentIndex = 0;
                                        menuContent.allAppsGrid.forceActiveFocus();
                                    });
                                } else {
                                    console.log("[AllAppsButton] RIGHT - already in AllApps, ignored");
                                }
                                return;
                            }

                            // LEFT: close AllApps when in AllApps mode
                            if (event.key === Qt.Key_Left) {
                                event.accepted = true;
                                if (root.showApps === 1) {
                                    console.log("[AllAppsButton] LEFT - closing AllApps, going to Favorites");
                                    root.showApps = 0;
                                    if (menuContent) {
                                        menuContent.showApps = 0;
                                    }
                                    if (menuContent.favoritesComponent) {
                                        var favGrid = menuContent.favoritesComponent.children[0].children[0]; // Column > Favorites
                                        if (favGrid && favGrid.count > 0) {
                                            favGrid.currentIndex = 0;
                                            Qt.callLater(function() {
                                                favGrid.forceActiveFocus();
                                            });
                                        }
                                    }
                                } else {
                                    console.log("[AllAppsButton] LEFT - already in Fav/Rec, ignored");
                                }
                                return;
                            }

                            // Enter/Return/Space: toggle view
                            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                                event.accepted = true;
                                console.log("[AllAppsButton] Activating button");
                                allAppsButton.clicked();
                                return;
                            }
                        }

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
                    } // End of wrapper Item

                    Item {
                        Layout.fillWidth: true
                    }

                    // Wrapper item for PowerButtons with highlight
                    Item {
                        Layout.preferredWidth: parent.width * 0.3
                        Layout.fillHeight: true

                        // Highlight background - visible when PowerButtons has keyboard focus
                        PlasmaExtras.Highlight {
                            anchors.fill: parent
                            visible: powerButtons.activeFocus
                            hovered: true
                            pressed: false
                        }

                        Parts.PowerButtons {
                            id: powerButtons
                            anchors.fill: parent

                            actionInProgress: root.systemActionInProgress

                            onExecuteAction: (command, actionType) => {
                                root.executeSystemAction(command, actionType);
                            }

                            onKeyNavUp: {
                                console.log("[Main] PowerButtons.onKeyNavUp - going to Sidebar");
                                if (menuContent && menuContent.sidebar) {
                                    menuContent.sidebar.forceActiveFocus();
                                }
                            }

                            onKeyNavDown: {
                                console.log("[Main] PowerButtons.onKeyNavDown - going to ProfilePic");
                                floatingAvatar.forceActiveFocus();
                            }

                            onKeyNavLeft: {
                                console.log("[Main] PowerButtons.onKeyNavLeft - going to AllAppsButton");
                                allAppsButton.forceActiveFocus();
                            }
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

            // Navigate Up to All Applications button
            if (event.key === Qt.Key_Up) {
                console.log("[Main] Up key pressed - going to All Apps button");
                event.accepted = true;
                allAppsButton.forceActiveFocus();
                return;
            }

            // Navigate Down to Recents
            if (event.key === Qt.Key_Down) {
                if (menuContent && menuContent.favoritesComponent) {
                    var recentsGrid = menuContent.favoritesComponent.children[0].children[2]; // Column > Recents
                    if (recentsGrid && recentsGrid.visible) {
                        event.accepted = true;
                        recentsGrid.forceActiveFocus();
                        recentsGrid.currentIndex = 0;
                        return;
                    }
                }
            }

            // Navigate Left/Right between columns
            if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
                // This will be handled by individual grids via keyNavLeft/keyNavRight signals
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