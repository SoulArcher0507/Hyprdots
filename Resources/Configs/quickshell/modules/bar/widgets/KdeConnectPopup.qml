import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import "../../theme" as ThemePkg
import "kdeconnect" as Kde

Item {
    id: root
    anchors.fill: parent
    focus: true

    readonly property int panelWidth: 680
    readonly property int panelHeight: 560
    readonly property int panelMargin: 16
    readonly property int contentMargin: 22
    readonly property real popupOpenWidth: root.panelWidth
    readonly property real popupOpenHeight: root.panelHeight
    readonly property real popupClosedWidth: 280
    readonly property real popupClosedHeight: 30
    readonly property real popupOpenRadius: 20
    readonly property real popupClosedRadius: 10
    readonly property real barPanelHeight: 47
    readonly property real barPanelCenterY: barPanelHeight / 2
    readonly property int overlayEnterDuration: 515
    readonly property int overlayExitDuration: 375
    readonly property bool overlayOwnsCloseAnimation: true

    readonly property color base: ThemePkg.Theme.surface(0.10)
    readonly property color crust: ThemePkg.Theme.background
    readonly property color text: ThemePkg.Theme.foreground
    readonly property color subtext0: ThemePkg.Theme.mix(ThemePkg.Theme.background, ThemePkg.Theme.foreground, 0.6)
    readonly property color overlay0: ThemePkg.Theme.mix(ThemePkg.Theme.background, ThemePkg.Theme.foreground, 0.3)
    readonly property color surface0: ThemePkg.Theme.surface(0.06)
    readonly property color surface1: ThemePkg.Theme.surface(0.08)
    readonly property color surface2: ThemePkg.Theme.surface(0.12)
    readonly property color accent: Qt.lighter(ThemePkg.Theme.c6, 1.12)
    readonly property color green: ThemePkg.Theme.success
    readonly property color red: ThemePkg.Theme.danger
    readonly property color yellow: ThemePkg.Theme.warning
    readonly property color panelBorderColor: ThemePkg.Theme.mix(ThemePkg.Theme.background, ThemePkg.Theme.foreground, 0.35)
    readonly property string textFont: "Fira Sans"
    readonly property string scriptsDir: Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/kdeconnect"
    readonly property string repoScriptsDir: Quickshell.env("HOME") + "/.config/hyprdots/Resources/Configs/hypr/scripts/quickshell/kdeconnect"
    readonly property string bundledScriptsDir: String(Qt.resolvedUrl("../../../../hypr/scripts/quickshell/kdeconnect")).replace("file://", "")

    property var overlaySwitcher: null
    property var selectedDevice: Kde.KDEConnect.mainDevice
    property bool popupTargetVisible: false
    property real popupCardOpacity: 0.0
    property real popupCardScaleX: 0.42
    property real popupCardScaleY: 0.24
    property real popupCardWidth: popupClosedWidth
    property real popupCardHeight: popupClosedHeight
    property real popupCardRadius: popupClosedRadius
    property real popupCardLift: popupOriginLift()
    property real hostLoaderOpacity: (parent && parent.opacity !== undefined) ? parent.opacity : 1.0
    property real lastHostLoaderOpacity: hostLoaderOpacity
    property real introProgress: 0.0

    Component.onCompleted: {
        popupTargetVisible = true;
        introProgress = 1.0;
        Kde.KDEConnect.checkDaemon();
        popupEnterAnim.start();
        root.forceActiveFocus();
    }

    onHostLoaderOpacityChanged: {
        if (hostLoaderOpacity < lastHostLoaderOpacity - 0.001 && popupTargetVisible) {
            popupTargetVisible = false;
            popupEnterAnim.stop();
            if (!popupExitAnim.running)
                popupExitAnim.start();
        }
        lastHostLoaderOpacity = hostLoaderOpacity;
    }

    function popupOriginLift() {
        return root.barPanelCenterY - (root.popupClosedHeight / 2);
    }

    function beginOverlayClose() {
        if (!popupTargetVisible)
            return;
        popupTargetVisible = false;
        popupEnterAnim.stop();
        if (!popupExitAnim.running)
            popupExitAnim.start();
    }

    function cancelOverlayClose() {
        popupTargetVisible = true;
        popupExitAnim.stop();
        popupEnterAnim.stop();
        popupEnterAnim.start();
    }

    function handleEscape() {
        return false;
    }

    function shellQuote(value) {
        return "'" + String(value === undefined || value === null ? "" : value).replace(/'/g, "'\\''") + "'";
    }

    function closePanel() {
        if (root.overlaySwitcher && typeof root.overlaySwitcher.close === "function")
            root.overlaySwitcher.close();
        else
            root.beginOverlayClose();
    }

    function openKdeConnectApp() {
        Quickshell.execDetached(["bash", "-lc", "(command -v kdeconnect-app >/dev/null 2>&1 && kdeconnect-app) || (command -v kdeconnect-settings >/dev/null 2>&1 && kdeconnect-settings) || (command -v systemsettings >/dev/null 2>&1 && systemsettings kcm_kdeconnect) || notify-send -a 'KDE Connect' 'KDE Connect' 'Install kdeconnect first.'"]);
    }

    function refreshNow() {
        Kde.KDEConnect.checkDaemon();
        Kde.KDEConnect.refreshDevices();
    }

    function openSendFilePicker() {
        if (!root.selectedDevice)
            return;

        const deployed = root.scriptsDir + "/kdeconnect_send_file_portal.py";
        const repo = root.repoScriptsDir + "/kdeconnect_send_file_portal.py";
        const bundled = root.bundledScriptsDir + "/kdeconnect_send_file_portal.py";
        const cmd = "script=" + root.shellQuote(deployed) + "; " +
            "[ -f \"$script\" ] || script=" + root.shellQuote(repo) + "; " +
            "[ -f \"$script\" ] || script=" + root.shellQuote(bundled) + "; " +
            "exec python3 \"$script\" " + root.shellQuote(root.selectedDevice.id) + " " + root.shellQuote(root.selectedDevice.name || "");

        root.closePanel();
        Quickshell.execDetached(["bash", "-lc", cmd]);
    }

    function openScrcpy() {
        if (!root.selectedDevice)
            return;

        const deployed = root.scriptsDir + "/kdeconnect_scrcpy.py";
        const repo = root.repoScriptsDir + "/kdeconnect_scrcpy.py";
        const bundled = root.bundledScriptsDir + "/kdeconnect_scrcpy.py";
        const cmd = "script=" + root.shellQuote(deployed) + "; " +
            "[ -f \"$script\" ] || script=" + root.shellQuote(repo) + "; " +
            "[ -f \"$script\" ] || script=" + root.shellQuote(bundled) + "; " +
            "exec python3 \"$script\" " + root.shellQuote(root.selectedDevice.id) + " " + root.shellQuote(root.selectedDevice.name || "");

        root.closePanel();
        Quickshell.execDetached(["bash", "-lc", cmd]);
    }

    function deviceStateText(device) {
        if (!Kde.KDEConnect.daemonAvailable)
            return "Daemon offline";
        if (!device)
            return "No device";
        if (!device.reachable)
            return "Offline";
        if (!device.paired)
            return device.pairRequested ? "Pair request sent" : "Not paired";
        return "Connected";
    }

    function deviceStateColor(device) {
        if (!device || !Kde.KDEConnect.daemonAvailable)
            return root.overlay0;
        if (!device.reachable)
            return root.red;
        if (!device.paired)
            return root.yellow;
        return root.green;
    }

    function batteryText(device) {
        if (!device || device.battery < 0)
            return "Unknown";
        return Math.round(device.battery) + "%" + (device.charging ? " charging" : "");
    }

    function signalText(device) {
        if (!device || device.cellularNetworkStrength < 0)
            return "Unknown";
        const labels = ["Very weak", "Weak", "Fair", "Good", "Excellent"];
        return labels[Math.max(0, Math.min(labels.length - 1, device.cellularNetworkStrength))];
    }

    function remoteInputText(device) {
        if (!device || !device.paired)
            return "Input off";
        return device.remoteInputReady ? "Input ready" : "Input locked";
    }

    function remoteInputColor(device) {
        if (!device || !device.paired)
            return root.overlay0;
        return device.remoteInputReady ? root.green : root.yellow;
    }

    function notificationsText(device) {
        if (!device || !Array.isArray(device.notificationIds))
            return "0";
        return String(device.notificationIds.length);
    }

    SequentialAnimation {
        id: popupEnterAnim
        running: false

        ParallelAnimation {
            NumberAnimation { target: root; property: "popupCardOpacity"; to: 0.82; duration: 210; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "popupCardScaleX"; to: 0.985; duration: 280; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "popupCardScaleY"; to: 0.94; duration: 300; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "popupCardWidth"; to: root.popupOpenWidth - 18; duration: 285; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "popupCardHeight"; to: root.popupOpenHeight - 18; duration: 300; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "popupCardRadius"; to: 28; duration: 270; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "popupCardLift"; to: 8; duration: 300; easing.type: Easing.OutCubic }
        }

        ParallelAnimation {
            NumberAnimation { target: root; property: "popupCardOpacity"; to: 1.0; duration: 175; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "popupCardScaleX"; to: 1.0; duration: 205; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "popupCardScaleY"; to: 1.0; duration: 205; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "popupCardWidth"; to: root.popupOpenWidth; duration: 205; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "popupCardHeight"; to: root.popupOpenHeight; duration: 215; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "popupCardRadius"; to: root.popupOpenRadius; duration: 195; easing.type: Easing.InOutQuad }
            NumberAnimation { target: root; property: "popupCardLift"; to: 0; duration: 205; easing.type: Easing.OutCubic }
        }
    }

    SequentialAnimation {
        id: popupExitAnim
        running: false

        ParallelAnimation {
            NumberAnimation { target: root; property: "popupCardScaleX"; to: 1.04; duration: 85; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "popupCardScaleY"; to: 0.95; duration: 85; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "popupCardWidth"; to: root.popupOpenWidth + 14; duration: 95; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "popupCardHeight"; to: root.popupOpenHeight - 16; duration: 95; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "popupCardRadius"; to: 28; duration: 95; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "popupCardLift"; to: 5; duration: 95; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "popupCardOpacity"; to: 0.88; duration: 80; easing.type: Easing.OutQuad }
        }

        ParallelAnimation {
            NumberAnimation { target: root; property: "popupCardOpacity"; to: 0.0; duration: 180; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "popupCardScaleX"; to: 0.42; duration: 260; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "popupCardScaleY"; to: 0.24; duration: 280; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "popupCardWidth"; to: root.popupClosedWidth; duration: 200; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "popupCardHeight"; to: root.popupClosedHeight; duration: 210; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "popupCardRadius"; to: root.popupClosedRadius; duration: 200; easing.type: Easing.InQuad }
            NumberAnimation { target: root; property: "popupCardLift"; to: root.popupOriginLift(); duration: 280; easing.type: Easing.InCubic }
        }
    }

    Item {
        id: panelShell
        width: root.popupCardWidth
        height: root.popupCardHeight
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: root.panelMargin
        anchors.rightMargin: root.panelMargin
        opacity: root.popupCardOpacity
        transform: [
            Scale {
                origin.x: panelShell.width / 2
                origin.y: panelShell.height / 2
                xScale: root.popupCardScaleX
                yScale: root.popupCardScaleY
            },
            Translate { y: root.popupCardLift }
        ]

        Rectangle {
            id: panel
            width: root.panelWidth
            height: root.panelHeight
            radius: root.popupCardRadius
            color: root.base
            border.color: root.panelBorderColor
            border.width: 1
            anchors.top: parent.top
            anchors.right: parent.right
            clip: true

            AnimatedBorder {
                anchors.fill: parent
                radius: parent.radius
                borderWidth: parent.border.width
                accentColor: root.accent
            }

            opacity: root.introProgress
            transform: Scale {
                origin.x: panel.width
                origin.y: 0
                xScale: 0.975 + (0.025 * root.introProgress)
                yScale: 0.975 + (0.025 * root.introProgress)
            }

            Text {
                anchors.centerIn: parent
                text: "󰄡"
                font.family: "Iosevka Nerd Font"
                font.pixelSize: 300
                color: root.accent
                opacity: 0.035
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onClicked: {}
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: root.contentMargin
                spacing: 14

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 46
                    spacing: 12

                    Text {
                        text: "󰄡"
                        font.family: "Iosevka Nerd Font"
                        font.pixelSize: 28
                        color: root.accent
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            Layout.fillWidth: true
                            text: "KDE Connect"
                            color: root.text
                            font.family: root.textFont
                            font.weight: Font.Black
                            font.pixelSize: 20
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: Kde.KDEConnect.daemonAvailable ? (Kde.KDEConnect.devices.length + " device" + (Kde.KDEConnect.devices.length === 1 ? "" : "s") + " discovered") : Kde.KDEConnect.lastError
                            color: root.subtext0
                            font.family: root.textFont
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                    }

                    RefreshButton {
                        enabled: !Kde.KDEConnect.refreshing
                        busy: Kde.KDEConnect.refreshing
                        onActivated: root.refreshNow()
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 12

                    Rectangle {
                        Layout.preferredWidth: 214
                        Layout.fillHeight: true
                        radius: 16
                        color: root.surface0
                        border.color: "#18ffffff"
                        border.width: 1
                        clip: true

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 10

                            Text {
                                Layout.fillWidth: true
                                text: "Devices"
                                color: root.text
                                font.family: root.textFont
                                font.weight: Font.Black
                                font.pixelSize: 13
                                elide: Text.ElideRight
                            }

                            ScrollView {
                                id: deviceScroll
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                                ScrollBar.vertical.policy: ScrollBar.AsNeeded

                                Column {
                                    width: deviceScroll.availableWidth
                                    spacing: 8

                                    Repeater {
                                        model: Kde.KDEConnect.devices

                                        delegate: DeviceRow {
                                            required property var modelData
                                            width: parent.width
                                            device: modelData
                                            selected: root.selectedDevice && root.selectedDevice.id === modelData.id
                                        }
                                    }
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: Kde.KDEConnect.devices.length === 0
                                text: Kde.KDEConnect.daemonAvailable ? "No paired or visible phones yet." : "Waiting for KDE Connect."
                                color: root.subtext0
                                font.family: root.textFont
                                font.pixelSize: 11
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    Loader {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        active: true
                        sourceComponent: Kde.KDEConnect.busctlCmd === "" ? busctlMissingComp :
                            (!Kde.KDEConnect.daemonAvailable) ? daemonMissingComp :
                            (Kde.KDEConnect.devices.length === 0) ? noDevicesComp :
                            (root.selectedDevice && !root.selectedDevice.reachable) ? offlineDeviceComp :
                            (root.selectedDevice && root.selectedDevice.paired) ? connectedDeviceComp :
                            root.selectedDevice ? pairingDeviceComp : noDevicesComp
                    }
                }

            }
        }
    }

    Component {
        id: busctlMissingComp

        EmptyState {
            icon: "󰅙"
            title: "busctl not found"
            body: "Install systemd tools so the popup can talk to KDE Connect over the user bus."
            primaryText: "Refresh"
            onPrimary: root.refreshNow()
        }
    }

    Component {
        id: daemonMissingComp

        EmptyState {
            icon: "󰀲"
            title: "kdeconnectd is not running"
            body: "Start KDE Connect, pair your phone, then refresh this popup."
            primaryText: "Open KDE Connect"
            secondaryText: "Refresh"
            onPrimary: root.openKdeConnectApp()
            onSecondary: root.refreshNow()
        }
    }

    Component {
        id: noDevicesComp

        EmptyState {
            icon: "󰀲"
            title: "No devices"
            body: "Open the KDE Connect app on your phone and keep both devices on the same network."
            primaryText: "Open KDE Connect"
            secondaryText: "Refresh"
            onPrimary: root.openKdeConnectApp()
            onSecondary: root.refreshNow()
        }
    }

    Component {
        id: offlineDeviceComp

        EmptyState {
            icon: "󰀲"
            title: root.selectedDevice ? root.selectedDevice.name : "Device offline"
            body: "This device is known but not reachable right now."
            primaryText: "Unpair"
            secondaryText: "Refresh"
            onPrimary: {
                if (!root.selectedDevice)
                    return;
                Kde.KDEConnect.unpairDevice(root.selectedDevice.id);
            }
            onSecondary: root.refreshNow()
        }
    }

    Component {
        id: pairingDeviceComp

        Rectangle {
            radius: 16
            color: root.surface0
            border.color: "#18ffffff"
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 14

                Text {
                    Layout.fillWidth: true
                    text: root.selectedDevice ? root.selectedDevice.name : "Device"
                    color: root.text
                    font.family: root.textFont
                    font.weight: Font.Black
                    font.pixelSize: 22
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: root.selectedDevice && root.selectedDevice.pairRequested ? "Confirm the pairing request on your phone." : "This device is visible but not paired."
                    color: root.subtext0
                    font.family: root.textFont
                    font.pixelSize: 13
                    wrapMode: Text.WordWrap
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 88
                    radius: 16
                    color: "#10ffffff"
                    border.color: "#18ffffff"
                    border.width: 1
                    visible: root.selectedDevice && root.selectedDevice.pairRequested

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 4

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Verification key"
                            color: root.subtext0
                            font.family: root.textFont
                            font.pixelSize: 11
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.selectedDevice ? root.selectedDevice.verificationKey : ""
                            color: root.accent
                            font.family: root.textFont
                            font.weight: Font.Black
                            font.pixelSize: 18
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    ActionButton {
                        Layout.fillWidth: true
                        icon: "󰐕"
                        label: root.selectedDevice && root.selectedDevice.pairRequested ? "Request Sent" : "Pair"
                        enabled: root.selectedDevice && !root.selectedDevice.pairRequested
                        onActivated: {
                            Kde.KDEConnect.requestPairing(root.selectedDevice.id);
                            root.selectedDevice.pairRequested = true;
                        }
                    }

                    ActionButton {
                        Layout.fillWidth: true
                        refreshIcon: true
                        label: "Refresh"
                        busy: Kde.KDEConnect.refreshing
                        onActivated: root.refreshNow()
                    }
                }
            }
        }
    }

    Component {
        id: connectedDeviceComp

        Rectangle {
            radius: 16
            color: root.surface0
            border.color: "#18ffffff"
            border.width: 1
            clip: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 14

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    PhoneFrame {
                        Layout.preferredWidth: 104
                        Layout.preferredHeight: 174
                        enabled: root.selectedDevice && root.selectedDevice.reachable && root.selectedDevice.paired && root.selectedDevice.remoteInputReady
                        onActivated: {
                            if (root.selectedDevice)
                                Kde.KDEConnect.wakeUpDevice(root.selectedDevice.id);
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Text {
                            Layout.fillWidth: true
                            text: root.selectedDevice ? root.selectedDevice.name : "Phone"
                            color: root.text
                            font.family: root.textFont
                            font.weight: Font.Black
                            font.pixelSize: 22
                            elide: Text.ElideRight
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 7

                            StatusPill {
                                label: root.deviceStateText(root.selectedDevice)
                                accentColor: root.deviceStateColor(root.selectedDevice)
                            }

                            StatusPill {
                                label: root.batteryText(root.selectedDevice)
                                accentColor: root.selectedDevice && root.selectedDevice.charging ? root.green : root.accent
                            }

                            StatusPill {
                                label: root.remoteInputText(root.selectedDevice)
                                accentColor: root.remoteInputColor(root.selectedDevice)
                            }
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: 2
                            columnSpacing: 8
                            rowSpacing: 8

                            StatTile {
                                icon: "󰁹"
                                label: "Battery"
                                value: root.batteryText(root.selectedDevice)
                            }

                            StatTile {
                                icon: "󰒢"
                                label: "Network"
                                value: root.selectedDevice && root.selectedDevice.cellularNetworkType !== "" ? root.selectedDevice.cellularNetworkType : "Unknown"
                            }

                            StatTile {
                                icon: "󰤨"
                                label: "Signal"
                                value: root.signalText(root.selectedDevice)
                            }

                            StatTile {
                                icon: "󰂚"
                                label: "Notifications"
                                value: root.notificationsText(root.selectedDevice)
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: "#18ffffff"
                }

                Text {
                    Layout.fillWidth: true
                    text: "Actions"
                    color: root.text
                    font.family: root.textFont
                    font.weight: Font.Black
                    font.pixelSize: 13
                    elide: Text.ElideRight
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: 8
                    rowSpacing: 8

                    ActionButton {
                        Layout.fillWidth: true
                        icon: "󰉋"
                        label: "Browse Files"
                        onActivated: {
                            root.closePanel();
                            Kde.KDEConnect.browseFiles(root.selectedDevice.id);
                        }
                    }

                    ActionButton {
                        Layout.fillWidth: true
                        icon: "󰍡"
                        label: "Send File"
                        onActivated: root.openSendFilePicker()
                    }

                    ActionButton {
                        Layout.fillWidth: true
                        icon: "󰢹"
                        label: "Screen"
                        onActivated: root.openScrcpy()
                    }

                    ActionButton {
                        Layout.fillWidth: true
                        icon: "󰐊"
                        label: "Ring"
                        onActivated: {
                            Kde.KDEConnect.triggerFindMyPhone(root.selectedDevice.id);
                        }
                    }

                    ActionButton {
                        Layout.fillWidth: true
                        icon: "󰤄"
                        label: "Tap"
                        enabled: root.selectedDevice && root.selectedDevice.remoteInputReady
                        onActivated: {
                            Kde.KDEConnect.wakeUpDevice(root.selectedDevice.id);
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    ActionButton {
                        Layout.fillWidth: true
                        icon: "󰍷"
                        label: "Unpair"
                        onActivated: {
                            Kde.KDEConnect.unpairDevice(root.selectedDevice.id);
                        }
                    }

                    ActionButton {
                        Layout.fillWidth: true
                        refreshIcon: true
                        label: "Refresh"
                        busy: Kde.KDEConnect.refreshing
                        onActivated: root.refreshNow()
                    }
                }
            }
        }
    }

    component DeviceRow: Rectangle {
        id: deviceRow

        property var device: null
        property bool selected: false

        height: 66
        radius: 14
        color: selected ? ThemePkg.Theme.withAlpha(root.accent, 0.20) : (rowHover.hovered ? "#14ffffff" : "#0affffff")
        border.color: selected ? root.accent : (rowHover.hovered ? "#26ffffff" : "#14ffffff")
        border.width: 1

        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 9

            Rectangle {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                radius: 12
                color: ThemePkg.Theme.withAlpha(root.deviceStateColor(device), 0.16)
                border.color: ThemePkg.Theme.withAlpha(root.deviceStateColor(device), 0.45)
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "󰀲"
                    color: root.deviceStateColor(device)
                    font.family: "Iosevka Nerd Font"
                    font.pixelSize: 17
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    Layout.fillWidth: true
                    text: device ? device.name : "Device"
                    color: root.text
                    font.family: root.textFont
                    font.weight: Font.Black
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: root.deviceStateText(device)
                    color: root.subtext0
                    font.family: root.textFont
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }
            }

            Text {
                text: device && device.paired && device.battery >= 0 ? Math.round(device.battery) + "%" : ""
                color: root.accent
                font.family: root.textFont
                font.weight: Font.Black
                font.pixelSize: 11
            }
        }

        HoverHandler {
            id: rowHover
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            acceptedButtons: Qt.LeftButton
            onTapped: {
                if (device)
                    Kde.KDEConnect.setMainDevice(device.id);
            }
        }
    }

    component EmptyState: Rectangle {
        id: empty

        property string icon: ""
        property string title: ""
        property string body: ""
        property string primaryText: ""
        property string secondaryText: ""
        signal primary()
        signal secondary()

        radius: 16
        color: root.surface0
        border.color: "#18ffffff"
        border.width: 1

        ColumnLayout {
            anchors.centerIn: parent
            width: Math.min(parent.width - 44, 320)
            spacing: 12

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: empty.icon
                color: root.accent
                font.family: "Iosevka Nerd Font"
                font.pixelSize: 48
            }

            Text {
                Layout.fillWidth: true
                text: empty.title
                color: root.text
                font.family: root.textFont
                font.weight: Font.Black
                font.pixelSize: 20
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            Text {
                Layout.fillWidth: true
                text: empty.body
                color: root.subtext0
                font.family: root.textFont
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 8
                visible: empty.primaryText !== "" || empty.secondaryText !== ""

                ActionButton {
                    icon: "󰐕"
                    label: empty.primaryText
                    visible: empty.primaryText !== ""
                    onActivated: empty.primary()
                }

                ActionButton {
                    refreshIcon: true
                    label: empty.secondaryText
                    visible: empty.secondaryText !== ""
                    onActivated: empty.secondary()
                }
            }
        }
    }

    component PhoneFrame: Rectangle {
        id: phoneFrame

        signal activated()

        radius: 22
        color: phoneHover.hovered && enabled ? "#111724" : "#0b0d12"
        border.color: phoneHover.hovered && enabled ? root.accent : "#36ffffff"
        border.width: 1
        opacity: enabled ? 1.0 : 0.52
        scale: phoneTap.pressed && enabled ? 0.98 : 1.0

        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 5
            radius: parent.radius - 5
            color: "#111723"

            Rectangle {
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.topMargin: 8
                width: 42
                height: 10
                radius: 5
                color: "#05070a"
            }

            Text {
                anchors.centerIn: parent
                text: "󰀲"
                color: root.accent
                opacity: 0.85
                font.family: "Iosevka Nerd Font"
                font.pixelSize: 42
            }

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottomMargin: 9
                width: 42
                height: 4
                radius: 2
                color: "#70ffffff"
            }
        }

        HoverHandler {
            id: phoneHover
            cursorShape: phoneFrame.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        }

        TapHandler {
            id: phoneTap
            acceptedButtons: Qt.LeftButton
            enabled: phoneFrame.enabled
            onTapped: phoneFrame.activated()
        }
    }

    component StatusPill: Rectangle {
        property string label: ""
        property color accentColor: root.accent

        implicitWidth: pillText.implicitWidth + 20
        implicitHeight: 28
        radius: 14
        color: ThemePkg.Theme.withAlpha(accentColor, 0.14)
        border.color: ThemePkg.Theme.withAlpha(accentColor, 0.45)
        border.width: 1

        Text {
            id: pillText
            anchors.centerIn: parent
            text: label
            color: root.text
            font.family: root.textFont
            font.weight: Font.Black
            font.pixelSize: 11
            maximumLineCount: 1
        }
    }

    component StatTile: Rectangle {
        property string icon: ""
        property string label: ""
        property string value: ""

        Layout.fillWidth: true
        Layout.preferredHeight: 52
        radius: 14
        color: "#0dffffff"
        border.color: "#18ffffff"
        border.width: 1

        RowLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8

            Text {
                text: icon
                color: root.accent
                font.family: "Iosevka Nerd Font"
                font.pixelSize: 18
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    Layout.fillWidth: true
                    text: value
                    color: root.text
                    font.family: root.textFont
                    font.weight: Font.Black
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: label
                    color: root.subtext0
                    font.family: root.textFont
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }
            }
        }
    }

    component ActionButton: Rectangle {
        id: actionBtn

        property string icon: ""
        property string iconFont: "Iosevka Nerd Font"
        property string label: ""
        property bool busy: false
        property bool refreshIcon: false
        signal activated()

        implicitWidth: label === "" ? 40 : 130
        implicitHeight: 40
        radius: 12
        color: enabled ? (actionHover.hovered ? "#20ffffff" : "#10ffffff") : "#08ffffff"
        border.color: enabled ? (actionHover.hovered ? root.accent : "#24ffffff") : "#12ffffff"
        border.width: 1
        opacity: enabled ? 1.0 : 0.45

        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }
        scale: actionTap.pressed && enabled ? 0.96 : 1.0
        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }

        RowLayout {
            anchors.centerIn: parent
            spacing: label === "" ? 0 : 7

            Item {
                Layout.preferredWidth: 18
                Layout.preferredHeight: 18

                RefreshIcon {
                    anchors.centerIn: parent
                    width: 18
                    height: 18
                    visible: actionBtn.refreshIcon
                    iconColor: actionHover.hovered && actionBtn.enabled ? root.accent : root.text
                }

                Text {
                    anchors.centerIn: parent
                    visible: !actionBtn.refreshIcon
                    text: icon
                    color: actionHover.hovered && actionBtn.enabled ? root.accent : root.text
                    font.family: actionBtn.iconFont
                    font.pixelSize: 16
                }

                RotationAnimation on rotation {
                    from: 0
                    to: 360
                    duration: 900
                    loops: Animation.Infinite
                    running: busy && actionBtn.refreshIcon && ThemePkg.Theme.edgeAnimationsEnabled
                }
            }

            Text {
                visible: label !== ""
                text: label
                color: actionHover.hovered && actionBtn.enabled ? root.accent : root.text
                font.family: root.textFont
                font.weight: Font.Black
                font.pixelSize: 12
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }

        HoverHandler {
            id: actionHover
            cursorShape: actionBtn.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        }

        TapHandler {
            id: actionTap
            acceptedButtons: Qt.LeftButton
            enabled: actionBtn.enabled
            onTapped: actionBtn.activated()
        }
    }

    component RefreshButton: Rectangle {
        id: refreshBtn

        property bool busy: false
        signal activated()

        implicitWidth: 40
        implicitHeight: 40
        radius: 12
        color: enabled ? (refreshHover.hovered ? "#20ffffff" : "#10ffffff") : "#08ffffff"
        border.color: enabled ? (refreshHover.hovered ? root.accent : "#24ffffff") : "#12ffffff"
        border.width: 1
        opacity: enabled ? 1.0 : 0.45

        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }
        scale: refreshTap.pressed && enabled ? 0.96 : 1.0
        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }

        RefreshIcon {
            id: refreshIcon
            anchors.centerIn: parent
            width: 20
            height: 20
            iconColor: refreshHover.hovered && refreshBtn.enabled ? root.accent : root.text
            opacity: refreshHover.hovered && refreshBtn.enabled ? 1.0 : 0.82

            RotationAnimation on rotation {
                from: 0
                to: 360
                duration: 900
                loops: Animation.Infinite
                running: refreshBtn.busy && ThemePkg.Theme.edgeAnimationsEnabled
            }
        }

        HoverHandler {
            id: refreshHover
            cursorShape: refreshBtn.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        }

        TapHandler {
            id: refreshTap
            acceptedButtons: Qt.LeftButton
            enabled: refreshBtn.enabled
            onTapped: refreshBtn.activated()
        }
    }

    component RefreshIcon: Shape {
        id: refreshIconShape

        property color iconColor: root.text

        implicitWidth: 20
        implicitHeight: 20
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeColor: refreshIconShape.iconColor
            strokeWidth: 2
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            startX: refreshIconShape.width * 0.79
            startY: refreshIconShape.height * 0.27

            PathAngleArc {
                centerX: refreshIconShape.width * 0.5
                centerY: refreshIconShape.height * 0.5
                radiusX: refreshIconShape.width * 0.34
                radiusY: refreshIconShape.height * 0.34
                startAngle: -46
                sweepAngle: 286
            }
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: refreshIconShape.iconColor
            strokeWidth: 2
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            startX: refreshIconShape.width * 0.70
            startY: refreshIconShape.height * 0.19

            PathLine {
                x: refreshIconShape.width * 0.88
                y: refreshIconShape.height * 0.18
            }

            PathLine {
                x: refreshIconShape.width * 0.82
                y: refreshIconShape.height * 0.36
            }
        }
    }
}
