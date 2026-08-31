/*
 *  SPDX-FileCopyrightText: 2025 Walter Rodrigues <wmr2@cin.ufpe.br>
 *  SPDX-FileCopyrightText: 2014 Eike Hein <hein@kde.org>
 *  SPDX-License-Identifier: AGPL-3.0-or-later
 */

import QtQuick
import org.kde.plasma.configuration 2.0

ConfigModel {
    ConfigCategory {
        name: i18n("General")
        icon: "configure"
        source: "ConfigGeneral.qml"
    }
    ConfigCategory {
        name: i18n("Appearance")
        icon: "preferences-desktop-color"
        source: "ConfigAppearance.qml"
    }
    ConfigCategory {
        name: i18n("Search")
        icon: "search"
        source: "ConfigSearch.qml"
    }
    ConfigCategory {
        name: i18n("Side Panel")
        icon: "view-list-details"
        source: "ConfigSidepanel.qml"
    }
}
