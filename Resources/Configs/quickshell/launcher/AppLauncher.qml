//@ pragma UseQApplication
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Qt.labs.platform 1.1

ShellRoot {
    id: root

    property bool edgeAnimationsEnabled: true

    property FileView _animStateFile: FileView {
        path: Quickshell.env("HOME") + "/.cache/quickshell/state.ini"
        watchChanges: true
        Component.onCompleted: this.reload()
        onFileChanged: this.reload()
        onLoaded: root._parseAnimState(this.text())
    }

    function _parseAnimState(txt) {
        if (!txt || txt === "") return;
        var lines = txt.split("\n");
        var inSection = false;
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim();
            if (line === "[quickshell.theme]") {
                inSection = true;
                continue;
            }
            if (inSection) {
                if (line.startsWith("[")) break; 
                if (line.startsWith("edgeAnimationsEnabled=")) {
                    var val = line.split("=")[1].trim().toLowerCase();
                    root.edgeAnimationsEnabled = (val === "true");
                    return;
                }
            }
        }
    }

    readonly property string textFont: "Fira Sans Semibold"
    readonly property string iconFont: "CaskaydiaMono Nerd Font"
    readonly property string nerdFont: "Iosevka Nerd Font"

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
            console.warn("AppLauncher: colors.json parse error:", e);
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
            return { r: x.r, g: x.g, b: x.b };
        }
        return { r: 0, g: 0, b: 0 };
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

    readonly property color c4: _pick("#61afef", _j?.colors?.color4)
    readonly property color c5: _pick("#c678dd", _j?.colors?.color5)
    readonly property color c6: _pick("#56b6c2", _j?.colors?.color6)
    readonly property color c8: _pick("#3e4451", _j?.colors?.color8)

    readonly property color accentClr: _pick(c4, _j?.quickshell?.accent)
    readonly property color accent2Clr: _pick(c6, _j?.quickshell?.accent2)

    readonly property color base: surface(0.10)
    readonly property color text: fg
    readonly property color subtext0: mix(bg, fg, 0.6)
    readonly property color overlay0: mix(bg, fg, 0.3)
    readonly property color overlay1: mix(bg, fg, 0.4)
    readonly property color surface0: surface(0.06)
    readonly property color surface1: surface(0.08)
    readonly property color surface2: surface(0.12)
    readonly property color accent: accentClr
    readonly property color moduleBorderColor: mix(bg, fg, 0.35)
    readonly property color moduleFontColor: accentClr

    readonly property real popupOpenWidth: 650
    readonly property real popupOpenHeight: 620
    readonly property real popupClosedWidth: 570
    readonly property real popupClosedHeight: 520
    readonly property real popupOpenRadius: 20
    readonly property real popupClosedRadius: 36

    property bool popupMounted: false
    property bool popupTargetVisible: false
    property real popupCardOpacity: 0.0
    property real popupCardScaleX: 0.91
    property real popupCardScaleY: 0.79
    property real popupCardWidth: popupClosedWidth
    property real popupCardHeight: popupClosedHeight
    property real popupCardRadius: popupClosedRadius
    property real popupCardLift: 18

    function _prepareLauncherOpen() {
        root.closeMainShellPopups();
        root.hideGameLauncher();
        search.text = "";
        appListModel.applyFilter("");
        appList.positionViewAtBeginning();
        filteredFiles.clear();
        root._showLauncherPopup();
        search.forceActiveFocus();
        appListModel.reload();
    }

    function _showLauncherPopup() {
        popupTargetVisible = true;
        popupMounted = true;
        popupExitAnim.stop();
        if (!popupEnterAnim.running && popupCardOpacity >= 0.999)
            return;
        popupEnterAnim.stop();
        popupEnterAnim.start();
    }

    function _hideLauncherPopup() {
        popupTargetVisible = false;
        popupEnterAnim.stop();
        if (!popupMounted && popupCardOpacity <= 0.001)
            return;
        popupExitAnim.stop();
        popupExitAnim.start();
    }

    SequentialAnimation {
        id: popupEnterAnim
        running: false

        onStopped: {
            if (!root.popupTargetVisible && root.popupCardOpacity <= 0.001)
                root.popupMounted = false;
        }

        ParallelAnimation {
            NumberAnimation { target: root; property: "popupCardOpacity"; to: 0.78; duration: 145; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "popupCardScaleX"; to: 0.985; duration: 175; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "popupCardScaleY"; to: 0.94; duration: 190; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "popupCardWidth"; to: root.popupOpenWidth - 26; duration: 190; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "popupCardHeight"; to: root.popupOpenHeight - 34; duration: 200; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "popupCardRadius"; to: 28; duration: 190; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "popupCardLift"; to: 8; duration: 190; easing.type: Easing.OutCubic }
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

        onStopped: {
            if (!root.popupTargetVisible && root.popupCardOpacity <= 0.001)
                root.popupMounted = false;
        }

        ParallelAnimation {
            NumberAnimation { target: root; property: "popupCardScaleX"; to: 1.04; duration: 85; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "popupCardScaleY"; to: 0.95; duration: 85; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "popupCardWidth"; to: root.popupOpenWidth + 18; duration: 95; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "popupCardHeight"; to: root.popupOpenHeight - 20; duration: 95; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "popupCardRadius"; to: 30; duration: 95; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "popupCardLift"; to: 5; duration: 95; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "popupCardOpacity"; to: 0.88; duration: 80; easing.type: Easing.OutQuad }
        }

        ParallelAnimation {
            NumberAnimation { target: root; property: "popupCardOpacity"; to: 0.0; duration: 180; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "popupCardScaleX"; to: 0.84; duration: 205; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "popupCardScaleY"; to: 0.68; duration: 220; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "popupCardWidth"; to: root.popupClosedWidth; duration: 200; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "popupCardHeight"; to: root.popupClosedHeight; duration: 210; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "popupCardRadius"; to: root.popupClosedRadius; duration: 200; easing.type: Easing.InQuad }
            NumberAnimation { target: root; property: "popupCardLift"; to: 24; duration: 200; easing.type: Easing.InCubic }
        }
    }

    function closeMainShellPopups() {
        Quickshell.execDetached([
            "qs", "ipc",
            "-p", Quickshell.env("HOME") + "/.config/quickshell",
            "call", "global", "closeShellPopups"
        ]);
    }

    function hideGameLauncher() {
        Quickshell.execDetached([
            "qs", "ipc",
            "-p", Quickshell.env("HOME") + "/.config/quickshell/gamelauncher",
            "call", "gamelauncher", "hide"
        ]);
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            if (root.popupTargetVisible) {
                root._hideLauncherPopup();
            } else {
                root._prepareLauncherOpen();
            }
        }

        function show(): void {
            root._prepareLauncherOpen();
        }

        function hide(): void {
            root._hideLauncherPopup();
        }
    }



    PanelWindow {
        id: win
        visible: root.popupMounted
        focusable: root.popupMounted
        color: "transparent"

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        Component.onCompleted: {
            try {
                if (win.WlrLayershell) {
                    win.WlrLayershell.layer = WlrLayer.Overlay;
                }
            } catch (e) {}
        }

        Item {
            anchors.fill: parent
            focus: true

            Keys.onReleased: e => {
                if (e.key === Qt.Key_Escape) {
                    root._hideLauncherPopup();
                    e.accepted = true;
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root._hideLauncherPopup()
            }

            Item {
                id: cardShell
                width: root.popupCardWidth
                height: root.popupCardHeight
                anchors.centerIn: parent
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
                    anchors.fill: parent
                    radius: root.popupCardRadius
                    color: root.base
                    border.color: root.moduleBorderColor
                    border.width: 1
                    clip: true

                    Item {
                        id: electricBorder
                        anchors.fill: parent
                        z: 1000
                        clip: true

                        property color ebAccentColor: root.accent
                        property real ebRadius: card.radius
                        property real ebBorderWidth: card.border.width
                        property real ebPixelsPerSecond: 120

                        readonly property bool ebEffectEnabled: root.edgeAnimationsEnabled && ebBorderWidth > 0 && width > 8 && height > 8
                        readonly property real ebInset: Math.max(1.0, (ebBorderWidth * 0.5) + 0.5)
                        readonly property real ebFrameWidth: Math.max(1, width - (ebInset * 2))
                        readonly property real ebFrameHeight: Math.max(1, height - (ebInset * 2))
                        readonly property real ebCornerRadius: Math.max(0, Math.min(ebRadius - ebInset, ebFrameWidth / 2, ebFrameHeight / 2))
                        readonly property real ebTopLength: Math.max(0, ebFrameWidth - (ebCornerRadius * 2))
                        readonly property real ebSideLength: Math.max(0, ebFrameHeight - (ebCornerRadius * 2))
                        readonly property real ebArcLength: ebCornerRadius > 0 ? ((Math.PI * ebCornerRadius) / 2) : 0
                        readonly property real ebPerimeter: Math.max(4, (ebTopLength * 2) + (ebSideLength * 2) + (ebArcLength * 4))
                        readonly property real ebSegmentLength: Math.max(10, Math.min(22, ebPerimeter * 0.032))
                        readonly property real ebSegmentThickness: Math.max(2.0, ebBorderWidth * 1.7)
                        readonly property real ebGlowThickness: Math.max(6.0, ebSegmentThickness * 2.2)

                        property real ebTravel: 0
                        property real ebTimeElapsed: 0
                        property real _ebLastTimeElapsed: 0
                        property real _ebLastPerimeter: ebPerimeter

                        visible: ebEffectEnabled

                        readonly property real ebEffectiveSpeed: {
                            if (electricBorder.ebPerimeter <= 0) return electricBorder.ebPixelsPerSecond;
                            var targetDuration = (electricBorder.ebPerimeter / Math.max(70, electricBorder.ebPixelsPerSecond)) * 1000;
                            var actualDuration = Math.max(2000, targetDuration);
                            return (electricBorder.ebPerimeter / actualDuration) * 1000;
                        }

                        onEbPerimeterChanged: {
                            if (_ebLastPerimeter > 0 && ebPerimeter > 0)
                                ebTravel = ebTravel * (ebPerimeter / _ebLastPerimeter);
                            _ebLastPerimeter = ebPerimeter;
                        }

                        NumberAnimation on ebTimeElapsed {
                            from: 0; to: 100000000; duration: 100000000
                            loops: Animation.Infinite
                            running: electricBorder.ebEffectEnabled && electricBorder.ebPerimeter > 0
                        }

                        onEbTimeElapsedChanged: {
                            var dt = (ebTimeElapsed - _ebLastTimeElapsed) / 1000.0;
                            if (dt < 0) dt = 0;
                            ebTravel = (ebTravel + (ebEffectiveSpeed * dt)) % Math.max(1, ebPerimeter);
                            _ebLastTimeElapsed = ebTimeElapsed;
                        }

                        function ebWithAlpha(c, a) {
                            var rgb = root._toRgb(c);
                            return Qt.rgba(rgb.r || 0, rgb.g || 0, rgb.b || 0, a);
                        }

                        function ebWrapDistance(distance) {
                            if (ebPerimeter <= 0) return 0;
                            var wrapped = distance % ebPerimeter;
                            return wrapped < 0 ? wrapped + ebPerimeter : wrapped;
                        }

                        function ebPointAt(distance) {
                            var d = ebWrapDistance(distance);
                            var r = ebCornerRadius, w = ebFrameWidth, h = ebFrameHeight;
                            var px = 0, py = 0;
                            if (d <= ebTopLength) { px = r + d; py = 0; }
                            else { d -= ebTopLength;
                                if (d <= ebArcLength && r > 0) { var a1 = (-Math.PI/2)+((d/ebArcLength)*(Math.PI/2)); px = (w-r)+Math.cos(a1)*r; py = r+Math.sin(a1)*r; }
                                else { d -= ebArcLength;
                                    if (d <= ebSideLength) { px = w; py = r + d; }
                                    else { d -= ebSideLength;
                                        if (d <= ebArcLength && r > 0) { var a2 = (d/ebArcLength)*(Math.PI/2); px = (w-r)+Math.cos(a2)*r; py = (h-r)+Math.sin(a2)*r; }
                                        else { d -= ebArcLength;
                                            if (d <= ebTopLength) { px = (w-r)-d; py = h; }
                                            else { d -= ebTopLength;
                                                if (d <= ebArcLength && r > 0) { var a3 = (Math.PI/2)+((d/ebArcLength)*(Math.PI/2)); px = r+Math.cos(a3)*r; py = (h-r)+Math.sin(a3)*r; }
                                                else { d -= ebArcLength;
                                                    if (d <= ebSideLength) { px = 0; py = (h-r)-d; }
                                                    else if (ebArcLength > 0 && r > 0) { d -= ebSideLength; var a4 = Math.PI+((d/ebArcLength)*(Math.PI/2)); px = r+Math.cos(a4)*r; py = r+Math.sin(a4)*r; }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            return { x: ebInset + px, y: ebInset + py };
                        }

                        function ebStateAt(distance) {
                            var p0 = ebPointAt(distance);
                            var p1 = ebPointAt(distance + 2);
                            var dx = p1.x - p0.x, dy = p1.y - p0.y;
                            var len = Math.hypot(dx, dy);
                            var rot = (len <= 0.0001) ? 0 : Math.atan2(dy, dx) * 180 / Math.PI;
                            return { x: p0.x, y: p0.y, rotation: rot };
                        }

                        Repeater {
                            model: electricBorder.ebEffectEnabled ? 6 : 0
                            delegate: Item {
                                required property int index
                                readonly property real tailT: index / Math.max(1, 5)
                                readonly property real offset: index * electricBorder.ebSegmentLength * 0.44
                                readonly property real alphaScale: 1.0 - (tailT * 0.82)
                                readonly property real shrinkScale: 1.0 - (tailT * 0.42)
                                readonly property var sparkState: electricBorder.ebStateAt(electricBorder.ebTravel - offset)

                                width: electricBorder.ebSegmentLength * (0.62 + (0.38 * shrinkScale))
                                height: electricBorder.ebGlowThickness * shrinkScale
                                x: Math.round(sparkState.x - (width / 2))
                                y: Math.round(sparkState.y - (height / 2))
                                rotation: sparkState.rotation
                                transformOrigin: Item.Center
                                opacity: alphaScale

                                Rectangle {
                                    anchors.centerIn: parent; width: parent.width; height: parent.height
                                    radius: height / 2
                                    color: electricBorder.ebWithAlpha(electricBorder.ebAccentColor, 0.10 * parent.opacity)
                                }
                                Rectangle {
                                    anchors.centerIn: parent; width: parent.width * 0.82
                                    height: electricBorder.ebSegmentThickness * shrinkScale
                                    radius: height / 2
                                    color: electricBorder.ebWithAlpha(electricBorder.ebAccentColor, index === 0 ? 0.86 : (0.28 * alphaScale))
                                }
                                Rectangle {
                                    visible: index === 0
                                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                    width: Math.max(4, electricBorder.ebSegmentThickness * 1.8); height: width; radius: width / 2
                                    color: electricBorder.ebAccentColor
                                }
                                Rectangle {
                                    visible: index === 0
                                    anchors.verticalCenter: parent.verticalCenter; anchors.right: parent.right
                                    anchors.rightMargin: Math.max(2, electricBorder.ebSegmentThickness)
                                    width: parent.width * 0.34; height: Math.max(1.0, electricBorder.ebBorderWidth); radius: height / 2
                                    rotation: 32
                                    color: electricBorder.ebWithAlpha(electricBorder.ebAccentColor, 0.65)
                                }
                                Rectangle {
                                    visible: index === 0
                                    anchors.verticalCenter: parent.verticalCenter; anchors.right: parent.right
                                    anchors.rightMargin: Math.max(2, electricBorder.ebSegmentThickness * 1.1)
                                    width: parent.width * 0.24; height: Math.max(1.0, electricBorder.ebBorderWidth); radius: height / 2
                                    rotation: -27
                                    color: electricBorder.ebWithAlpha(electricBorder.ebAccentColor, 0.48)
                                }
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.AllButtons
                        onClicked: {}
                    }

                    property real globalOrbitAngle: 0
                    NumberAnimation on globalOrbitAngle {
                        from: 0; to: Math.PI * 2; duration: 90000; loops: Animation.Infinite; running: root.popupMounted && root.edgeAnimationsEnabled
                    }

                    Rectangle {
                        width: parent.width * 0.8; height: width; radius: width / 2
                        x: (parent.width * 0.5 - width / 2) + Math.cos(card.globalOrbitAngle * 1.5) * 80
                        y: (parent.height * 0.1 - height / 2) + Math.sin(card.globalOrbitAngle * 1.5) * 100
                        opacity: 0.04
                        color: root.accent
                        z: 0
                    }

                    Rectangle {
                        width: parent.width * 0.6; height: width; radius: width / 2
                        x: (parent.width * 0.2 - width / 2) + Math.sin(card.globalOrbitAngle * 1.2) * -60
                        y: (parent.height * 0.8 - height / 2) + Math.cos(card.globalOrbitAngle * 1.2) * -80
                        opacity: 0.03
                        color: root.c5 
                        z: 0
                    }

                    Text {
                        id: bgIcon
                        anchors.centerIn: parent
                        property real drift: 0
                        SequentialAnimation on drift {
                            loops: Animation.Infinite; running: root.popupMounted && root.edgeAnimationsEnabled
                            NumberAnimation { to: -15; duration: 6000; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 0; duration: 6000; easing.type: Easing.InOutSine }
                        }
                        transform: Translate { y: bgIcon.drift }

                        text: "\u{F14DE}" 
                        font.family: root.nerdFont
                        font.pixelSize: 320
                        color: root.accent
                        opacity: 0.03 + (0.01 * Math.sin(card.globalOrbitAngle * 4))
                        z: 0
                    }

                    ColumnLayout {
                        id: content
                        anchors.fill: parent
                        anchors.margins: 25
                        spacing: 12
                        z: 1

                        TextField {
                            id: search
                            Layout.fillWidth: true
                            Layout.preferredHeight: 34
                            placeholderText: "Search applications…"
                            leftPadding: 16
                            rightPadding: 16
                            verticalAlignment: TextInput.AlignVCenter
                            color: root.text
                            placeholderTextColor: root.overlay1
                            font.pixelSize: 14
                            font.family: root.textFont

                            background: Rectangle {
                                color: "#0dffffff"
                                border.color: search.activeFocus ? root.accent : "#1affffff"
                                border.width: 1
                                radius: 10
                            }

                            onTextChanged: {
                                if (text.startsWith("/")) {
                                    appList.visible = false;
                                    fileList.visible = true;
                                    commandBox.visible = false;
                                    searchDebouncer.restart();
                                } else if (text.startsWith("-")) {
                                    appList.visible = false;
                                    fileList.visible = false;
                                    commandBox.visible = true;
                                    searchDebouncer.stop();
                                } else {
                                    appList.visible = true;
                                    fileList.visible = false;
                                    commandBox.visible = false;
                                    searchDebouncer.stop();
                                    appListModel.applyFilter(text);
                                }
                            }

                            Timer {
                                id: searchDebouncer
                                interval: 150
                                repeat: false
                                onTriggered: {
                                    fileSearchProc.command = ["bash", root.scriptDir + "search_files.sh", search.text];
                                    fileSearchProc.running = true;
                                }
                            }

                            Keys.onReturnPressed: {
                                if (search.text.startsWith("/")) {
                                    if (filteredFiles.count > 0) {
                                        const first = filteredFiles.get(0);
                                        if (first && first.path) {
                                            const safePath = first.path.replace(/'/g, "'\\''");
                                            launchApp("xdg-open '" + safePath + "'");
                                        }
                                    }
                                } else if (search.text.startsWith("-")) {
                                    const cmd = search.text.substring(1).trim();
                                    if (cmd.length > 0) {
                                        launchApp(cmd);
                                    }
                                } else {
                                    if (filteredApps.count > 0) {
                                        const first = filteredApps.get(0);
                                        if (first && first.exec)
                                            launchApp(first.exec);
                                    }
                                }
                            }
                            Keys.onEscapePressed: root._hideLauncherPopup()
                            Keys.onDownPressed: {
                                if (search.text.startsWith("/")) {
                                    fileList.forceActiveFocus();
                                    fileList.currentIndex = 0;
                                } else if (!search.text.startsWith("-")) {
                                    appList.forceActiveFocus();
                                    appList.currentIndex = 0;
                                }
                            }
                        }

                    ListView {
                        id: appList
                        visible: true
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 4
                        boundsBehavior: Flickable.StopAtBounds
                        model: filteredApps
                        highlight: null
                        currentIndex: -1
                        highlightMoveDuration: 0
                        highlightMoveVelocity: -1

                        FastScrollHandler {
                            anchors.fill: parent
                            flickable: appList
                        }

                        Keys.onReturnPressed: {
                            if (currentIndex >= 0 && currentIndex < filteredApps.count) {
                                const item = filteredApps.get(currentIndex);
                                if (item && item.exec)
                                    launchApp(item.exec);
                            }
                        }
                        Keys.onEscapePressed: root._hideLauncherPopup()
                        Keys.onUpPressed: {
                            if (currentIndex <= 0) {
                                search.forceActiveFocus();
                                currentIndex = -1;
                            } else {
                                currentIndex--;
                                positionViewAtIndex(currentIndex, ListView.Contain);
                            }
                        }
                        Keys.onDownPressed: {
                            if (currentIndex < filteredApps.count - 1) {
                                currentIndex++;
                                positionViewAtIndex(currentIndex, ListView.Contain);
                            }
                        }

                        delegate: Rectangle {
                            id: appRow
                            width: appList.width - 12
                            height: 52
                            radius: 14
                            color: (hovered || appList.currentIndex === index) ? "#0affffff" : "#05ffffff"
                            border.width: 1
                            border.color: (hovered || appList.currentIndex === index) ? root.accent : "#1affffff"

                            property bool hovered: false

                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 14

                                Image {
                                    id: appIcon
                                    Layout.preferredWidth: 32
                                    Layout.preferredHeight: 32
                                    Layout.alignment: Qt.AlignVCenter
                                    source: model.icon !== "" ? ("file://" + model.icon) : ""
                                    sourceSize: Qt.size(32, 32)
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    visible: status === Image.Ready

                                    smooth: true
                                    mipmap: true
                                }

                                Rectangle {
                                    Layout.preferredWidth: 32
                                    Layout.preferredHeight: 32
                                    Layout.alignment: Qt.AlignVCenter
                                    radius: 8
                                    color: root.alpha(root.accent, 0.15)
                                    visible: appIcon.status !== Image.Ready

                                    Text {
                                        anchors.centerIn: parent
                                        text: model.name ? model.name.charAt(0).toUpperCase() : "?"
                                        color: root.accent
                                        font.pixelSize: 16
                                        font.family: root.textFont
                                        font.weight: Font.Bold
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: 2

                                    Text {
                                        Layout.fillWidth: true
                                        text: model.name || ""
                                        color: root.text
                                        font.pixelSize: 14
                                        font.family: root.textFont
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: model.comment || ""
                                        color: root.overlay1
                                        font.pixelSize: 11
                                        font.family: root.textFont
                                        elide: Text.ElideRight
                                        visible: text !== ""
                                    }
                                }

                                Text {
                                    Layout.alignment: Qt.AlignVCenter
                                    text: ""
                                    color: appRow.hovered || appList.currentIndex === index ? root.accent : root.overlay0
                                    font.pixelSize: 14
                                    font.family: root.iconFont
                                    opacity: appRow.hovered || appList.currentIndex === index ? 1.0 : 0.0
                                    Behavior on opacity { NumberAnimation { duration: 150 } }
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: appRow.hovered = true
                                onExited: appRow.hovered = false
                                onClicked: launchApp(model.exec)
                            }
                        }

                        ScrollBar.vertical: ScrollBar {
                            id: vbar
                            policy: ScrollBar.AsNeeded
                            hoverEnabled: true
                            implicitWidth: 10
                            minimumSize: 0.08
                            active: hovered || pressed || appList.moving

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
                    }

                    ListView {
                        id: fileList
                        visible: false
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 4
                        boundsBehavior: Flickable.StopAtBounds
                        model: filteredFiles
                        highlight: null
                        currentIndex: -1
                        highlightMoveDuration: 0
                        highlightMoveVelocity: -1

                        FastScrollHandler {
                            anchors.fill: parent
                            flickable: fileList
                        }

                        Keys.onReturnPressed: {
                            if (currentIndex >= 0 && currentIndex < filteredFiles.count) {
                                const item = filteredFiles.get(currentIndex);
                                if (item && item.path) {
                                    const safePath = item.path.replace(/'/g, "'\\''");
                                    launchApp("xdg-open '" + safePath + "'");
                                }
                            }
                        }
                        Keys.onEscapePressed: root._hideLauncherPopup()
                        Keys.onUpPressed: {
                            if (currentIndex <= 0) {
                                search.forceActiveFocus();
                                currentIndex = -1;
                            } else {
                                currentIndex--;
                                positionViewAtIndex(currentIndex, ListView.Contain);
                            }
                        }
                        Keys.onDownPressed: {
                            if (currentIndex < filteredFiles.count - 1) {
                                currentIndex++;
                                positionViewAtIndex(currentIndex, ListView.Contain);
                            }
                        }

                        delegate: Rectangle {
                            id: fileRow
                            width: fileList.width - 12
                            height: 52
                            radius: 14
                            color: (hovered || fileList.currentIndex === index) ? "#0affffff" : "#05ffffff"
                            border.width: 1
                            border.color: (hovered || fileList.currentIndex === index) ? root.accent : "#1affffff"

                            property bool hovered: false

                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 14

                                Image {
                                    id: fileIcon
                                    Layout.preferredWidth: 32
                                    Layout.preferredHeight: 32
                                    Layout.alignment: Qt.AlignVCenter
                                    source: "image://icon/" + model.icon
                                    sourceSize: Qt.size(32, 32)
                                    asynchronous: true
                                }
                                
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: 2
                                    
                                    Text {
                                        Layout.fillWidth: true
                                        text: model.name || ""
                                        font.family: root.textFont
                                        font.pixelSize: 15
                                        font.weight: Font.DemiBold
                                        color: root.text
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: model.path || ""
                                        font.family: root.textFont
                                        font.pixelSize: 12
                                        color: root.overlay1
                                        elide: Text.ElideLeft
                                    }
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onEntered: fileRow.hovered = true
                                onExited: fileRow.hovered = false
                                onClicked: {
                                    const safePath = model.path.replace(/'/g, "'\\''");
                                    launchApp("xdg-open '" + safePath + "'");
                                }
                            }
                        }
                        
                        ScrollBar.vertical: ScrollBar {
                            id: fileVbar
                            policy: ScrollBar.AsNeeded
                            hoverEnabled: true
                            implicitWidth: 10
                            minimumSize: 0.08
                            active: hovered || pressed || fileList.moving

                            background: Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: root.moduleBorderColor
                                border.color: root.moduleBorderColor
                                opacity: fileVbar.active ? 1.0 : 0.7
                            }

                            contentItem: Rectangle {
                                radius: width / 2
                                border.width: 1
                                border.color: root.moduleBorderColor
                                color: root.moduleFontColor
                            }
                        }
                    }

                    Rectangle {
                        id: commandBox
                        visible: false
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: "transparent"
                        
                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 16
                            
                            Text {
                                text: "󰆍"
                                font.family: root.iconFont
                                font.pixelSize: 64
                                color: root.overlay0
                                Layout.alignment: Qt.AlignHCenter
                            }
                            
                            Text {
                                text: {
                                    const cmd = search.text.substring(1).trim();
                                    return cmd.length > 0 ? "Run command: sh -c \"" + cmd + "\"" : "Type a command to run...";
                                }
                                color: root.text
                                font.pixelSize: 18
                                font.family: root.textFont
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        radius: 10
                        color: "#0dffffff"
                        border.color: "#1affffff"
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            spacing: 20



                            Row {
                                spacing: 6
                                Layout.alignment: Qt.AlignVCenter

                                Rectangle {
                                    width: hintKey3.implicitWidth + 10
                                    height: 20
                                    radius: 4
                                    color: root.alpha(root.surface2, 0.4)
                                    border.color: root.alpha(root.overlay0, 0.3)
                                    border.width: 1
                                    anchors.verticalCenter: parent.verticalCenter

                                    Text {
                                        id: hintKey3
                                        anchors.centerIn: parent
                                        text: "/"
                                        color: root.overlay1
                                        font.pixelSize: 10
                                        font.family: root.textFont
                                    }
                                }
                                Text {
                                    text: "search files"
                                    color: root.overlay0
                                    font.pixelSize: 11
                                    font.family: root.textFont
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Row {
                                spacing: 6
                                Layout.alignment: Qt.AlignVCenter

                                Rectangle {
                                    width: hintKeyCmd.implicitWidth + 10
                                    height: 20
                                    radius: 4
                                    color: root.alpha(root.surface2, 0.4)
                                    border.color: root.alpha(root.overlay0, 0.3)
                                    border.width: 1
                                    anchors.verticalCenter: parent.verticalCenter

                                    Text {
                                        id: hintKeyCmd
                                        anchors.centerIn: parent
                                        text: "-"
                                        color: root.overlay1
                                        font.pixelSize: 10
                                        font.family: root.textFont
                                    }
                                }
                                Text {
                                    text: "run cmd"
                                    color: root.overlay0
                                    font.pixelSize: 11
                                    font.family: root.textFont
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                Layout.alignment: Qt.AlignVCenter
                                text: filteredApps.count + " apps"
                                color: root.overlay0
                                font.pixelSize: 11
                                font.family: root.textFont
                            }
                        }
                    }
                    }
                }
            }
        }
    }

    function launchApp(execCmd) {
        if (!execCmd)
            return;
        root._hideLauncherPopup();
        Quickshell.execDetached(["sh", "-c", execCmd + " &"]);
    }

    ListModel {
        id: filteredApps
    }
    ListModel {
        id: filteredFiles
    }

    QtObject {
        id: appListModel
        property var all: []

        function applyFilter(q) {
            filteredApps.clear();
            const needle = String(q || "").toLowerCase();
            let items = [];

            if (!needle) {
                items = all;
            } else {
                for (let i = 0; i < all.length; i++) {
                    const app = all[i];
                    const appName = app.name.toLowerCase();
                    const appComment = app.comment ? app.comment.toLowerCase() : "";

                    let score = -1;
                    if (appName === needle) {
                        score = 100;
                    } else if (appName.startsWith(needle)) {
                        score = 50;
                    } else if (appName.includes(needle)) {
                        score = 10;
                    } else {
                        let subIdx = 0;
                        for (let j = 0; j < appName.length && subIdx < needle.length; j++) {
                            if (needle[subIdx] === appName[j]) subIdx++;
                        }
                        if (subIdx === needle.length) {
                            score = 8;
                        } else if (needle.length >= 3) {
                            let matches = 0;
                            let nameArray = appName.split("");
                            for (let k = 0; k < needle.length; k++) {
                                let idx = nameArray.indexOf(needle[k]);
                                if (idx !== -1) {
                                    matches++;
                                    nameArray[idx] = null; 
                                }
                            }
                            let matchRatio = matches / needle.length;
                            if (matchRatio >= 0.75) {
                                let lengthPenalty = Math.abs(needle.length - appName.length) / Math.max(appName.length, 1);
                                let firstLetterPenalty = (appName[0] !== needle[0]) ? 1.0 : 0.0;
                                let fuzzyScore = (5 * matchRatio) - lengthPenalty - firstLetterPenalty;
                                if (fuzzyScore > 0) score = fuzzyScore;
                            }
                        }
                        
                        if (score < 1 && appComment.includes(needle)) {
                            score = 1;
                        }
                    }

                    if (score > 0) {
                        items.push({app: app, score: score});
                    }
                }
                
                items.sort(function(a, b) {
                    if (a.score !== b.score) {
                        return b.score - a.score;
                    }
                    return a.app.name.toLowerCase().localeCompare(b.app.name.toLowerCase());
                });
                
                items = items.map(function(item) { return item.app; });
            }

            if (items.length > 0)
                filteredApps.append(items);

            if (appList.count > 0)
                appList.positionViewAtBeginning();

            appList.currentIndex = -1;
        }

        function reload() {
            procList.running = true;
        }
    }

    readonly property string scriptDir: Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/launcher/"

    Process {
        id: procList
        command: ["bash", root.scriptDir + "list_apps.sh"]
        stdout: StdioCollector {
            id: collector
            waitForEnd: true
            onStreamFinished: {
                try {
                    const apps = JSON.parse(String(text || "[]"));
                    apps.sort(function(a, b) {
                        return a.name.toLowerCase().localeCompare(b.name.toLowerCase());
                    });
                    appListModel.all = apps;
                    appListModel.applyFilter(search.text);
                } catch (e) {
                    console.warn("AppLauncher: failed to parse app list:", e);
                }
            }
        }
    }

    Process {
        id: fileSearchProc
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    const files = JSON.parse(String(text || "[]"));
                    filteredFiles.clear();
                    if (files.length > 0)
                        filteredFiles.append(files);
                    if (fileList.count > 0)
                        fileList.positionViewAtBeginning();
                } catch (e) {
                    console.warn("AppLauncher: failed to parse file list:", e);
                }
            }
        }
    }

    Component.onCompleted: {
        Qt.application.organization = "Quickshell";
        Qt.application.domain = "quickshell.org";
        appListModel.reload();
    }
}
