/*
    SPDX-FileCopyrightText: 2025 Walter Rodrigues <wmr2@cin.ufpe.br>
    SPDX-FileCopyrightText: 2013 Aurélien Gâteau <agateau@kde.org>
    SPDX-FileCopyrightText: 2013-2015 Eike Hein <hein@kde.org>
    SPDX-FileCopyrightText: 2017 Ivan Cukic <ivan.cukic@kde.org>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

.pragma library

// Normalize an action list that may be a JS Array, a ListModel proxy
// (.count + .get), or a generic .length-indexed object into a plain JS array.
function actionListToArray(items) {
    if (!items) return [];
    var result = [];
    // Prefer .count + .get for QML ListModel proxies, where .length is often
    // undefined or stale.
    if (typeof items.count === "number" && typeof items.get === "function") {
        for (var j = 0; j < items.count; j++) result.push(items.get(j));
        return result;
    }
    if (Array.isArray(items)) return items.slice();
    if (typeof items.length === "number") {
        for (var i = 0; i < items.length; i++) result.push(items[i]);
        return result;
    }
    return [];
}

// Fetch the actionList for a given row in any kicker model. Discovers the
// "actionList" role at runtime via roleNames() (with sensible fallbacks),
// so it works uniformly against FavoritesModel, RecentUsageModel, and
// the apps tree under RootModel.
function getUpstreamActionList(model, row) {
    if (!model || row === undefined || row === null || row < 0) return [];
    try {
        var modelIndex = model.index(row, 0);
        var roleId = -1;
        if (typeof model.roleNames === "function") {
            var roles = model.roleNames();
            for (var key in roles) {
                var rname = roles[key];
                var rstr = (rname && rname.toString) ? rname.toString() : rname;
                if (rstr === "actionList") {
                    roleId = parseInt(key);
                    break;
                }
            }
        }
        // Discovered role first, then known fallbacks: standard
        // AbstractModel ActionListRole = Qt.UserRole + 2 = 258, and the
        // legacy +9 = 265 used by some kicker model variants in this fork.
        var candidates = [];
        if (roleId !== -1) candidates.push(roleId);
        candidates.push(258);
        candidates.push(265);

        for (var c = 0; c < candidates.length; c++) {
            var raw = model.data(modelIndex, candidates[c]);
            var arr = actionListToArray(raw);
            if (arr.length > 0) return arr;
        }
        return [];
    } catch (e) {
        return [];
    }
}

function fillActionMenu(i18n, actionMenu, actionList, favoriteModel, favoriteId) {
    var existing = actionListToArray(actionList);
    var actions = createFavoriteActions(i18n, favoriteModel, favoriteId);

    var combined = existing;
    if (actions && actions.length > 0) {
        if (combined.length > 0) {
            combined.push({ "type": "separator" });
            combined.push.apply(combined, actions);
        } else {
            combined = actions;
        }
    }

    actionMenu.actionList = combined;
}

function createFavoriteActions(i18n, favoriteModel, favoriteId) {
    if (!favoriteModel || !favoriteModel.enabled || !favoriteId) {
        return null;
    }


    if (!favoriteModel.activities ||
        !favoriteModel.activities.runningActivities ||
        favoriteModel.activities.runningActivities.length <= 1) {
        var action = {};

        if (favoriteModel.isFavorite(favoriteId)) {
            action.text = i18n("Remove from Favorites");
            action.icon = "bookmark-remove";
            action.actionId = "_kicker_favorite_remove";
        } else if (favoriteModel.maxFavorites === -1 || favoriteModel.count < favoriteModel.maxFavorites) {
            action.text = i18n("Add to Favorites");
            action.icon = "bookmark-new";
            action.actionId = "_kicker_favorite_add";
        } else {
            return null;
        }

        action.actionArgument = { favoriteModel: favoriteModel, favoriteId: favoriteId };

        return [action];

    } else {
        var actions = [];

        var linkedActivities = favoriteModel.linkedActivitiesFor(favoriteId);

        var activities = favoriteModel.activities.runningActivities;

        // Adding the item to link/unlink to all activities

        var linkedToAllActivities =
            !(linkedActivities.indexOf(":global") === -1);

        actions.push({
            text      : i18n("On All Activities"),
            checkable : true,

            actionId  : linkedToAllActivities ?
                             "_kicker_favorite_remove_from_activity" :
                             "_kicker_favorite_set_to_activity",
            checked   : linkedToAllActivities,

            actionArgument : {
                favoriteModel: favoriteModel,
                favoriteId: favoriteId,
                favoriteActivity: ""
            }
        });


        // Adding items for each activity separately

        var addActivityItem = function(activityId, activityName) {
            var linkedToThisActivity =
                !(linkedActivities.indexOf(activityId) === -1);

            actions.push({
                text      : activityName,
                checkable : true,
                checked   : linkedToThisActivity && !linkedToAllActivities,

                actionId :
                    // If we are on all activities, and the user clicks just one
                    // specific activity, unlink from everything else
                    linkedToAllActivities ? "_kicker_favorite_set_to_activity" :

                    // If we are linked to the current activity, just unlink from
                    // that single one
                    linkedToThisActivity ? "_kicker_favorite_remove_from_activity" :

                    // Otherwise, link to this activity, but do not unlink from
                    // other ones
                    "_kicker_favorite_add_to_activity",

                actionArgument : {
                    favoriteModel    : favoriteModel,
                    favoriteId       : favoriteId,
                    favoriteActivity : activityId
                }
            });
        };

        // Adding the item to link/unlink to the current activity

        addActivityItem(favoriteModel.activities.currentActivity, i18n("On the Current Activity"));

        actions.push({
            type: "separator",
            actionId: "_kicker_favorite_separator"
        });

        // Adding the items for each activity

        activities.forEach(function(activityId) {
            addActivityItem(activityId, favoriteModel.activityNameForId(activityId));
        });

        return [{
            text       : i18n("Show in Favorites"),
            icon       : "favorite",
            subActions : actions
        }];
    }
}

function triggerAction(model, index, actionId, actionArgument) {
    function startsWith(txt, needle) {
        return txt.substr(0, needle.length) === needle;
    }

    if (startsWith(actionId, "_kicker_favorite_")) {
        handleFavoriteAction(actionId, actionArgument);
        return true; // Close menu after favorite action
    }

    // Check if model has trigger function before calling it
    if (model && typeof model.trigger === "function") {
        var closeRequested = model.trigger(index, actionId, actionArgument);

        if (closeRequested) {
            return true;
        }
    }

    return false;
}

function handleFavoriteAction(actionId, actionArgument) {
    var favoriteId = actionArgument.favoriteId;
    var favoriteModel = actionArgument.favoriteModel;

    if (favoriteModel === null || favoriteId === null) {
        return null;
    }

    if (actionId === "_kicker_favorite_remove") {
        favoriteModel.removeFavorite(favoriteId);
    } else if (actionId === "_kicker_favorite_add") {
        favoriteModel.addFavorite(favoriteId);
    } else if (actionId === "_kicker_favorite_remove_from_activity") {
        favoriteModel.removeFavoriteFrom(favoriteId, actionArgument.favoriteActivity);
    } else if (actionId === "_kicker_favorite_add_to_activity") {
        favoriteModel.addFavoriteTo(favoriteId, actionArgument.favoriteActivity);
    } else if (actionId === "_kicker_favorite_set_to_activity") {
        favoriteModel.setFavoriteOn(favoriteId, actionArgument.favoriteActivity);
    }
}