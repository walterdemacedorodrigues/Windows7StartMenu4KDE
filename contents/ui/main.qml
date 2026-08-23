/*
 *  SPDX-FileCopyrightText: 2025 Walter Rodrigues <wmr2@cin.ufpe.br>
 *  SPDX-FileCopyrightText: 2023 WackyIdeas <wackyideas@disroot.org>
 *  SPDX-License-Identifier: AGPL-3.0-or-later
 */

import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.plasma.extras 2.0 as PlasmaExtras
import org.kde.plasma.private.kicker 0.1 as Kicker
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami
import org.kde.ksvg 1.0 as KSvg
import org.kde.coreaddons 1.0 as KCoreAddons
import org.kde.kitemmodels as KItemModels
import "parts" as Parts

PlasmoidItem {
    id: kicker

    signal reset
    signal modelsRefreshed()

    property Item dragSource: null

    clip: false

    property QtObject globalFavorites: rootModel ? rootModel.favoritesModel : null
    property QtObject systemFavorites: rootModel ? rootModel.systemFavoritesModel : null

    readonly property bool hierarchical: Plasmoid.configuration.hierarchicalAllPrograms

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
        Layout.minimumWidth: orb.implicitWidth
        Layout.minimumHeight: orb.implicitHeight

        OrbButton {
            id: orb
            anchors.centerIn: parent
            width: Math.min(parent.width, implicitWidth > 0 ? implicitWidth : parent.width)
            height: Math.min(parent.height, implicitHeight > 0 ? implicitHeight : parent.height)
            hovered: mouseArea.containsMouse
            pressed: kicker.expanded
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: kicker.expanded = !kicker.expanded
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

        // Tint over the theme background. Nothing is drawn while the opacity
        // sits at zero, so the stock look stays exactly as the theme paints it.
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            z: -2
            radius: Math.round(Kirigami.Units.gridUnit * 0.45)
            visible: Plasmoid.configuration.menuFrameOpacity > 0
            opacity: Plasmoid.configuration.menuFrameOpacity / 100
            color: Plasmoid.configuration.menuFrameUseThemeColor
                   ? Kirigami.Theme.backgroundColor
                   : Plasmoid.configuration.menuFrameColor
        }

        // Right clicking empty space inside the popup reached nothing, so the
        // applet options were only available from the panel button.
        MouseArea {
            anchors.fill: parent
            z: -1
            acceptedButtons: Qt.RightButton
            onClicked: mouse => appletContextMenu.popup(root, mouse.x, mouse.y)
        }

        PlasmaComponents3.Menu {
            id: appletContextMenu

            PlasmaComponents3.MenuItem {
                text: i18n("Edit Applications…")
                icon.name: "kmenuedit"
                enabled: Plasmoid.immutability !== PlasmaCore.Types.SystemImmutable
                onTriggered: processRunner.runMenuEditor()
            }

            PlasmaComponents3.MenuSeparator {}

            PlasmaComponents3.MenuItem {
                text: i18n("Configure Start Menu…")
                icon.name: "configure"
                enabled: Plasmoid.immutability === PlasmaCore.Types.Mutable
                onTriggered: {
                    const action = Plasmoid.internalAction("configure");
                    if (action) action.trigger();
                }
            }
        }

        function executeSystemAction(command, actionType) {
            if (systemActionInProgress) return;
            systemActionInProgress = true;
            currentAction = actionType;

            const executable = kicker.executable;
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
            const executable = kicker.executable;
            if (executable) executable.exited.disconnect(onSystemActionCompleted);
            systemActionInProgress = false;
            currentAction = "";
        }

        function toggle() {
            kicker.expanded = false;
        }

        function setShowApps(value) {
            showApps = value;
            menuContent.showApps = value;
            if (value === 1) {
                Qt.callLater(() => menuContent.appsView.focusFirst());
            } else if (menuContent.favoritesGrid.count > 0) {
                Qt.callLater(() => {
                    menuContent.favoritesGrid.currentIndex = 0;
                    menuContent.favoritesGrid.forceActiveFocus();
                });
            }
        }

        clip: false

        readonly property int avatarSize: Kirigami.Units.iconSizes.huge

        // Wayland forbids a client from placing its own window, so the avatar
        // cannot live in a separate window overhanging the popup the way the
        // original does. It hugs the inner top right corner instead.
        Item {
            id: profilePicWrapper
            width: root.avatarSize
            height: root.avatarSize
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: Kirigami.Units.smallSpacing
            anchors.topMargin: Kirigami.Units.smallSpacing
            z: 99999
            visible: kicker.expanded && !root.searching && Plasmoid.configuration.viewUser

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

                onClicked: root.toggle()
                onKeyNavDown: menuContent.sidebar.focusFirst()
                onKeyNavUp: powerButtons.forceActiveFocus()
                onKeyNavLeft: {
                    if (root.showApps === 1) {
                        menuContent.appsView.focusFirst();
                    } else if (menuContent.recentsGrid.visible && menuContent.recentsGrid.count > 0) {
                        menuContent.recentsGrid.forceActiveFocus();
                        menuContent.recentsGrid.currentIndex = 0;
                    }
                }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * 1.5
                Layout.minimumHeight: Kirigami.Units.gridUnit * 1.5
                Layout.maximumHeight: Kirigami.Units.gridUnit * 1.5
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                MenuContent {
                    id: menuContent
                    anchors.fill: parent
                    showApps: root.showApps
                    searching: root.searching
                    // 44 px matches the reference row, and it is what lets two pinned
                    // entries plus ten most used ones fit without clipping.
                    cellHeight: 44
                    iconSize: 32
                    executable: kicker.executable

                    onSearchTextChanged: text => {
                        root.searching = (text !== "");
                        runnerModel.query = text;
                    }
                    onCloseRequested: root.toggle()
                    onContextMenuRequested: (x, y) => {
                        const p = menuContent.mapToItem(root, x, y);
                        appletContextMenu.popup(root, p.x, p.y);
                    }
                    onKeyNavUpRequested: allAppsButton.forceActiveFocus()
                    onKeyNavDownRequested: searchBar.focusSearchField()
                    onShowAppsChangeRequested: value => root.setShowApps(value)
                }

                Connections {
                    target: kicker
                    function onSearchResultsReady() {
                        menuContent.runnerGrid.model = null;
                        menuContent.runnerGrid.model = runnerModel;
                    }
                }

                Connections {
                    target: menuContent.sidebar

                    function onKeyNavUp() { floatingAvatar.forceActiveFocus(); }
                    function onKeyNavDown() { powerButtons.forceActiveFocus(); }
                }
            }

            Parts.SearchBar {
                id: searchBar

                menuContentRef: menuContent
                runnerModelRef: runnerModel
                currentShowApps: root.showApps

                onSearchTextChanged: text => root.searching = (text !== "")
                onContextMenuRequested: (x, y) => {
                    const p = searchBar.mapToItem(root, x, y);
                    appletContextMenu.popup(root, p.x, p.y);
                }
                onEscapePressed: root.toggle()
                onKeyNavDown: allAppsButton.forceActiveFocus()
                onNavigateToResults: {
                    if (root.searching) {
                        if (menuContent.runnerGrid.tryActivate) menuContent.runnerGrid.tryActivate(0, 0);
                    } else if (root.showApps === 1) {
                        menuContent.appsView.focusFirst();
                    } else if (menuContent.favoritesComponent.tryActivate) {
                        menuContent.favoritesComponent.tryActivate(0, 0);
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * 2
                Layout.minimumHeight: Kirigami.Units.gridUnit * 2
                Layout.maximumHeight: Kirigami.Units.gridUnit * 2
                color: "transparent"

                MouseArea {
                    anchors.fill: parent
                    z: -1
                    acceptedButtons: Qt.RightButton
                    onClicked: mouse => {
                        const p = mapToItem(root, mouse.x, mouse.y);
                        appletContextMenu.popup(root, p.x, p.y);
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.smallSpacing

                    Item {
                        Layout.preferredWidth: parent.width * 0.6
                        Layout.fillHeight: true

                        PlasmaExtras.Highlight {
                            anchors.fill: parent
                            visible: allAppsButton.activeFocus
                            hovered: true
                            pressed: allAppsButton.pressed
                        }

                        // Glows while an application the user has not opened yet
                        // is sitting somewhere in the tree.
                        Rectangle {
                            anchors.fill: parent
                            radius: Kirigami.Units.smallSpacing
                            color: Kirigami.Theme.positiveTextColor
                            opacity: 0.18
                            visible: Plasmoid.configuration.highlightNewApps
                                     && newlyInstalledApps.count > 0
                                     && root.showApps === 0
                        }

                        PlasmaComponents3.Button {
                            id: allAppsButton
                            anchors.fill: parent
                            text: root.showApps === 0 ? i18n("All Applications") : i18n("Favorites")
                            icon.name: root.showApps === 0 ? "applications-all" : "bookmarks"
                            activeFocusOnTab: true
                            background: Item {}

                            Keys.onPressed: (event) => {
                                switch (event.key) {
                                case Qt.Key_Up:
                                    event.accepted = true;
                                    if (root.showApps === 0) {
                                        searchBar.focusSearchField();
                                    } else {
                                        menuContent.appsView.focusFirst();
                                    }
                                    break;
                                case Qt.Key_Down:
                                    // This is the bottom row, so down continues to
                                    // the power button instead of jumping back up.
                                    event.accepted = true;
                                    powerButtons.forceActiveFocus();
                                    break;
                                case Qt.Key_Right:
                                    event.accepted = true;
                                    powerButtons.forceActiveFocus();
                                    break;
                                case Qt.Key_Left:
                                    event.accepted = true;
                                    if (root.showApps === 1) root.setShowApps(0);
                                    break;
                                case Qt.Key_Return:
                                case Qt.Key_Enter:
                                case Qt.Key_Space:
                                    event.accepted = true;
                                    allAppsButton.clicked();
                                    break;
                                }
                            }

                            onClicked: root.setShowApps(root.showApps === 0 ? 1 : 0)
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Item {
                        Layout.preferredWidth: parent.width * 0.3
                        Layout.fillHeight: true

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
                            onExecuteAction: (command, actionType) => root.executeSystemAction(command, actionType)
                            onCloseRequested: root.toggle()
                            onKeyNavUp: searchBar.focusSearchField()
                            onKeyNavDown: menuContent.sidebar.focusFirst()
                            onKeyNavLeft: allAppsButton.forceActiveFocus()
                        }
                    }
                }
            }
        }

        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape) {
                event.accepted = true;
                if (root.searching) searchBar.clear(); else kicker.expanded = false;
                return;
            }
            if (event.key === Qt.Key_Up) {
                event.accepted = true;
                allAppsButton.forceActiveFocus();
                return;
            }
            if (event.key === Qt.Key_Down) {
                if (root.showApps === 1) {
                    event.accepted = true;
                    menuContent.appsView.focusFirst();
                } else if (menuContent.recentsGrid.visible && menuContent.recentsGrid.count > 0) {
                    event.accepted = true;
                    menuContent.recentsGrid.forceActiveFocus();
                    menuContent.recentsGrid.currentIndex = 0;
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

        Connections {
            target: kicker
            // Without an explicit entry point the popup opens with focus on a
            // container that handles no keys, so the arrows did nothing at all.
            function onExpandedChanged() {
                // The query outlives the popup otherwise, so reopening still
                // showed the previous search instead of the menu.
                searchBar.clear();
                root.setShowApps(0);
                if (kicker.expanded) Qt.callLater(() => searchBar.focusSearchField());
            }
            function onModelsRefreshed() {
                menuContent.favoritesComponent.model = kicker.globalFavorites;
                kicker.bindAppModels(menuContent);
            }
        }

        Component.onCompleted: {
            menuContent.favoritesComponent.model = kicker.globalFavorites;
            kicker.bindAppModels(menuContent);
            // The popup is built on the first expand, so the entry point has to
            // live here too or the very first keypress lands on nothing.
            Qt.callLater(() => searchBar.focusSearchField());
        }
    }

    // Keeps the All Programs views pointed at whichever shape the model has.
    function bindAppModels(menuContent) {
        if (!menuContent || !rootModel) return;
        if (kicker.hierarchical) {
            menuContent.appsView.treeModel = rootModel;
        } else {
            menuContent.appsView.flatModel = rootModel.modelForRow(0);
        }
        menuContent.runnerGrid.model = runnerModel;
    }

    // Drives the glow on the All Programs button while an application the user
    // has never launched is sitting somewhere in the tree.
    KItemModels.KSortFilterProxyModel {
        id: newlyInstalledApps
        sourceModel: rootModel
        filterRowCallback: function (sourceRow, sourceParent) {
            const role = sourceModel.KItemModels.KRoleNames.role("isNewlyInstalled");
            return sourceModel.data(sourceModel.index(sourceRow, 0, sourceParent), role) === true;
        }
    }

    Kicker.RootModel {
        id: rootModel
        autoPopulate: true
        appNameFormat: Plasmoid.configuration.appNameFormat
        flat: true
        appletInterface: kicker

        // Hierarchical mode keeps the category rows so they can be expanded in
        // place; flat mode collapses everything into one alphabetical list.
        sorted: !kicker.hierarchical
        showSeparators: !kicker.hierarchical
        showTopLevelItems: kicker.hierarchical
        showAllApps: !kicker.hierarchical
        showAllAppsCategorized: false

        showRecentApps: false
        showRecentDocs: false
        showPowerSession: false
        highlightNewlyInstalledApps: Plasmoid.configuration.highlightNewApps

        onRefreshed: Qt.callLater(() => kicker.modelsRefreshed())

        Component.onCompleted: {
            favoritesModel.initForClient("org.kde.plasma.kicker.favorites.instance-" + Plasmoid.id)

            // Seeds the ten defaults on a first run only; an existing list is never overwritten.
            if (!Plasmoid.configuration.favoritesPortedToKAstats) {
                if (favoritesModel.count < 1) {
                    favoritesModel.portOldFavorites(Plasmoid.configuration.favoriteApps);
                }
                Plasmoid.configuration.favoritesPortedToKAstats = true;
            }
            refresh();
        }
    }

    Connections {
        target: Plasmoid.configuration

        function onHierarchicalAllProgramsChanged() { rootModel.refresh(); }
        function onHiddenApplicationsChanged() { rootModel.refresh(); }
        function onFavoriteSystemActionsChanged() {
            if (systemFavorites) systemFavorites.favorites = Plasmoid.configuration.favoriteSystemActions;
        }
    }

    Connections {
        target: globalFavorites
        // One way only; pushing the config list back would re-add the defaults on every start.
        function onFavoritesChanged() {
            if (target) Plasmoid.configuration.favoriteApps = target.favorites;
        }
    }

    Connections {
        target: systemFavorites
        function onFavoritesChanged() {
            if (target) Plasmoid.configuration.favoriteSystemActions = target.favorites;
        }
    }

    Connections {
        target: runnerModel
        function onQueryFinished() {
            if (!kicker.fullRepresentationItem) return;
            kicker.searchResultsReady();
        }
    }

    signal searchResultsReady()

    Kicker.RunnerModel {
        id: runnerModel
        appletInterface: kicker
        favoritesModel: globalFavorites
        mergeResults: true
        runners: {
            const results = ["quicksearch",
                             "krunner_services",
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
        windowSystem.focusIn.connect(enableHideOnWindowDeactivate);
        dragHelper.dropped.connect(resetDragSource);
    }
}
