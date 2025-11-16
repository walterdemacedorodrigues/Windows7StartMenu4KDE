/*
 *  SPDX-FileCopyrightText: 2025 Walter Rodrigues <wmr2@cin.ufpe.br>
 *  SPDX-FileCopyrightText: zayronxio
 *  SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick 2.4
import QtQuick.Layouts 1.1
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 3.0 as PC3
import org.kde.plasma.extras 2.0 as PlasmaExtras
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.kicker 0.1 as Kicker
import org.kde.taskmanager 0.1 as TaskManager
import org.kde.plasma.private.taskmanager as TaskManagerApplet
import "parts" as Parts

Item {
    id: contentRoot

    // Properties passed from parent
    property int showApps: 0
    property bool searching: false
    property int cellHeight: 48
    property int iconSize: 32
    property alias searchField: searchField
    property alias favoritesComponent: favoritesContainer
    property alias allAppsGrid: allAppsGrid
    property alias runnerGrid: runnerGrid
    property alias mainColumn: mainColumn
    property var executable

    // Signal sent when search text changes
    signal searchTextChanged(string text)

    // MODELOS DE DADOS REAIS
    // Modelo de arquivos recentes
    Kicker.RecentUsageModel {
        id: recentFilesModel
        ordering: 0 // Recent
    }

    // Modelo de aplicativos mais usados
    Kicker.RecentUsageModel {
        id: frequentAppsModel
        ordering: 1 // Popular / Frequently Used
    }

    // Backend do Task Manager para acessar arquivos recentes
    TaskManagerApplet.Backend {
        id: taskManagerBackend
    }

    // MODELO PARA ARQUIVOS RECENTES (usando dados reais)
    ListModel {
        id: recentFilesProcessed
    }

    // MODELO PARA LOCAIS RECENTES (usando dados reais)
    ListModel {
        id: recentPlacesProcessed
    }

    // Extrai automaticamente URL do launcher de um item do modelo
    function extractLauncherUrl(modelItem, originalIndex, sourceModel) {
        if (!modelItem) return "";

        try {
            var modelIndex = sourceModel.index(originalIndex, 0);
            var desktopFile = sourceModel.data(modelIndex, Qt.UserRole + 3);

            if (desktopFile && desktopFile.indexOf(".desktop") !== -1) {
                return "applications:" + desktopFile;
            }
        } catch (e) {
            // Continue with fallbacks
        }

        var url = modelItem.url || "";
        var favoriteId = modelItem.favoriteId || "";

        if (url && url.indexOf(".desktop") !== -1) {
            return url;
        }

        if (favoriteId && favoriteId.indexOf(".desktop") !== -1) {
            return "applications:" + favoriteId;
        }

        return "";
    }

    // Verifica se um item é um aplicativo válido
    function isValidApplication(modelItem) {
        if (!modelItem) return false;

        var display = modelItem.display || "";
        var url = modelItem.url || "";
        var favoriteId = modelItem.favoriteId || "";

        if (!display || display.trim() === "") return false;

        // Rejeitar categorias que não são aplicativos
        if (favoriteId === "Pastas" || favoriteId === "Folders" || favoriteId === "Arquivos") return false;

        // Aceitar automaticamente categoria "Aplicativos"
        if (favoriteId === "Aplicativos") return true;

        // URLs com .desktop são aplicativos
        if (url && url.toLowerCase().indexOf(".desktop") !== -1) return true;

        // Validações básicas
        if (display.length < 2) return false;
        if (/^[0-9\W]+$/.test(display)) return false;

        return true;
    }

    // Processa arquivos recentes usando o taskManagerBackend (método correto)
    function processRecentFiles() {
        recentFilesProcessed.clear();

        // Usar o mesmo método do RecentnFavorites: obter arquivos via taskManagerBackend
        for (var i = 0; i < Math.min(frequentAppsModel.count, 15); i++) {
            try {
                var modelIndex = frequentAppsModel.index(i, 0);
                var item = {
                    display: frequentAppsModel.data(modelIndex, Qt.DisplayRole) || "",
                    url: frequentAppsModel.data(modelIndex, Qt.UserRole + 1) || "",
                    favoriteId: frequentAppsModel.data(modelIndex, Qt.UserRole + 2) || "",
                    originalIndex: i
                };

                if (!isValidApplication(item)) continue;

                var launcherUrl = extractLauncherUrl(item, i, frequentAppsModel);
                if (!launcherUrl) continue;

                // Usar taskManagerBackend para obter arquivos recentes
                try {
                    var recentActions = taskManagerBackend.recentDocumentActions(launcherUrl, contentRoot);

                    if (recentActions && recentActions.length > 0) {
                        // Adicionar arquivos deste app
                        for (var k = 0; k < Math.min(recentActions.length, 3); k++) {
                            var action = recentActions[k];
                            if (action && action.text) {
                                var actionData = action.data || "";
                                var fileName = action.text || "";

                                // FILTRAR: Remover URLs da web (http/https)
                                if (actionData.startsWith("http://") || actionData.startsWith("https://")) {
                                    continue;
                                }

                                // FILTRAR: Remover pastas (URLs que terminam com / ou são diretórios)
                                if (actionData.endsWith("/") || actionData.indexOf("file://") !== -1 && fileName.indexOf(".") === -1) {
                                    continue;
                                }

                                // FILTRAR: Verificar se tem extensão de arquivo (apenas arquivos reais)
                                if (fileName.indexOf(".") === -1) {
                                    continue;
                                }

                                // Determinar ícone baseado na extensão ou usar o da action
                                var extension = fileName.toLowerCase().split('.').pop();
                                var icon = action.icon || "text-x-generic";

                                if (!action.icon) {
                                    if (extension === "pdf") icon = "application-pdf";
                                    else if (extension === "doc" || extension === "docx") icon = "application-msword";
                                    else if (extension === "xls" || extension === "xlsx") icon = "application-vnd.ms-excel";
                                    else if (["jpg", "jpeg", "png", "gif", "bmp", "svg"].indexOf(extension) !== -1) icon = "image-x-generic";
                                    else if (["mp3", "wav", "ogg", "flac", "m4a"].indexOf(extension) !== -1) icon = "audio-x-generic";
                                    else if (["mp4", "avi", "mkv", "mov", "webm"].indexOf(extension) !== -1) icon = "video-x-generic";
                                }

                                var fileItem = {
                                    "text": action.text,
                                    "icon": icon,
                                    "url": actionData,
                                    "action": action,
                                    "command": "# File action"
                                };

                                recentFilesProcessed.append(fileItem);
                            }
                        }
                    }
                } catch (e) {
                    // Continuar silenciosamente
                }

                if (recentFilesProcessed.count >= 10) break;

            } catch (e) {
                continue;
            }
        }

        // Fallback: Se não encontrou arquivos, tentar usar recentFilesModel com filtros
        if (recentFilesProcessed.count === 0) {
            for (var j = 0; j < Math.min(recentFilesModel.count, 10); j++) {
                try {
                    var modelIndex = recentFilesModel.index(j, 0);
                    var item = {
                        display: recentFilesModel.data(modelIndex, Qt.DisplayRole) || "",
                        url: recentFilesModel.data(modelIndex, Qt.UserRole + 1) || "",
                        decoration: recentFilesModel.data(modelIndex, Qt.DecorationRole)
                    };

                    if (!item.display) continue;

                    // FILTRAR: Remover URLs da web
                    if (item.url.startsWith("http://") || item.url.startsWith("https://")) {
                        continue;
                    }

                    // FILTRAR: Remover aplicativos (.desktop)
                    if (item.url.indexOf(".desktop") !== -1 || item.url.indexOf("applications:") !== -1) {
                        continue;
                    }

                    // FILTRAR: Verificar se tem extensão de arquivo
                    if (item.display.indexOf(".") === -1) {
                        continue;
                    }

                    // FILTRAR: Aceitar apenas arquivos locais
                    if (!item.url.startsWith("file://") && !item.url.startsWith("/")) {
                        continue;
                    }

                    var icon = "text-x-generic";
                    if (typeof item.decoration === "string" && item.decoration !== "") {
                        icon = item.decoration;
                    }

                    var fileItem = {
                        "text": item.display,
                        "icon": icon,
                        "url": item.url || "",
                        "command": item.url ? "xdg-open '" + item.url + "'" : "echo 'No URL'"
                    };

                    recentFilesProcessed.append(fileItem);

                } catch (e) {
                    continue;
                }
            }
        }
    }

    // Processa locais recentes usando dados reais + fallback para locais padrão
    function processRecentPlaces() {
        recentPlacesProcessed.clear();
        var placesFound = 0;

        // Tentar obter locais de aplicativos como Dolphin usando dados reais
        for (var j = 0; j < Math.min(frequentAppsModel.count, 10); j++) {
            try {
                var modelIndex = frequentAppsModel.index(j, 0);
                var item = {
                    display: frequentAppsModel.data(modelIndex, Qt.DisplayRole) || "",
                    url: frequentAppsModel.data(modelIndex, Qt.UserRole + 1) || "",
                    favoriteId: frequentAppsModel.data(modelIndex, Qt.UserRole + 2) || "",
                    originalIndex: j
                };

                if (!isValidApplication(item)) continue;

                var launcherUrl = extractLauncherUrl(item, j, frequentAppsModel);
                if (!launcherUrl) continue;

                // Verificar se tem locais recentes (para apps como Dolphin)
                try {
                    var placesActions = taskManagerBackend.placesActions(launcherUrl, false, contentRoot);

                    if (placesActions && placesActions.length > 0) {
                        // Adicionar alguns locais deste app
                        for (var k = 0; k < Math.min(placesActions.length, 3); k++) {
                            var action = placesActions[k];
                            if (action && action.text) {
                                var placeItem = {
                                    "text": action.text,
                                    "icon": action.icon || "folder",
                                    "command": "# Place action",
                                    "action": action
                                };

                                recentPlacesProcessed.append(placeItem);
                                placesFound++;
                            }
                        }
                    }
                } catch (e) {
                    // Continuar silenciosamente
                }

                if (placesFound >= 5) break;

            } catch (e) {
                continue;
            }
        }

        // Fallback: Se não encontrou places suficientes, adicionar locais padrão
        if (recentPlacesProcessed.count < 3) {
            var defaultPlaces = [
                { text: "Desktop", icon: "user-desktop", command: "xdg-open $(xdg-user-dir DESKTOP)" },
                { text: "Downloads", icon: "folder-downloads", command: "xdg-open $(xdg-user-dir DOWNLOAD)" },
                { text: "Documents", icon: "folder-documents", command: "xdg-open $(xdg-user-dir DOCUMENTS)" },
                { text: "Images", icon: "folder-pictures", command: "xdg-open $(xdg-user-dir PICTURES)" },
                { text: "Music", icon: "folder-music", command: "xdg-open $(xdg-user-dir MUSIC)" }
            ];

            for (var i = 0; i < defaultPlaces.length && recentPlacesProcessed.count < 8; i++) {
                recentPlacesProcessed.append(defaultPlaces[i]);
            }
        }
    }

    // Search field (pode ser ocultado pelo main.qml)
    PC3.TextField {
        id: searchField
        width: parent.width * 0.4
        height: Kirigami.Units.gridUnit * 2
        anchors {
            top: parent.top
            topMargin: Kirigami.Units.gridUnit
            horizontalCenter: parent.horizontalCenter
        }
        placeholderText: i18n("Type here to search ...")
        font.pointSize: Kirigami.Theme.defaultFont.pointSize
        visible: false // Por padrão oculto, main.qml controla

        onTextChanged: {
            contentRoot.searchTextChanged(text);
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

        Kirigami.Icon {
            source: 'search'
            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
                leftMargin: Kirigami.Units.smallSpacing * 2
            }
            height: Kirigami.Units.iconSizes.small
            width: height
        }
    }

    // Main Content Area
    Item {
        id: mainArea
        anchors {
            top: searchField.visible ? searchField.bottom : parent.top
            topMargin: searchField.visible ? Kirigami.Units.gridUnit : 0
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }

        // Favorites + Recents Container
        Item {
            id: favoritesContainer
            visible: showApps === 0 && !searching
            anchors {
                top: parent.top
                left: parent.left
            }
            width: parent.width * 0.6
            height: parent.height

            property alias model: favoritesGrid.model
            function tryActivate(row, col) {
                var favoritesRows = Math.ceil(favoritesGrid.count / Math.floor(width / favoritesGrid.cellWidth));
                if (row < favoritesRows) {
                    favoritesGrid.tryActivate(row, col);
                } else {
                    var adjustedRow = row - favoritesRows;
                    recentsGrid.tryActivate(adjustedRow, col);
                }
            }

            Column {
                anchors.fill: parent
                spacing: 0

                // Favorites Grid
                Parts.Favorites {
                    id: favoritesGrid
                    width: parent.width
                    height: calculateFavoritesHeight()
                    dragEnabled: true
                    dropEnabled: true
                    cellWidth: parent.width
                    cellHeight: contentRoot.cellHeight
                    iconSize: contentRoot.iconSize

                    function calculateFavoritesHeight() {
                        var favoritesRows = Math.ceil(count / Math.floor(width / cellWidth));
                        var recentsRows = Math.ceil(recentsGrid.count / Math.floor(width / cellWidth));
                        var minRecentsHeight = cellHeight * 2;
                        var availableHeight = parent.height - 2; // 2px separator
                        var favHeight = Math.min((favoritesRows * cellHeight), availableHeight - minRecentsHeight);
                        return favHeight > 0 ? favHeight : 0;
                    }

                    onCountChanged: Qt.callLater(function() { height = calculateFavoritesHeight(); })

                    onKeyNavDown: {
                        recentsGrid.forceActiveFocus();
                        recentsGrid.currentIndex = 0;
                    }

                    onMenuClosed: {
                        if (typeof root !== "undefined" && root.toggle) {
                            root.toggle();
                        } else if (typeof kicker !== "undefined") {
                            kicker.expanded = false;
                        }
                    }
                }

                // Separator
                Rectangle {
                    width: parent.width * 0.9
                    height: 2
                    color: Kirigami.Theme.textColor || "#eff0f1"
                    opacity: 0.3
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: favoritesGrid.count > 0
                }

                // Recents Grid
                Parts.Recents {
                    id: recentsGrid
                    width: parent.width
                    height: parent.height - favoritesGrid.height - 2
                    cellWidth: parent.width
                    cellHeight: contentRoot.cellHeight
                    iconSize: contentRoot.iconSize
                    favoritesModel: favoritesGrid.model

                    onCountChanged: Qt.callLater(function() { favoritesGrid.height = favoritesGrid.calculateFavoritesHeight(); })

                    onKeyNavUp: {
                        favoritesGrid.forceActiveFocus();
                        favoritesGrid.currentIndex = favoritesGrid.count - 1;
                    }

                    onMenuClosed: {
                        if (typeof root !== "undefined" && root.toggle) {
                            root.toggle();
                        } else if (typeof kicker !== "undefined") {
                            kicker.expanded = false;
                        }
                    }
                }
            }
        }

        // Apps Grid Container
        Item {
            id: mainGrids
            visible: showApps === 1 && !searching
            anchors {
                top: parent.top
                left: parent.left
            }
            width: parent.width * 0.6
            height: parent.height

            Item {
                id: mainColumn
                anchors.fill: parent
                property Item visibleGrid: allAppsGrid

                // Regular apps grid
                ItemGridView {
                    id: allAppsGrid
                    anchors.fill: parent
                    cellWidth: parent.width
                    cellHeight: contentRoot.cellHeight
                    iconSize: contentRoot.iconSize
                    enabled: parent.visible
                    z: enabled ? 5 : -1
                }
            }
        }

        // Search Results Container
        Item {
            id: searchContainer
            visible: searching
            anchors {
                top: parent.top
                left: parent.left
            }
            width: parent.width * 0.6
            height: parent.height

            // Search results grid
            ItemMultiGridView {
                id: runnerGrid
                anchors.fill: parent
                cellWidth: parent.width
                cellHeight: contentRoot.cellHeight
                enabled: parent.visible
                z: enabled ? 5 : -1
                grabFocus: true
            }
        }

        // Sidebar com navegação - USANDO DADOS REAIS
        Rectangle {
            id: sidebar
            width: parent.width * 0.35
            color: Kirigami.Theme.backgroundColor
            border.width: 0
            radius: 8

            anchors {
                top: parent.top
                topMargin: Kirigami.Units.gridUnit * 4
                right: parent.right
                rightMargin: Kirigami.Units.smallSpacing
                bottom: parent.bottom
            }

            // Dropdown menu properties
            property QtObject currentDropdown: null

            function showDropdown(menuType, visualParentItem) {
                // Fechar dropdown anterior se existir
                if (currentDropdown) {
                    currentDropdown.close();
                    currentDropdown.destroy();
                    currentDropdown = null;
                }

                try {
                    var component = null;
                    if (menuType === "recent") {
                        component = recentFilesDropdownComponent;
                    } else if (menuType === "places") {
                        component = recentPlacesDropdownComponent;
                    }

                    if (component && visualParentItem) {
                        currentDropdown = component.createObject(contentRoot);
                        if (currentDropdown) {
                            currentDropdown.visualParent = visualParentItem;
                            currentDropdown.placement = PlasmaExtras.Menu.RightPosedTopAlignedPopup;
                            currentDropdown.openRelative();
                        }
                    }
                } catch (e) {
                    // Handle errors silently
                }
            }

            PC3.ScrollView {
                id: sidebarScroll
                anchors.fill: parent
                anchors.margins: Kirigami.Units.smallSpacing
                anchors.leftMargin: Kirigami.Units.smallSpacing * 2

                PC3.ScrollBar.horizontal.policy: PC3.ScrollBar.AlwaysOff
                PC3.ScrollBar.vertical.policy: PC3.ScrollBar.AsNeeded

                Column {
                    id: sidebarColumn
                    width: sidebarScroll.width
                    spacing: 4

                    // SEÇÃO 1: Pastas do usuário
                    Repeater {
                        model: ListModel {
                            ListElement {
                                text: "Home"
                                icon: "user-home"
                                command: "xdg-open $HOME"
                                type: "folder"
                            }
                            ListElement {
                                text: "Documents"
                                icon: "folder-documents"
                                command: "xdg-open $(xdg-user-dir DOCUMENTS)"
                                type: "folder"
                            }
                            ListElement {
                                text: "Images"
                                icon: "folder-pictures"
                                command: "xdg-open $(xdg-user-dir PICTURES)"
                                type: "folder"
                            }
                            ListElement {
                                text: "Musics"
                                icon: "folder-music"
                                command: "xdg-open $(xdg-user-dir MUSIC)"
                                type: "folder"
                            }
                            ListElement {
                                text: "Videos"
                                icon: "folder-videos"
                                command: "xdg-open $(xdg-user-dir VIDEOS)"
                                type: "folder"
                            }
                            ListElement {
                                text: "Downloads"
                                icon: "folder-downloads"
                                command: "xdg-open $(xdg-user-dir DOWNLOAD)"
                                type: "folder"
                            }
                        }

                        delegate: SidebarItem {
                            text: model.text
                            icon: model.icon
                            onClicked: {
                                if (contentRoot.executable) {
                                    contentRoot.executable.exec(model.command);
                                }
                            }
                        }
                    }

                    // Separador 1
                    Rectangle {
                        width: parent.width * 0.8
                        height: 1
                        color: Kirigami.Theme.separatorColor || "#3c4043"
                        opacity: 0.5
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.margins: 8
                    }

                    // SEÇÃO 2: Menus com dropdown - DADOS REAIS
                    SidebarItem {
                        id: arquivosRecentesItem
                        text: "Recent Files (" + recentFilesProcessed.count + ")"
                        icon: "document-open-recent"
                        hasDropdown: true
                        onClicked: sidebar.showDropdown("recent", arquivosRecentesItem)
                    }

                    SidebarItem {
                        id: locaisRecentesItem
                        text: "Recent Places (" + recentPlacesProcessed.count + ")"
                        icon: "folder-recent"
                        hasDropdown: true
                        onClicked: sidebar.showDropdown("places", locaisRecentesItem)
                    }

                    SidebarItem {
                        text: "Network"
                        icon: "network-workgroup"
                        onClicked: {
                            if (contentRoot.executable) {
                                contentRoot.executable.exec("dolphin network:/");
                            }
                        }
                    }

                    // Separador 2
                    Rectangle {
                        width: parent.width * 0.8
                        height: 1
                        color: Kirigami.Theme.separatorColor || "#3c4043"
                        opacity: 0.5
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.margins: 8
                    }

                    // SEÇÃO 3: Ferramentas do sistema
                    SidebarItem {
                        text: "Settings"
                        icon: "preferences-system"
                        onClicked: {
                            if (contentRoot.executable) {
                                contentRoot.executable.exec("systemsettings");
                            }
                        }
                    }

                    SidebarItem {
                        text: "Run"
                        icon: "system-run"
                        onClicked: {
                            if (contentRoot.executable) {
                                contentRoot.executable.exec("krunner");
                            }
                        }
                    }
                }
            }
        }
    }

    // Componente para items da sidebar
    component SidebarItem: Rectangle {
        id: sidebarItem
        width: parent.width
        height: 36
        radius: 4
        color: mouseArea.containsMouse ? (Kirigami.Theme.hoverColor || "#93cee9") : "transparent"

        property string text: ""
        property string icon: ""
        property bool hasDropdown: false

        signal clicked()

        Row {
            anchors.fill: parent
            anchors.leftMargin: 0
            anchors.rightMargin: 8
            spacing: 12

            Kirigami.Icon {
                id: itemIcon
                width: 20
                height: 20
                anchors.verticalCenter: parent.verticalCenter
                source: sidebarItem.icon
                color: Kirigami.Theme.textColor || "#eff0f1"
            }

            PC3.Label {
                id: itemLabel
                anchors.verticalCenter: parent.verticalCenter
                text: sidebarItem.text
                color: Kirigami.Theme.textColor || "#eff0f1"
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.9
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            // Seta para dropdown
            Kirigami.Icon {
                width: 16
                height: 16
                anchors.verticalCenter: parent.verticalCenter
                source: "arrow-right"
                color: Kirigami.Theme.textColor || "#eff0f1"
                opacity: 0.7
                visible: sidebarItem.hasDropdown
            }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onClicked: sidebarItem.clicked()
        }

        Behavior on color {
            ColorAnimation { duration: 150 }
        }
    }

    // Componente para dropdown de arquivos recentes - DADOS REAIS
    Component {
        id: recentFilesDropdownComponent

        PlasmaExtras.Menu {
            id: recentMenu

            Component.onCompleted: {
                for (var i = 0; i < recentFilesProcessed.count; i++) {
                    var item = recentFilesProcessed.get(i);

                    var menuItem = Qt.createQmlObject(`
                        import org.kde.plasma.extras 2.0 as PlasmaExtras
                        PlasmaExtras.MenuItem {}
                    `, recentMenu);

                    menuItem.text = item.text;
                    menuItem.icon = item.icon;

                    // Criar closure para capturar os dados
                    (function(itemData) {
                        menuItem.clicked.connect(function() {
                            if (itemData.action && typeof itemData.action.trigger === "function") {
                                itemData.action.trigger();
                            } else if (contentRoot.executable && itemData.url) {
                                contentRoot.executable.exec(itemData.command);
                            }

                            if (typeof root !== "undefined" && root.toggle) {
                                root.toggle();
                            } else if (typeof kicker !== "undefined") {
                                kicker.expanded = false;
                            }
                        });
                    })(item);

                    recentMenu.addMenuItem(menuItem);
                }

                // Adicionar separador se há itens
                if (recentFilesProcessed.count > 0) {
                    var separatorItem = Qt.createQmlObject(`
                        import org.kde.plasma.extras 2.0 as PlasmaExtras
                        PlasmaExtras.MenuItem { separator: true }
                    `, recentMenu);
                    recentMenu.addMenuItem(separatorItem);
                }

                // Adicionar "Limpar Lista" no final
                var clearItem = Qt.createQmlObject(`
                    import org.kde.plasma.extras 2.0 as PlasmaExtras
                    PlasmaExtras.MenuItem {}
                `, recentMenu);
                clearItem.text = "Limpar Lista";
                clearItem.icon = "edit-clear-history";
                clearItem.clicked.connect(function() {
                    if (contentRoot.executable) {
                        contentRoot.executable.exec("rm -f ~/.local/share/recently-used.xbel");
                    }
                    processRecentFiles();
                });
                recentMenu.addMenuItem(clearItem);

                // Adicionar mensagem se não há arquivos
                if (recentFilesProcessed.count === 0) {
                    var noItemsItem = Qt.createQmlObject(`
                        import org.kde.plasma.extras 2.0 as PlasmaExtras
                        PlasmaExtras.MenuItem { enabled: false }
                    `, recentMenu);
                    noItemsItem.text = "Nenhum arquivo recente";
                    recentMenu.addMenuItem(noItemsItem);
                }
            }
        }
    }

    // Componente para dropdown de locais recentes - DADOS REAIS
    Component {
        id: recentPlacesDropdownComponent

        PlasmaExtras.Menu {
            id: placesMenu

            Component.onCompleted: {
                for (var i = 0; i < recentPlacesProcessed.count; i++) {
                    var item = recentPlacesProcessed.get(i);

                    var menuItem = Qt.createQmlObject(`
                        import org.kde.plasma.extras 2.0 as PlasmaExtras
                        PlasmaExtras.MenuItem {}
                    `, placesMenu);

                    menuItem.text = item.text;
                    menuItem.icon = item.icon;

                    // Criar closure para capturar os dados
                    (function(itemData) {
                        menuItem.clicked.connect(function() {
                            if (itemData.action && typeof itemData.action.trigger === "function") {
                                itemData.action.trigger();
                            } else if (contentRoot.executable) {
                                contentRoot.executable.exec(itemData.command);
                            }

                            if (typeof root !== "undefined" && root.toggle) {
                                root.toggle();
                            } else if (typeof kicker !== "undefined") {
                                kicker.expanded = false;
                            }
                        });
                    })(item);

                    placesMenu.addMenuItem(menuItem);
                }

                // Adicionar separador se há itens
                if (recentPlacesProcessed.count > 0) {
                    var separatorItem = Qt.createQmlObject(`
                        import org.kde.plasma.extras 2.0 as PlasmaExtras
                        PlasmaExtras.MenuItem { separator: true }
                    `, placesMenu);
                    placesMenu.addMenuItem(separatorItem);
                }

                // Adicionar "Limpar Lista" no final
                var clearItem = Qt.createQmlObject(`
                    import org.kde.plasma.extras 2.0 as PlasmaExtras
                    PlasmaExtras.MenuItem {}
                `, placesMenu);
                clearItem.text = "Limpar Lista";
                clearItem.icon = "edit-clear-history";
                clearItem.clicked.connect(function() {
                    processRecentPlaces();
                });
                placesMenu.addMenuItem(clearItem);

                // Adicionar mensagem se não há locais
                if (recentPlacesProcessed.count === 0) {
                    var noItemsItem = Qt.createQmlObject(`
                        import org.kde.plasma.extras 2.0 as PlasmaExtras
                        PlasmaExtras.MenuItem { enabled: false }
                    `, placesMenu);
                    noItemsItem.text = "Nenhum local recente";
                    placesMenu.addMenuItem(noItemsItem);
                }
            }
        }
    }

    // Conectar mudanças nos modelos para reprocessar dados
    Connections {
        target: recentFilesModel
        function onCountChanged() {
            Qt.callLater(processRecentFiles);
        }
        function onDataChanged() {
            Qt.callLater(processRecentFiles);
        }
    }

    Connections {
        target: frequentAppsModel
        function onCountChanged() {
            Qt.callLater(processRecentPlaces);
        }
        function onDataChanged() {
            Qt.callLater(processRecentPlaces);
        }
    }

    Component.onCompleted: {
        // Processar dados iniciais
        Qt.callLater(processRecentFiles);
        Qt.callLater(processRecentPlaces);
    }
}