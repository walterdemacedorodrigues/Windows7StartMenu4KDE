/*
 *  SPDX-FileCopyrightText: 2026 Walter Rodrigues <wmr2@cin.ufpe.br>
 *  SPDX-License-Identifier: AGPL-3.0-or-later
 */

import QtQml 2.15

// Reads a Kicker model by role name: the numeric indices are private API that shifts between Plasma releases, the names do not.
Instantiator {
    id: reader

    property var sourceModel: null

    model: sourceModel
    active: sourceModel !== null && sourceModel !== undefined && typeof sourceModel === "object"

    function row(index) {
        return (index >= 0 && index < count) ? objectAt(index) : null;
    }

    delegate: QtObject {
        readonly property string roleDisplay: model.display !== undefined && model.display !== null ? String(model.display) : ""
        readonly property var roleDecoration: model.decoration
        readonly property string roleUrl: model.url !== undefined && model.url !== null ? String(model.url) : ""
        readonly property string roleFavoriteId: model.favoriteId !== undefined && model.favoriteId !== null ? String(model.favoriteId) : ""
        readonly property string roleGroup: model.group !== undefined && model.group !== null ? String(model.group) : ""
        readonly property var roleActionList: model.actionList !== undefined && model.actionList !== null ? model.actionList : []
    }
}
