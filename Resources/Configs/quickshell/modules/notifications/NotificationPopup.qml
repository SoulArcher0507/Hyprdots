import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import Quickshell.Hyprland
import Quickshell.Io
import Qt.labs.platform 1.1 as Labs
import Qt.labs.folderlistmodel
import QtMultimedia
import "../theme" as ThemePkg
import "../bar/widgets/dnd" as DndMod
import "../bar/widgets" as BarWidgets

Item {
    id: root
    readonly property real popupOpenRadius: 20
    readonly property real popupClosedRadius: 34
    property bool popupMounted: false
    property bool popupTargetVisible: false
    property real popupCardOpacity: 0.0
    property real popupCardScaleX: 0.91
    property real popupCardScaleY: 0.79
    property real popupCardWidth: Math.max(minCardWidth, Math.min(maxCardWidth, content.implicitWidth + 50))
    property real popupCardHeight: Math.min(maxCardHeight, content.implicitHeight + 50)
    property real popupCardRadius: popupClosedRadius
    property real popupCardLift: 18
    readonly property bool soundEnabled: DndMod.DndState.soundEnabled && !root.doNotDisturb
    readonly property url defaultNotificationSound: Qt.resolvedUrl("default-notification.wav")
    readonly property url currentNotificationSound: root._currentNotificationSound()
    property var groupedNotifications: []
    property var expandedGroups: ({})
    property var expandedBodies: ({})
    property var iconLookupCache: ({})
    property int iconLookupCacheSize: 0
    property string notificationSnapshot: ""
    property int dismissAnimationDuration: 220
    property int popupResizeDuration: 170
    property var pendingNotificationDismissals: ({})
    property var pendingGroupDismissals: ({})

    readonly property color base: ThemePkg.Theme.surface(0.10)
    readonly property color mantle: ThemePkg.Theme.surface(0.05)
    readonly property color crust: ThemePkg.Theme.background
    readonly property color text: ThemePkg.Theme.foreground
    readonly property color subtext0: ThemePkg.Theme.mix(ThemePkg.Theme.background, ThemePkg.Theme.foreground, 0.6)
    readonly property color overlay0: ThemePkg.Theme.mix(ThemePkg.Theme.background, ThemePkg.Theme.foreground, 0.3)
    readonly property color overlay1: ThemePkg.Theme.mix(ThemePkg.Theme.background, ThemePkg.Theme.foreground, 0.4)
    readonly property color surface0: ThemePkg.Theme.surface(0.06)
    readonly property color surface1: ThemePkg.Theme.surface(0.08)
    readonly property color surface2: ThemePkg.Theme.surface(0.12)
    readonly property color accent: ThemePkg.Theme.accent
    readonly property color moduleBorderColor: ThemePkg.Theme.mix(ThemePkg.Theme.background, ThemePkg.Theme.foreground, 0.35)
    readonly property color moduleFontColor: ThemePkg.Theme.accent
    readonly property color cardBg: ThemePkg.Theme.surface(0.08)

    property int topMarginPx: 0
    property int minCardWidth: 420
    property int maxCardWidth: 520
    property int maxCardHeight: 680

    readonly property bool doNotDisturb: DndMod.DndState.dnd

    Component.onCompleted: {
        root.syncNotificationCount(true)
    }

    function schedulePopupLayoutRefresh() {
        if (!root.popupMounted)
            return;
        popupLayoutRefresh.restart();
    }

    function _applyOpenCardSize() {
        if (!root.popupMounted || !root.popupTargetVisible || popupEnterAnim.running || popupExitAnim.running)
            return;
        const targetWidth = Math.max(root.minCardWidth, Math.min(root.maxCardWidth, content.implicitWidth + 50));
        const targetHeight = Math.min(root.maxCardHeight, content.implicitHeight + 50);
        const shouldAnimate = root.popupCardOpacity >= 0.96;

        if (Math.abs(root.popupCardWidth - targetWidth) < 0.5 && Math.abs(root.popupCardHeight - targetHeight) < 0.5)
            return;

        if (!shouldAnimate) {
            popupResizeAnim.stop();
            popupCardWidth = targetWidth;
            popupCardHeight = targetHeight;
            return;
        }

        popupResizeWidthAnim.to = targetWidth;
        popupResizeHeightAnim.to = targetHeight;
        popupResizeAnim.restart();
    }

    function _showNotificationPopup() {
        popupTargetVisible = true;
        popupMounted = true;
        popupExitAnim.stop();
        popupResizeAnim.stop();
        root.schedulePopupLayoutRefresh();
        if (!popupEnterAnim.running && popupCardOpacity >= 0.999) {
            Qt.callLater(function() {
                root.schedulePopupLayoutRefresh();
                card.forceActiveFocus();
            });
            return;
        }
        root.syncNotificationCount(true);
        popupEnterAnim.stop();
        Qt.callLater(function() {
            if (!root.popupTargetVisible)
                return;
            root.schedulePopupLayoutRefresh();
            popupEnterAnim.start();
            card.forceActiveFocus();
        });
    }

    function _hideNotificationPopup() {
        popupTargetVisible = false;
        popupEnterAnim.stop();
        popupResizeAnim.stop();
        if (!popupMounted && popupCardOpacity <= 0.001)
            return;
        popupExitAnim.stop();
        popupExitAnim.start();
    }

    function syncNotificationCount(force) {
        const values = server && server.trackedNotifications && server.trackedNotifications.values
            ? server.trackedNotifications.values
            : [];
        root._prunePendingDismissals(values);
        DndMod.DndState.notificationCount = Math.max(0, (values.length || 0) - root._pendingNotificationCountFor(values));
        const snapshot = root.notificationSnapshotFor(values);
        if (!force && snapshot === root.notificationSnapshot)
            return;
        root.notificationSnapshot = snapshot;
        root.rebuildGroupedNotifications(values);
    }

    function notificationSnapshotFor(values) {
        const items = values || [];
        const tokens = [String(items.length)];

        for (let i = 0; i < items.length; ++i) {
            const notif = items[i];
            const actionItems = root._notificationActions(notif);
            const summary = notif && notif.summary ? String(notif.summary) : "";
            const body = notif && notif.body ? String(notif.body) : "";
            tokens.push([
                String(notif && notif.id !== undefined ? notif.id : i),
                root._sourceKeyFor(notif),
                root._iconCacheKeyFor(notif),
                summary.slice(0, 120),
                body.slice(0, 160),
                actionItems.map(action => root._actionText(action)).join("\u001d").slice(0, 160)
            ].join("\u001e"));
        }

        return tokens.join("\u001f");
    }

    function _sourceKeyFor(n) {
        if (!n)
            return "__unknown__";
        return String(
            n.desktopEntry || n.desktopId || n.appName || n.appIconName || n.iconName || "__unknown__"
        );
    }

    function _sourceLabelFor(n) {
        if (!n)
            return "Notification";
        return String(n.appName || n.desktopEntry || n.desktopId || "Notification");
    }

    function _actionText(action) {
        if (!action)
            return "";
        return String(action.text || action.label || action.title || "").trim();
    }

    function _notificationActions(notification) {
        const raw = notification && notification.actions ? notification.actions : [];
        const filtered = [];
        for (let i = 0; i < raw.length; ++i) {
            if (root._actionText(raw[i]).length > 0)
                filtered.push(raw[i]);
        }
        return filtered;
    }

    function _notificationId(notification) {
        if (!notification)
            return "";
        if (notification.id !== undefined && notification.id !== null)
            return String(notification.id);
        return [
            root._sourceKeyFor(notification),
            String(notification.summary || ""),
            String(notification.body || "")
        ].join("\u001e");
    }

    function _pendingNotificationCountFor(values) {
        const ids = {};
        const items = values || [];
        for (let i = 0; i < items.length; ++i) {
            const id = root._notificationId(items[i]);
            if (id !== "")
                ids[id] = true;
        }

        let count = 0;
        const pending = root.pendingNotificationDismissals || ({});
        for (const id in pending) {
            if (ids[id])
                count += 1;
        }
        return count;
    }

    function _prunePendingDismissals(values) {
        const ids = {};
        const items = values || [];
        for (let i = 0; i < items.length; ++i) {
            const id = root._notificationId(items[i]);
            if (id !== "")
                ids[id] = true;
        }

        let notifChanged = false;
        const nextPendingNotifications = {};
        const pendingNotifications = root.pendingNotificationDismissals || ({});
        for (const id in pendingNotifications) {
            if (ids[id]) {
                nextPendingNotifications[id] = pendingNotifications[id];
            } else {
                notifChanged = true;
            }
        }
        if (notifChanged)
            root.pendingNotificationDismissals = nextPendingNotifications;

        let groupChanged = false;
        const nextPendingGroups = {};
        const pendingGroups = root.pendingGroupDismissals || ({});
        for (const groupKey in pendingGroups) {
            const pendingGroup = pendingGroups[groupKey];
            const pendingIds = pendingGroup && pendingGroup.ids ? pendingGroup.ids : ({});
            let hasRemaining = false;
            const nextIds = {};
            for (const id in pendingIds) {
                if (ids[id]) {
                    nextIds[id] = true;
                    hasRemaining = true;
                } else {
                    groupChanged = true;
                }
            }

            if (hasRemaining) {
                nextPendingGroups[groupKey] = {
                    at: pendingGroup.at,
                    ids: nextIds
                };
            } else {
                groupChanged = true;
            }
        }
        if (groupChanged)
            root.pendingGroupDismissals = nextPendingGroups;

        if (Object.keys(root.pendingNotificationDismissals).length === 0
                && Object.keys(root.pendingGroupDismissals).length === 0
                && pendingDismissTimer.running) {
            pendingDismissTimer.stop();
        }
    }

    function _markNotificationsPending(notifications) {
        const next = Object.assign({}, root.pendingNotificationDismissals);
        const now = Date.now();
        const items = notifications || [];

        for (let i = 0; i < items.length; ++i) {
            const notif = items[i];
            const id = root._notificationId(notif);
            if (id === "")
                continue;
            if (next[id] && next[id].dismissRequested)
                continue;
            next[id] = {
                notification: notif,
                at: now,
                dismissRequested: false
            };
        }

        root.pendingNotificationDismissals = next;
        if (Object.keys(next).length > 0 && !pendingDismissTimer.running)
            pendingDismissTimer.start();
    }

    function _markGroupPending(group, notifications) {
        if (!group || !group.groupKey)
            return;

        const ids = {};
        const items = notifications || [];
        for (let i = 0; i < items.length; ++i) {
            const id = root._notificationId(items[i]);
            if (id !== "")
                ids[id] = true;
        }

        if (Object.keys(ids).length === 0)
            return;

        const next = Object.assign({}, root.pendingGroupDismissals);
        next[String(group.groupKey)] = {
            at: Date.now(),
            ids: ids
        };
        root.pendingGroupDismissals = next;
        if (!pendingDismissTimer.running)
            pendingDismissTimer.start();
    }

    function _isNotificationPending(notification) {
        const id = root._notificationId(notification);
        return id !== "" && !!root.pendingNotificationDismissals[id];
    }

    function _isGroupPending(group) {
        if (!group || !group.groupKey)
            return false;
        const pendingGroup = root.pendingGroupDismissals[String(group.groupKey)];
        if (!pendingGroup || !pendingGroup.ids)
            return false;

        const entries = group.notifications || [];
        if (entries.length === 0)
            return false;

        for (let i = 0; i < entries.length; ++i) {
            const notif = entries[i] ? entries[i].notification : null;
            const id = root._notificationId(notif);
            if (id === "" || !pendingGroup.ids[id])
                return false;
        }
        return true;
    }

    function _bodyIsLong(body) {
        const text = String(body || "");
        return text.length > 180 || text.split("\n").length > 3;
    }

    function _bodyAutoExpanded(notification, summary, body) {
        const appName = notification ? String(notification.appName || notification.desktopEntry || notification.desktopId || root._sourceLabelFor(notification) || "") : "";
        const title = String(summary || "");
        return root._bodyIsLong(body)
            && appName === "ArchTools"
            && (title.indexOf("Update Errors") !== -1 || title.indexOf("Update Interrupted") !== -1);
    }

    function _bodyExpanded(notification, summary, body) {
        if (!root._bodyIsLong(body))
            return false;
        const id = root._notificationId(notification);
        if (id !== "" && root.expandedBodies[id] !== undefined)
            return !!root.expandedBodies[id];
        return root._bodyAutoExpanded(notification, summary, body);
    }

    function toggleBodyExpanded(notification, summary, body) {
        if (!root._bodyIsLong(body))
            return false;
        const id = root._notificationId(notification);
        if (id === "")
            return false;
        const next = Object.assign({}, root.expandedBodies);
        next[id] = !root._bodyExpanded(notification, summary, body);
        root.expandedBodies = next;
        root.syncNotificationCount(true);
        root.schedulePopupLayoutRefresh();
        return true;
    }

    function _processPendingDismissals() {
        const now = Date.now();
        const next = Object.assign({}, root.pendingNotificationDismissals);
        let changed = false;
        let requestedDismiss = false;

        for (const id in next) {
            const pending = next[id];
            if (!pending || pending.dismissRequested || (now - pending.at) < root.dismissAnimationDuration)
                continue;

            try {
                pending.notification.dismiss();
                pending.dismissRequested = true;
                changed = true;
                requestedDismiss = true;
            } catch (e) {
                delete next[id];
                changed = true;
            }
        }

        if (changed)
            root.pendingNotificationDismissals = next;
        if (requestedDismiss)
            root.scheduleNotificationCountRefresh();
        if (Object.keys(root.pendingNotificationDismissals).length === 0
                && Object.keys(root.pendingGroupDismissals).length === 0
                && pendingDismissTimer.running) {
            pendingDismissTimer.stop();
        }
    }

    function rebuildGroupedNotifications(values) {
        const items = values || [];
        const groups = [];
        const byKey = {};
        const nextExpanded = {};

        for (let i = 0; i < items.length; ++i) {
            const notif = items[i];
            const key = root._sourceKeyFor(notif);
            if (!byKey[key]) {
                byKey[key] = {
                    groupKey: key,
                    sourceLabel: root._sourceLabelFor(notif),
                    iconSource: root._iconSourceFor(notif),
                    notifications: []
                };
                groups.push(byKey[key]);
            }

            byKey[key].notifications.push({
                notification: notif,
                summary: notif.summary || "Notification",
                body: notif.body || "",
                iconSource: root._iconSourceFor(notif),
                actions: root._notificationActions(notif)
            });
        }

        for (let j = 0; j < groups.length; ++j) {
            const group = groups[j];
            const latest = group.notifications[group.notifications.length - 1] || {};
            nextExpanded[group.groupKey] = !!root.expandedGroups[group.groupKey];
            group.count = group.notifications.length;
            group.expanded = !!nextExpanded[group.groupKey] && group.count > 1;
            group.latestSummary = group.count > 1
                ? latest.summary || (group.sourceLabel + " notification")
                : (latest.summary || "Notification");
            group.latestBody = latest.body || "";
            group.latestNotification = latest.notification || null;
            group.latestActions = latest.actions || [];
            group.latestIconSource = latest.iconSource || group.iconSource || "";
        }

        root.expandedGroups = nextExpanded;
        root.groupedNotifications = groups;
    }

    function toggleGroupExpanded(groupKey) {
        const state = Object.assign({}, root.expandedGroups);
        state[groupKey] = !state[groupKey];
        root.expandedGroups = state;
        root.syncNotificationCount(true);
    }

    function dismissNotification(notification) {
        if (!notification || root._isNotificationPending(notification))
            return;
        root._markNotificationsPending([notification]);
        DndMod.DndState.notificationCount = Math.max(0, DndMod.DndState.notificationCount - 1);
        root.scheduleNotificationCountRefresh();
    }

    function dismissGroup(group) {
        const entries = (group && group.notifications) ? group.notifications.slice() : [];
        if (entries.length === 0 || root._isGroupPending(group))
            return;
        const notifications = [];
        for (let i = 0; i < entries.length; ++i) {
            if (entries[i] && entries[i].notification)
                notifications.push(entries[i].notification);
        }
        root._markNotificationsPending(notifications);
        root._markGroupPending(group, notifications);
        DndMod.DndState.notificationCount = Math.max(0, DndMod.DndState.notificationCount - entries.length);
        root.scheduleNotificationCountRefresh();
    }

    function dismissAllNotifications() {
        const notifications = (server.trackedNotifications.values || []).slice();
        if (notifications.length === 0)
            return;

        root._markNotificationsPending(notifications);

        const groups = root.groupedNotifications || [];
        for (let i = 0; i < groups.length; ++i) {
            const group = groups[i];
            const entries = (group && group.notifications) ? group.notifications : [];
            const groupNotifications = [];
            for (let j = 0; j < entries.length; ++j) {
                if (entries[j] && entries[j].notification)
                    groupNotifications.push(entries[j].notification);
            }
            root._markGroupPending(group, groupNotifications);
        }

        DndMod.DndState.notificationCount = 0;
        root.scheduleNotificationCountRefresh();
    }

    function invokePrimaryNotification(notification) {
        if (notification && notification.actions && notification.actions.length > 0) {
            try { notification.actions[0].invoke(); } catch (e) {}
        }
    }

    function invokeNotificationAction(action, notification) {
        if (!action || !action.invoke)
            return;
        try { action.invoke(); } catch (e) {}
        root.scheduleNotificationCountRefresh();
    }

    function scheduleNotificationCountRefresh() {
        root.syncNotificationCount(true);
        notificationCountFastSync.restart();
        notificationCountDelayedSync.restart();
    }

    Timer {
        id: notificationCountSync
        interval: 2500
        repeat: true
        running: true
        triggeredOnStart: false
        onTriggered: root.syncNotificationCount()
    }

    Timer {
        id: notificationCountFastSync
        interval: 25
        repeat: false
        onTriggered: root.syncNotificationCount(true)
    }

    Timer {
        id: notificationCountDelayedSync
        interval: 140
        repeat: false
        onTriggered: root.syncNotificationCount(true)
    }

    Timer {
        id: pendingDismissTimer
        interval: 25
        repeat: true
        running: false
        onTriggered: root._processPendingDismissals()
    }

    Timer {
        id: popupLayoutRefresh
        interval: 0
        repeat: false
        onTriggered: root._applyOpenCardSize()
    }

    ParallelAnimation {
        id: popupResizeAnim
        running: false

        NumberAnimation {
            id: popupResizeWidthAnim
            target: root
            property: "popupCardWidth"
            duration: root.popupResizeDuration
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            id: popupResizeHeightAnim
            target: root
            property: "popupCardHeight"
            duration: root.popupResizeDuration
            easing.type: Easing.OutCubic
        }
    }

    Connections {
        target: ThemePkg.Theme
        function onGlobalToggleNotifications() {
            if (!root.popupTargetVisible) {
                ThemePkg.Theme.globalCloseAllPopups();
            }
            if (root.popupTargetVisible)
                root._hideNotificationPopup();
            else
                root._showNotificationPopup();
        }

        function onGlobalCloseAllPopups() {
            root._hideNotificationPopup();
        }

        function onGlobalCloseShellPopups() {
            root._hideNotificationPopup();
        }
    }

    Connections {
        target: content
        function onImplicitHeightChanged() { root.schedulePopupLayoutRefresh() }
        function onImplicitWidthChanged() { root.schedulePopupLayoutRefresh() }
    }

    Connections {
        target: notificationList
        function onContentHeightChanged() { root.schedulePopupLayoutRefresh() }
        function onCountChanged() { root.schedulePopupLayoutRefresh() }
    }

    NotificationServer {
        id: server
        bodySupported: true
        actionsSupported: true
        imageSupported: true
        keepOnReload: true
        onNotification: (n) => {
            n.tracked = true;
            root.scheduleNotificationCountRefresh();
            if (!root.doNotDisturb) {
                let iconHint = "";
                let h = n.hints || {};
                iconHint = h["image-path"] || h["app_icon"] || h["image"] ||
                           n.image || n.appIcon || h["icon-name"] ||
                           n.appIconName || n.iconName ||
                           h["desktop-entry"] || n.desktopEntry || n.desktopId ||
                           "";
                root._sendToast(
                    n.summary || "",
                    n.body || "",
                    n.appName || "",
                    String(iconHint || ""),
                    {
                        notification: n,
                        actions: root._notificationActions(n)
                    }
                );
                if (root.soundEnabled) {
                    root._playNotificationSound();
                }
            }
        }
    }

    Process {
        id: focusClientProc
        property string targetApp: ""
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (focusClientProc.targetApp === "") return;
                try {
                    const clients = JSON.parse(this.text);
                    const app = focusClientProc.targetApp.toLowerCase();
                    let bestMatch = null;

                    for (let i = 0; i < clients.length; i++) {
                        const client = clients[i];
                        const cls = (client.class || "").toLowerCase();
                        const initCls = (client.initialClass || "").toLowerCase();
                        const title = (client.title || "").toLowerCase();

                        if (cls === app || initCls === app) {
                            bestMatch = client;
                            break;
                        }
                        if (cls.includes(app) || app.includes(cls) || title.includes(app)) {
                            if (!bestMatch) bestMatch = client;
                        }
                    }

                    if (bestMatch) {
                        const x = Math.round(bestMatch.at[0] + bestMatch.size[0] / 2);
                        const y = Math.round(bestMatch.at[1] + bestMatch.size[1] / 2);

                        if (bestMatch.workspace && bestMatch.workspace.id !== -1) {
                            Hyprland.dispatch("workspace " + bestMatch.workspace.id);
                        }

                        Hyprland.dispatch("focuswindow address:" + bestMatch.address);
                        Hyprland.dispatch("movecursor " + x + " " + y);
                        
                        root._hideNotificationPopup();
                    }
                } catch (e) {
                    console.error("Failed to parse hyprctl clients:", e);
                }
                focusClientProc.targetApp = "";
            }
        }
    }

    function focusApp(appName) {
        if (!appName || appName === "") return;
        focusClientProc.targetApp = appName;
        focusClientProc.running = true;
    }

    function _sendToast(summary, body, appName, iconHint, payload) {
        ThemePkg.Theme.notify(summary, body, appName, iconHint, payload || ({}));
    }

    function _currentNotificationSound() {
        if (soundFiles.count > 0) {
            const fileUrl = soundFiles.get(0, "fileUrl");
            if (fileUrl)
                return fileUrl;
        }
        return root.defaultNotificationSound;
    }

    function _playNotificationSound() {
        notificationPlayer.stop();
        notificationPlayer.source = root.currentNotificationSound;
        notificationPlayer.play();
    }

    FolderListModel {
        id: soundFiles
        folder: Qt.resolvedUrl("sounds")
        showDirs: false
        sortField: FolderListModel.Name
        nameFilters: ["*.wav", "*.ogg", "*.oga", "*.mp3", "*.flac", "*.aac", "*.m4a"]
    }

    MediaPlayer {
        id: notificationPlayer
        audioOutput: AudioOutput {
            volume: 1.0
        }
    }

    component HoldOrbButton: Item {
        id: orb
        width: 57
        height: 57

        property string activeIcon: ""
        property string inactiveIcon: ""
        property string tip: ""
        property bool active: false
        property bool buttonEnabled: true
        property color activeColor: root.accent
        property real fillLevel: 0.0
        property bool triggered: false
        property real flashOpacity: 0.0
        property int holdDuration: 650
        readonly property bool hovered: orbMa.containsMouse
        readonly property color shellTopColor: active ? Qt.lighter(activeColor, 1.15) : (hovered ? root.surface2 : root.surface1)
        readonly property color shellBottomColor: active ? activeColor : root.surface0
        readonly property color shellBorderColor: active ? Qt.lighter(activeColor, 1.08) : root.moduleBorderColor
        readonly property color glowColor: active ? activeColor : root.surface2
        readonly property color waveTopColor: root.surface1
        readonly property color waveBottomColor: root.crust

        signal activated()

        opacity: buttonEnabled ? 1.0 : 0.42
        Behavior on opacity { NumberAnimation { duration: 120 } }

        Rectangle {
            anchors.centerIn: parent
            width: parent.width + 15
            height: width
            radius: width / 2
            color: glowColor
            opacity: active ? 0.26 : (orb.hovered ? 0.12 : 0.08)
            z: -2

            Behavior on color { ColorAnimation { duration: 180 } }
            Behavior on opacity { NumberAnimation { duration: 180 } }
        }

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            border.width: 1
            border.color: shellBorderColor
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: shellTopColor }
                GradientStop { position: 1.0; color: shellBottomColor }
            }

            Behavior on border.color { ColorAnimation { duration: 180 } }
        }

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            border.width: 1
            border.color: ThemePkg.Theme.withAlpha("#ffffff", orb.hovered ? 0.10 : 0.05)
        }

        Canvas {
            id: orbWave
            anchors.fill: parent
            visible: orb.fillLevel > 0.0
            opacity: 0.95
            property real wavePhase: 0.0

            NumberAnimation on wavePhase {
                running: orb.fillLevel > 0.0 && orb.fillLevel < 1.0
                loops: Animation.Infinite
                from: 0
                to: Math.PI * 2
                duration: 800
            }

            onWavePhaseChanged: requestPaint()
            Connections {
                target: orb
                function onFillLevelChanged() { orbWave.requestPaint() }
            }

            onPaint: {
                const ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                if (orb.fillLevel <= 0.001)
                    return;

                const radius = width / 2;
                const fillY = height * (1.0 - orb.fillLevel);
                ctx.save();
                ctx.beginPath();
                ctx.arc(radius, radius, radius, 0, 2 * Math.PI);
                ctx.clip();

                ctx.beginPath();
                ctx.moveTo(0, fillY);
                if (orb.fillLevel < 0.99) {
                    const waveAmp = 5 * Math.sin(orb.fillLevel * Math.PI);
                    const cp1y = fillY + Math.sin(wavePhase) * waveAmp;
                    const cp2y = fillY + Math.cos(wavePhase + Math.PI) * waveAmp;
                    ctx.bezierCurveTo(width * 0.33, cp2y, width * 0.66, cp1y, width, fillY);
                    ctx.lineTo(width, height);
                    ctx.lineTo(0, height);
                } else {
                    ctx.lineTo(width, 0);
                    ctx.lineTo(width, height);
                    ctx.lineTo(0, height);
                }
                ctx.closePath();

                const grad = ctx.createLinearGradient(0, 0, 0, height);
                grad.addColorStop(0, orb.waveTopColor.toString());
                grad.addColorStop(1, orb.waveBottomColor.toString());
                ctx.fillStyle = grad;
                ctx.fill();
                ctx.restore();
            }
        }

        Text {
            anchors.centerIn: parent
            text: orb.active ? orb.activeIcon : orb.inactiveIcon
            color: orb.active ? root.crust : (orb.hovered ? root.text : root.overlay1)
            font.pixelSize: 22
            font.family: "Iosevka Nerd Font"
        }

        Item {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: parent.height * orb.fillLevel
            clip: true
            visible: orb.fillLevel > 0.0

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: (orb.height / 2) - (height / 2) - (orb.height - parent.height)
                text: orb.active ? orb.activeIcon : orb.inactiveIcon
                color: root.text
                font.pixelSize: 22
                font.family: "Iosevka Nerd Font"
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "#ffffff"
            opacity: orb.flashOpacity
        }

        MouseArea {
            id: orbMa
            anchors.fill: parent
            hoverEnabled: true
            enabled: orb.buttonEnabled
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

            onPressed: {
                if (!orb.triggered) {
                    orbDrain.stop();
                    orbFill.start();
                }
            }
            onReleased: {
                if (!orb.triggered && orb.fillLevel < 1.0) {
                    orbFill.stop();
                    orbDrain.start();
                }
            }
            onCanceled: {
                if (!orb.triggered) {
                    orbFill.stop();
                    orbDrain.start();
                }
            }
        }

        ToolTip.visible: orbMa.containsMouse
        ToolTip.delay: 250
        ToolTip.text: tip

        NumberAnimation {
            id: orbFill
            target: orb
            property: "fillLevel"
            to: 1.0
            duration: orb.holdDuration * (1.0 - orb.fillLevel)
            easing.type: Easing.InSine
            onFinished: {
                orb.triggered = true;
                orb.flashOpacity = 0.55;
                orbFlash.start();
                orb.activated();
                orbReset.start();
            }
        }

        NumberAnimation {
            id: orbDrain
            target: orb
            property: "fillLevel"
            to: 0.0
            duration: 1000 * orb.fillLevel
            easing.type: Easing.OutQuad
        }

        NumberAnimation {
            id: orbFlash
            target: orb
            property: "flashOpacity"
            to: 0.0
            duration: 420
            easing.type: Easing.OutExpo
        }

        NumberAnimation {
            id: orbReset
            target: orb
            property: "fillLevel"
            to: 0.0
            duration: 280
            easing.type: Easing.OutExpo
            onFinished: orb.triggered = false
        }
    }

    component HoldCardButton: Rectangle {
        id: holdCard
        width: 132
        height: 42
        radius: 14

        property string valueText: ""
        property string labelText: ""
        property string tip: ""
        property string valueFontFamily: "JetBrains Mono"
        property string labelFontFamily: "JetBrains Mono"
        property bool buttonEnabled: true
        property real fillLevel: 0.0
        property bool triggered: false
        property real flashOpacity: 0.0
        property int holdDuration: 700

        signal activated()

        color: cardMouse.containsMouse ? "#14ffffff" : "#08ffffff"
        border.color: cardMouse.containsMouse ? root.accent : "#1affffff"
        border.width: 1
        opacity: buttonEnabled ? 1.0 : 0.42

        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }
        Behavior on opacity { NumberAnimation { duration: 120 } }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            clip: true
            color: "transparent"

            Canvas {
                id: cardWaveCanvas
                anchors.fill: parent
                visible: holdCard.fillLevel > 0.0
                opacity: 0.92
                property real wavePhase: 0.0

                NumberAnimation on wavePhase {
                    running: holdCard.fillLevel > 0.0 && holdCard.fillLevel < 1.0
                    loops: Animation.Infinite
                    from: 0
                    to: Math.PI * 2
                    duration: 800
                }

                onWavePhaseChanged: requestPaint()
                Connections {
                    target: holdCard
                    function onFillLevelChanged() { cardWaveCanvas.requestPaint() }
                }

                onPaint: {
                    const ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    if (holdCard.fillLevel <= 0.001)
                        return;

                    const currentW = width * holdCard.fillLevel;
                    const waveAmpBase = 10 * Math.sin(holdCard.fillLevel * Math.PI);
                    const waveAmp = Math.min(Math.max(0, currentW), waveAmpBase);
                    const r = holdCard.radius;

                    ctx.save();
                    ctx.beginPath();
                    ctx.moveTo(r, 0);
                    ctx.lineTo(width - r, 0);
                    ctx.arcTo(width, 0, width, r, r);
                    ctx.lineTo(width, height - r);
                    ctx.arcTo(width, height, width - r, height, r);
                    ctx.lineTo(r, height);
                    ctx.arcTo(0, height, 0, height - r, r);
                    ctx.lineTo(0, r);
                    ctx.arcTo(0, 0, r, 0, r);
                    ctx.closePath();
                    ctx.clip();

                    ctx.beginPath();
                    ctx.moveTo(0, 0);
                    if (holdCard.fillLevel < 0.99) {
                        const cp1x = currentW + Math.sin(wavePhase) * waveAmp;
                        const cp2x = currentW + Math.cos(wavePhase + Math.PI) * waveAmp;
                        ctx.lineTo(currentW, 0);
                        ctx.bezierCurveTo(cp2x, height * 0.33, cp1x, height * 0.66, currentW, height);
                        ctx.lineTo(0, height);
                    } else {
                        ctx.lineTo(width, 0);
                        ctx.lineTo(width, height);
                        ctx.lineTo(0, height);
                    }
                    ctx.closePath();

                    const grad = ctx.createLinearGradient(0, 0, width, 0);
                    grad.addColorStop(0.0, Qt.lighter(root.accent, 1.12).toString());
                    grad.addColorStop(1.0, root.accent.toString());
                    ctx.fillStyle = grad;
                    ctx.fill();
                    ctx.restore();
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "#ffffff"
            opacity: holdCard.flashOpacity
        }

        Column {
            id: holdCardBaseText
            anchors.centerIn: parent
            spacing: labelText === "" ? 0 : 2

            Text {
                id: holdCardValueText
                text: holdCard.valueText
                color: root.text
                font.pixelSize: 15
                font.family: holdCard.valueFontFamily
                font.weight: Font.Black
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                id: holdCardLabelText
                text: holdCard.labelText
                visible: holdCard.labelText !== ""
                color: root.subtext0
                font.pixelSize: 10
                font.family: holdCard.labelFontFamily
                font.weight: Font.Bold
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }

        Item {
            id: holdCardTextClip
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * holdCard.fillLevel
            clip: true
            visible: holdCard.fillLevel > 0.0

            Column {
                spacing: holdCard.labelText === "" ? 0 : 2
                x: holdCardBaseText.x
                y: holdCardBaseText.y

                Text {
                    text: holdCard.valueText
                    color: root.crust
                    font.pixelSize: holdCardValueText.font.pixelSize
                    font.family: holdCardValueText.font.family
                    font.weight: holdCardValueText.font.weight
                }

                Text {
                    text: holdCard.labelText
                    visible: holdCard.labelText !== ""
                    color: root.crust
                    font.pixelSize: holdCardLabelText.font.pixelSize
                    font.family: holdCardLabelText.font.family
                    font.weight: holdCardLabelText.font.weight
                }
            }
        }

        MouseArea {
            id: cardMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: holdCard.buttonEnabled
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

            onPressed: {
                if (!holdCard.triggered) {
                    cardDrain.stop();
                    cardFill.start();
                }
            }
            onReleased: {
                if (!holdCard.triggered && holdCard.fillLevel < 1.0) {
                    cardFill.stop();
                    cardDrain.start();
                }
            }
            onCanceled: {
                if (!holdCard.triggered) {
                    cardFill.stop();
                    cardDrain.start();
                }
            }
        }

        ToolTip.visible: cardMouse.containsMouse && tip !== ""
        ToolTip.delay: 250
        ToolTip.text: tip

        NumberAnimation {
            id: cardFill
            target: holdCard
            property: "fillLevel"
            to: 1.0
            duration: holdCard.holdDuration * (1.0 - holdCard.fillLevel)
            easing.type: Easing.InSine
            onFinished: {
                holdCard.triggered = true;
                holdCard.flashOpacity = 0.55;
                cardFlash.start();
                holdCard.activated();
                cardReset.start();
            }
        }

        NumberAnimation {
            id: cardDrain
            target: holdCard
            property: "fillLevel"
            to: 0.0
            duration: 1000 * holdCard.fillLevel
            easing.type: Easing.OutQuad
        }

        NumberAnimation {
            id: cardFlash
            target: holdCard
            property: "flashOpacity"
            to: 0.0
            duration: 420
            easing.type: Easing.OutExpo
        }

        NumberAnimation {
            id: cardReset
            target: holdCard
            property: "fillLevel"
            to: 0.0
            duration: 280
            easing.type: Easing.OutExpo
            onFinished: holdCard.triggered = false
        }
    }

    component NotificationActionChip: Button {
        id: chip
        flat: true
        leftPadding: 10
        rightPadding: 10
        topPadding: 6
        bottomPadding: 6
        implicitHeight: contentItem.implicitHeight + topPadding + bottomPadding
        implicitWidth: Math.max(80, contentItem.implicitWidth + leftPadding + rightPadding)

        background: Rectangle {
            radius: 8
            color: chip.hovered ? ThemePkg.Theme.withAlpha(root.accent, 0.16) : "#0dffffff"
            border.color: chip.hovered
                ? ThemePkg.Theme.withAlpha(root.accent, 0.72)
                : "#1affffff"
            border.width: 1

            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on border.color { ColorAnimation { duration: 120 } }
        }

        contentItem: Text {
            text: chip.text
            color: root.accent
            font.pixelSize: 12
            font.family: "Fira Sans Semibold"
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            maximumLineCount: 1
        }
    }

    readonly property int maxPopupHeight: Math.floor(
        win.screen && win.screen.geometry
            ? win.screen.geometry.height * 0.5
            : 540
    )


    function _fileExists(urlOrPath) {
        var url = urlOrPath.startsWith("file:") ? urlOrPath : "file://" + urlOrPath
        try {
            var xhr = new XMLHttpRequest();
            xhr.open("GET", url, false);
            xhr.send();
            return xhr.responseText !== null && xhr.responseText.length > 0;
        } catch (e) {
            return false;
        }
    }

    function _guessIconFileFromName(name) {
        const home = Labs.StandardPaths.writableLocation(Labs.StandardPaths.HomeLocation)
        const bases = [
            "/usr/share/icons/hicolor/256x256/apps/",
            "/usr/share/icons/hicolor/128x128/apps/",
            "/usr/share/icons/hicolor/64x64/apps/",
            "/usr/share/icons/hicolor/48x48/apps/",
            "/usr/share/icons/hicolor/32x32/apps/",
            "/usr/share/icons/hicolor/24x24/apps/",
            "/usr/share/icons/hicolor/16x16/apps/",
            "/usr/share/icons/hicolor/scalable/apps/",
            "/usr/share/pixmaps/",
            "/var/lib/flatpak/exports/share/icons/hicolor/256x256/apps/",
            "/var/lib/flatpak/exports/share/icons/hicolor/128x128/apps/",
            "/var/lib/flatpak/exports/share/icons/hicolor/64x64/apps/",
            "/var/lib/flatpak/exports/share/icons/hicolor/48x48/apps/",
            "/var/lib/flatpak/exports/share/icons/hicolor/32x32/apps/",
            "/var/lib/flatpak/exports/share/icons/hicolor/24x24/apps/",
            "/var/lib/flatpak/exports/share/icons/hicolor/16x16/apps/",
            "/var/lib/flatpak/exports/share/icons/hicolor/scalable/apps/",
            home + "/.local/share/flatpak/exports/share/icons/hicolor/256x256/apps/",
            home + "/.local/share/flatpak/exports/share/icons/hicolor/128x128/apps/",
            home + "/.local/share/flatpak/exports/share/icons/hicolor/64x64/apps/",
            home + "/.local/share/flatpak/exports/share/icons/hicolor/48x48/apps/",
            home + "/.local/share/flatpak/exports/share/icons/hicolor/32x32/apps/",
            home + "/.local/share/flatpak/exports/share/icons/hicolor/24x24/apps/",
            home + "/.local/share/flatpak/exports/share/icons/hicolor/16x16/apps/",
            home + "/.local/share/flatpak/exports/share/icons/hicolor/scalable/apps/"
        ];
        const exts = [".png", ".svg", ".xpm"];
        for (let b of bases) {
            for (let e of exts) {
                let p = b + name + e;
                if (_fileExists(p)) return "file://" + p;
            }
        }
        return "";
    }

    function _cacheResolvedIcon(cacheKey, resolved) {
        const key = String(cacheKey || "");
        if (key === "")
            return resolved;

        if (root.iconLookupCache[key] === undefined) {
            if (root.iconLookupCacheSize >= 256) {
                root.iconLookupCache = ({});
                root.iconLookupCacheSize = 0;
            }
            root.iconLookupCacheSize += 1;
        }

        root.iconLookupCache[key] = resolved;
        return resolved;
    }

    function _iconHintFor(n) {
        if (!n)
            return "";

        let h = n.hints || {};
        return h["image-path"] || h["app_icon"] || h["image"] ||
               n.image || n.appIcon || h["icon-name"] ||
               n.appIconName || n.iconName ||
               h["desktop-entry"] || n.desktopEntry || n.desktopId ||
               "";
    }

    function _iconCacheKeyFor(n) {
        if (!n)
            return "";

        const iconHint = String(root._iconHintFor(n) || "");
        if (iconHint.length > 0)
            return "hint:" + iconHint;

        const appName = n.appName ? String(n.appName).replace(/\s+/g, "-").toLowerCase() : "";
        return appName.length > 0 ? "app:" + appName : "";
    }

    function _iconSourceFor(n) {
        if (!n) return "";
        const cacheKey = root._iconCacheKeyFor(n);
        if (cacheKey !== "" && root.iconLookupCache[cacheKey] !== undefined)
            return root.iconLookupCache[cacheKey];

        let iconHint = String(root._iconHintFor(n) || "");
        let appName = n.appName || "";
        var iconSrc = "";
        if (iconHint.length > 0) {
            if (iconHint.startsWith("file:") || iconHint.startsWith("/") || iconHint.startsWith("image://") || iconHint.startsWith("http"))
                iconSrc = iconHint.startsWith("/") ? "file://" + iconHint : iconHint;
            else {
                var g = _guessIconFileFromName(iconHint);
                iconSrc = g || ("image://icon/" + iconHint);
            }
        } else if (appName && String(appName).length > 0) {
            var base = String(appName).replace(/\s+/g, "-").toLowerCase();
            if (base !== "notify-send") {
                iconSrc = _guessIconFileFromName(base);
            }
        }
        return root._cacheResolvedIcon(cacheKey, iconSrc);
    }

    PanelWindow {
        id: win
        visible: root.popupMounted
        focusable: root.popupMounted
        color: "transparent"
        anchors { top: true; bottom: true; left: true; right: true }

        Component.onCompleted: {
            try {
                if (win.WlrLayershell) {
                    win.WlrLayershell.layer = WlrLayer.Overlay;
                    win.WlrLayershell.keyboardFocus = WlrKeyboardFocus.OnDemand;
                }
            } catch(e) {}
        }

        Shortcut {
            sequence: "Escape"
            context: Qt.ApplicationShortcut
            enabled: root.popupTargetVisible
            onActivated: root._hideNotificationPopup()
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root._hideNotificationPopup()
        }

        Item {
            anchors.fill: parent

            Item {
                id: cardShell
                width: root.popupCardWidth
                height: root.popupCardHeight
                anchors.top: parent.top
                anchors.right: parent.right
                
                MouseArea {
                    anchors.fill: parent
                    onClicked: {} 
                }
                anchors.topMargin: topMarginPx
                anchors.rightMargin: 16
                opacity: root.popupCardOpacity
                transform: [
                    Scale {
                        origin.x: cardShell.width / 2
                        origin.y: cardShell.height / 2
                        xScale: root.popupCardScaleX
                        yScale: root.popupCardScaleY
                    },
                    Translate { y: root.popupCardLift }
                ]

                Rectangle {
                    id: card
                    focus: true
                    anchors.fill: parent
                    radius: root.popupCardRadius
                    color: root.base
                    border.color: root.moduleBorderColor
                    border.width: 1
                    clip: true

                    BarWidgets.ElectricBorder {
                        anchors.fill: parent
                        radius: parent.radius
                        borderWidth: parent.border.width
                        accentColor: root.moduleFontColor
                    }

                    property real globalOrbitAngle: 0
                    NumberAnimation on globalOrbitAngle {
                        from: 0; to: Math.PI * 2; duration: 90000; loops: Animation.Infinite; running: root.popupMounted
                    }

                    Rectangle {
                        width: parent.width * 0.8; height: width; radius: width / 2
                        x: (parent.width * 0.5 - width / 2) + Math.cos(card.globalOrbitAngle * 1.5) * 80
                        y: (parent.height * 0.1 - height / 2) + Math.sin(card.globalOrbitAngle * 1.5) * 100
                        opacity: 0.04; color: root.accent; z: 0
                    }
                    Rectangle {
                        width: parent.width * 0.6; height: width; radius: width / 2
                        x: (parent.width * 0.2 - width / 2) + Math.sin(card.globalOrbitAngle * 1.2) * -60
                        y: (parent.height * 0.8 - height / 2) + Math.cos(card.globalOrbitAngle * 1.2) * -80
                        opacity: 0.03; color: ThemePkg.Theme.c5; z: 0
                    }

                    Text {
                        id: parallaxIcon
                        anchors.centerIn: parent
                        property real drift: 0
                        SequentialAnimation on drift {
                            loops: Animation.Infinite; running: root.popupMounted
                            NumberAnimation { to: -15; duration: 6000; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 0; duration: 6000; easing.type: Easing.InOutSine }
                        }
                        transform: Translate { y: parallaxIcon.drift }
                        text: "󰂚"
                        font.family: "Iosevka Nerd Font"
                        font.pixelSize: 320
                        color: root.accent
                        opacity: 0.03 + (0.01 * Math.sin(card.globalOrbitAngle * 4))
                        z: 0
                    }

                    ColumnLayout {
                        id: content
                        anchors.fill: parent
                        z: 1
                        anchors.margins: 25
                        spacing: 12

                RowLayout {
                    id: headerRow
                    Layout.fillWidth: true
                    height: 58
                    spacing: 14

                    HoldOrbButton {
                        Layout.alignment: Qt.AlignVCenter
                        active: root.doNotDisturb
                        activeIcon: "󰂛"
                        inactiveIcon: "󰂚"
                        tip: root.doNotDisturb ? "Hold to disable Do Not Disturb" : "Hold to enable Do Not Disturb"
                        onActivated: {
                            DndMod.DndState.dnd = !DndMod.DndState.dnd
                        }
                    }

                    HoldOrbButton {
                        Layout.alignment: Qt.AlignVCenter
                        active: root.soundEnabled
                        buttonEnabled: !root.doNotDisturb
                        activeIcon: "󰕾"
                        inactiveIcon: "󰖁"
                        tip: root.doNotDisturb
                             ? "Notification sound is disabled while Do Not Disturb is active"
                             : (root.soundEnabled ? "Hold to mute notification sound" : "Hold to enable notification sound")
                        onActivated: {
                            DndMod.DndState.soundEnabled = !DndMod.DndState.soundEnabled
                        }
                    }

                    Item { Layout.fillWidth: true }

                    HoldCardButton {
                        id: clearAllBtn
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        visible: DndMod.DndState.notificationCount > 0
                        Layout.preferredHeight: height
                        Layout.preferredWidth: width
                        valueText: "Clear all"
                        labelText: ""
                        valueFontFamily: "Fira Sans"
                        labelFontFamily: "Fira Sans"

                        onActivated: {
                            root.dismissAllNotifications();
                        }
                    }
                }

                ListView {
                    id: notificationList
                    Layout.fillWidth: true
                    Layout.preferredHeight: {
                        const rowH = headerRow ? Math.max(headerRow.height, headerRow.implicitHeight) : 30
                        let header = rowH + content.spacing
                        const contentMax = Math.max(120, root.maxPopupHeight - 50)
                        const listMax = Math.max(80, contentMax - header)
                        return Math.min(notificationList.contentHeight, listMax)
                    }

                    spacing: 6
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    interactive: contentHeight > height

                    ThemePkg.FastScrollHandler {
                        anchors.fill: parent
                        flickable: notificationList
                    }

                    property int _vbarWidth: (vbar.visible ? Math.max(8, vbar.implicitWidth) + 4 : 0)
                    rightMargin: _vbarWidth

                    ScrollBar.vertical: ScrollBar {
                        id: vbar
                        policy: notificationList.contentHeight > notificationList.height
                                ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded
                        hoverEnabled: true
                        implicitWidth: 10
                        minimumSize: 0.08
                        active: hovered || pressed || notificationList.moving

                        background: Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: root.moduleBorderColor
                            border.color: root.moduleBorderColor
                            opacity: vbar.active ? 1.0 : 0.7
                        }
                        contentItem: Rectangle {
                            radius: width / 2
                            border.width: 1
                            border.color: root.moduleBorderColor
                            color: root.moduleFontColor
                        }
                    }

                    model: root.groupedNotifications

                    delegate: Item {
                        id: groupDelegate
                        width: notificationList.width - notificationList._vbarWidth
                        height: groupExiting ? 0 : delegateBaseHeight
                        implicitHeight: height
                        opacity: groupExiting ? 0.0 : 1.0
                        x: groupExiting ? 18 : 0
                        scale: groupExiting ? 0.92 : 1.0
                        clip: true
                        transformOrigin: Item.Top
                        property var groupData: modelData || ({})
                        property bool groupExpanded: !!groupData.expanded
                        property int groupCount: groupData.count || 0
                        property int stackDepth: (!groupExpanded && groupCount > 1) ? Math.min(2, groupCount - 1) : 0
                        property bool delegateHover: false
                        property string iconSource: groupData.latestIconSource || groupData.iconSource || ""
                        property var primaryNotification: groupData.latestNotification || null
                        property var primaryActions: groupData.latestActions || []
                        readonly property real delegateBaseHeight: mainCard.implicitHeight + stackDepth * 6
                        readonly property bool groupExiting: root._isGroupPending(groupData)
                        readonly property bool latestBodyLong: root._bodyIsLong(groupData.latestBody || "")
                        readonly property bool latestBodyExpanded: root._bodyExpanded(primaryNotification, groupData.latestSummary || "", groupData.latestBody || "")

                        Behavior on height {
                            NumberAnimation { duration: root.dismissAnimationDuration; easing.type: Easing.InCubic }
                        }
                        Behavior on opacity {
                            NumberAnimation { duration: Math.max(140, root.dismissAnimationDuration - 20); easing.type: Easing.InCubic }
                        }
                        Behavior on x {
                            NumberAnimation { duration: root.dismissAnimationDuration; easing.type: Easing.InOutQuad }
                        }
                        Behavior on scale {
                            NumberAnimation { duration: root.dismissAnimationDuration; easing.type: Easing.InCubic }
                        }

                        Repeater {
                            model: stackDepth
                            delegate: Rectangle {
                                x: (index + 1) * 5
                                y: (index + 1) * 6
                                width: parent.width - ((index + 1) * 10)
                                height: mainCard.implicitHeight
                                radius: 14
                                color: index === 0 ? "#07ffffff" : "#05ffffff"
                                border.color: "#14ffffff"
                                border.width: 1
                                z: -1 - index
                            }
                        }

                        Rectangle {
                            id: mainCard
                            width: parent.width
                            radius: 14
                            color: delegateHover ? "#0affffff" : "#05ffffff"
                            border.color: delegateHover ? root.accent : "#1affffff"
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: 150 } }
                            implicitHeight: groupColumn.implicitHeight + 20

                                Column {
                                    id: groupColumn
                                    z: 2
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 8

                                Row {
                                    id: groupHeaderRow
                                    spacing: 8
                                    anchors.left: parent.left
                                    anchors.right: parent.right

                                    Image {
                                        id: appIcon
                                        width: 22
                                        height: 22
                                        source: iconSource
                                        fillMode: Image.PreserveAspectFit
                                        asynchronous: true
                                        smooth: true
                                        cache: true
                                        visible: source != "" && status === Image.Ready
                                        property bool iconRetried: false
                                        onStatusChanged: {
                                            if (status === Image.Error) {
                                                if (!iconRetried) {
                                                    iconRetried = true;
                                                    if (source.toString().startsWith("image://icon/")) {
                                                        source = source.toString().replace("image://icon/", "image://theme/");
                                                        return;
                                                    } else if (source.toString().startsWith("image://theme/")) {
                                                        source = source.toString().replace("image://theme/", "image://icon/");
                                                        return;
                                                    }
                                                }
                                                source = "";
                                            }
                                        }
                                    }

                                    Column {
                                        width: parent.width - appIcon.width - 12
                                        spacing: 2

                                        Row {
                                            width: parent.width
                                            spacing: 4

                                            Text {
                                                text: groupData.sourceLabel || "Notification"
                                                color: root.text
                                                font.pixelSize: 13
                                                font.family: "Fira Sans Semibold"
                                                wrapMode: Text.NoWrap
                                                elide: Text.ElideRight
                                                width: Math.min(implicitWidth, parent.width - (groupCount > 1 ? 32 : 0))
                                            }

                                            Rectangle {
                                                visible: groupCount > 1
                                                width: 24
                                                height: 18
                                                radius: 8
                                                color: "#12ffffff"
                                                border.color: "#1affffff"
                                                border.width: 1

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: String(groupCount)
                                                    color: root.accent
                                                    font.pixelSize: 11
                                                    font.family: "JetBrains Mono"
                                                    font.weight: Font.Black
                                                }
                                            }
                                        }

                                        Text {
                                            text: groupCount > 1
                                                ? (groupExpanded ? "Click to collapse" : (groupCount + " notifications"))
                                                : (groupData.latestSummary || "Notification")
                                            color: ThemePkg.Theme.withAlpha(root.text, 0.8)
                                            font.pixelSize: 11
                                            textFormat: Text.PlainText
                                            wrapMode: Text.NoWrap
                                            elide: Text.ElideRight
                                            width: parent.width
                                        }
                                    }
                                }

                                Column {
                                    width: parent.width
                                    spacing: 8
                                    visible: !groupExpanded

                                    Text {
                                        visible: groupCount > 1
                                        width: parent.width
                                        text: groupData.latestSummary || "Notification"
                                        color: root.text
                                        font.pixelSize: 14
                                        font.bold: true
                                        textFormat: Text.PlainText
                                        wrapMode: Text.NoWrap
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        width: parent.width
                                        visible: (groupData.latestBody || "").length > 0
                                        text: groupData.latestBody || ""
                                        color: ThemePkg.Theme.withAlpha(root.text, 0.85)
                                        font.pixelSize: 12
                                        textFormat: Text.PlainText
                                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                        elide: groupDelegate.latestBodyExpanded ? Text.ElideNone : Text.ElideRight
                                        maximumLineCount: groupDelegate.latestBodyExpanded ? 999 : 3
                                    }

                                    Flow {
                                        width: parent.width
                                        spacing: 8
                                        visible: primaryActions.length > 0
                                        height: visible ? implicitHeight : 0

                                        Repeater {
                                            model: primaryActions
                                            delegate: NotificationActionChip {
                                                visible: root._actionText(modelData).length > 0
                                                text: root._actionText(modelData)
                                                onClicked: root.invokeNotificationAction(modelData, primaryNotification)
                                            }
                                        }
                                    }
                                }

                                Column {
                                    width: parent.width
                                    spacing: 8
                                    visible: groupExpanded

                                    Repeater {
                                        model: groupData.notifications || []
                                        delegate: Rectangle {
                                            id: childCard
                                            width: parent.width
                                            height: childExiting ? 0 : childBaseHeight
                                            implicitHeight: height
                                            radius: 12
                                            color: childHover ? "#0affffff" : "#09000000"
                                            border.color: childHover ? root.accent : "#18ffffff"
                                            border.width: 1
                                            opacity: childExiting ? 0.0 : 1.0
                                            x: childExiting ? 14 : 0
                                            scale: childExiting ? 0.95 : 1.0
                                            clip: true
                                            transformOrigin: Item.Top

                                            property var notifEntry: modelData || ({})
                                            property var notifObject: notifEntry.notification
                                            property bool childHover: childMouse.containsMouse
                                            readonly property real childBaseHeight: childContent.implicitHeight + 18
                                            readonly property bool childExiting: root._isNotificationPending(notifObject) || groupDelegate.groupExiting
                                            readonly property bool childBodyLong: root._bodyIsLong(notifEntry.body || "")
                                            readonly property bool childBodyExpanded: root._bodyExpanded(notifObject, notifEntry.summary || "", notifEntry.body || "")

                                            Behavior on color { ColorAnimation { duration: 150 } }
                                            Behavior on border.color { ColorAnimation { duration: 150 } }
                                            Behavior on height {
                                                NumberAnimation { duration: root.dismissAnimationDuration; easing.type: Easing.InCubic }
                                            }
                                            Behavior on opacity {
                                                NumberAnimation { duration: Math.max(140, root.dismissAnimationDuration - 20); easing.type: Easing.InCubic }
                                            }
                                            Behavior on x {
                                                NumberAnimation { duration: root.dismissAnimationDuration; easing.type: Easing.InOutQuad }
                                            }
                                            Behavior on scale {
                                                NumberAnimation { duration: root.dismissAnimationDuration; easing.type: Easing.InCubic }
                                            }

                                            MouseArea {
                                                id: childMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                enabled: !childCard.childExiting
                                                cursorShape: Qt.PointingHandCursor
                                                z: 1
                                                onClicked: {
                                                    if (root.toggleBodyExpanded(notifObject, notifEntry.summary || "", notifEntry.body || ""))
                                                        return;
                                                    root.invokePrimaryNotification(notifObject);
                                                    root.focusApp(notifObject.appName);
                                                }
                                            }

                                            Column {
                                                id: childContent
                                                z: 2
                                                anchors.fill: parent
                                                anchors.margins: 9
                                                spacing: 6

                                                Text {
                                                    width: parent.width - 24
                                                    text: notifEntry.summary || "Notification"
                                                    color: root.text
                                                    font.pixelSize: 13
                                                    font.bold: true
                                                    textFormat: Text.PlainText
                                                    wrapMode: Text.NoWrap
                                                    elide: Text.ElideRight
                                                }

                                                Text {
                                                    width: parent.width
                                                    visible: (notifEntry.body || "").length > 0
                                                    text: notifEntry.body || ""
                                                    color: ThemePkg.Theme.withAlpha(root.text, 0.85)
                                                    font.pixelSize: 12
                                                    textFormat: Text.PlainText
                                                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                                    maximumLineCount: childCard.childBodyExpanded ? 999 : 3
                                                    elide: childCard.childBodyExpanded ? Text.ElideNone : Text.ElideRight
                                                }

                                                Flow {
                                                    width: parent.width
                                                    spacing: 8
                                                    visible: notifEntry.actions && notifEntry.actions.length > 0
                                                    height: visible ? implicitHeight : 0

                                                    Repeater {
                                                        model: notifEntry.actions || []
                                                        delegate: NotificationActionChip {
                                                            visible: root._actionText(modelData).length > 0
                                                            text: root._actionText(modelData)
                                                            onClicked: root.invokeNotificationAction(modelData, notifObject)
                                                        }
                                                    }
                                                }
                                            }

                                            MouseArea {
                                                id: childCloseBtn
                                                anchors.right: parent.right
                                                anchors.top: parent.top
                                                anchors.margins: 8
                                                width: 20
                                                height: 20
                                                hoverEnabled: true
                                                enabled: !childCard.childExiting
                                                cursorShape: Qt.PointingHandCursor
                                                z: 3
                                                onClicked: root.dismissNotification(notifObject)

                                                Rectangle {
                                                    anchors.fill: parent
                                                    radius: width / 2
                                                    color: parent.pressed ? ThemePkg.Theme.withAlpha(root.accent, 0.3) : "transparent"
                                                    border.width: 1
                                                    border.color: parent.containsMouse
                                                        ? ThemePkg.Theme.withAlpha(root.accent, 0.6)
                                                        : ThemePkg.Theme.withAlpha(root.text, 0.14)

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "✕"
                                                        color: parent.parent.containsMouse ? root.accent : ThemePkg.Theme.withAlpha(root.text, 0.5)
                                                        font.pixelSize: 10
                                                        font.bold: true
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: !groupExpanded && !groupDelegate.groupExiting
                                cursorShape: Qt.PointingHandCursor
                                z: 1
                                onEntered: parent.parent.delegateHover = true
                                onExited: parent.parent.delegateHover = false
                                onClicked: {
                                    if (groupCount > 1) {
                                        root.toggleGroupExpanded(groupData.groupKey);
                                    } else if (groupData.notifications && groupData.notifications.length > 0) {
                                        let notif = primaryNotification;
                                        if (root.toggleBodyExpanded(notif, groupData.latestSummary || "", groupData.latestBody || ""))
                                            return;
                                        root.invokePrimaryNotification(notif);
                                        root.focusApp(notif.appName);
                                    }
                                }
                            }

                            MouseArea {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                height: groupHeaderRow.height + 6
                                hoverEnabled: true
                                enabled: groupExpanded && groupCount > 1 && !groupDelegate.groupExiting
                                cursorShape: Qt.PointingHandCursor
                                z: 1
                                onEntered: parent.parent.delegateHover = true
                                onExited: parent.parent.delegateHover = false
                                onClicked: root.toggleGroupExpanded(groupData.groupKey)
                            }

                            MouseArea {
                                id: groupCloseBtn
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 8
                                width: 20
                                height: 20
                                hoverEnabled: true
                                enabled: !groupDelegate.groupExiting
                                cursorShape: Qt.PointingHandCursor
                                z: 3
                                onClicked: root.dismissGroup(groupData)

                                Rectangle {
                                    anchors.fill: parent
                                    radius: width / 2
                                    color: parent.pressed ? ThemePkg.Theme.withAlpha(root.accent, 0.3) : "transparent"
                                    border.width: 1
                                    border.color: parent.containsMouse
                                        ? ThemePkg.Theme.withAlpha(root.accent, 0.6)
                                        : ThemePkg.Theme.withAlpha(root.text, 0.14)

                                    Text {
                                        anchors.centerIn: parent
                                        text: "✕"
                                        color: parent.parent.containsMouse ? root.accent : ThemePkg.Theme.withAlpha(root.text, 0.5)
                                        font.pixelSize: 10
                                        font.bold: true
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        visible: notificationList.count === 0

                        Text {
                            anchors.centerIn: parent
                            text: root.doNotDisturb ? "Do Not Disturb enabled" : "No notifications"
                            color: ThemePkg.Theme.withAlpha(root.text, 0.6)
                            font.pixelSize: 12
                            font.family: "Fira Sans"
                        }
                    }
                }
                    }
                }
            }
        }
    }

    SequentialAnimation {
        id: popupEnterAnim
        running: false

        onStopped: {
            root.schedulePopupLayoutRefresh();
            if (!root.popupTargetVisible && root.popupCardOpacity <= 0.001)
                root.popupMounted = false;
        }

        ParallelAnimation {
            NumberAnimation { target: root; property: "popupCardOpacity"; to: 0.78; duration: 145; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "popupCardScaleX"; to: 0.985; duration: 175; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "popupCardScaleY"; to: 0.94; duration: 190; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "popupCardWidth"; to: Math.max(root.minCardWidth, Math.min(root.maxCardWidth, content.implicitWidth + 32)); duration: 190; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "popupCardHeight"; to: Math.min(root.maxCardHeight, content.implicitHeight + 32); duration: 200; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "popupCardRadius"; to: 28; duration: 190; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "popupCardLift"; to: 8; duration: 190; easing.type: Easing.OutCubic }
        }

        ParallelAnimation {
            NumberAnimation { target: root; property: "popupCardOpacity"; to: 1.0; duration: 175; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "popupCardScaleX"; to: 1.0; duration: 205; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "popupCardScaleY"; to: 1.0; duration: 205; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "popupCardWidth"; to: Math.max(root.minCardWidth, Math.min(root.maxCardWidth, content.implicitWidth + 50)); duration: 205; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "popupCardHeight"; to: Math.min(root.maxCardHeight, content.implicitHeight + 50); duration: 215; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "popupCardRadius"; to: root.popupOpenRadius; duration: 195; easing.type: Easing.InOutQuad }
            NumberAnimation { target: root; property: "popupCardLift"; to: 0; duration: 205; easing.type: Easing.OutCubic }
        }
    }

    SequentialAnimation {
        id: popupExitAnim
        running: false

        onStopped: {
            if (!root.popupTargetVisible && root.popupCardOpacity <= 0.001)
                root.popupMounted = false;
        }

        ParallelAnimation {
            NumberAnimation { target: root; property: "popupCardScaleX"; to: 1.04; duration: 85; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "popupCardScaleY"; to: 0.95; duration: 85; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "popupCardWidth"; to: Math.max(root.minCardWidth - 10, Math.min(root.maxCardWidth + 14, content.implicitWidth + 64)); duration: 95; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "popupCardHeight"; to: Math.min(root.maxCardHeight, content.implicitHeight + 34); duration: 95; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "popupCardRadius"; to: 28; duration: 95; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "popupCardLift"; to: 5; duration: 95; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "popupCardOpacity"; to: 0.88; duration: 80; easing.type: Easing.OutQuad }
        }

        ParallelAnimation {
            NumberAnimation { target: root; property: "popupCardOpacity"; to: 0.0; duration: 180; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "popupCardScaleX"; to: 0.84; duration: 205; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "popupCardScaleY"; to: 0.68; duration: 220; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "popupCardWidth"; to: Math.max(root.minCardWidth - 44, Math.min(root.maxCardWidth - 20, content.implicitWidth + 6)); duration: 200; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "popupCardHeight"; to: Math.max(160, Math.min(root.maxCardHeight - 28, content.implicitHeight + 22)); duration: 210; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "popupCardRadius"; to: root.popupClosedRadius; duration: 200; easing.type: Easing.InQuad }
            NumberAnimation { target: root; property: "popupCardLift"; to: 24; duration: 200; easing.type: Easing.InCubic }
        }
    }
}
