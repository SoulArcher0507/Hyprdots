//@ pragma UseQApplication
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import QtCore
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import Quickshell.Services.UPower
import Qt.labs.platform 1.1

ShellRoot {
    id: root

    readonly property string textFont: "Fira Sans Semibold"
    readonly property string iconFont: "CaskaydiaMono Nerd Font"
    readonly property string monoFont: "JetBrains Mono"

    property var _j: ({
            special: {
                background: "#222222",
                foreground: "#cccccc"
            },
            colors: {
                color0: "#111111",
                color1: "#dc2f2f",
                color2: "#98c379",
                color3: "#d19a66",
                color4: "#61afef",
                color5: "#c678dd",
                color6: "#56b6c2",
                color7: "#abb2bf",
                color8: "#3e4451",
                color9: "#e06c75",
                color10: "#98c379",
                color11: "#d19a66",
                color12: "#61afef",
                color13: "#c678dd",
                color14: "#56b6c2",
                color15: "#ffffff"
            },
            quickshell: {
                bg: "",
                fg: "",
                accent: "",
                accent2: "",
                success: "",
                warning: "",
                danger: "",
                muted: ""
            }
        })

    property FileView _colorFile: FileView {
        path: StandardPaths.writableLocation(StandardPaths.ConfigLocation) + "/quickshell/colors.json"
        watchChanges: true
        Component.onCompleted: this.reload()
        onFileChanged: this.reload()
        onLoaded: root._applyColors(this.text())
    }

    function _applyColors(txt) {
        if (!txt || txt === "")
            return;
        try {
            const parsed = JSON.parse(txt);
            function pick(a, b) {
                return (b !== undefined && b !== null && b !== "") ? b : a;
            }
            const s = parsed.special || {};
            const c = parsed.colors || {};
            const q = parsed.quickshell || {};
            _j = {
                special: {
                    background: pick(_j.special.background, s.background),
                    foreground: pick(_j.special.foreground, s.foreground)
                },
                colors: {
                    color0: pick(_j.colors.color0, c.color0),
                    color1: pick(_j.colors.color1, c.color1),
                    color2: pick(_j.colors.color2, c.color2),
                    color3: pick(_j.colors.color3, c.color3),
                    color4: pick(_j.colors.color4, c.color4),
                    color5: pick(_j.colors.color5, c.color5),
                    color6: pick(_j.colors.color6, c.color6),
                    color7: pick(_j.colors.color7, c.color7),
                    color8: pick(_j.colors.color8, c.color8),
                    color9: pick(_j.colors.color9, c.color9),
                    color10: pick(_j.colors.color10, c.color10),
                    color11: pick(_j.colors.color11, c.color11),
                    color12: pick(_j.colors.color12, c.color12),
                    color13: pick(_j.colors.color13, c.color13),
                    color14: pick(_j.colors.color14, c.color14),
                    color15: pick(_j.colors.color15, c.color15)
                },
                quickshell: {
                    bg: pick(_j.quickshell.bg, q.bg),
                    fg: pick(_j.quickshell.fg, q.fg),
                    accent: pick(_j.quickshell.accent, q.accent),
                    accent2: pick(_j.quickshell.accent2, q.accent2),
                    success: pick(_j.quickshell.success, q.success),
                    warning: pick(_j.quickshell.warning, q.warning),
                    danger: pick(_j.quickshell.danger, q.danger),
                    muted: pick(_j.quickshell.muted, q.muted)
                }
            };
        } catch (e) {
            console.warn("LockScreen: colors.json parse error:", e);
        }
    }

    function _toRgb(x) {
        if (typeof x === "string") {
            let s = x.trim();
            if (s[0] === "#")
                s = s.slice(1);
            if (s.length === 3)
                s = s.split("").map(ch => ch + ch).join("");
            if (s.length === 8)
                s = s.slice(2);
            return {
                r: parseInt(s.slice(0, 2), 16) / 255,
                g: parseInt(s.slice(2, 4), 16) / 255,
                b: parseInt(s.slice(4, 6), 16) / 255
            };
        } else if (x && x.r !== undefined) {
            return {
                r: x.r,
                g: x.g,
                b: x.b
            };
        }
        return {
            r: 0,
            g: 0,
            b: 0
        };
    }

    function _pick(deflt) {
        for (let i = 1; i < arguments.length; ++i) {
            const v = arguments[i];
            if (v !== undefined && v !== null && v !== "")
                return v;
        }
        return deflt;
    }

    function mix(a, b, t) {
        const A = _toRgb(a), B = _toRgb(b);
        const k = Math.max(0, Math.min(1, t));
        return Qt.rgba(A.r * (1 - k) + B.r * k, A.g * (1 - k) + B.g * k, A.b * (1 - k) + B.b * k, 1.0);
    }

    function surface(level) {
        return mix(bg, fg, Math.max(0, Math.min(1, level)));
    }

    function alpha(c, a) {
        const rgb = _toRgb(c);
        return Qt.rgba(rgb.r || 0, rgb.g || 0, rgb.b || 0, (a === undefined || a === null) ? 1.0 : a);
    }

    readonly property color bg: _pick("#222222", _j?.quickshell?.bg, _j?.special?.background)
    readonly property color fg: _pick("#cccccc", _j?.quickshell?.fg, _j?.special?.foreground)

    readonly property color c0: _pick("#111111", _j?.colors?.color0)
    readonly property color c1: _pick("#dc2f2f", _j?.colors?.color1)
    readonly property color c2: _pick("#98c379", _j?.colors?.color2)
    readonly property color c3: _pick("#d19a66", _j?.colors?.color3)
    readonly property color c4: _pick("#61afef", _j?.colors?.color4)
    readonly property color c5: _pick("#c678dd", _j?.colors?.color5)
    readonly property color c6: _pick("#56b6c2", _j?.colors?.color6)
    readonly property color c7: _pick("#abb2bf", _j?.colors?.color7)
    readonly property color c8: _pick("#3e4451", _j?.colors?.color8)
    readonly property color c13: _pick("#c678dd", _j?.colors?.color13)

    readonly property color accentClr: _pick(c4, _j?.quickshell?.accent)
    readonly property color accent2Clr: _pick(c6, _j?.quickshell?.accent2)
    readonly property color successClr: _pick(c2, _j?.quickshell?.success)
    readonly property color warningClr: _pick(c3, _j?.quickshell?.warning)
    readonly property color dangerClr: _pick(c1, _j?.quickshell?.danger)
    readonly property color mutedClr: _pick(c8, _j?.quickshell?.muted)

    readonly property color base: surface(0.10)
    readonly property color mantle: surface(0.05)
    readonly property color crust: bg
    readonly property color text: fg
    readonly property color subtext0: mix(bg, fg, 0.6)
    readonly property color overlay0: mix(bg, fg, 0.3)
    readonly property color overlay1: mix(bg, fg, 0.4)
    readonly property color surface0: surface(0.06)
    readonly property color surface1: surface(0.08)
    readonly property color surface2: surface(0.12)
    readonly property color surfLow: surface(0.06)
    readonly property color surfMid: surface(0.10)
    readonly property color surfHigh: surface(0.15)

    readonly property color mauve: c5
    readonly property color pink: c13
    readonly property color sapphire: c4
    readonly property color blue: accentClr
    readonly property color red: dangerClr
    readonly property color maroon: c1
    readonly property color peach: warningClr
    readonly property color yellow: c3
    readonly property color green: successClr
    readonly property color teal: c6

    readonly property color panelBorderColor: mix(bg, fg, 0.35)

    Component.onCompleted: {
        Qt.application.organization = "Quickshell";
        Qt.application.domain = "quickshell.org";
    }

    Settings {
        id: lockSettings
        category: "QuickshellLockscreen"
        property bool hidePassword: false
        property int revealDuration: 300
    }

    QtObject {
        id: lockUI
        property bool failed: false
        property bool authenticating: false
        property string statusText: "Locked"
    }

    PamContext {
        id: pam

        Component.onCompleted: pam.start()

        onCompleted: result => {
            lockUI.authenticating = false;
            if (result === PamResult.Success) {
                rootLock.locked = false;
                Qt.quit();
            } else {
                lockUI.failed = true;
                lockUI.statusText = "Access Denied";
                pam.start();
            }
        }
    }

    Process {
        id: suspendProcess
        command: ["systemctl", "suspend"]
    }

    Process {
        id: poweroffProcess
        command: ["systemctl", "poweroff"]
    }

    Process {
        id: reloadProcess
        command: ["systemctl", "reboot"]
    }

    WlSessionLock {
        id: rootLock
        locked: true

        WlSessionLockSurface {
            id: surface

            Item {
                id: screenRoot
                anchors.fill: parent

                property string staticWallpaperPath: "file://" + Quickshell.env("HOME") + "/Pictures/Wallpapers/active/active.jpg"

                readonly property bool hasBattery: UPower.displayDevice.ready && UPower.displayDevice.isLaptopBattery && UPower.displayDevice.isPresent

                property string batPct: "100"
                property string batStatus: "AC"
                property string currentUser: "User"
                property string faceIconPath: "file://" + Quickshell.env("HOME") + "/Pictures/Wallpapers/active/active_square.jpg"
                property string kbLayout: "US"
                property string weatherIcon: ""
                property string weatherTemp: "--°C"

                property real introState: 0.0
                property bool powerMenuOpen: false
                property bool inputActive: false
                property bool isPlayingIntro: true

                Component.onCompleted: {
                    introSequence.start();
                }

                property real globalOrbitAngle: 0
                NumberAnimation on globalOrbitAngle {
                    from: 0
                    to: Math.PI * 2
                    duration: 90000
                    loops: Animation.Infinite
                    running: true
                }

                Timer {
                    id: idleTimer
                    interval: 15000
                    running: screenRoot.inputActive && inputField.text.length === 0
                    repeat: false
                    onTriggered: screenRoot.inputActive = false
                }

                Process {
                    id: userPoller
                    command: ["bash", "-c", "USER_VAR=$(whoami); ICON_PATH=\"\"; if [ -f ~/.face.icon ]; then ICON_PATH=$(readlink -f ~/.face.icon); elif [ -f ~/.face ]; then ICON_PATH=$(readlink -f ~/.face); fi; echo -n \"$USER_VAR|$ICON_PATH\""]
                    stdout: StdioCollector {
                        onStreamFinished: {
                            let parts = this.text.trim().split("|");
                            if (parts.length > 0 && parts[0] !== "")
                                screenRoot.currentUser = parts[0];
                            if (parts.length > 1 && parts[1].trim() !== "") {
                                let path = parts[1].trim();
                                screenRoot.faceIconPath = path.startsWith("file://") ? path : "file://" + path;
                            }
                        }
                    }
                    Component.onCompleted: running = true
                }

                Process {
                    id: kbPoller
                    command: ["bash", "-c", "hyprctl devices -j | jq -r '.keyboards[] | select(.main == true) | .active_keymap' | head -n1 | cut -c1-2 | tr '[:lower:]' '[:upper:]'"]
                    stdout: StdioCollector {
                        onStreamFinished: {
                            let layout = this.text.trim();
                            if (layout !== "" && layout !== "null") {
                                screenRoot.kbLayout = layout;
                            }
                        }
                    }
                }
                Timer {
                    interval: 150
                    running: true
                    repeat: true
                    triggeredOnStart: true
                    onTriggered: kbPoller.running = true
                }

                Process {
                    id: batPoller
                    command: ["bash", "-c", "cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -n1 || echo '100'; cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -n1 || echo 'AC'"]
                    stdout: StdioCollector {
                        onStreamFinished: {
                            let lines = this.text.trim().split("\n");
                            if (lines.length >= 2) {
                                screenRoot.batPct = lines[0] || "100";
                                screenRoot.batStatus = lines[1] || "Unknown";
                            }
                        }
                    }
                }
                Timer {
                    interval: 5000
                    running: screenRoot.hasBattery
                    repeat: true
                    triggeredOnStart: true
                    onTriggered: batPoller.running = true
                }

                Process {
                    id: weatherPoller
                    property string scriptPath: Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/calendar/weather.sh"
                    command: ["bash", "-c", '"' + scriptPath + '" --current-icon; "' + scriptPath + '" --current-temp']
                    stdout: StdioCollector {
                        onStreamFinished: {
                            let lines = this.text.trim().split("\n");
                            if (lines.length >= 2) {
                                screenRoot.weatherIcon = lines[0] || "";
                                screenRoot.weatherTemp = lines[1] || "--°C";
                            }
                        }
                    }
                }
                Timer {
                    interval: 900000
                    running: true
                    repeat: true
                    triggeredOnStart: true
                    onTriggered: weatherPoller.running = true
                }

                Rectangle {
                    anchors.fill: parent
                    color: root.bg
                }

                Image {
                    id: bgWallpaper
                    anchors.fill: parent
                    source: screenRoot.staticWallpaperPath
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: false
                    cache: false
                }

                MultiEffect {
                    source: bgWallpaper
                    anchors.fill: bgWallpaper
                    blurEnabled: true
                    blurMax: 64
                    blur: 1.0
                }

                Rectangle {
                    id: dimmer
                    anchors.fill: parent
                    color: "black"
                    opacity: 0.25
                }

                Item {
                    anchors.fill: parent

                    Rectangle {
                        width: parent.width * 0.8
                        height: width
                        radius: width / 2
                        x: (parent.width / 2 - width / 2) + Math.cos(screenRoot.globalOrbitAngle * 2) * 200
                        y: (parent.height / 2 - height / 2) + Math.sin(screenRoot.globalOrbitAngle * 2) * 150
                        scale: 1.0 + Math.sin(screenRoot.globalOrbitAngle * 6) * 0.05
                        opacity: screenRoot.inputActive ? 0.04 : 0.08
                        color: root.accentClr
                        Behavior on color {
                            ColorAnimation {
                                duration: 1000
                            }
                        }
                        Behavior on opacity {
                            NumberAnimation {
                                duration: 600
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width * 0.9
                        height: width
                        radius: width / 2
                        x: (parent.width / 2 - width / 2) + Math.sin(screenRoot.globalOrbitAngle * 1.5) * -200
                        y: (parent.height / 2 - height / 2) + Math.cos(screenRoot.globalOrbitAngle * 1.5) * -150
                        scale: 1.0 + Math.cos(screenRoot.globalOrbitAngle * 5) * 0.05
                        opacity: screenRoot.inputActive ? 0.03 : 0.06
                        color: root.accent2Clr
                        Behavior on color {
                            ColorAnimation {
                                duration: 1000
                            }
                        }
                        Behavior on opacity {
                            NumberAnimation {
                                duration: 600
                            }
                        }
                    }

                    Item {
                        anchors.fill: parent
                        opacity: screenRoot.introState
                        scale: 1.1 - (0.1 * screenRoot.introState)

                        Repeater {
                            model: 4
                            Rectangle {
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: -40
                                width: 400 + (index * 220)
                                height: width
                                radius: width / 2
                                color: "transparent"
                                border.color: lockUI.failed ? root.dangerClr : root.fg
                                border.width: 1
                                opacity: lockUI.failed ? (0.1 - (index * 0.02)) : (screenRoot.inputActive ? (0.02 - (index * 0.005)) : (0.04 - (index * 0.01)))
                                Behavior on border.color {
                                    ColorAnimation {
                                        duration: 600
                                        easing.type: Easing.OutExpo
                                    }
                                }
                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 600
                                        easing.type: Easing.OutExpo
                                    }
                                }
                            }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: !screenRoot.isPlayingIntro
                    onClicked: {
                        if (screenRoot.powerMenuOpen)
                            screenRoot.powerMenuOpen = false;
                        if (!screenRoot.inputActive)
                            screenRoot.inputActive = true;
                        inputField.forceActiveFocus();
                    }
                }

                Item {
                    anchors.fill: parent
                    opacity: screenRoot.introState
                    transform: Translate {
                        y: 30 * (1.0 - screenRoot.introState)
                    }

                    ColumnLayout {
                        id: clockModule
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: screenRoot.inputActive ? -120 : -40
                        spacing: -10

                        opacity: screenRoot.inputActive ? 0.0 : 1.0
                        scale: screenRoot.inputActive ? 0.9 : 1.0
                        visible: opacity > 0.01

                        Behavior on anchors.verticalCenterOffset {
                            NumberAnimation {
                                duration: 600
                                easing.type: Easing.OutExpo
                            }
                        }
                        Behavior on opacity {
                            NumberAnimation {
                                duration: 400
                                easing.type: Easing.OutCubic
                            }
                        }
                        Behavior on scale {
                            NumberAnimation {
                                duration: 500
                                easing.type: Easing.OutBack
                            }
                        }

                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 0

                            Text {
                                id: clockHours
                                font.family: root.monoFont
                                font.pixelSize: 140
                                font.weight: Font.Bold
                                color: root.fg
                                Behavior on color {
                                    ColorAnimation {
                                        duration: 300
                                    }
                                }
                            }
                            Text {
                                text: ":"
                                font.family: root.monoFont
                                font.pixelSize: 140
                                font.weight: Font.Bold
                                opacity: 0.5
                                color: root.fg
                                Behavior on color {
                                    ColorAnimation {
                                        duration: 300
                                    }
                                }
                            }
                            Text {
                                id: clockMinutes
                                font.family: root.monoFont
                                font.pixelSize: 140
                                font.weight: Font.Bold
                                color: root.fg
                                Behavior on color {
                                    ColorAnimation {
                                        duration: 300
                                    }
                                }
                            }
                        }

                        Text {
                            id: dateText
                            Layout.alignment: Qt.AlignHCenter
                            font.family: root.textFont
                            font.pixelSize: 22
                            font.weight: Font.Bold
                            color: root.fg
                        }

                        Timer {
                            interval: 1000
                            running: true
                            repeat: true
                            triggeredOnStart: true
                            onTriggered: {
                                let d = new Date();
                                clockHours.text = Qt.formatDateTime(d, "hh");
                                clockMinutes.text = Qt.formatDateTime(d, "mm");
                                dateText.text = Qt.formatDateTime(d, "dddd, MMMM dd");
                            }
                        }
                    }

                    RowLayout {
                        id: authModule
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: screenRoot.inputActive ? -40 : 40
                        spacing: 32

                        opacity: screenRoot.inputActive ? 1.0 : 0.0
                        scale: screenRoot.inputActive ? 1.0 : 0.9
                        visible: opacity > 0.01

                        Behavior on anchors.verticalCenterOffset {
                            NumberAnimation {
                                duration: 600
                                easing.type: Easing.OutExpo
                            }
                        }
                        Behavior on opacity {
                            NumberAnimation {
                                duration: 400
                                easing.type: Easing.OutCubic
                            }
                        }
                        Behavior on scale {
                            NumberAnimation {
                                duration: 500
                                easing.type: Easing.OutBack
                            }
                        }

                        Item {
                            Layout.alignment: Qt.AlignVCenter
                            width: 170
                            height: 170

                            Rectangle {
                                id: avatarMask
                                anchors.fill: parent
                                radius: 85
                                color: "black"
                                visible: false
                                layer.enabled: true
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: 85
                                color: root.alpha(root.surfLow, 0.5)
                                visible: avatarImg.status !== Image.Ready

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰄽"
                                    font.family: root.iconFont
                                    font.pixelSize: 64
                                    color: root.mutedClr
                                }
                            }

                            Image {
                                id: avatarImg
                                anchors.fill: parent
                                source: screenRoot.faceIconPath !== "" ? screenRoot.faceIconPath : ""
                                fillMode: Image.PreserveAspectCrop
                                visible: false
                                cache: false
                                asynchronous: true
                            }

                            MultiEffect {
                                source: avatarImg
                                anchors.fill: avatarImg
                                maskEnabled: true
                                maskSource: avatarMask
                                visible: avatarImg.status === Image.Ready
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: 85
                                color: "transparent"
                                border.color: lockUI.failed ? root.dangerClr : (lockUI.authenticating ? root.warningClr : root.alpha(root.fg, 0.5))
                                border.width: 3
                                Behavior on border.color {
                                    ColorAnimation {
                                        duration: 300
                                    }
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 16

                            Text {
                                Layout.alignment: Qt.AlignLeft
                                text: screenRoot.currentUser
                                font.family: root.textFont
                                font.pixelSize: 28
                                font.weight: Font.Bold
                                color: root.fg
                            }

                            RowLayout {
                                Layout.alignment: Qt.AlignLeft
                                spacing: 12

                                Rectangle {
                                    width: 36
                                    height: 36
                                    radius: 18
                                    color: lockUI.failed ? root.alpha(root.dangerClr, 0.2) : (lockUI.authenticating ? root.alpha(root.warningClr, 0.2) : root.alpha(root.accentClr, 0.15))
                                    border.color: lockUI.failed ? root.dangerClr : (lockUI.authenticating ? root.warningClr : root.accentClr)
                                    border.width: 1
                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 300
                                        }
                                    }
                                    Behavior on border.color {
                                        ColorAnimation {
                                            duration: 300
                                        }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: lockUI.failed ? "󰌾" : (lockUI.authenticating ? "󰌿" : "󰌾")
                                        font.family: root.iconFont
                                        font.pixelSize: 18
                                        color: lockUI.failed ? root.dangerClr : (lockUI.authenticating ? root.warningClr : root.accentClr)
                                        Behavior on color {
                                            ColorAnimation {
                                                duration: 300
                                            }
                                        }
                                    }
                                }

                                Text {
                                    font.family: root.textFont
                                    font.pixelSize: 14
                                    font.weight: Font.Medium
                                    font.letterSpacing: 2.0
                                    color: lockUI.failed ? root.dangerClr : (lockUI.authenticating ? root.warningClr : root.fg)
                                    text: lockUI.statusText.toUpperCase()
                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 300
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                id: pinPill
                                Layout.alignment: Qt.AlignLeft
                                width: 280
                                height: 60
                                radius: 30
                                clip: true

                                color: lockUI.failed ? root.alpha(root.dangerClr, 0.1) : root.alpha(root.surfLow, 0.5)
                                border.width: 2
                                border.color: {
                                    if (lockUI.failed)
                                        return root.dangerClr;
                                    if (lockUI.authenticating)
                                        return root.warningClr;
                                    if (inputField.text.length > 0)
                                        return root.fg;
                                    return root.alpha(root.fg, 0.08);
                                }

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 250
                                        easing.type: Easing.OutExpo
                                    }
                                }
                                Behavior on border.color {
                                    ColorAnimation {
                                        duration: 250
                                        easing.type: Easing.OutExpo
                                    }
                                }

                                scale: lockUI.failed ? 1.05 : (lockUI.authenticating ? 0.98 : 1.0)
                                Behavior on scale {
                                    NumberAnimation {
                                        duration: 300
                                        easing.type: Easing.OutBack
                                    }
                                }

                                transform: Translate {
                                    id: shakeTranslate
                                    x: 0
                                }

                                SequentialAnimation {
                                    id: shakeAnim
                                    NumberAnimation {
                                        target: shakeTranslate
                                        property: "x"
                                        from: 0
                                        to: -8
                                        duration: 120
                                        easing.type: Easing.InOutSine
                                    }
                                    NumberAnimation {
                                        target: shakeTranslate
                                        property: "x"
                                        from: -8
                                        to: 8
                                        duration: 120
                                        easing.type: Easing.InOutSine
                                    }
                                    NumberAnimation {
                                        target: shakeTranslate
                                        property: "x"
                                        from: 8
                                        to: 0
                                        duration: 120
                                        easing.type: Easing.InOutSine
                                    }
                                }

                                Connections {
                                    target: lockUI
                                    function onFailedChanged() {
                                        if (lockUI.failed)
                                            shakeAnim.restart();
                                    }
                                }

                                TextInput {
                                    id: inputField
                                    anchors.fill: parent
                                    opacity: 0
                                    echoMode: TextInput.Password
                                    enabled: !screenRoot.isPlayingIntro

                                    property string oldText: ""

                                    Component.onCompleted: forceActiveFocus()

                                    onActiveFocusChanged: {
                                        if (!activeFocus && !screenRoot.powerMenuOpen && !screenRoot.isPlayingIntro) {
                                            forceActiveFocus();
                                        }
                                    }

                                    Keys.onPressed: event => {
                                        if (event.key === Qt.Key_Escape) {
                                            screenRoot.inputActive = false;
                                            text = "";
                                            passModel.clear();
                                            event.accepted = true;
                                        } else if (!screenRoot.inputActive) {
                                            screenRoot.inputActive = true;
                                        }
                                    }

                                    onAccepted: {
                                        if (text.length > 0 && pam.responseRequired && !lockUI.authenticating) {
                                            lockUI.authenticating = true;
                                            lockUI.statusText = "Authenticating...";
                                            lockUI.failed = false;
                                            pam.respond(text);
                                            text = "";
                                            oldText = "";
                                            passModel.clear();
                                        }
                                    }

                                    onTextChanged: {
                                        if (lockUI.authenticating)
                                            return;

                                        if (text.length > 0 && !screenRoot.inputActive) {
                                            screenRoot.inputActive = true;
                                        }

                                        idleTimer.restart();

                                        if (text !== oldText) {
                                            if (text.length > oldText.length) {
                                                for (let i = oldText.length; i < text.length; i++) {
                                                    passModel.append({
                                                        "charStr": text.charAt(i),
                                                        "isDot": lockSettings.hidePassword
                                                    });
                                                }
                                            } else if (text.length < oldText.length) {
                                                let diff = oldText.length - text.length;
                                                for (let i = 0; i < diff; i++) {
                                                    passModel.remove(passModel.count - 1);
                                                }
                                            } else {
                                                passModel.clear();
                                                for (let i = 0; i < text.length; i++) {
                                                    passModel.append({
                                                        "charStr": text.charAt(i),
                                                        "isDot": lockSettings.hidePassword
                                                    });
                                                }
                                            }
                                            oldText = text;
                                        }

                                        if (text.length > 0) {
                                            lockUI.failed = false;
                                            lockUI.statusText = "Enter Password";
                                        } else {
                                            if (!lockUI.failed)
                                                lockUI.statusText = "Locked";
                                        }
                                    }
                                }

                                ListModel {
                                    id: passModel
                                }

                                Item {
                                    anchors.fill: parent
                                    anchors.leftMargin: 20
                                    anchors.rightMargin: 20
                                    clip: true

                                    Row {
                                        id: dotRow
                                        anchors.verticalCenter: parent.verticalCenter
                                        x: width > parent.width ? parent.width - width : (parent.width - width) / 2
                                        spacing: 4

                                        Behavior on x {
                                            NumberAnimation {
                                                duration: 150
                                                easing.type: Easing.OutQuad
                                            }
                                        }

                                        Repeater {
                                            model: passModel
                                            delegate: Item {
                                                width: charText.implicitWidth
                                                height: 30

                                                Timer {
                                                    interval: lockSettings.revealDuration
                                                    running: !model.isDot && !lockSettings.hidePassword
                                                    onTriggered: {
                                                        if (index >= 0 && index < passModel.count) {
                                                            passModel.setProperty(index, "isDot", true);
                                                        }
                                                    }
                                                }

                                                Text {
                                                    id: charText
                                                    anchors.centerIn: parent
                                                    text: model.isDot ? "•" : model.charStr
                                                    font.family: root.monoFont
                                                    font.pixelSize: model.isDot ? 32 : 24
                                                    font.weight: Font.Bold
                                                    color: lockUI.failed ? root.dangerClr : (lockUI.authenticating ? root.warningClr : root.fg)

                                                    NumberAnimation on opacity {
                                                        from: 0
                                                        to: 1
                                                        duration: 150
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

                RowLayout {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 40
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 16

                    opacity: screenRoot.introState
                    transform: Translate {
                        y: 20 * (1.0 - screenRoot.introState)
                    }

                    Rectangle {
                        property bool isHovered: kbMouse.containsMouse
                        Layout.preferredHeight: 48
                        Layout.preferredWidth: kbLayoutRow.implicitWidth + 36
                        radius: 24

                        color: isHovered ? root.alpha(root.surfMid, 0.6) : root.alpha(root.surfLow, 0.4)
                        border.color: isHovered ? root.accentClr : root.alpha(root.fg, 0.08)
                        border.width: 1

                        scale: isHovered ? 1.05 : 1.0
                        Behavior on scale {
                            NumberAnimation {
                                duration: 250
                                easing.type: Easing.OutExpo
                            }
                        }
                        Behavior on color {
                            ColorAnimation {
                                duration: 200
                            }
                        }
                        Behavior on border.color {
                            ColorAnimation {
                                duration: 200
                            }
                        }

                        RowLayout {
                            id: kbLayoutRow
                            anchors.centerIn: parent
                            spacing: 8
                            Text {
                                text: "󰌌"
                                font.family: root.iconFont
                                font.pixelSize: 18
                                color: parent.parent.isHovered ? root.accentClr : root.mutedClr
                                Behavior on color {
                                    ColorAnimation {
                                        duration: 200
                                    }
                                }
                            }
                            Text {
                                text: screenRoot.kbLayout
                                font.family: "Fira Sans"
                                font.pixelSize: 14
                                font.weight: Font.Black
                                color: root.fg
                            }
                        }
                        MouseArea {
                            id: kbMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: !screenRoot.isPlayingIntro
                        }
                    }

                    Rectangle {
                        visible: screenRoot.hasBattery
                        property bool isHovered: batMouse.containsMouse
                        Layout.preferredHeight: 48
                        Layout.preferredWidth: batLayoutRow.implicitWidth + 36
                        radius: 24

                        color: isHovered ? root.alpha(root.surfMid, 0.6) : root.alpha(root.surfLow, 0.4)
                        border.color: isHovered ? batLayoutRow.dynamicBatColor : root.alpha(root.fg, 0.08)
                        border.width: 1

                        scale: isHovered ? 1.05 : 1.0
                        Behavior on scale {
                            NumberAnimation {
                                duration: 250
                                easing.type: Easing.OutExpo
                            }
                        }
                        Behavior on color {
                            ColorAnimation {
                                duration: 200
                            }
                        }
                        Behavior on border.color {
                            ColorAnimation {
                                duration: 200
                            }
                        }

                        RowLayout {
                            id: batLayoutRow
                            anchors.centerIn: parent
                            spacing: 8

                            property color dynamicBatColor: {
                                if (screenRoot.batStatus === "Charging")
                                    return root.successClr;
                                let pct = parseInt(screenRoot.batPct);
                                if (pct >= 60)
                                    return root.successClr;
                                if (pct >= 25)
                                    return root.warningClr;
                                return root.dangerClr;
                            }

                            Text {
                                text: screenRoot.batStatus === "Charging" ? "󰂄" : (parseInt(screenRoot.batPct) < 20 ? "󰂃" : "󰁹")
                                font.family: root.iconFont
                                font.pixelSize: 20
                                color: batLayoutRow.dynamicBatColor
                                Behavior on color {
                                    ColorAnimation {
                                        duration: 200
                                    }
                                }
                            }
                            Text {
                                text: screenRoot.batPct + "%"
                                font.family: "Fira Sans"
                                font.pixelSize: 14
                                font.weight: Font.Black
                                color: batLayoutRow.dynamicBatColor
                                Behavior on color {
                                    ColorAnimation {
                                        duration: 200
                                    }
                                }
                            }
                        }
                        MouseArea {
                            id: batMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: !screenRoot.isPlayingIntro
                        }
                    }

                    Rectangle {
                        property bool isHovered: weatherMouse.containsMouse
                        Layout.preferredHeight: 48
                        Layout.preferredWidth: weatherLayoutRow.implicitWidth + 36
                        radius: 24

                        color: isHovered ? root.alpha(root.surfMid, 0.6) : root.alpha(root.surfLow, 0.4)
                        border.color: isHovered ? root.accent2Clr : root.alpha(root.fg, 0.08)
                        border.width: 1

                        scale: isHovered ? 1.05 : 1.0
                        Behavior on scale {
                            NumberAnimation {
                                duration: 250
                                easing.type: Easing.OutExpo
                            }
                        }
                        Behavior on color {
                            ColorAnimation {
                                duration: 200
                            }
                        }
                        Behavior on border.color {
                            ColorAnimation {
                                duration: 200
                            }
                        }

                        RowLayout {
                            id: weatherLayoutRow
                            anchors.centerIn: parent
                            spacing: 8
                            Text {
                                text: screenRoot.weatherIcon
                                font.family: root.iconFont
                                font.pixelSize: 20
                                color: parent.parent.isHovered ? root.accent2Clr : root.fg
                                Behavior on color {
                                    ColorAnimation {
                                        duration: 200
                                    }
                                }
                            }
                            Text {
                                text: screenRoot.weatherTemp
                                font.family: "Fira Sans"
                                font.pixelSize: 14
                                font.weight: Font.Black
                                color: root.fg
                                Behavior on color {
                                    ColorAnimation {
                                        duration: 200
                                    }
                                }
                            }
                        }
                        MouseArea {
                            id: weatherMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: !screenRoot.isPlayingIntro
                        }
                    }
                }

                Rectangle {
                    id: powerMenu
                    anchors.bottom: powerBtn.top
                    anchors.right: parent.right
                    anchors.bottomMargin: 15
                    anchors.rightMargin: 40
                    width: 280
                    height: screenRoot.powerMenuOpen ? (menuLayout.implicitHeight + 20) : 0
                    radius: 18
                    clip: true
                    opacity: screenRoot.powerMenuOpen ? 1 : 0

                    color: root.alpha(root.surfLow, 0.95)
                    border.color: root.alpha(root.accentClr, 0.25)
                    border.width: 1

                    Behavior on height {
                        NumberAnimation {
                            duration: 350
                            easing.type: Easing.OutExpo
                        }
                    }
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 250
                        }
                    }

                    ColumnLayout {
                        id: menuLayout
                        anchors.top: parent.top
                        anchors.topMargin: 10
                        anchors.left: parent.left
                        anchors.right: parent.right
                        spacing: 6

                        Text {
                            text: "SETTINGS"
                            font.family: root.textFont
                            font.weight: Font.Black
                            font.pixelSize: 12
                            font.letterSpacing: 1.5
                            color: root.accentClr
                            Layout.leftMargin: 18
                            Layout.topMargin: 4
                            Layout.bottomMargin: 4
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: 18
                            Layout.rightMargin: 18
                            Layout.topMargin: 4
                            Text {
                                text: "Hide password"
                                font.family: root.textFont
                                font.pixelSize: 14
                                font.weight: Font.Medium
                                color: root.fg
                                Layout.fillWidth: true
                            }

                            Rectangle {
                                width: 40
                                height: 22
                                radius: 11
                                color: lockSettings.hidePassword ? root.accentClr : root.surfHigh
                                Behavior on color {
                                    ColorAnimation {
                                        duration: 250
                                    }
                                }

                                Rectangle {
                                    width: 18
                                    height: 18
                                    radius: 9
                                    x: lockSettings.hidePassword ? 20 : 2
                                    y: 2
                                    color: root.bg
                                    Behavior on x {
                                        NumberAnimation {
                                            duration: 200
                                            easing.type: Easing.OutBack
                                        }
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        lockSettings.hidePassword = !lockSettings.hidePassword;
                                        if (lockSettings.hidePassword) {
                                            for (let i = 0; i < passModel.count; i++)
                                                passModel.setProperty(i, "isDot", true);
                                        }
                                    }
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: 18
                            Layout.rightMargin: 18
                            Layout.topMargin: 8
                            Layout.bottomMargin: 8
                            spacing: 8
                            opacity: lockSettings.hidePassword ? 0.3 : 1.0
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 200
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: "Reveal delay"
                                    font.family: root.textFont
                                    font.pixelSize: 14
                                    font.weight: Font.Medium
                                    color: root.accent2Clr
                                    Layout.fillWidth: true
                                }
                                Text {
                                    text: lockSettings.revealDuration >= 1000 ? (lockSettings.revealDuration / 1000).toFixed(1) + " s" : lockSettings.revealDuration + " ms"
                                    font.family: root.textFont
                                    font.pixelSize: 13
                                    font.weight: Font.Bold
                                    color: root.warningClr
                                }
                            }

                            Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 28

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width
                                    height: 8
                                    radius: 4
                                    color: root.surfHigh
                                    Rectangle {
                                        width: ((lockSettings.revealDuration - 100) / 2900) * parent.width
                                        height: parent.height
                                        radius: 4
                                        color: root.accentClr
                                    }
                                }

                                Rectangle {
                                    id: sliderThumb
                                    width: 20
                                    height: 20
                                    radius: 10
                                    color: root.warningClr
                                    border.color: root.bg
                                    border.width: 2
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: Math.max(0, Math.min(((lockSettings.revealDuration - 100) / 2900) * parent.width - 10, parent.width - 20))

                                    scale: sliderMouse.pressed ? 1.3 : (sliderMouse.containsMouse ? 1.15 : 1.0)
                                    Behavior on scale {
                                        NumberAnimation {
                                            duration: 150
                                            easing.type: Easing.OutBack
                                        }
                                    }
                                }

                                MultiEffect {
                                    source: sliderThumb
                                    anchors.fill: sliderThumb
                                    shadowEnabled: true
                                    shadowBlur: 0.5
                                    shadowColor: "#000000"
                                    shadowOpacity: 0.4
                                    shadowVerticalOffset: 2
                                }

                                MouseArea {
                                    id: sliderMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: !lockSettings.hidePassword
                                    preventStealing: true

                                    function updateVal(mouseX) {
                                        let pct = Math.max(0, Math.min(1, mouseX / width));
                                        let ms = Math.round(100 + (pct * 2900));
                                        if (ms % 100 < 10)
                                            ms -= (ms % 100);
                                        else if (ms % 100 > 90)
                                            ms += (100 - (ms % 100));
                                        lockSettings.revealDuration = ms;
                                    }

                                    onPositionChanged: mouse => {
                                        if (pressed) {
                                            updateVal(mouse.x);
                                        }
                                    }
                                    onPressed: mouse => updateVal(mouse.x)
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: root.alpha(root.accentClr, 0.2)
                            Layout.leftMargin: 18
                            Layout.rightMargin: 18
                            Layout.topMargin: 4
                            Layout.bottomMargin: 4
                        }

                        Text {
                            text: "SYSTEM"
                            font.family: root.textFont
                            font.weight: Font.Black
                            font.pixelSize: 12
                            font.letterSpacing: 1.5
                            color: root.accentClr
                            Layout.leftMargin: 18
                            Layout.bottomMargin: 4
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 48
                            Layout.leftMargin: 10
                            Layout.rightMargin: 10
                            radius: 12
                            color: ma1.containsMouse ? root.alpha(root.accent2Clr, 0.1) : "transparent"
                            scale: ma1.pressed ? 0.95 : (ma1.containsMouse ? 1.02 : 1.0)
                            Behavior on color {
                                ColorAnimation {
                                    duration: 200
                                }
                            }
                            Behavior on scale {
                                NumberAnimation {
                                    duration: 200
                                    easing.type: Easing.OutBack
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16
                                spacing: 0
                                Text {
                                    text: "󰜉"
                                    font.family: root.iconFont
                                    font.pixelSize: 18
                                    color: ma1.containsMouse ? root.accent2Clr : root.alpha(root.accent2Clr, 0.6)
                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 200
                                        }
                                    }
                                }
                                Item {
                                    Layout.fillWidth: true
                                }
                                Text {
                                    text: "Reboot"
                                    font.family: root.textFont
                                    font.pixelSize: 15
                                    font.weight: Font.Medium
                                    color: ma1.containsMouse ? root.accent2Clr : root.alpha(root.accent2Clr, 0.6)
                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 200
                                        }
                                    }
                                }
                            }
                            MouseArea {
                                id: ma1
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    screenRoot.powerMenuOpen = false;
                                    reloadProcess.running = true;
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 48
                            Layout.leftMargin: 10
                            Layout.rightMargin: 10
                            radius: 12
                            color: ma2.containsMouse ? root.alpha(root.accentClr, 0.1) : "transparent"
                            scale: ma2.pressed ? 0.95 : (ma2.containsMouse ? 1.02 : 1.0)
                            Behavior on color {
                                ColorAnimation {
                                    duration: 200
                                }
                            }
                            Behavior on scale {
                                NumberAnimation {
                                    duration: 200
                                    easing.type: Easing.OutBack
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16
                                spacing: 0
                                Text {
                                    text: "󰒲"
                                    font.family: root.iconFont
                                    font.pixelSize: 18
                                    color: ma2.containsMouse ? root.accentClr : root.alpha(root.accentClr, 0.6)
                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 200
                                        }
                                    }
                                }
                                Item {
                                    Layout.fillWidth: true
                                }
                                Text {
                                    text: "Suspend"
                                    font.family: root.textFont
                                    font.pixelSize: 15
                                    font.weight: Font.Medium
                                    color: ma2.containsMouse ? root.accentClr : root.alpha(root.accentClr, 0.6)
                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 200
                                        }
                                    }
                                }
                            }
                            MouseArea {
                                id: ma2
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    screenRoot.powerMenuOpen = false;
                                    suspendProcess.running = true;
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 48
                            Layout.leftMargin: 10
                            Layout.rightMargin: 10
                            Layout.bottomMargin: 8
                            radius: 12
                            color: ma3.containsMouse ? root.alpha(root.dangerClr, 0.1) : "transparent"
                            scale: ma3.pressed ? 0.95 : (ma3.containsMouse ? 1.02 : 1.0)
                            Behavior on color {
                                ColorAnimation {
                                    duration: 200
                                }
                            }
                            Behavior on scale {
                                NumberAnimation {
                                    duration: 200
                                    easing.type: Easing.OutBack
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16
                                spacing: 0
                                Text {
                                    text: "󰐥"
                                    font.family: root.iconFont
                                    font.pixelSize: 18
                                    color: ma3.containsMouse ? root.dangerClr : root.alpha(root.dangerClr, 0.6)
                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 200
                                        }
                                    }
                                }
                                Item {
                                    Layout.fillWidth: true
                                }
                                Text {
                                    text: "Power Off"
                                    font.family: root.textFont
                                    font.pixelSize: 15
                                    font.weight: Font.Medium
                                    color: ma3.containsMouse ? root.dangerClr : root.alpha(root.dangerClr, 0.6)
                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 200
                                        }
                                    }
                                }
                            }
                            MouseArea {
                                id: ma3
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    screenRoot.powerMenuOpen = false;
                                    poweroffProcess.running = true;
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    id: powerBtn
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    anchors.margins: 40
                    width: 52
                    height: 52
                    radius: 26

                    color: screenRoot.powerMenuOpen ? root.surfHigh : (powerBtnMa.containsMouse ? root.alpha(root.surfMid, 0.8) : root.alpha(root.surfLow, 0.4))
                    border.color: screenRoot.powerMenuOpen ? root.fg : root.alpha(root.fg, 0.15)
                    border.width: 1

                    opacity: screenRoot.introState
                    transform: Translate {
                        y: 20 * (1.0 - screenRoot.introState)
                    }

                    scale: powerBtnMa.pressed ? 0.9 : (powerBtnMa.containsMouse ? 1.08 : 1.0)

                    Behavior on color {
                        ColorAnimation {
                            duration: 200
                        }
                    }
                    Behavior on border.color {
                        ColorAnimation {
                            duration: 200
                        }
                    }
                    Behavior on scale {
                        NumberAnimation {
                            duration: 300
                            easing.type: Easing.OutBack
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "󰐥"
                        font.family: root.iconFont
                        font.pixelSize: 22
                        color: screenRoot.powerMenuOpen ? root.dangerClr : (powerBtnMa.containsMouse ? root.fg : root.mutedClr)
                        Behavior on color {
                            ColorAnimation {
                                duration: 200
                            }
                        }
                    }

                    MouseArea {
                        id: powerBtnMa
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !screenRoot.isPlayingIntro
                        onClicked: {
                            screenRoot.powerMenuOpen = !screenRoot.powerMenuOpen;
                            if (!screenRoot.powerMenuOpen)
                                inputField.forceActiveFocus();
                        }
                    }
                }

                Item {
                    id: introOverlay
                    anchors.fill: parent
                    z: 999
                    visible: screenRoot.isPlayingIntro || opacity > 0

                    Rectangle {
                        id: ring3
                        width: 360
                        height: 360
                        radius: 180
                        anchors.centerIn: parent
                        color: "transparent"
                        border.color: root.accentClr
                        border.width: 1
                        scale: 0.5
                        opacity: 0.0
                    }
                    Rectangle {
                        id: ring2
                        width: 300
                        height: 300
                        radius: 150
                        anchors.centerIn: parent
                        color: "transparent"
                        border.color: root.fg
                        border.width: 1
                        scale: 0.8
                        opacity: 0.0
                    }
                    Rectangle {
                        id: ring1
                        width: 240
                        height: 240
                        radius: 120
                        anchors.centerIn: parent
                        color: "transparent"
                        border.color: root.fg
                        border.width: 2
                        scale: 0.8
                        opacity: 0.0
                    }

                    Item {
                        id: introLockOrb
                        width: 170
                        height: 170
                        anchors.centerIn: parent
                        scale: 0.0
                        opacity: 0.0

                        Rectangle {
                            anchors.fill: parent
                            radius: 85
                            color: root.alpha(root.surfLow, 0.9)
                            border.color: root.fg
                            border.width: 2
                        }

                        Text {
                            id: introIconUnlocked
                            anchors.centerIn: parent
                            text: "󰌿"
                            font.family: root.iconFont
                            font.pixelSize: 64
                            color: root.fg
                            opacity: 1.0
                            scale: 1.0
                            transformOrigin: Item.Center
                        }

                        Text {
                            id: introIconLocked
                            anchors.centerIn: parent
                            text: "󰌾"
                            font.family: root.iconFont
                            font.pixelSize: 64
                            color: root.fg
                            opacity: 0.0
                            scale: 1.6
                            transformOrigin: Item.Center
                        }
                    }

                    SequentialAnimation {
                        id: introSequence

                        ParallelAnimation {
                            NumberAnimation {
                                target: introLockOrb
                                property: "scale"
                                from: 0.0
                                to: 1.0
                                duration: 300
                                easing.type: Easing.OutCubic
                            }
                            NumberAnimation {
                                target: introLockOrb
                                property: "opacity"
                                from: 0.0
                                to: 1.0
                                duration: 200
                                easing.type: Easing.OutCubic
                            }

                            NumberAnimation {
                                target: ring1
                                property: "scale"
                                from: 0.8
                                to: 1.25
                                duration: 250
                                easing.type: Easing.OutCubic
                            }
                            NumberAnimation {
                                target: ring1
                                property: "opacity"
                                from: 0.6
                                to: 0.0
                                duration: 250
                                easing.type: Easing.OutCubic
                            }

                            NumberAnimation {
                                target: ring2
                                property: "scale"
                                from: 0.8
                                to: 1.4
                                duration: 300
                                easing.type: Easing.OutCubic
                            }
                            NumberAnimation {
                                target: ring2
                                property: "opacity"
                                from: 0.4
                                to: 0.0
                                duration: 300
                                easing.type: Easing.OutCubic
                            }

                            NumberAnimation {
                                target: ring3
                                property: "scale"
                                from: 0.5
                                to: 1.5
                                duration: 350
                                easing.type: Easing.OutCubic
                            }
                            NumberAnimation {
                                target: ring3
                                property: "opacity"
                                from: 0.3
                                to: 0.0
                                duration: 350
                                easing.type: Easing.OutCubic
                            }

                            SequentialAnimation {
                                PauseAnimation {
                                    duration: 300
                                }
                                ParallelAnimation {
                                    NumberAnimation {
                                        target: introIconUnlocked
                                        property: "scale"
                                        from: 1.0
                                        to: 0.5
                                        duration: 100
                                        easing.type: Easing.InCubic
                                    }
                                    NumberAnimation {
                                        target: introIconUnlocked
                                        property: "opacity"
                                        from: 1.0
                                        to: 0.0
                                        duration: 50
                                    }

                                    NumberAnimation {
                                        target: introIconLocked
                                        property: "scale"
                                        from: 1.6
                                        to: 1.0
                                        duration: 200
                                        easing.type: Easing.OutBack
                                    }
                                    NumberAnimation {
                                        target: introIconLocked
                                        property: "opacity"
                                        from: 0.0
                                        to: 1.0
                                        duration: 100
                                    }

                                    SequentialAnimation {
                                        NumberAnimation {
                                            target: introLockOrb
                                            property: "anchors.verticalCenterOffset"
                                            from: 0
                                            to: 3
                                            duration: 40
                                            easing.type: Easing.OutQuad
                                        }
                                        NumberAnimation {
                                            target: introLockOrb
                                            property: "anchors.verticalCenterOffset"
                                            from: 3
                                            to: 0
                                            duration: 120
                                            easing.type: Easing.OutBack
                                        }
                                    }
                                }
                            }
                        }

                        PauseAnimation {
                            duration: 50
                        }

                        SequentialAnimation {
                            ParallelAnimation {
                                NumberAnimation {
                                    target: introLockOrb
                                    property: "scale"
                                    to: 1.8
                                    duration: 100
                                    easing.type: Easing.InCubic
                                }
                                NumberAnimation {
                                    target: introOverlay
                                    property: "opacity"
                                    to: 0.0
                                    duration: 100
                                    easing.type: Easing.InCubic
                                }
                            }

                            NumberAnimation {
                                target: screenRoot
                                property: "introState"
                                from: 0.0
                                to: 1.0
                                duration: 100
                                easing.type: Easing.OutCubic
                            }
                        }

                        PropertyAction {
                            target: screenRoot
                            property: "isPlayingIntro"
                            value: false
                        }
                        ScriptAction {
                            script: {
                                inputField.text = "";
                                inputField.forceActiveFocus();
                            }
                        }
                    }
                }
            }
        }
    }
}
