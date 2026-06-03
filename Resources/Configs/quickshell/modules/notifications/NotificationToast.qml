import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import Quickshell.Widgets
import Quickshell.Hyprland
import Quickshell.Io
import Qt.labs.platform 1.1 as Labs
import "../theme" as ThemePkg
import "../bar/widgets/dnd" as DndMod
import "../bar/widgets" as BarWidgets

Scope {
    id: root

    readonly property color base: ThemePkg.Theme.surface(0.10)
    readonly property color text: ThemePkg.Theme.foreground
    readonly property color textMuted: ThemePkg.Theme.withAlpha(ThemePkg.Theme.foreground, 0.85)
    readonly property color accent: ThemePkg.Theme.accent
    readonly property color moduleBorderColor: ThemePkg.Theme.mix(ThemePkg.Theme.background, ThemePkg.Theme.foreground, 0.35)
    readonly property color cardBg: ThemePkg.Theme.surface(0.08)

    property int toastDuration: 5000
    property int maxToasts: 3
    property int toastWidth: 380

    readonly property bool doNotDisturb: DndMod.DndState.dnd

    ListModel {
        id: toastModel
    }

    property var iconLookupCache: ({})
    property int iconLookupCacheSize: 0
    property var toastPayloads: ({})
    property var expandedToastBodies: ({})

    function _fileExists(urlOrPath) {
        var url = urlOrPath.startsWith("file:") ? urlOrPath : "file://" + urlOrPath
        try {
            var xhr = new XMLHttpRequest();
            xhr.open("GET", url, false);
            xhr.send();
            return xhr.responseText !== null && xhr.responseText.length > 0;
        } catch (e) { return false; }
    }

    function _guessIconFileFromName(name) {
        const home = Labs.StandardPaths.writableLocation(Labs.StandardPaths.HomeLocation)
        const bases = [
            "/usr/share/icons/hicolor/48x48/apps/",
            "/usr/share/icons/hicolor/64x64/apps/",
            "/usr/share/icons/hicolor/128x128/apps/",
            "/usr/share/icons/hicolor/scalable/apps/",
            "/usr/share/pixmaps/",
            "/var/lib/flatpak/exports/share/icons/hicolor/48x48/apps/",
            "/var/lib/flatpak/exports/share/icons/hicolor/64x64/apps/",
            home + "/.local/share/flatpak/exports/share/icons/hicolor/48x48/apps/",
            home + "/.local/share/flatpak/exports/share/icons/hicolor/64x64/apps/"
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
            if (root.iconLookupCacheSize >= 128) {
                root.iconLookupCache = ({});
                root.iconLookupCacheSize = 0;
            }
            root.iconLookupCacheSize += 1;
        }

        root.iconLookupCache[key] = resolved;
        return resolved;
    }

    function _iconCacheKey(iconHint, appName) {
        const hint = String(iconHint || "");
        if (hint.length > 0)
            return "hint:" + hint;

        const base = String(appName || "").replace(/\s+/g, "-").toLowerCase();
        return base.length > 0 ? "app:" + base : "";
    }

    property int _lastNotifCount: 0
    property var _seenIds: ({})

    property var _pendingToasts: []

    Connections {
        target: ThemePkg.Theme
        function onNotify(summary, body, appName, iconHint, payload) {
            if (root.doNotDisturb) return;
            root._addToast(summary, body, appName, iconHint, payload);
        }
    }

    function _actionText(action) {
        if (!action)
            return "";
        return String(action.text || action.label || action.title || "").trim();
    }

    function _filteredActions(actions) {
        const raw = actions || [];
        const filtered = [];
        for (let i = 0; i < raw.length; ++i) {
            if (root._actionText(raw[i]).length > 0)
                filtered.push(raw[i]);
        }
        return filtered;
    }

    function _toastPayload(toastId) {
        return root.toastPayloads[String(toastId)] || ({});
    }

    function _toastActions(toastId) {
        const payload = root._toastPayload(toastId);
        if (payload.actions && payload.actions.length)
            return root._filteredActions(payload.actions);
        if (payload.notification && payload.notification.actions)
            return root._filteredActions(payload.notification.actions);
        return [];
    }

    function _removeToastById(toastId) {
        const key = String(toastId);
        const nextPayloads = Object.assign({}, root.toastPayloads);
        delete nextPayloads[key];
        root.toastPayloads = nextPayloads;

        for (let i = 0; i < toastModel.count; ++i) {
            if (toastModel.get(i).toastId === toastId) {
                toastModel.remove(i);
                break;
            }
        }
    }

    function _invokeToastAction(toastId, action) {
        if (!action || !action.invoke)
            return;
        try { action.invoke(); } catch (e) {}
        root._removeToastById(toastId);
    }

    function _toastBodyIsLong(body) {
        const text = String(body || "");
        return text.length > 180 || text.split("\n").length > 3;
    }

    function _toastBodyExpanded(toastId, body) {
        return root._toastBodyIsLong(body) && !!root.expandedToastBodies[String(toastId)];
    }

    function _toggleToastBodyExpanded(toastId, body) {
        if (!root._toastBodyIsLong(body))
            return false;
        const key = String(toastId);
        const next = Object.assign({}, root.expandedToastBodies);
        next[key] = !next[key];
        root.expandedToastBodies = next;
        return true;
    }

    function _isHyprdotsUpdateNotification(summary, appName) {
        return String(appName || "").toLowerCase() === "archtools"
            && String(summary || "").toLowerCase() === "hyprdots updates";
    }

    function _handleHyprdotsUpdateClick(summary, appName) {
        if (!root._isHyprdotsUpdateNotification(summary, appName))
            return false;
        ThemePkg.Theme.globalApplyHyprdotsUpdates();
        return true;
    }

    function _addToast(summary, body, appName, iconHint, payload) {
        while (toastModel.count >= maxToasts) {
            root._removeToastById(toastModel.get(0).toastId);
        }

        var iconSrc = "";
        const cacheKey = root._iconCacheKey(iconHint, appName);
        if (cacheKey !== "" && root.iconLookupCache[cacheKey] !== undefined) {
            iconSrc = root.iconLookupCache[cacheKey];
        } else if (iconHint && iconHint.length > 0) {
            if (iconHint.startsWith("file:") || iconHint.startsWith("/") || iconHint.startsWith("image://") || iconHint.startsWith("http"))
                iconSrc = iconHint.startsWith("/") ? "file://" + iconHint : iconHint;
            else {
                var g = _guessIconFileFromName(iconHint);
                iconSrc = g || ("image://icon/" + iconHint);
            }
        } else if (appName) {
            var base = appName.replace(/\s+/g, "-").toLowerCase();
            if (base !== "notify-send") {
                iconSrc = _guessIconFileFromName(base);
            }
        }
        iconSrc = root._cacheResolvedIcon(cacheKey, iconSrc);
        const toastId = Date.now() + Math.round(Math.random() * 1000);
        const nextPayloads = Object.assign({}, root.toastPayloads);
        nextPayloads[String(toastId)] = payload || ({});
        root.toastPayloads = nextPayloads;

        toastModel.append({
            "toastSummary": summary || "Notification",
            "toastBody": body || "",
            "toastApp": appName || "",
            "toastIcon": iconSrc,
            "toastId": toastId
        });
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

    LazyLoader {
        active: toastModel.count > 0

        PanelWindow {
            id: toastWin
            anchors.top: true
            anchors.right: true
            exclusiveZone: 0
            color: "transparent"
            mask: Region { item: toastColumn }
            margins { top: 0; right: 16 }
            width: root.toastWidth + 20
            height: toastColumn.implicitHeight + 20

            Column {
                id: toastColumn
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: 10
                anchors.rightMargin: 10
                width: root.toastWidth
                spacing: 8

                Repeater {
                    model: toastModel

                    delegate: Item {
                        id: toastCard
                        readonly property real toastTargetHeight: Math.ceil(toastContent.implicitHeight + 28)
                        readonly property real toastOpenWidth: root.toastWidth
                        readonly property real toastClosedWidth: 280
                        readonly property real toastClosedHeight: 30
                        readonly property real toastOpenRadius: 16
                        readonly property real toastClosedRadius: 10
                        property bool dismissing: false
                        property real popupOpacity: 0.0
                        property real popupScaleX: 0.42
                        property real popupScaleY: 0.24
                        property real popupWidth: toastClosedWidth
                        property real popupHeight: toastClosedHeight
                        property real popupRadius: toastClosedRadius
                        property real popupLift: 8.5
                        property bool toastReady: false
                        readonly property bool richAnimationsActive: !dismissing && popupOpacity > 0.98 && ThemePkg.Theme.edgeAnimationsEnabled
                        width: root.toastWidth
                        height: Math.ceil(Math.max(toastTargetHeight, popupHeight + Math.max(0, popupLift)))
                        implicitWidth: root.toastWidth
                        implicitHeight: height

                        readonly property real _thisId: model.toastId
                        readonly property var toastActions: root._toastActions(model.toastId)
                        readonly property bool toastBodyLong: root._toastBodyIsLong(model.toastBody)
                        readonly property bool toastBodyExpanded: root._toastBodyExpanded(model.toastId, model.toastBody)

                        Component.onCompleted: {
                            toastReady = true;
                            popupEnterAnim.start();
                            dismissTimer.start();
                        }

                        onToastTargetHeightChanged: {
                            if (toastReady && !dismissing && !popupEnterAnim.running && !popupExitAnim.running)
                                popupHeight = toastTargetHeight;
                        }

                        function dismissToast() {
                            if (dismissing)
                                return;
                            dismissing = true;
                            dismissTimer.stop();
                            popupEnterAnim.stop();
                            popupExitAnim.stop();
                            popupExitAnim.start();
                        }

                        SequentialAnimation {
                            id: popupEnterAnim
                            running: false

                            ParallelAnimation {
                                NumberAnimation { target: toastCard; property: "popupOpacity"; to: 0.82; duration: 210; easing.type: Easing.OutCubic }
                                NumberAnimation { target: toastCard; property: "popupScaleX"; to: 0.985; duration: 280; easing.type: Easing.OutCubic }
                                NumberAnimation { target: toastCard; property: "popupScaleY"; to: 0.94; duration: 300; easing.type: Easing.OutCubic }
                                NumberAnimation { target: toastCard; property: "popupWidth"; to: toastCard.toastOpenWidth - 18; duration: 285; easing.type: Easing.OutCubic }
                                NumberAnimation { target: toastCard; property: "popupHeight"; to: toastCard.toastTargetHeight - 18; duration: 300; easing.type: Easing.OutCubic }
                                NumberAnimation { target: toastCard; property: "popupRadius"; to: 28; duration: 270; easing.type: Easing.OutQuad }
                                NumberAnimation { target: toastCard; property: "popupLift"; to: 8; duration: 300; easing.type: Easing.OutCubic }
                            }

                            ParallelAnimation {
                                NumberAnimation { target: toastCard; property: "popupOpacity"; to: 1.0; duration: 175; easing.type: Easing.OutCubic }
                                NumberAnimation { target: toastCard; property: "popupScaleX"; to: 1.0; duration: 205; easing.type: Easing.OutCubic }
                                NumberAnimation { target: toastCard; property: "popupScaleY"; to: 1.0; duration: 205; easing.type: Easing.OutCubic }
                                NumberAnimation { target: toastCard; property: "popupWidth"; to: toastCard.toastOpenWidth; duration: 205; easing.type: Easing.OutCubic }
                                NumberAnimation { target: toastCard; property: "popupHeight"; to: toastCard.toastTargetHeight; duration: 215; easing.type: Easing.OutCubic }
                                NumberAnimation { target: toastCard; property: "popupRadius"; to: toastCard.toastOpenRadius; duration: 195; easing.type: Easing.InOutQuad }
                                NumberAnimation { target: toastCard; property: "popupLift"; to: 0; duration: 205; easing.type: Easing.OutCubic }
                            }

                            onFinished: {
                                if (!toastCard.dismissing)
                                    toastCard.popupHeight = toastCard.toastTargetHeight;
                            }
                        }

                        SequentialAnimation {
                            id: popupExitAnim
                            running: false

                            ParallelAnimation {
                                NumberAnimation { target: toastCard; property: "popupScaleX"; to: 1.04; duration: 85; easing.type: Easing.OutQuad }
                                NumberAnimation { target: toastCard; property: "popupScaleY"; to: 0.95; duration: 85; easing.type: Easing.OutQuad }
                                NumberAnimation { target: toastCard; property: "popupWidth"; to: toastCard.toastOpenWidth + 14; duration: 95; easing.type: Easing.OutQuad }
                                NumberAnimation { target: toastCard; property: "popupHeight"; to: toastCard.toastTargetHeight - 16; duration: 95; easing.type: Easing.OutQuad }
                                NumberAnimation { target: toastCard; property: "popupRadius"; to: 28; duration: 95; easing.type: Easing.OutQuad }
                                NumberAnimation { target: toastCard; property: "popupLift"; to: 5; duration: 95; easing.type: Easing.OutQuad }
                                NumberAnimation { target: toastCard; property: "popupOpacity"; to: 0.88; duration: 80; easing.type: Easing.OutQuad }
                            }

                            ParallelAnimation {
                                NumberAnimation { target: toastCard; property: "popupOpacity"; to: 0.0; duration: 180; easing.type: Easing.InCubic }
                                NumberAnimation { target: toastCard; property: "popupScaleX"; to: 0.42; duration: 260; easing.type: Easing.InCubic }
                                NumberAnimation { target: toastCard; property: "popupScaleY"; to: 0.24; duration: 280; easing.type: Easing.InCubic }
                                NumberAnimation { target: toastCard; property: "popupWidth"; to: toastCard.toastClosedWidth; duration: 200; easing.type: Easing.InCubic }
                                NumberAnimation { target: toastCard; property: "popupHeight"; to: toastCard.toastClosedHeight; duration: 210; easing.type: Easing.InCubic }
                                NumberAnimation { target: toastCard; property: "popupRadius"; to: toastCard.toastClosedRadius; duration: 200; easing.type: Easing.InQuad }
                                NumberAnimation { target: toastCard; property: "popupLift"; to: 8.5; duration: 280; easing.type: Easing.InCubic }
                            }

                            onFinished: root._removeToastById(toastCard._thisId)
                        }

                        Timer {
                            id: dismissTimer
                            interval: root.toastDuration
                            onTriggered: toastCard.dismissToast()
                        }

                        property real globalOrbitAngle: 0
                        NumberAnimation on globalOrbitAngle {
                            from: 0; to: Math.PI * 2; duration: 90000; loops: Animation.Infinite; running: toastCard.richAnimationsActive
                        }

                        Item {
                            id: toastShell
                            anchors.right: parent.right
                            anchors.top: parent.top
                            width: toastCard.popupWidth
                            height: toastCard.popupHeight
                            opacity: toastCard.popupOpacity
                            transform: [
                                Scale {
                                    origin.x: toastShell.width / 2
                                    origin.y: toastShell.height / 2
                                    xScale: toastCard.popupScaleX
                                    yScale: toastCard.popupScaleY
                                },
                                Translate { y: toastCard.popupLift }
                            ]

                            Rectangle {
                                id: toastSurface
                                anchors.fill: parent
                                radius: toastCard.popupRadius
                                color: bodyMouse.containsMouse ? Qt.lighter(root.base, 1.1) : root.base
                                border.color: bodyMouse.containsMouse ? root.accent : root.moduleBorderColor
                                border.width: 1
                                clip: true

                                BarWidgets.AnimatedBorder {
                                    anchors.fill: parent
                                    radius: parent.radius
                                    borderWidth: parent.border.width
                                    accentColor: root.accent
                                    active: toastCard.richAnimationsActive
                                }

                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on border.color { ColorAnimation { duration: 150 } }

                                Rectangle {
                                    width: parent.width * 0.8; height: width; radius: width / 2
                                    x: (parent.width * 0.5 - width / 2) + Math.cos(toastCard.globalOrbitAngle * 1.5) * 80
                                    y: (parent.height * 0.1 - height / 2) + Math.sin(toastCard.globalOrbitAngle * 1.5) * 100
                                    opacity: 0.04; color: root.accent; z: 0
                                    visible: toastCard.richAnimationsActive
                                }
                                Rectangle {
                                    width: parent.width * 0.6; height: width; radius: width / 2
                                    x: (parent.width * 0.2 - width / 2) + Math.sin(toastCard.globalOrbitAngle * 1.2) * -60
                                    y: (parent.height * 0.8 - height / 2) + Math.cos(toastCard.globalOrbitAngle * 1.2) * -80
                                    opacity: 0.03; color: ThemePkg.Theme.c5 ? ThemePkg.Theme.c5 : root.accent; z: 0
                                    visible: toastCard.richAnimationsActive
                                }

                                ColumnLayout {
                                    id: toastContent
                                    z: 2
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 10

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 10

                                        Image {
                                            id: toastIcon
                                            Layout.preferredWidth: 28
                                            Layout.preferredHeight: 28
                                            Layout.alignment: Qt.AlignTop
                                            source: model.toastIcon
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

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 3

                                            Text {
                                                Layout.fillWidth: true
                                                text: model.toastSummary
                                                color: root.text
                                                font.pixelSize: 13
                                                font.bold: true
                                                font.family: "Fira Sans Semibold"
                                                elide: Text.ElideRight
                                                maximumLineCount: 1
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                text: model.toastBody
                                                color: root.textMuted
                                                font.pixelSize: 12
                                                font.family: "Fira Sans"
                                                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                                elide: toastCard.toastBodyExpanded ? Text.ElideNone : Text.ElideRight
                                                maximumLineCount: toastCard.toastBodyExpanded ? 12 : 3
                                                visible: text.length > 0
                                            }
                                        }

                                        Item { Layout.fillWidth: true }
                                        Item { Layout.preferredWidth: 20 }
                                    }

                                    Flow {
                                        Layout.fillWidth: true
                                        spacing: 8
                                        visible: toastActions.length > 0
                                        height: visible ? implicitHeight : 0

                                        Repeater {
                                            model: toastActions
                                            delegate: NotificationActionChip {
                                                visible: root._actionText(modelData).length > 0
                                                text: root._actionText(modelData)
                                                onClicked: {
                                                    dismissTimer.stop();
                                                    root._invokeToastAction(toastCard._thisId, modelData);
                                                }
                                            }
                                        }
                                    }
                                }

                                MouseArea {
                                    id: closeBtn
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    width: 38
                                    height: 38
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    z: 10
                                    onClicked: toastCard.dismissToast()

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 22
                                        height: 22
                                        radius: 11
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
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                    }
                                }

                                MouseArea {
                                    id: bodyMouse
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    z: 1
                                    onClicked: {
                                        if (root._toggleToastBodyExpanded(model.toastId, model.toastBody)) {
                                            dismissTimer.stop();
                                            return;
                                        }
                                        if (root._handleHyprdotsUpdateClick(model.toastSummary, model.toastApp)) {
                                            toastCard.dismissToast();
                                            return;
                                        }
                                        const actions = root._toastActions(model.toastId);
                                        if (actions.length > 0) {
                                            root._invokeToastAction(model.toastId, actions[0]);
                                        } else {
                                            root.focusApp(model.toastApp);
                                        }
                                        toastCard.dismissToast();
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
