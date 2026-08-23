/*
 *  SPDX-FileCopyrightText: 2025 Walter Rodrigues <wmr2@cin.ufpe.br>
 *  SPDX-FileCopyrightText: 2023 WackyIdeas <wackyideas@disroot.org>
 *  SPDX-License-Identifier: AGPL-3.0-or-later
 */

import QtQuick
import QtCore
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.private.kicker 0.1 as Kicker
import org.kde.coreaddons 1.0 as KCoreAddons

// Declarative description of the right hand column. Each entry carries both a
// Windows style icon name and a freedesktop fallback, so the icon set is a
// preference rather than a hard dependency.
Item {
    id: models

    KCoreAddons.KUser { id: kuser }

    // Documents the user opened recently, feeding the "Recent Items" flyout.
    Kicker.RecentUsageModel {
        id: recentDocsModel
        ordering: 0
        shownItems: Kicker.RecentUsageModel.OnlyDocs
    }

    readonly property var recentDocuments: recentDocsModel

    property var firstCategory: [
        {
            name: "Home directory",
            itemText: Plasmoid.configuration.useFullName ? kuser.fullName : kuser.loginName,
            description: i18n("Open your personal folder."),
            itemIcon: "user-home",
            itemIconFallback: "user-home",
            executableString: StandardPaths.writableLocation(StandardPaths.HomeLocation),
            menuModel: null,
            executeProgram: false
        },
        {
            name: "Documents",
            itemText: i18n("Documents"),
            description: i18n("Access letters, reports, notes and other kinds of documents."),
            itemIcon: "library-txt",
            itemIconFallback: "folder-documents",
            executableString: StandardPaths.writableLocation(StandardPaths.DocumentsLocation),
            menuModel: null,
            executeProgram: false
        },
        {
            name: "Pictures",
            itemText: i18n("Pictures"),
            description: i18n("View and organize digital pictures."),
            itemIcon: "library-images",
            itemIconFallback: "folder-pictures",
            executableString: StandardPaths.writableLocation(StandardPaths.PicturesLocation),
            menuModel: null,
            executeProgram: false
        },
        {
            name: "Music",
            itemText: i18n("Music"),
            description: i18n("Play music and other audio files."),
            itemIcon: "library-music",
            itemIconFallback: "folder-music",
            executableString: StandardPaths.writableLocation(StandardPaths.MusicLocation),
            menuModel: null,
            executeProgram: false
        },
        {
            name: "Videos",
            itemText: i18n("Videos"),
            description: i18n("Watch home movies and other digital videos."),
            itemIcon: "library-video",
            itemIconFallback: "folder-videos",
            executableString: StandardPaths.writableLocation(StandardPaths.MoviesLocation),
            menuModel: null,
            executeProgram: false
        },
        {
            name: "Downloads",
            itemText: i18n("Downloads"),
            description: i18n("Find Internet downloads and links to favorite websites."),
            itemIcon: "folder-download",
            itemIconFallback: "folder-download",
            executableString: StandardPaths.writableLocation(StandardPaths.DownloadLocation),
            menuModel: null,
            executeProgram: false
        }
    ]

    property var secondCategory: [
        {
            name: "Games",
            itemText: i18n("Games"),
            description: i18n("Play and manage games on your computer."),
            itemIcon: "applications-games",
            itemIconFallback: "applications-games",
            executableString: "applications:///Games/",
            menuModel: null,
            executeProgram: false
        },
        {
            name: "Recent Items",
            itemText: i18n("Recent Items"),
            description: i18n("Open documents you worked on recently."),
            itemIcon: "document-open-recent",
            itemIconFallback: "document-open-recent",
            executableString: "recentlyused:/",
            menuModel: recentDocsModel,
            executeProgram: false
        },
        {
            name: "Computer",
            itemText: i18n("Computer"),
            description: i18n("See the disk drives and other hardware connected to your computer."),
            itemIcon: "computer",
            itemIconFallback: "computer",
            executableString: "file:///",
            menuModel: null,
            executeProgram: false
        },
        {
            name: "Network",
            itemText: i18n("Network"),
            description: i18n("Access the computers and devices that are on your network."),
            itemIcon: "folder-network",
            itemIconFallback: "network-workgroup",
            executableString: "remote:/",
            menuModel: null,
            executeProgram: false
        }
    ]

    property var thirdCategory: [
        {
            name: "Control Panel",
            itemText: i18n("Control Panel"),
            description: i18n("Change settings and customize the functionality of your computer."),
            itemIcon: "preferences-system",
            itemIconFallback: "preferences-system",
            executableString: "systemsettings",
            menuModel: null,
            executeProgram: true
        },
        {
            name: "Devices and Printers",
            itemText: i18n("Devices and Printers"),
            description: i18n("View and manage devices, printers and print jobs."),
            itemIcon: "input_devices_settings",
            itemIconFallback: "printer",
            executableString: "systemsettings kcm_printer_manager",
            menuModel: null,
            executeProgram: true
        },
        {
            name: "Default Programs",
            itemText: i18n("Default Programs"),
            description: i18n("Choose default programs for web browsing, e-mail and other activities."),
            itemIcon: "preferences-desktop-default-applications",
            itemIconFallback: "preferences-desktop-default-applications",
            executableString: "systemsettings kcm_componentchooser",
            menuModel: null,
            executeProgram: true
        },
        {
            name: "Help and Support",
            itemText: i18n("Help and Support"),
            description: i18n("Find help topics, tutorials, troubleshooting and other support services."),
            itemIcon: "help-browser",
            itemIconFallback: "help-browser",
            executableString: "https://userbase.kde.org/",
            menuModel: null,
            executeProgram: false
        },
        {
            name: "Run",
            itemText: i18n("Run..."),
            description: i18n("Open a program, folder, document or web site."),
            itemIcon: "krunner",
            itemIconFallback: "system-run",
            executableString: "krunner --replace",
            menuModel: null,
            executeProgram: true
        }
    ]

    readonly property var allCategories: [firstCategory, secondCategory, thirdCategory]
}
