/*
 *  SPDX-FileCopyrightText: 2025 Walter Rodrigues <wmr2@cin.ufpe.br>
 *  SPDX-FileCopyrightText: 2023 WackyIdeas <wackyideas@disroot.org>
 *  SPDX-License-Identifier: AGPL-3.0-or-later
 */

import QtQuick
import org.kde.kirigami as Kirigami

// Hides itself whenever it would end up leading, trailing or doubled, which
// happens as soon as the user turns side panel entries off.
Item {
    id: separator

    objectName: "SidePanelSeparator"
    implicitHeight: Kirigami.Units.smallSpacing * 2

    function updateVisibility() {
        const siblings = parent ? parent.children : [];
        let self = -1;
        for (let i = 0; i < siblings.length; i++) {
            if (siblings[i] === separator) { self = i; break; }
        }
        if (self === -1) { separator.visible = false; return; }

        // Repeaters and other bookkeeping objects sit in the same child list,
        // so only panel entries and separators count as neighbours.
        function neighbour(step) {
            for (let i = self + step; i >= 0 && i < siblings.length; i += step) {
                const c = siblings[i];
                if (!c) continue;
                if (c.objectName === "SidePanelSeparator") return false;
                if (c.objectName === "SidePanelItem" && c.visible) return true;
            }
            return false;
        }
        separator.visible = neighbour(-1) && neighbour(1);
    }

    Rectangle {
        anchors.centerIn: parent
        width: parent.width * 0.85
        height: 1
        color: Kirigami.Theme.textColor
        opacity: 0.25
    }
}
