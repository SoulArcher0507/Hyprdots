pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Qt.labs.platform 1.1
import Quickshell
import Quickshell.Io
import "functions"
import "." as Common

Singleton {
    id: root

    readonly property string jsonPath: StandardPaths.writableLocation(StandardPaths.ConfigLocation) + "/quickshell/colors.json"

    property var _j: ({
        special: {
            background: "#222222",
            foreground: "#cccccc",
            cursor: "#cccccc"
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

    property FileView _themeFile: FileView {
        path: root.jsonPath
        watchChanges: true
        Component.onCompleted: this.reload()
        onFileChanged: this.reload()
        onLoaded: root._applyFromText(this.text())
    }

    property bool edgeAnimationsEnabled: true
    property bool borderAnimationsEnabled: true

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
        var legacyValue = undefined;
        var foundBorderValue = false;
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim();
            if (line === "[quickshell.theme]") {
                inSection = true;
                continue;
            }
            if (inSection) {
                if (line.startsWith("[")) break;
                if (line.startsWith("borderAnimationsEnabled=")) {
                    var val = line.split("=")[1].trim().toLowerCase();
                    root.borderAnimationsEnabled = (val === "true");
                    foundBorderValue = true;
                    continue;
                }
                if (line.startsWith("edgeAnimationsEnabled=")) {
                    legacyValue = (line.split("=")[1].trim().toLowerCase() === "true");
                }
            }
        }
        if (!foundBorderValue && legacyValue !== undefined)
            root.borderAnimationsEnabled = legacyValue;
        if (legacyValue !== undefined)
            root.edgeAnimationsEnabled = legacyValue;
    }

    function _applyFromText(txt) {
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
                    foreground: pick(_j.special.foreground, s.foreground),
                    cursor: pick(_j.special.cursor, s.cursor)
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
            console.warn("overview Appearance: invalid colors.json, using fallback theme", e);
        }
    }

    function _pick(deflt) {
        for (let i = 1; i < arguments.length; ++i) {
            const v = arguments[i];
            if (v !== undefined && v !== null && v !== "")
                return v;
        }
        return deflt;
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

    function mix(a, b, t) {
        const A = _toRgb(a), B = _toRgb(b);
        const k = Math.max(0, Math.min(1, t));
        return Qt.rgba(A.r * (1 - k) + B.r * k, A.g * (1 - k) + B.g * k, A.b * (1 - k) + B.b * k, 1.0);
    }

    function surface(level) {
        return mix(background, foreground, Math.max(0, Math.min(1, level)));
    }

    function withAlpha(c, a) {
        const rgb = _toRgb(c);
        const alpha = (a === undefined || a === null) ? 1.0 : Math.max(0, Math.min(1, a));
        return Qt.rgba(rgb.r || 0, rgb.g || 0, rgb.b || 0, alpha);
    }

    function bestOnColor(color) {
        const c = Qt.color(color);
        function ch(v) { return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4); }
        const luminance = 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
        return luminance > 0.5 ? "#121212" : "#f5f5f5";
    }

    readonly property color background: _pick("#222222", _j?.quickshell?.bg, _j?.special?.background)
    readonly property color foreground: _pick("#cccccc", _j?.quickshell?.fg, _j?.special?.foreground)

    readonly property color c4: _pick("#61afef", _j?.colors?.color4)
    readonly property color c5: _pick("#c678dd", _j?.colors?.color5)
    readonly property color c6: _pick("#56b6c2", _j?.colors?.color6)
    readonly property color c8: _pick("#3e4451", _j?.colors?.color8)

    readonly property color accent: _pick(c4, _j?.quickshell?.accent)
    readonly property color accent2: _pick(c6, _j?.quickshell?.accent2)

    readonly property color base: surface(0.10)
    readonly property color text: foreground
    readonly property color subtext0: mix(background, foreground, 0.6)
    readonly property color overlay0: mix(background, foreground, 0.3)
    readonly property color overlay1: mix(background, foreground, 0.4)
    readonly property color surface0: surface(0.06)
    readonly property color surface1: surface(0.08)
    readonly property color surface2: surface(0.12)
    readonly property color moduleBorderColor: mix(background, foreground, 0.35)
    readonly property color moduleFontColor: accent

    property QtObject m3colors: QtObject {
        property color m3background: root.background
        property color m3outline: root.moduleBorderColor
    }

    property QtObject colors
    property QtObject rounding
    property QtObject font
    property QtObject sizes

    colors: QtObject {
        property color base: root.base
        property color text: root.text
        property color subtext0: root.subtext0
        property color overlay0: root.overlay0
        property color overlay1: root.overlay1
        property color surface0: root.surface0
        property color surface1: root.surface1
        property color surface2: root.surface2
        property color accent: root.accent
        property color moduleBorderColor: root.moduleBorderColor
        property color moduleFontColor: root.moduleFontColor

        property color colSubtext: subtext0
        property color colLayer0: base
        property color colOnLayer0: text
        property color colLayer0Border: moduleBorderColor
        property color colLayer1: surface1
        property color colOnLayer1: text
        property color colOnLayer1Inactive: root.overlay1
        property color colLayer1Hover: surface2
        property color colLayer1Active: root.mix(surface2, text, 0.12)
        property color colLayer2: surface2
        property color colOnLayer2: text
        property color colLayer2Border: moduleBorderColor
        property color colLayer2Hover: root.mix(surface2, text, 0.14)
        property color colLayer2Active: root.mix(surface2, text, 0.22)
        property color colPrimary: root.accent
        property color colOnPrimary: root.bestOnColor(root.accent)
        property color colSecondary: root.accent
        property color colSecondaryContainer: root.mix(root.background, root.accent, 0.24)
        property color colOnSecondaryContainer: text
        property color colTooltip: root.foreground
        property color colOnTooltip: root.background
        property color colShadow: root.withAlpha("#000000", 0.3)
        property color colOutline: root.moduleBorderColor
    }

    property QtObject animation
    property QtObject animationCurves

    rounding: QtObject {
        property int unsharpen: Common.Config.options.appearance.rounding.unsharpen
        property int verysmall: Common.Config.options.appearance.rounding.verysmall
        property int small: Common.Config.options.appearance.rounding.small
        property int normal: Common.Config.options.appearance.rounding.normal
        property int large: Common.Config.options.appearance.rounding.large
        property int full: Common.Config.options.appearance.rounding.full
        property int screenRounding: Common.Config.options.appearance.rounding.screenRounding
        property int windowRounding: Common.Config.options.appearance.rounding.windowRounding
    }

    font: QtObject {
        property QtObject family: QtObject {
            property string main: Common.Config.options.appearance.font.family.main
            property string title: Common.Config.options.appearance.font.family.title
            property string expressive: Common.Config.options.appearance.font.family.expressive
        }
        property QtObject pixelSize: QtObject {
            property int smaller: Common.Config.options.appearance.font.pixelSize.smaller
            property int small: Common.Config.options.appearance.font.pixelSize.small
            property int normal: Common.Config.options.appearance.font.pixelSize.normal
            property int larger: Common.Config.options.appearance.font.pixelSize.larger
            property int huge: Common.Config.options.appearance.font.pixelSize.huge
        }
    }

    animationCurves: QtObject {
        readonly property list<real> expressiveDefaultSpatial: [0.38, 1.21, 0.22, 1.00, 1, 1]
        readonly property list<real> expressiveEffects: [0.34, 0.80, 0.34, 1.00, 1, 1]
        readonly property list<real> emphasizedDecel: [0.05, 0.7, 0.1, 1, 1, 1]
        readonly property real expressiveDefaultSpatialDuration: Common.Config.options.appearance.animation.duration.elementMove
        readonly property real expressiveEffectsDuration: Common.Config.options.appearance.animation.duration.elementMoveFast
    }

    animation: QtObject {
        property QtObject elementMove: QtObject {
            property int duration: animationCurves.expressiveDefaultSpatialDuration
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.expressiveDefaultSpatial
            property Component numberAnimation: Component {
                NumberAnimation {
                    duration: root.animation.elementMove.duration
                    easing.type: root.animation.elementMove.type
                    easing.bezierCurve: root.animation.elementMove.bezierCurve
                }
            }
        }

        property QtObject elementMoveEnter: QtObject {
            property int duration: Common.Config.options.appearance.animation.duration.elementMoveEnter
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.emphasizedDecel
            property Component numberAnimation: Component {
                NumberAnimation {
                    duration: root.animation.elementMoveEnter.duration
                    easing.type: root.animation.elementMoveEnter.type
                    easing.bezierCurve: root.animation.elementMoveEnter.bezierCurve
                }
            }
        }

        property QtObject elementMoveFast: QtObject {
            property int duration: animationCurves.expressiveEffectsDuration
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.expressiveEffects
            property Component numberAnimation: Component {
                NumberAnimation {
                    duration: root.animation.elementMoveFast.duration
                    easing.type: root.animation.elementMoveFast.type
                    easing.bezierCurve: root.animation.elementMoveFast.bezierCurve
                }
            }
        }
    }

    sizes: QtObject {
        property real elevationMargin: Common.Config.options.appearance.sizes.elevationMargin
    }
}
