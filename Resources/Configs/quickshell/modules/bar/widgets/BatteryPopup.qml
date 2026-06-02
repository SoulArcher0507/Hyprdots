import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import "../../theme" as ThemePkg

Item {
    id: window

    property Item batteryButton
    property var overlayWindow
    readonly property real popupOpenWidth: 360
    readonly property real popupOpenHeight: 444
    readonly property real popupClosedWidth: 280
    readonly property real popupClosedHeight: 30
    readonly property real popupOpenRadius: 20
    readonly property real popupClosedRadius: 10
    readonly property real barPanelHeight: 47
    readonly property real barPanelCenterY: barPanelHeight / 2
    readonly property int overlayEnterDuration: 515
    readonly property int overlayExitDuration: 375
    readonly property bool overlayOwnsCloseAnimation: true

    width: popupOpenWidth
    height: popupOpenHeight
    visible: true
    z: 99999

    property int sideMargin: 16
    property int topGap: 0
    function _win() {
        return overlayWindow ? overlayWindow : (window.Window ? window.Window.window : null);
    }

    Connections {
        target: overlayWindow
        function onWidthChanged() {
            Qt.callLater(positionPopup);
        }
        function onHeightChanged() {
            Qt.callLater(positionPopup);
        }
    }
    Connections {
        target: batteryButton
        function onWidthChanged() {
            Qt.callLater(positionPopup);
        }
        function onHeightChanged() {
            Qt.callLater(positionPopup);
        }
        function onXChanged() {
            Qt.callLater(positionPopup);
        }
        function onYChanged() {
            Qt.callLater(positionPopup);
        }
    }

    function positionPopup() {
        const win = _win();
        if (!win)
            return;
        var maxW = Math.max(260, win.width - sideMargin * 2);
        var newW = Math.min(360, maxW);
        if (window.width !== newW)
            window.width = newW;

        var baseY = topGap;
        if (batteryButton) {
            try {
                var gp = batteryButton.mapToGlobal(Qt.point(batteryButton.width / 2, batteryButton.height));
                var lp = win.mapFromGlobal(gp.x, gp.y);
                baseY = lp.y;
            } catch (e) {}
        }

        var desiredX = win.width - window.width - sideMargin;

        window.x = Math.max(sideMargin, Math.min(desiredX, win.width - window.width - sideMargin));
        window.y = Math.max(topGap, Math.min(baseY, Math.max(topGap, win.height - window.height - topGap)));
    }

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

    readonly property color mauve: ThemePkg.Theme.c5
    readonly property color pink: ThemePkg.Theme.c13
    readonly property color red: ThemePkg.Theme.danger
    readonly property color maroon: ThemePkg.Theme.c1
    readonly property color peach: ThemePkg.Theme.warning
    readonly property color yellow: ThemePkg.Theme.c3
    readonly property color green: ThemePkg.Theme.success
    readonly property color teal: ThemePkg.Theme.c6
    readonly property color sapphire: ThemePkg.Theme.c4
    readonly property color blue: ThemePkg.Theme.c4
    readonly property color panelBorderColor: ThemePkg.Theme.mix(ThemePkg.Theme.background, ThemePkg.Theme.foreground, 0.35)
    readonly property string textFont: "Fira Sans"

    property int batCapacity: 0
    property string batStatus: "Unknown"
    property string powerProfile: "balanced"

    readonly property var batteryDevice: UPower.displayDevice
    property int tteOverride: -1
    property int ttfOverride: -1

    property real sysBrightness: 0
    readonly property string brightnessScript: Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/brightness/brightness_control.sh"

    property string currentUserName: ""
    property bool popupTargetVisible: false
    property real popupCardOpacity: 0.0
    property real popupCardScaleX: 0.42
    property real popupCardScaleY: 0.24
    property real popupCardWidth: popupClosedWidth
    property real popupCardHeight: popupClosedHeight
    property real popupCardRadius: popupClosedRadius
    property real popupCardLift: popupOriginLift()

    property bool isDraggingBri: false

    Timer {
        id: briSyncDelay
        interval: 400
        onTriggered: window.isDraggingBri = false
        triggeredOnStart: true
    }

    readonly property bool isCharging: batteryDevice.state === UPowerDeviceState.Charging
        || batteryDevice.state === UPowerDeviceState.PendingCharge
        || batStatus === "Charging"
    readonly property bool isDischarging: batteryDevice.state === UPowerDeviceState.Discharging
        || batteryDevice.state === UPowerDeviceState.PendingDischarge
        || batStatus === "Discharging"
    readonly property int tte: (batteryDevice.timeToEmpty && batteryDevice.timeToEmpty > 0) ? batteryDevice.timeToEmpty : (tteOverride >= 0 ? tteOverride : 0)
    readonly property int ttf: (batteryDevice.timeToFull && batteryDevice.timeToFull > 0) ? batteryDevice.timeToFull : (ttfOverride >= 0 ? ttfOverride : 0)
    readonly property int batteryEtaSeconds: isCharging ? ttf : (isDischarging ? tte : 0)
    readonly property string batteryEtaHoursText: batteryEtaSeconds > 0 ? Math.floor(batteryEtaSeconds / 3600).toString().padStart(2, '0') : "--"
    readonly property string batteryEtaMinsText: batteryEtaSeconds > 0 ? Math.floor((batteryEtaSeconds % 3600) / 60).toString().padStart(2, '0') : "--"
    readonly property string batteryEtaTitle: {
        if (isCharging)
            return batteryEtaSeconds > 0 ? "TO FULL" : "CHARGING";
        if (isDischarging)
            return batteryEtaSeconds > 0 ? "LEFT" : "BATTERY";
        return "BATTERY";
    }

    readonly property color batColorStart: {
        if (isCharging)
            return window.green;
        if (batCapacity >= 70)
            return window.blue;
        if (batCapacity >= 30)
            return window.yellow;
        return window.red;
    }
    readonly property color batColorEnd: Qt.lighter(batColorStart, 1.15)

    readonly property color profileStart: {
        if (powerProfile === "performance")
            return window.red;
        if (powerProfile === "power-saver")
            return window.green;
        return window.blue;
    }
    readonly property color profileEnd: Qt.lighter(profileStart, 1.15)

    readonly property color ambientPrimary: window.batColorStart
    readonly property color ambientSecondary: {
        if (isCharging)
            return window.sapphire;
        if (batCapacity >= 70)
            return window.mauve;
        if (batCapacity >= 30)
            return window.peach;
        return window.maroon;
    }

    property real animCapacity: 0
    Behavior on animCapacity {
        NumberAnimation {
            duration: 1200
            easing.type: Easing.OutQuint
        }
    }

    function glyphFor(p, charging) {
        if (charging) {
            if (p >= 95) return "󰂅";
            if (p >= 85) return "󰂋";
            if (p >= 75) return "󰂊";
            if (p >= 65) return "󰢞";
            if (p >= 55) return "󰂉";
            if (p >= 45) return "󰢝";
            if (p >= 35) return "󰂈";
            if (p >= 25) return "󰂇";
            if (p >= 15) return "󰂆";
            if (p >= 5)  return "󰢜";
            return "󰢟";
        } else {
            if (p >= 95) return "󰁹";
            if (p >= 85) return "󰂂";
            if (p >= 75) return "󰂁";
            if (p >= 65) return "󰂀";
            if (p >= 55) return "󰁿";
            if (p >= 45) return "󰁾";
            if (p >= 35) return "󰁽";
            if (p >= 25) return "󰁼";
            if (p >= 15) return "󰁻";
            if (p >= 5)  return "󰁺";
            return "󰂎";
        }
    }

    onAnimCapacityChanged: batCanvas.requestPaint()
    onBatColorStartChanged: batCanvas.requestPaint()

    Process {
        id: userPoller
        command: ["bash", "-c", "echo $USER"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                window.currentUserName = this.text.trim();
            }
        }
    }

    Process {
        id: sysPoller
        command: ["bash", "-c", "cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo '0'; " + "cat /sys/class/power_supply/BAT0/status 2>/dev/null || echo 'Unknown'; " + "powerprofilesctl get 2>/dev/null || echo 'balanced'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = this.text.trim().split("\n");
                if (lines.length >= 3) {
                    if (window.batCapacity !== parseInt(lines[0])) {
                        window.batCapacity = parseInt(lines[0]);
                        window.animCapacity = window.batCapacity;
                    }
                    window.batStatus = lines[1];
                    window.powerProfile = lines[2];
                }
            }
        }
    }

    Process {
        id: briPoller
        command: ["bash", "-c", "brightnessctl -m 2>/dev/null | awk -F, '{print substr($4, 1, length($4)-1)}' || echo '0'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                if (!window.isDraggingBri) {
                    window.sysBrightness = parseInt(this.text.trim()) || 0;
                }
            }
        }
    }

    property string _tteCmd: "dev=$(upower -e | grep -m1 battery || true); " + "[ -n \"$dev\" ] && upower -i \"$dev\" | awk -F: '/time to empty/ {gsub(/^ +/,\"\",$2); v=$2; split(v,a,\" \"); x=a[1]; gsub(/,/,\".\",x); if (v ~ /hour/) print int(x*3600); else if (v ~ /minute/) print int(x*60); }'"
    property string _ttfCmd: "dev=$(upower -e | grep -m1 battery || true); " + "[ -n \"$dev\" ] && upower -i \"$dev\" | awk -F: '/time to full/ {gsub(/^ +/,\"\",$2); v=$2; split(v,a,\" \"); x=a[1]; gsub(/,/,\".\",x); if (v ~ /hour/) print int(x*3600); else if (v ~ /minute/) print int(x*60); }'"

    Process {
        id: batTteProc
        command: ["bash", "-lc", window._tteCmd]
        stdout: StdioCollector {
            id: batTteOut
            waitForEnd: true
        }
        onExited: {
            const value = parseInt((batTteOut.text || "").trim());
            window.tteOverride = (!isNaN(value) && value > 0) ? value : -1;
        }
    }

    Process {
        id: batTtfProc
        command: ["bash", "-lc", window._ttfCmd]
        stdout: StdioCollector {
            id: batTtfOut
            waitForEnd: true
        }
        onExited: {
            const value = parseInt((batTtfOut.text || "").trim());
            window.ttfOverride = (!isNaN(value) && value > 0) ? value : -1;
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: sysPoller.running = true
    }

    Timer {
        interval: 250
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: briPoller.running = true
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: {
            batTteProc.exec(["bash", "-lc", window._tteCmd]);
            batTtfProc.exec(["bash", "-lc", window._ttfCmd]);
        }
    }

    property real globalOrbitAngle: 0
    NumberAnimation on globalOrbitAngle {
        from: 0
        to: Math.PI * 2
        duration: 90000
        loops: Animation.Infinite
        running: true
    }

    property real introState: 0.0
    Component.onCompleted: {
        popupTargetVisible = true;
        introState = 1.0;
        Qt.callLater(positionPopup);
        batTteProc.exec(["bash", "-lc", window._tteCmd]);
        batTtfProc.exec(["bash", "-lc", window._ttfCmd]);
        popupEnterAnim.start();
    }
    Behavior on introState {
        NumberAnimation {
            duration: 800
            easing.type: Easing.OutQuint
        }
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

    function popupOriginLift() {
        return window.barPanelCenterY - (window.popupClosedHeight / 2);
    }

    SequentialAnimation {
        id: popupEnterAnim
        running: false

        ParallelAnimation {
            NumberAnimation { target: window; property: "popupCardOpacity"; to: 0.82; duration: 210; easing.type: Easing.OutCubic }
            NumberAnimation { target: window; property: "popupCardScaleX"; to: 0.985; duration: 280; easing.type: Easing.OutCubic }
            NumberAnimation { target: window; property: "popupCardScaleY"; to: 0.94; duration: 300; easing.type: Easing.OutCubic }
            NumberAnimation { target: window; property: "popupCardWidth"; to: window.popupOpenWidth - 18; duration: 285; easing.type: Easing.OutCubic }
            NumberAnimation { target: window; property: "popupCardHeight"; to: window.popupOpenHeight - 18; duration: 300; easing.type: Easing.OutCubic }
            NumberAnimation { target: window; property: "popupCardRadius"; to: 28; duration: 270; easing.type: Easing.OutQuad }
            NumberAnimation { target: window; property: "popupCardLift"; to: 8; duration: 300; easing.type: Easing.OutCubic }
        }

        ParallelAnimation {
            NumberAnimation { target: window; property: "popupCardOpacity"; to: 1.0; duration: 175; easing.type: Easing.OutCubic }
            NumberAnimation { target: window; property: "popupCardScaleX"; to: 1.0; duration: 205; easing.type: Easing.OutCubic }
            NumberAnimation { target: window; property: "popupCardScaleY"; to: 1.0; duration: 205; easing.type: Easing.OutCubic }
            NumberAnimation { target: window; property: "popupCardWidth"; to: window.popupOpenWidth; duration: 205; easing.type: Easing.OutCubic }
            NumberAnimation { target: window; property: "popupCardHeight"; to: window.popupOpenHeight; duration: 215; easing.type: Easing.OutCubic }
            NumberAnimation { target: window; property: "popupCardRadius"; to: window.popupOpenRadius; duration: 195; easing.type: Easing.InOutQuad }
            NumberAnimation { target: window; property: "popupCardLift"; to: 0; duration: 205; easing.type: Easing.OutCubic }
        }
    }

    SequentialAnimation {
        id: popupExitAnim
        running: false

        ParallelAnimation {
            NumberAnimation { target: window; property: "popupCardScaleX"; to: 1.04; duration: 85; easing.type: Easing.OutQuad }
            NumberAnimation { target: window; property: "popupCardScaleY"; to: 0.95; duration: 85; easing.type: Easing.OutQuad }
            NumberAnimation { target: window; property: "popupCardWidth"; to: window.popupOpenWidth + 14; duration: 95; easing.type: Easing.OutQuad }
            NumberAnimation { target: window; property: "popupCardHeight"; to: window.popupOpenHeight - 16; duration: 95; easing.type: Easing.OutQuad }
            NumberAnimation { target: window; property: "popupCardRadius"; to: 28; duration: 95; easing.type: Easing.OutQuad }
            NumberAnimation { target: window; property: "popupCardLift"; to: 5; duration: 95; easing.type: Easing.OutQuad }
            NumberAnimation { target: window; property: "popupCardOpacity"; to: 0.88; duration: 80; easing.type: Easing.OutQuad }
        }

        ParallelAnimation {
            NumberAnimation { target: window; property: "popupCardOpacity"; to: 0.0; duration: 180; easing.type: Easing.InCubic }
            NumberAnimation { target: window; property: "popupCardScaleX"; to: 0.42; duration: 260; easing.type: Easing.InCubic }
            NumberAnimation { target: window; property: "popupCardScaleY"; to: 0.24; duration: 280; easing.type: Easing.InCubic }
            NumberAnimation { target: window; property: "popupCardWidth"; to: window.popupClosedWidth; duration: 200; easing.type: Easing.InCubic }
            NumberAnimation { target: window; property: "popupCardHeight"; to: window.popupClosedHeight; duration: 210; easing.type: Easing.InCubic }
            NumberAnimation { target: window; property: "popupCardRadius"; to: window.popupClosedRadius; duration: 200; easing.type: Easing.InQuad }
            NumberAnimation { target: window; property: "popupCardLift"; to: window.popupOriginLift(); duration: 280; easing.type: Easing.InCubic }
        }
    }

    Rectangle {
        id: cardShell
        width: window.popupCardWidth
        height: window.popupCardHeight
        x: (window.width - width) / 2
        y: window.popupCardLift
        radius: window.popupCardRadius
        opacity: window.popupCardOpacity
        color: window.base
        border.color: ThemePkg.Theme.mix(ThemePkg.Theme.background, ThemePkg.Theme.foreground, 0.35)
        border.width: 1
        clip: true

        transform: Scale {
            origin.x: cardShell.width / 2
            origin.y: cardShell.height / 2
            xScale: window.popupCardScaleX
            yScale: window.popupCardScaleY
        }

        AnimatedBorder {
            anchors.fill: parent
            radius: parent.radius
            borderWidth: parent.border.width
            accentColor: ThemePkg.Theme.accent
        }

        Rectangle {
            width: parent.width * 0.8
            height: width
            radius: width / 2
            x: (parent.width / 2 - width / 2) + Math.cos(window.globalOrbitAngle * 2) * 150
            y: (parent.height / 2 - height / 2) + Math.sin(window.globalOrbitAngle * 2) * 100
            opacity: 0.08
            color: window.ambientPrimary
            Behavior on color {
                ColorAnimation {
                    duration: 1000
                }
            }
        }

        Rectangle {
            width: parent.width * 0.9
            height: width
            radius: width / 2
            x: (parent.width / 2 - width / 2) + Math.sin(window.globalOrbitAngle * 1.5) * -150
            y: (parent.height / 2 - height / 2) + Math.cos(window.globalOrbitAngle * 1.5) * -100
            opacity: 0.06
            color: window.ambientSecondary
            Behavior on color {
                ColorAnimation {
                    duration: 1000
                }
            }
        }

        Item {
            id: radarItem
            anchors.fill: parent

            Repeater {
                model: 3
                Rectangle {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -70
                    width: 320 + (index * 170)
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border.color: window.ambientSecondary
                    border.width: 1
                    Behavior on border.color {
                        ColorAnimation {
                            duration: 1000
                        }
                    }
                    opacity: 0.06 - (index * 0.02)
                }
            }
        }

        Row {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.margins: 25
            spacing: 6
            z: 2

            transform: Translate {
                y: -15 * (1.0 - introState)
            }
            opacity: introState

            Rectangle {
                width: 44
                height: 48
                radius: 10
                color: "#0dffffff"
                border.color: "#1affffff"
                border.width: 1

                Rectangle {
                    anchors.fill: parent
                    radius: 10
                    color: window.ambientPrimary
                    opacity: 0.05
                    Behavior on color {
                        ColorAnimation {
                            duration: 1000
                        }
                    }
                }
                Column {
                    anchors.centerIn: parent
                    Text {
                        text: window.batteryEtaHoursText
                        font.pixelSize: 18
                        font.family: window.textFont
                        font.weight: Font.Black
                        color: window.ambientPrimary
                        Behavior on color {
                            ColorAnimation {
                                duration: 1000
                            }
                        }
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    Text {
                        text: "HR"
                        font.pixelSize: 8
                        font.family: window.textFont
                        font.weight: Font.Bold
                        color: window.subtext0
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: ":"
                font.pixelSize: 22
                font.family: window.textFont
                font.weight: Font.Black
                color: window.ambientPrimary
                Behavior on color {
                    ColorAnimation {
                        duration: 1000
                    }
                }

                opacity: uptimePulse
                property real uptimePulse: 1.0
                SequentialAnimation on uptimePulse {
                    loops: Animation.Infinite
                    running: true
                    NumberAnimation {
                        to: 0.2
                        duration: 800
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        to: 1.0
                        duration: 800
                        easing.type: Easing.InOutSine
                    }
                }
            }

            Rectangle {
                width: 44
                height: 48
                radius: 10
                color: "#0dffffff"
                border.color: "#1affffff"
                border.width: 1

                Rectangle {
                    anchors.fill: parent
                    radius: 10
                    color: window.ambientSecondary
                    opacity: 0.05
                    Behavior on color {
                        ColorAnimation {
                            duration: 1000
                        }
                    }
                }
                Column {
                    anchors.centerIn: parent
                    Text {
                        text: window.batteryEtaMinsText
                        font.pixelSize: 18
                        font.family: window.textFont
                        font.weight: Font.Black
                        color: window.ambientSecondary
                        Behavior on color {
                            ColorAnimation {
                                duration: 1000
                            }
                        }
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    Text {
                        text: "MIN"
                        font.pixelSize: 8
                        font.family: window.textFont
                        font.weight: Font.Bold
                        color: window.subtext0
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }
        }

        Item {
            anchors.fill: parent
            z: 1

                Rectangle {
                    anchors.centerIn: centralCore
                    width: centralCore.width + 45
                    height: width
                    radius: width / 2
                    color: centralCore.isDangerState ? window.red : window.ambientPrimary
                    opacity: centralCore.isDangerState ? 0.25 : 0.15
                    z: 0
                    Behavior on color {
                        ColorAnimation {
                            duration: 400
                        }
                    }
                    SequentialAnimation on scale {
                        loops: Animation.Infinite
                        running: true
                        NumberAnimation {
                            to: heroMa.containsMouse ? 1.15 : 1.08
                            duration: heroMa.containsMouse ? 800 : 2000
                            easing.type: Easing.InOutSine
                        }
                        NumberAnimation {
                            to: 1.0
                            duration: heroMa.containsMouse ? 800 : 2000
                            easing.type: Easing.InOutSine
                        }
                    }
                }

                Rectangle {
                    id: centralCore
                    width: 168
                    height: width
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -52
                    radius: width / 2
                    z: 1

                    property bool isDangerState: !window.isCharging && window.batCapacity < 15

                    SequentialAnimation on scale {
                        loops: Animation.Infinite
                        running: true
                        NumberAnimation {
                            to: heroMa.containsMouse ? 1.05 : (centralCore.isDangerState ? 1.04 : 1.01)
                            duration: heroMa.containsMouse ? 1200 : (centralCore.isDangerState ? 600 : 2500)
                            easing.type: Easing.InOutSine
                        }
                        NumberAnimation {
                            to: 1.0
                            duration: heroMa.containsMouse ? 1200 : (centralCore.isDangerState ? 600 : 2500)
                            easing.type: Easing.InOutSine
                        }
                    }

                    gradient: Gradient {
                        orientation: Gradient.Vertical
                        GradientStop {
                            position: 0.0
                            color: window.surface0
                        }
                        GradientStop {
                            position: 1.0
                            color: window.base
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: window.maroon
                        opacity: centralCore.isDangerState ? 0.15 : 0.0
                        Behavior on opacity {
                            NumberAnimation {
                                duration: 1000
                            }
                        }
                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            running: centralCore.isDangerState
                            NumberAnimation {
                                to: 0.25
                                duration: 600
                                easing.type: Easing.InOutSine
                            }
                            NumberAnimation {
                                to: 0.15
                                duration: 600
                                easing.type: Easing.InOutSine
                            }
                        }
                    }

                    Item {
                        anchors.fill: parent

                        property real textPulse: 0.0
                        SequentialAnimation on textPulse {
                            loops: Animation.Infinite
                            running: true
                            NumberAnimation {
                                from: 0.0
                                to: 1.0
                                duration: 1200
                                easing.type: Easing.InOutSine
                            }
                            NumberAnimation {
                                from: 1.0
                                to: 0.0
                                duration: 1200
                                easing.type: Easing.InOutSine
                            }
                        }

                        property real pumpPhase: 0.0
                        NumberAnimation on pumpPhase {
                            running: heroMa.containsMouse && window.isCharging
                            loops: Animation.Infinite
                            from: 0.0
                            to: 1.0
                            duration: 1200
                            easing.type: Easing.InOutSine
                            onStopped: batCanvas.requestPaint()
                        }

                        property real dischargePhase: 1.0
                        NumberAnimation on dischargePhase {
                            running: heroMa.containsMouse && !window.isCharging
                            loops: Animation.Infinite
                            from: 1.0
                            to: 0.0
                            duration: 1600
                            easing.type: Easing.InOutSine
                            onStopped: batCanvas.requestPaint()
                        }

                        onPumpPhaseChanged: {
                            if (heroMa.containsMouse && window.isCharging)
                                batCanvas.requestPaint();
                        }
                        onDischargePhaseChanged: {
                            if (heroMa.containsMouse && !window.isCharging)
                                batCanvas.requestPaint();
                        }

                        Canvas {
                            id: batCanvas
                            anchors.fill: parent
                            rotation: 180

                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.clearRect(0, 0, width, height);

                                var centerX = width / 2;
                                var centerY = height / 2;
                                var radius = (width / 2) - 18;
                                var endAngle = (window.animCapacity / 100) * 2 * Math.PI;

                                ctx.lineCap = "round";

                                ctx.lineWidth = 8;
                                ctx.beginPath();
                                ctx.arc(centerX, centerY, radius, 0, 2 * Math.PI);
                                ctx.strokeStyle = "#0dffffff";
                                ctx.stroke();

                                var fillGrad = ctx.createLinearGradient(0, height, width, 0);
                                fillGrad.addColorStop(0, window.batColorStart.toString());
                                fillGrad.addColorStop(1, window.batColorEnd.toString());

                                ctx.globalAlpha = 1.0;
                                ctx.lineWidth = 14;
                                ctx.beginPath();
                                ctx.arc(centerX, centerY, radius, 0, endAngle);
                                ctx.strokeStyle = fillGrad;
                                ctx.stroke();

                                if (heroMa.containsMouse && endAngle > 0.1) {
                                    if (window.isCharging) {
                                        var surgeAngle = parent.pumpPhase * (endAngle + 0.6) - 0.3;
                                        if (surgeAngle > 0 && surgeAngle < endAngle) {
                                            var sStart = Math.max(0, surgeAngle - 0.4);
                                            var sEnd = Math.min(endAngle, surgeAngle + 0.4);
                                            ctx.beginPath();
                                            ctx.arc(centerX, centerY, radius, sStart, sEnd);
                                            ctx.lineWidth = 22;
                                            ctx.strokeStyle = window.batColorStart.toString();
                                            ctx.globalAlpha = 0.5 * Math.sin(parent.pumpPhase * Math.PI);
                                            ctx.stroke();

                                            sStart = Math.max(0, surgeAngle - 0.2);
                                            sEnd = Math.min(endAngle, surgeAngle + 0.2);
                                            ctx.beginPath();
                                            ctx.arc(centerX, centerY, radius, sStart, sEnd);
                                            ctx.lineWidth = 28;
                                            ctx.strokeStyle = window.batColorEnd.toString();
                                            ctx.globalAlpha = 0.8 * Math.sin(parent.pumpPhase * Math.PI);
                                            ctx.stroke();
                                        }

                                        if (parent.pumpPhase > 0.7) {
                                            var flarePhase = (parent.pumpPhase - 0.7) / 0.3;
                                            var hitX = centerX + Math.cos(endAngle) * radius;
                                            var hitY = centerY + Math.sin(endAngle) * radius;
                                            ctx.beginPath();
                                            ctx.arc(hitX, hitY, 7 + (flarePhase * 15), 0, 2 * Math.PI);
                                            ctx.fillStyle = window.batColorEnd.toString();
                                            ctx.globalAlpha = (1.0 - flarePhase) * 0.6;
                                            ctx.fill();
                                        }
                                    } else {
                                        var drainCenter = parent.dischargePhase * endAngle;
                                        for (var d = 0; d < 2; d++) {
                                            var dSpread = 0.2 + (d * 0.15);
                                            var dStart = Math.max(0, drainCenter - dSpread);
                                            var dEnd = Math.min(endAngle, drainCenter + dSpread);

                                            if (dStart < dEnd) {
                                                ctx.beginPath();
                                                ctx.arc(centerX, centerY, radius, dStart, dEnd);
                                                ctx.lineWidth = 14 + (1 - d) * 2;
                                                ctx.strokeStyle = window.batColorEnd.toString();
                                                ctx.globalAlpha = 0.2 * Math.sin(parent.dischargePhase * Math.PI);
                                                ctx.stroke();
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 2

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            font.family: window.textFont
                            font.weight: Font.Black
                            font.pixelSize: Math.round(window.animCapacity) >= 100 ? 32 : 40
                            color: window.text
                            text: Math.round(window.animCapacity) + "%"
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            font.family: window.textFont
                            font.weight: Font.Bold
                            font.pixelSize: 11

                            color: window.isCharging ? Qt.tint(window.green, Qt.rgba(1, 1, 1, parent.textPulse * 0.4)) : (centralCore.isDangerState ? Qt.tint(window.red, Qt.rgba(1, 1, 1, parent.textPulse * 0.3)) : window.subtext0)

                            text: window.batStatus.toUpperCase()
                            Behavior on color {
                                ColorAnimation {
                                    duration: 300
                                }
                            }
                        }
                    }
                }

                MouseArea {
                    id: heroMa
                    anchors.fill: centralCore
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: batCanvas.requestPaint()
                    onExited: batCanvas.requestPaint()
                }
            }

        ColumnLayout {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 25
            spacing: 15
            transform: Translate {
                y: 20 * (1.0 - introState)
            }
            opacity: introState

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 60
                    radius: 14
                    color: "#05ffffff"
                    border.color: "#1affffff"
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 12

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 15

                            Item {
                                Layout.preferredWidth: 32
                                Layout.preferredHeight: 32
                                Text {
                                    anchors.centerIn: parent
                                    text: window.sysBrightness > 66 ? "󰃠" : (window.sysBrightness > 33 ? "󰃟" : "󰃞")
                                    font.family: "Iosevka Nerd Font"
                                    font.pixelSize: 22
                                    color: window.ambientPrimary
                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 200
                                        }
                                    }
                                }
                            }

                            Item {
                                Layout.fillWidth: true
                                height: 18

                                Timer {
                                    id: briCmdThrottle
                                    interval: 50
                                    property int targetPct: -1
                                    onTriggered: {
                                        if (targetPct >= 0) {
                                            Quickshell.execDetached(["bash", window.brightnessScript, "set", targetPct]);
                                            targetPct = -1;
                                        }
                                    }
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 9
                                    color: "#0dffffff"
                                    border.color: "#1affffff"
                                    border.width: 1
                                    clip: true

                                    Rectangle {
                                        height: parent.height
                                        width: parent.width * (window.sysBrightness / 100)
                                        radius: 9
                                        opacity: briMa.containsMouse ? 1.0 : 0.85
                                        Behavior on opacity {
                                            NumberAnimation {
                                                duration: 200
                                            }
                                        }
                                        Behavior on width {
                                            enabled: !window.isDraggingBri
                                            NumberAnimation {
                                                duration: 150
                                                easing.type: Easing.OutQuart
                                            }
                                        }

                                        gradient: Gradient {
                                            orientation: Gradient.Horizontal
                                            GradientStop {
                                                position: 0.0
                                                color: window.batColorStart
                                                Behavior on color {
                                                    ColorAnimation {
                                                        duration: 300
                                                    }
                                                }
                                            }
                                            GradientStop {
                                                position: 1.0
                                                color: window.batColorEnd
                                                Behavior on color {
                                                    ColorAnimation {
                                                        duration: 300
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                                MouseArea {
                                    id: briMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onPressed: mouse => {
                                        briSyncDelay.stop();
                                        window.isDraggingBri = true;
                                        updateBri(mouse.x);
                                    }
                                    onPositionChanged: mouse => {
                                        if (pressed)
                                            updateBri(mouse.x);
                                    }
                                    onReleased: {
                                        briSyncDelay.restart();
                                    }

                                    function updateBri(mx) {
                                        let pct = Math.max(0, Math.min(100, Math.round((mx / width) * 100)));
                                        window.sysBrightness = pct;
                                        briCmdThrottle.targetPct = pct;
                                        if (!briCmdThrottle.running)
                                            briCmdThrottle.start();
                                    }
                                }
                            }
                        }

                        }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 54
                    radius: 14
                    color: "#0dffffff"
                    border.color: "#1affffff"
                    border.width: 1

                    Rectangle {
                        id: sliderPill
                        width: (parent.width - 2) / 3
                        height: parent.height - 2
                        y: 1
                        radius: 10
                        x: {
                            if (window.powerProfile === "performance")
                                return 1;
                            if (window.powerProfile === "balanced")
                                return width + 1;
                            return (width * 2) + 1;
                        }

                        Behavior on x {
                            NumberAnimation {
                                duration: 400
                                easing.type: Easing.OutBack
                                easing.overshoot: 1.2
                            }
                        }

                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop {
                                position: 0.0
                                color: window.profileStart
                                Behavior on color {
                                    ColorAnimation {
                                        duration: 400
                                    }
                                }
                            }
                            GradientStop {
                                position: 1.0
                                color: window.profileEnd
                                Behavior on color {
                                    ColorAnimation {
                                        duration: 400
                                    }
                                }
                            }
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        spacing: 0

                        Repeater {
                            model: ListModel {
                                ListElement {
                                    name: "performance"
                                    icon: "󰓅"
                                    label: "Perform"
                                }
                                ListElement {
                                    name: "balanced"
                                    icon: "󰗑"
                                    label: "Balance"
                                }
                                ListElement {
                                    name: "power-saver"
                                    icon: "󰌪"
                                    label: "Saver"
                                }
                            }

                            delegate: Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 8
                                    Text {
                                        font.family: "Iosevka Nerd Font"
                                        font.pixelSize: 18
                                        color: window.powerProfile === name ? window.crust : (profileMa.containsMouse ? window.text : window.subtext0)
                                        text: icon
                                        Behavior on color {
                                            ColorAnimation {
                                                duration: 200
                                            }
                                        }
                                    }
                                    Text {
                                        font.family: window.textFont
                                        font.weight: Font.Black
                                        font.pixelSize: 13
                                        color: window.powerProfile === name ? window.crust : (profileMa.containsMouse ? window.text : window.subtext0)
                                        text: label
                                        Behavior on color {
                                            ColorAnimation {
                                                duration: 200
                                            }
                                        }
                                    }
                                }

                                MouseArea {
                                    id: profileMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        Quickshell.execDetached(["powerprofilesctl", "set", name]);
                                        sysPoller.running = true;
                                    }
                                }
                            }
                        }
                    }
                }
        }
    }
}
