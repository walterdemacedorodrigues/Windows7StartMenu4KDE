/*
 * SPDX-FileCopyrightText: 2025 waltermr <wmr2@cin.ufpe.br>
 * SPDX-FileCopyrightText: zayronxio
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick 2.4
import QtQuick.Layouts 1.1
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 3.0 as PC3
import org.kde.plasma.extras 2.0 as PlasmaExtras
import org.kde.kirigami as Kirigami
import org.kde.ksvg 1.0 as KSvg
import org.kde.plasma.private.kicker 0.1 as Kicker
import org.kde.plasma.private.taskmanager 0.1 as TaskManagerApplet
import ".." // Importa os componentes da pasta pai

Item {
    id: favoritesView

    property alias gridView: globalFavoritesGrid
    property bool dragEnabled: true
    property bool dropEnabled: true
    property int cellHeight: 48
    property int cellWidth: width
    property int iconSize: 32
    property alias model: globalFavoritesGrid.model
    property alias frequentModel: appsWithRecentFiles
    property alias taskManagerBackend: taskManagerBackend
    property int minFrequentAppsHeight: cellHeight * 2
    property int separatorHeight: 2

    signal keyNavUp()

    // MODELO 1: Aplicativos mais usados
    Kicker.RecentUsageModel {
        id: frequentAppsModel
        ordering: 1 // Popular / Frequently Used
    }

    // Menu de arquivos recentes para favoritos
    function showRecentFilesMenuForFavorite(item, visualParent) {
        if (!item || !item.launcherUrl) return;

        // Destruir menu anterior
        if (currentMenu) {
            currentMenu.destroy();
            currentMenu = null;
        }

        try {
            // Obter actions usando o backend (igual aos recents)
            var recentActions = taskManagerBackend.recentDocumentActions(item.launcherUrl, favoritesView);
            var placesActions = taskManagerBackend.placesActions(item.launcherUrl, false, favoritesView);

            var allActions = [];
            var menuTitle = "";

            // Determinar tipo de menu baseado nas actions
            if (placesActions && placesActions.length > 0) {
                allActions = placesActions;
                menuTitle = i18n("Locais recentes");
            } else if (recentActions && recentActions.length > 0) {
                allActions = recentActions;
                menuTitle = i18n("Arquivos recentes");
            }

            // Só criar menu se há itens
            if (allActions.length > 0) {
                currentMenu = createMenuFromActions(allActions, visualParent, menuTitle);
                if (currentMenu) {
                    currentMenu.visualParent = visualParent;
                    currentMenu.placement = PlasmaExtras.Menu.RightPosedTopAlignedPopup;
                    currentMenu.openRelative();
                }
            }

        } catch (e) {
            // Silently handle errors
        }
    }

    // Função para adicionar app aos favoritos
    function addToFavorites(index) {
        var item = appsWithRecentFiles.get(index);
        if (!item) return;

        try {
            // Buscar o modelo de favoritos globais
            var favoritesModel = null;

            // Tentar várias formas de acessar o modelo de favoritos
            if (globalFavoritesGrid && globalFavoritesGrid.model) {
                favoritesModel = globalFavoritesGrid.model;
            } else if (typeof kicker !== "undefined" && kicker.globalFavorites) {
                favoritesModel = kicker.globalFavorites;
            } else if (typeof parent !== "undefined" && parent.globalFavorites) {
                favoritesModel = parent.globalFavorites;
            }

            if (!favoritesModel) {
                return;
            }

            // URL para adicionar (priorizar launcherUrl)
            var urlToAdd = item.launcherUrl || item.url || "";
            if (!urlToAdd) {
                return;
            }

            // Tentar múltiplos métodos para adicionar aos favoritos
            var added = false;

            // Método 1: addFavorite
            if (typeof favoritesModel.addFavorite === "function") {
                favoritesModel.addFavorite(urlToAdd);
                added = true;
            }
            // Método 2: favorites array
            else if (typeof favoritesModel.favorites !== "undefined") {
                var currentFavorites = favoritesModel.favorites || [];
                if (currentFavorites.indexOf(urlToAdd) === -1) {
                    currentFavorites.push(urlToAdd);
                    favoritesModel.favorites = currentFavorites;
                    added = true;
                }
            }

            if (added) {
                // Forçar atualização do modelo de recents
                modelsProcessed = false;
                Qt.callLater(function() {
                    buildSegregatedModel();
                    calculateHeights();
                });

                // Fechar menu após adicionar
                if (typeof root !== "undefined" && root.toggle) {
                    root.toggle();
                } else if (typeof kicker !== "undefined") {
                    kicker.expanded = false;
                }
            }

        } catch (e) {
            // Handle errors silently
        }
    }

    // BACKEND: Acesso às mesmas funções que o Task Manager usa
    TaskManagerApplet.Backend {
        id: taskManagerBackend
    }

    // MODELO 3: Aplicativos com seus arquivos recentes (modelo final)
    ListModel {
        id: appsWithRecentFiles
    }

    // Cache para evitar reprocessamento
    property var desktopIdCache: ({})
    property bool modelsProcessed: false
    property var lastFavoritesSnapshot: []

    // Captura snapshot dos favoritos para detectar mudanças
    function getFavoritesSnapshot() {
        var snapshot = [];
        if (globalFavoritesGrid.model) {
            var favoritesModel = globalFavoritesGrid.model;
            for (var f = 0; f < favoritesModel.count; f++) {
                try {
                    var favIndex = favoritesModel.index(f, 0);
                    var favoriteUrl = favoritesModel.data(favIndex, Qt.UserRole + 1) || "";
                    if (favoriteUrl) {
                        snapshot.push(favoriteUrl);
                    }
                } catch (e) {
                    continue;
                }
            }
        }
        return snapshot;
    }

    // Verifica se os favoritos mudaram
    function favoritesChanged() {
        var currentSnapshot = getFavoritesSnapshot();

        // Comparar tamanhos
        if (currentSnapshot.length !== lastFavoritesSnapshot.length) {
            return true;
        }

        // Comparar conteúdo
        for (var i = 0; i < currentSnapshot.length; i++) {
            if (lastFavoritesSnapshot.indexOf(currentSnapshot[i]) === -1) {
                return true;
            }
        }

        return false;
    }

    // Extrai automaticamente o desktop ID de um item do modelo
    function extractDesktopIdFromModel(modelItem) {
        if (!modelItem) return "";

        var url = modelItem.url || "";
        var favoriteId = modelItem.favoriteId || "";
        var display = modelItem.display || "";

        // Tentar extrair de URL .desktop
        if (url && url.indexOf(".desktop") !== -1) {
            var parts = url.split("/");
            var desktopFile = parts[parts.length - 1];
            return desktopFile.replace(".desktop", "");
        }

        // Tentar usar favoriteId se parecer um desktop ID
        if (favoriteId && favoriteId.indexOf(".") !== -1 && favoriteId.length > 5) {
            return favoriteId;
        }

        // Fallback: usar display name normalizado
        if (display) {
            return display.toLowerCase().replace(/\s+/g, "-").replace(/[^a-z0-9-]/g, "");
        }

        return "";
    }

    // Extrai automaticamente URL do launcher de um item do modelo
    function extractLauncherUrl(modelItem, originalIndex) {
        if (!modelItem) return "";

        // DESCOBERTA: UserRole+3 contém o desktop file correto!
        try {
            var modelIndex = frequentAppsModel.index(originalIndex, 0);
            var desktopFile = frequentAppsModel.data(modelIndex, Qt.UserRole + 3);

            if (desktopFile && desktopFile.indexOf(".desktop") !== -1) {
                return "applications:" + desktopFile;
            }
        } catch (e) {
            return "";
        }

        // Fallbacks apenas se UserRole+3 falhar
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

    // Usa o backend do Task Manager para obter arquivos recentes
    function getRecentFilesForApp(launcherUrl) {
        if (!launcherUrl || !taskManagerBackend) return [];

        try {
            var recentActions = taskManagerBackend.recentDocumentActions(launcherUrl, favoritesView);
            var placesActions = taskManagerBackend.placesActions(launcherUrl, false, favoritesView);

            var totalCount = 0;

            // Contar arquivos recentes
            if (recentActions && recentActions.length > 0) {
                totalCount += recentActions.length;
            }

            // Contar locais recentes (para apps como Dolphin)
            if (placesActions && placesActions.length > 0) {
                totalCount += placesActions.length;
            }

            return totalCount;

        } catch (e) {
            return 0;
        }
    }

    // Verifica se um item é um aplicativo válido
    function isValidApplication(modelItem) {
        if (!modelItem) return false;

        var display = modelItem.display || "";
        var url = modelItem.url || "";
        var favoriteId = modelItem.favoriteId || "";
        var decoration = modelItem.decoration;

        if (!display || display.trim() === "") return false;

        // Rejeitar categorias que não são aplicativos
        if (favoriteId === "Pastas" || favoriteId === "Folders" || favoriteId === "Arquivos") return false;

        // Aceitar automaticamente categoria "Aplicativos"
        if (favoriteId === "Aplicativos") return true;

        // URLs com .desktop são aplicativos
        if (url && url.toLowerCase().indexOf(".desktop") !== -1) return true;

        // Rejeitar objetos complexos de decoração
        if (typeof decoration === "object" && decoration !== null && decoration.constructor === Object) return false;

        // Validações básicas
        if (display.length < 2) return false;
        if (/^[0-9\W]+$/.test(display)) return false;

        // Rejeitar IDs hexadecimais
        if (display.length >= 8 && /^[0-9A-F]+$/i.test(display)) return false;

        return true;
    }

    // Constrói o modelo final segregado com aplicativos e seus arquivos
    function buildSegregatedModel() {
        appsWithRecentFiles.clear();

        // Atualizar snapshot dos favoritos
        lastFavoritesSnapshot = getFavoritesSnapshot();

        // PRIMEIRO: Processar favoritos para adicionar informações de arquivos recentes
        if (globalFavoritesGrid.model) {
            var favoritesModel = globalFavoritesGrid.model;
            for (var f = 0; f < favoritesModel.count; f++) {
                try {
                    var favIndex = favoritesModel.index(f, 0);
                    var favoriteUrl = favoritesModel.data(favIndex, Qt.UserRole + 1) || "";

                    if (favoriteUrl) {
                        var recentFilesCount = getRecentFilesForApp(favoriteUrl);
                        var hasRecentFiles = recentFilesCount > 0;

                        // Atualizar o modelo de favoritos com informação de arquivos recentes
                        // (Isso é feito através de setData se suportado, senão ignoramos)
                        try {
                            if (typeof favoritesModel.setData === "function") {
                                favoritesModel.setData(favIndex, hasRecentFiles, Qt.UserRole + 10); // hasRecentFiles
                                favoritesModel.setData(favIndex, recentFilesCount, Qt.UserRole + 11); // recentFilesCount
                            }
                        } catch (e) {
                            // Modelo não suporta setData, continuar
                        }
                    }
                } catch (e) {
                    continue;
                }
            }
        }

        // SEGUNDO: Coletar IDs dos aplicativos favoritos para evitar duplicatas
        var favoriteIds = new Set();
        if (globalFavoritesGrid.model) {
            var favoritesModel = globalFavoritesGrid.model;
            for (var f = 0; f < favoritesModel.count; f++) {
                try {
                    var favIndex = favoritesModel.index(f, 0);
                    var favoriteId = favoritesModel.data(favIndex, Qt.UserRole + 2) || "";
                    var favoriteUrl = favoritesModel.data(favIndex, Qt.UserRole + 1) || "";
                    var favoriteDisplay = favoritesModel.data(favIndex, Qt.DisplayRole) || "";

                    // Adicionar diferentes formas de identificação
                    if (favoriteId) favoriteIds.add(favoriteId);
                    if (favoriteUrl) favoriteIds.add(favoriteUrl);
                    if (favoriteDisplay) favoriteIds.add(favoriteDisplay.toLowerCase());

                    // Extrair desktop file do URL se existir
                    if (favoriteUrl && favoriteUrl.indexOf(".desktop") !== -1) {
                        var parts = favoriteUrl.split("/");
                        var desktopFile = parts[parts.length - 1];
                        favoriteIds.add(desktopFile);
                        favoriteIds.add("applications:" + desktopFile);
                    }
                } catch (e) {
                    continue;
                }
            }
        }

        // TERCEIRO: Coletar aplicativos válidos (excluindo os que estão nos favoritos)
        var totalApps = frequentAppsModel.count;
        var targetAppsCount = 10; // META: sempre 10 apps
        var addedAppsCount = 0;

        // EXPANDIR BUSCA: Verificar até 50 apps se necessário para encontrar 10 únicos
        var maxSearchApps = Math.min(totalApps, 50);

        for (var i = 0; i < maxSearchApps && addedAppsCount < targetAppsCount; i++) {
            try {
                var modelIndex = frequentAppsModel.index(i, 0);
                var item = {
                    display: frequentAppsModel.data(modelIndex, Qt.DisplayRole) || "",
                    decoration: frequentAppsModel.data(modelIndex, Qt.DecorationRole),
                    url: frequentAppsModel.data(modelIndex, Qt.UserRole + 1) || "",
                    favoriteId: frequentAppsModel.data(modelIndex, Qt.UserRole + 2) || "",
                    originalIndex: i
                };

                if (!isValidApplication(item)) continue;

                // VERIFICAR SE JÁ ESTÁ NOS FAVORITOS
                var isDuplicate = false;

                var launcherUrl = extractLauncherUrl(item, i);
                if (!launcherUrl) continue;

                // Verificar por launcherUrl (mais preciso)
                if (favoriteIds.has(launcherUrl)) {
                    isDuplicate = true;
                }

                // Verificar por favoriteId
                if (!isDuplicate && item.favoriteId && favoriteIds.has(item.favoriteId)) {
                    isDuplicate = true;
                }

                // Verificar por URL
                if (!isDuplicate && item.url && favoriteIds.has(item.url)) {
                    isDuplicate = true;
                }

                // Verificar por display name
                if (!isDuplicate && item.display && favoriteIds.has(item.display.toLowerCase())) {
                    isDuplicate = true;
                }

                // Verificar por desktop file extraído
                if (!isDuplicate && item.url && item.url.indexOf(".desktop") !== -1) {
                    var parts = item.url.split("/");
                    var desktopFile = parts[parts.length - 1];
                    if (favoriteIds.has(desktopFile) || favoriteIds.has("applications:" + desktopFile)) {
                        isDuplicate = true;
                    }
                }

                // PULAR SE JÁ ESTÁ NOS FAVORITOS
                if (isDuplicate) {
                    continue;
                }

                var recentFilesCount = getRecentFilesForApp(launcherUrl);
                var hasRecentFiles = recentFilesCount > 0;

                var iconValue = (typeof item.decoration === "object" && item.decoration !== null) ? "" : item.decoration || "";

                appsWithRecentFiles.append({
                    "display": item.display,
                    "decoration": iconValue,
                    "name": item.display,
                    "icon": iconValue,
                    "url": item.url,
                    "favoriteId": item.favoriteId,
                    "launcherUrl": launcherUrl,
                    "actionList": [
                        {
                            "text": i18n("Add to Favorites"),
                            "icon": "bookmark-new",
                            "actionId": "_kicker_favorite_add",
                            "actionArgument": {
                                "favoriteModel": globalFavoritesGrid.model,
                                "favoriteId": launcherUrl
                            }
                        }
                    ],
                    "originalIndex": item.originalIndex,
                    "hasActionList": true,
                    "hasRecentFiles": hasRecentFiles,
                    "recentFilesCount": recentFilesCount
                });

                addedAppsCount++;

            } catch (e) {
                continue;
            }
        }

        modelsProcessed = true;
    }

    // Executa um aplicativo do modelo
    function executeItem(index) {
        try {
            if (frequentAppsModel && typeof frequentAppsModel.trigger === "function") {
                var item = appsWithRecentFiles.get(index);
                if (item && typeof item.originalIndex !== "undefined") {
                    frequentAppsModel.trigger(item.originalIndex, "", null);
                    return true;
                }
            }

            // Fallback para execução direta
            var item = appsWithRecentFiles.get(index);
            if (item) {
                var executable = root.executable || parent.executable;
                if (executable && typeof executable.exec === "function") {
                    if (item.desktopId && item.desktopId !== "") {
                        executable.exec("gtk-launch " + item.desktopId);
                        return true;
                    } else if (item.url && item.url !== "") {
                        executable.exec("xdg-open '" + item.url + "'");
                        return true;
                    }
                }
            }
        } catch (e) {
            return false;
        }
        return false;
    }

    // Executa um arquivo recente específico
    function executeRecentFile(fileUrl) {
        try {
            var executable = root.executable || parent.executable;
            if (executable && typeof executable.exec === "function") {
                executable.exec("xdg-open '" + fileUrl + "'");
                return true;
            }
        } catch (e) {
            return false;
        }
        return false;
    }

    // Calcula alturas dos componentes dinamicamente
    function calculateHeights() {
        var favoritesRows = Math.ceil(globalFavoritesGrid.count / Math.floor(width / cellWidth));
        var frequentRows = Math.ceil(appsWithRecentFiles.count / Math.floor(width / cellWidth));

        var availableHeight = height - separatorHeight;
        var favoritesHeight = Math.min(
            (favoritesRows * cellHeight),
            availableHeight - minFrequentAppsHeight
        );
        var frequentAppsHeight = availableHeight - favoritesHeight;

        globalFavoritesGrid.height = favoritesHeight;
        frequentAppsGrid.height = frequentAppsHeight;
    }

    // Menu de contexto para arquivos recentes - IGUAL AO TASK MANAGER
    property QtObject currentMenu: null
    property Item currentVisualParent: null

    function createMenuFromActions(actions, parent, title) {
        var menu = Qt.createQmlObject(`
            import org.kde.plasma.extras 2.0 as PlasmaExtras
            PlasmaExtras.Menu {
                placement: PlasmaExtras.Menu.RightPosedTopAlignedPopup
            }
        `, parent);

        if (!menu) return null;

        // Adicionar título se fornecido
        if (title && title !== "") {
            var headerItem = Qt.createQmlObject(`
                import org.kde.plasma.extras 2.0 as PlasmaExtras
                PlasmaExtras.MenuItem {
                    enabled: false
                }
            `, menu);
            headerItem.text = title;
            menu.addMenuItem(headerItem);

            // Separador
            var separatorItem = Qt.createQmlObject(`
                import org.kde.plasma.extras 2.0 as PlasmaExtras
                PlasmaExtras.MenuItem {
                    separator: true
                }
            `, menu);
            menu.addMenuItem(separatorItem);
        }

        // Adicionar itens das actions
        if (actions && actions.length > 0) {
            for (var i = 0; i < actions.length; i++) {
                var action = actions[i];
                if (!action || typeof action !== "object") continue;

                var menuItem = Qt.createQmlObject(`
                    import org.kde.plasma.extras 2.0 as PlasmaExtras
                    PlasmaExtras.MenuItem {}
                `, menu);

                menuItem.text = action.text || "";
                menuItem.icon = action.icon || "";

                // Conectar ação
                if (action.trigger && typeof action.trigger === "function") {
                    menuItem.clicked.connect(action.trigger);
                } else if (action.data) {
                    // Fallback para abrir arquivo diretamente
                    menuItem.clicked.connect(function() {
                        executeRecentFile(action.data);
                        // Fechar menu principal após execução
                        if (typeof root !== "undefined" && root.toggle) {
                            root.toggle();
                        } else if (typeof kicker !== "undefined") {
                            kicker.expanded = false;
                        }
                    });
                }

                menu.addMenuItem(menuItem);
            }
        } else {
            // Nenhum item encontrado
            var noItemsItem = Qt.createQmlObject(`
                import org.kde.plasma.extras 2.0 as PlasmaExtras
                PlasmaExtras.MenuItem {
                    enabled: false
                }
            `, menu);
            noItemsItem.text = i18n("Nenhum item recente");
            menu.addMenuItem(noItemsItem);
        }

        return menu;
    }

    property QtObject recentFilesMenu: QtObject {
        function showForApp(index, visualParent) {
            var item = appsWithRecentFiles.get(index);
            if (!item || !item.launcherUrl) return;

            currentVisualParent = visualParent;

            // Destruir menu anterior
            if (currentMenu) {
                currentMenu.destroy();
                currentMenu = null;
            }

            try {
                // Obter actions usando o backend (igual ao Task Manager)
                var recentActions = taskManagerBackend.recentDocumentActions(item.launcherUrl, favoritesView);
                var placesActions = taskManagerBackend.placesActions(item.launcherUrl, false, favoritesView);

                var allActions = [];
                var menuTitle = "";

                // Determinar tipo de menu baseado nas actions (igual ao Task Manager)
                if (placesActions && placesActions.length > 0) {
                    allActions = placesActions;
                    menuTitle = i18n("Locais recentes");
                } else if (recentActions && recentActions.length > 0) {
                    allActions = recentActions;
                    menuTitle = i18n("Arquivos recentes");
                }

                // Criar menu
                currentMenu = createMenuFromActions(allActions, currentVisualParent, menuTitle);
                if (currentMenu) {
                    // POSICIONAMENTO CORRETO: ao lado direito do item específico
                    currentMenu.visualParent = currentVisualParent;

                    // Para menu lateral, sempre usar RightPosedTopAlignedPopup
                    // pois o menu principal está do lado esquerdo
                    currentMenu.placement = PlasmaExtras.Menu.RightPosedTopAlignedPopup;

                    // Abrir menu posicionado ao lado do item
                    currentMenu.openRelative();
                }

            } catch (e) {
                // Silently handle errors
            }
        }
    }

    Column {
        id: mainColumn
        anchors.fill: parent
        spacing: 0

        // Grid de Favoritos
        FavoritesGridView {
            id: globalFavoritesGrid
            width: parent.width
            height: 100
            dragEnabled: favoritesView.dragEnabled
            dropEnabled: favoritesView.dropEnabled
            cellWidth: favoritesView.cellWidth
            cellHeight: favoritesView.cellHeight
            iconSize: favoritesView.iconSize
            focus: true

            // Usar Connections para evitar parameter injection deprecated
            Connections {
                target: globalFavoritesGrid
                function onItemActivated(index, actionId, argument) {
                    // Lançar aplicativo favorito normalmente
                    if (!actionId || actionId === "") {
                        // Execução normal - fechar menu
                        if (typeof root !== "undefined" && root.toggle) {
                            root.toggle();
                        } else if (typeof kicker !== "undefined") {
                            kicker.expanded = false;
                        }
                    }
                }

                function onSubmenuRequested(index, x, y) {
                    // Mostrar arquivos recentes para favoritos
                    if (globalFavoritesGrid.model) {
                        var favIndex = globalFavoritesGrid.model.index(index, 0);
                        var favoriteUrl = globalFavoritesGrid.model.data(favIndex, Qt.UserRole + 1) || "";

                        if (favoriteUrl) {
                            // Criar item temporário para usar com recentFilesMenu
                            var tempItem = {
                                launcherUrl: favoriteUrl,
                                display: globalFavoritesGrid.model.data(favIndex, Qt.DisplayRole) || ""
                            };

                            // Buscar o item visual correto no GridView
                            var visualItem = null;
                            for (var i = 0; i < globalFavoritesGrid.contentItem.children.length; i++) {
                                var child = globalFavoritesGrid.contentItem.children[i];
                                if (child.itemIndex === index) {
                                    visualItem = child;
                                    break;
                                }
                            }

                            // Mostrar menu de arquivos recentes
                            if (visualItem) {
                                showRecentFilesMenuForFavorite(tempItem, visualItem);
                            } else {
                                showRecentFilesMenuForFavorite(tempItem, globalFavoritesGrid);
                            }
                        }
                    }
                }
            }

            onCountChanged: favoritesView.calculateHeights()

            Keys.onPressed: (event) => {
                if (event.modifiers & Qt.ControlModifier || event.modifiers & Qt.ShiftModifier) {
                    event.accepted = true;
                    favoritesView.keyNavUp();
                    return;
                }
                if (event.key === Qt.Key_Tab) {
                    event.accepted = true;
                    favoritesView.keyNavUp();
                } else if (event.key === Qt.Key_Down && currentIndex >= (count - Math.floor(width / cellWidth))) {
                    event.accepted = true;
                    frequentAppsGrid.forceActiveFocus();
                    frequentAppsGrid.currentIndex = 0;
                }
            }
        }

        // Linha separadora - APENAS SE HOUVER FAVORITOS
        Rectangle {
            id: separatorLine
            width: parent.width * 0.9
            height: separatorHeight
            color: Kirigami.Theme.textColor || "#eff0f1"
            opacity: 0.3
            anchors.horizontalCenter: parent.horizontalCenter
            visible: globalFavoritesGrid.count > 0  // CONDIÇÃO ADICIONADA
        }

        // Grid de Aplicativos Frequentes
        FavoritesGridView {
            id: frequentAppsGrid
            width: parent.width
            height: 100
            cellWidth: favoritesView.cellWidth
            cellHeight: favoritesView.cellHeight
            iconSize: favoritesView.iconSize
            model: appsWithRecentFiles

            // Usar Connections para evitar parameter injection deprecated
            Connections {
                target: frequentAppsGrid
                function onItemActivated(index, actionId, argument) {
                    // Ação de favoritos - interceptar e processar manualmente
                    if (actionId && actionId.indexOf("_kicker_favorite_") === 0) {
                        var item = appsWithRecentFiles.get(index);
                        if (item && argument && argument.favoriteModel && argument.favoriteId) {
                            var favoriteModel = argument.favoriteModel;
                            var favoriteId = argument.favoriteId;

                            if (actionId === "_kicker_favorite_add" && typeof favoriteModel.addFavorite === "function") {
                                favoriteModel.addFavorite(favoriteId);

                                // Atualizar modelo IMEDIATAMENTE
                                modelsProcessed = false;
                                buildSegregatedModel();
                                calculateHeights();

                                // NÃO fechar menu - return early
                                return;
                            }
                        }
                    }

                    // Execução normal do aplicativo
                    if (!actionId || actionId === "" || actionId === undefined) {
                        if (favoritesView.executeItem(index)) {
                            // Fechar menu após execução de aplicativo
                            if (typeof root !== "undefined" && root.toggle) {
                                root.toggle();
                            } else if (typeof kicker !== "undefined") {
                                kicker.expanded = false;
                            }
                        }
                    }
                }
            }

            onSubmenuRequested: function (index, x, y) {
                var item = appsWithRecentFiles.get(index);
                if (item && item.hasRecentFiles) {
                    // Buscar o item visual correto no GridView
                    var visualItem = null;
                    for (var i = 0; i < frequentAppsGrid.contentItem.children.length; i++) {
                        var child = frequentAppsGrid.contentItem.children[i];
                        if (child.itemIndex === index) {
                            visualItem = child;
                            break;
                        }
                    }

                    if (visualItem) {
                        recentFilesMenu.showForApp(index, visualItem);
                    } else {
                        // Fallback
                        recentFilesMenu.showForApp(index, frequentAppsGrid);
                    }
                }
            }

            onCountChanged: favoritesView.calculateHeights()

            Keys.onPressed: (event) => {
                if (event.modifiers & Qt.ControlModifier || event.modifiers & Qt.ShiftModifier) {
                    event.accepted = true;
                    favoritesView.keyNavUp();
                    return;
                }
                if (event.key === Qt.Key_Tab) {
                    event.accepted = true;
                    favoritesView.keyNavUp();
                } else if (event.key === Qt.Key_Up && currentIndex < Math.floor(width / cellWidth)) {
                    event.accepted = true;
                    globalFavoritesGrid.forceActiveFocus();
                    globalFavoritesGrid.currentIndex = globalFavoritesGrid.count - 1;
                }
            }
        }
    }

    // Ativa item por coordenadas
    function tryActivate(row, col) {
        var favoritesRows = Math.ceil(globalFavoritesGrid.count / Math.floor(width / cellWidth));

        if (row < favoritesRows) {
            globalFavoritesGrid.tryActivate(row, col);
        } else {
            var adjustedRow = row - favoritesRows;
            frequentAppsGrid.tryActivate(adjustedRow, col);
        }
    }

    // Atualizar quando modelo original mudar
    Connections {
        target: frequentAppsModel
        function onCountChanged() {
            modelsProcessed = false;
            Qt.callLater(buildSegregatedModel);
        }
        function onDataChanged() {
            modelsProcessed = false;
            Qt.callLater(buildSegregatedModel);
        }
    }

    // Atualizar quando os favoritos mudarem - REMOVIDO (sinal não existe)

    Component.onCompleted: {
        buildSegregatedModel();
        calculateHeights();
    }

    // Forçar atualização quando o componente se torna visível
    onVisibleChanged: {
        if (visible) {
            // Verificar se favoritos mudaram
            if (favoritesChanged()) {
                modelsProcessed = false;
                Qt.callLater(function() {
                    buildSegregatedModel();
                    calculateHeights();
                });
            }
        }
    }

    // Timer para verificar mudanças nos favoritos periodicamente
    Timer {
        id: favoritesWatcher
        interval: 1000 // Verifica a cada 1 segundo
        running: favoritesView.visible
        repeat: true
        onTriggered: {
            if (favoritesChanged()) {
                modelsProcessed = false;
                buildSegregatedModel();
                calculateHeights();
            }
        }
    }

    onWidthChanged: Qt.callLater(calculateHeights)
    onHeightChanged: Qt.callLater(calculateHeights)
}