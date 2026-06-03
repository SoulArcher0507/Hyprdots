import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "../../theme" as ThemePkg

Item {
    id: root
    focus: true
    anchors.fill: parent

    readonly property int panelWidth: 1020
    readonly property int panelHeight: 580
    readonly property int panelMargin: 16
    readonly property int contentMargin: 22

    readonly property color base: ThemePkg.Theme.surface(0.10)
    readonly property color mantle: ThemePkg.Theme.surface(0.05)
    readonly property color crust: ThemePkg.Theme.background
    readonly property color text: ThemePkg.Theme.foreground
    readonly property color subtext0: ThemePkg.Theme.mix(ThemePkg.Theme.background, ThemePkg.Theme.foreground, 0.6)
    readonly property color overlay0: ThemePkg.Theme.mix(ThemePkg.Theme.background, ThemePkg.Theme.foreground, 0.3)
    readonly property color surface0: ThemePkg.Theme.surface(0.06)
    readonly property color surface1: ThemePkg.Theme.surface(0.08)
    readonly property color surface2: ThemePkg.Theme.surface(0.12)
    readonly property color accent: ThemePkg.Theme.accent
    readonly property color accent2: ThemePkg.Theme.accent2
    readonly property color panelBorderColor: ThemePkg.Theme.mix(ThemePkg.Theme.background, ThemePkg.Theme.foreground, 0.35)

    readonly property color pink: ThemePkg.Theme.c5
    readonly property color mauve: ThemePkg.Theme.c13
    readonly property color blue: ThemePkg.Theme.c4
    readonly property color teal: ThemePkg.Theme.c6
    readonly property color yellow: ThemePkg.Theme.c3
    readonly property color peach: ThemePkg.Theme.c11
    readonly property color green: ThemePkg.Theme.c2
    readonly property color red: ThemePkg.Theme.danger
    readonly property color sapphire: ThemePkg.Theme.c14

    property int activeEditIndex: 0
    property real uiScale: 0.10
    property int originalLayoutOriginX: 0
    property int originalLayoutOriginY: 0
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

    ListModel { id: monitorsModel }

    property color selectedResAccent: root.mauve
    property color selectedRateAccent: root.blue

    property real currentSimW: monitorsModel.count > 0 ? monitorsModel.get(activeEditIndex).resW : 1920
    property real currentSimH: monitorsModel.count > 0 ? monitorsModel.get(activeEditIndex).resH : 1080

    function isRotated(xform) { return xform === 1 || xform === 3 || xform === 5 || xform === 7; }
    function displayW(m) { return isRotated(m.transform) ? m.resH : m.resW; }
    function displayH(m) { return isRotated(m.transform) ? m.resW : m.resH; }
    readonly property var transformLabels: ["0°", "90°", "180°", "270°"]
    readonly property var transformValues: [0, 1, 2, 3]

    readonly property string deviceProfileScriptPath: Quickshell.env("HOME") + "/.config/hypr/scripts/device-profile.sh"
    readonly property string profileConfigDir: Quickshell.env("HOME") + "/.config/hypr/conf/profiles"
    readonly property string activeWallpaperPath: Quickshell.env("HOME") + "/Pictures/Wallpapers/active/active.jpg"
    readonly property string wallpaperScriptPath: Quickshell.env("HOME") + "/.config/awww/wallpaper.sh"

    property real globalOrbitAngle: 0
    NumberAnimation on globalOrbitAngle {
        from: 0; to: Math.PI * 2; duration: 90000
        loops: Animation.Infinite; running: true
    }

    property real introProgress: 0.0
    property real monitorScale: 0.85
    property real uiYOffset: 25
    property real screenLight: 0.0
    property bool applyHovered: false
    property bool applyPressed: false
    property real applyFillLevel: 0.0
    property bool applyTriggered: false
    property real applyFlashOpacity: 0.0
    property int applyHoldDuration: 750
    readonly property real dragBoundsPadding: 40
    readonly property real monitorSnapThreshold: 20
    readonly property real monitorDragSnapDistance: 12
    readonly property real monitorKeySnapDistance: 0
    readonly property real monitorKeyStep: Math.max(root.uiScale, root.uiScale * 2)

    Component.onCompleted: {
        root.forceActiveFocus();
        root.popupTargetVisible = true;
        startupAnim.start();
        popupEnterAnim.start();
    }

    function canHandleMonitorArrowKeys() {
        return monitorsModel.count >= 2 && !root.editorHasFocus();
    }

    Keys.onPressed: event => {
        if (!root.canHandleMonitorArrowKeys())
            return;

        var handled = false;
        switch (event.key) {
        case Qt.Key_Left:
            handled = root.nudgeSelectedMonitor(-root.monitorKeyStep, 0);
            break;
        case Qt.Key_Right:
            handled = root.nudgeSelectedMonitor(root.monitorKeyStep, 0);
            break;
        case Qt.Key_Up:
            handled = root.nudgeSelectedMonitor(0, -root.monitorKeyStep);
            break;
        case Qt.Key_Down:
            handled = root.nudgeSelectedMonitor(0, root.monitorKeyStep);
            break;
        }

        if (handled)
            event.accepted = true;
    }

    Shortcut {
        sequence: "Left"
        context: Qt.WindowShortcut
        enabled: root.canHandleMonitorArrowKeys()
        autoRepeat: true
        onActivated: root.nudgeSelectedMonitor(-root.monitorKeyStep, 0)
    }

    Shortcut {
        sequence: "Right"
        context: Qt.WindowShortcut
        enabled: root.canHandleMonitorArrowKeys()
        autoRepeat: true
        onActivated: root.nudgeSelectedMonitor(root.monitorKeyStep, 0)
    }

    Shortcut {
        sequence: "Up"
        context: Qt.WindowShortcut
        enabled: root.canHandleMonitorArrowKeys()
        autoRepeat: true
        onActivated: root.nudgeSelectedMonitor(0, -root.monitorKeyStep)
    }

    Shortcut {
        sequence: "Down"
        context: Qt.WindowShortcut
        enabled: root.canHandleMonitorArrowKeys()
        autoRepeat: true
        onActivated: root.nudgeSelectedMonitor(0, root.monitorKeyStep)
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
        return root.barPanelCenterY - (root.popupClosedHeight / 2);
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

    ParallelAnimation {
        id: startupAnim
        NumberAnimation { target: root; property: "introProgress"; from: 0.0; to: 1.0; duration: 900; easing.type: Easing.OutQuint }
        NumberAnimation { target: root; property: "monitorScale"; from: 0.85; to: 1.0; duration: 1200; easing.type: Easing.OutQuint }
        NumberAnimation { target: root; property: "uiYOffset"; from: 25; to: 0; duration: 1800; easing.type: Easing.OutQuint }
        NumberAnimation { target: root; property: "screenLight"; from: 0.0; to: 1.0; duration: 1500; easing.type: Easing.InOutQuad }
    }

    function shellQuote(value) {
        return "'" + String(value === undefined || value === null ? "" : value).replace(/'/g, "'\\''") + "'";
    }

    function luaQuote(value) {
        return "\"" + String(value === undefined || value === null ? "" : value).replace(/\\/g, "\\\\").replace(/"/g, "\\\"") + "\"";
    }

    function layoutWidthFor(monitor) {
        return Math.round(root.displayW(monitor) / monitor.sysScale);
    }

    function layoutHeightFor(monitor) {
        return Math.round(root.displayH(monitor) / monitor.sysScale);
    }

    function formatRefreshRate(value) {
        var num = Number(value);
        if (!isFinite(num) || num <= 0)
            return "60";
        var fixed = num.toFixed(3);
        return fixed.replace(/\.?0+$/, "");
    }

    function commitPendingEditorState() {
        if (typeof customWInput !== "undefined")
            customWInput.focus = false;
        if (typeof customHInput !== "undefined")
            customHInput.focus = false;

        if (monitorsModel.count === 0 || root.activeEditIndex < 0 || root.activeEditIndex >= monitorsModel.count)
            return;

        if (typeof customWInput !== "undefined" && customWInput.acceptableInput)
            monitorsModel.setProperty(root.activeEditIndex, "resW", parseInt(customWInput.text));
        if (typeof customHInput !== "undefined" && customHInput.acceptableInput)
            monitorsModel.setProperty(root.activeEditIndex, "resH", parseInt(customHInput.text));

        root.forceLayoutUpdate();
    }

    function editorHasFocus() {
        return (typeof customWInput !== "undefined" && customWInput.activeFocus)
            || (typeof customHInput !== "undefined" && customHInput.activeFocus);
    }

    function syncCustomInputs() {
        if (monitorsModel.count === 0 || root.activeEditIndex < 0 || root.activeEditIndex >= monitorsModel.count)
            return;
        var active = monitorsModel.get(root.activeEditIndex);
        if (typeof customWInput !== "undefined")
            customWInput.text = String(active.resW);
        if (typeof customHInput !== "undefined")
            customHInput.text = String(active.resH);
    }

    function selectMonitor(index) {
        if (index < 0 || index >= monitorsModel.count || index === root.activeEditIndex)
            return;
        root.commitPendingEditorState();
        root.activeEditIndex = index;
        root.syncCustomInputs();
        root.forceActiveFocus();
    }

    function normalizedMonitorLayout() {
        var rects = [];
        for (var i = 0; i < monitorsModel.count; i++) {
            var m = monitorsModel.get(i);
            rects.push({
                index: i,
                name: m.name,
                resW: Number(m.resW),
                resH: Number(m.resH),
                sysScale: Number(m.sysScale),
                rate: String(m.rate),
                uiX: Number(m.uiX),
                uiY: Number(m.uiY),
                transform: Number(m.transform || 0),
                isMirror: !!m.isMirror,
                mirrorTarget: String(m.mirrorTarget || ""),
                layoutW: root.layoutWidthFor(m),
                layoutH: root.layoutHeightFor(m)
            });
        }

        rects.sort(function (a, b) {
            if (a.uiX !== b.uiX)
                return a.uiX - b.uiX;
            if (a.uiY !== b.uiY)
                return a.uiY - b.uiY;
            return a.name.localeCompare(b.name);
        });

        var minX = 999999;
        var minY = 999999;
        for (var j = 0; j < rects.length; j++) {
            var r = rects[j];
            if (r.isMirror && r.mirrorTarget)
                continue;
            var layoutX = Math.round(r.uiX / root.uiScale);
            var layoutY = Math.round(r.uiY / root.uiScale);
            r.layoutX = layoutX;
            r.layoutY = layoutY;
            minX = Math.min(minX, layoutX);
            minY = Math.min(minY, layoutY);
        }

        if (minX === 999999)
            minX = 0;
        if (minY === 999999)
            minY = 0;

        for (var k = 0; k < rects.length; k++) {
            var item = rects[k];
            if (item.isMirror && item.mirrorTarget)
                continue;
            item.layoutX = Math.round(item.layoutX - minX);
            item.layoutY = Math.round(item.layoutY - minY);
        }

        return rects;
    }

    function monitorConfigLine(monitor) {
        var rate = String(monitor.rate || "60");
        if (monitor.isMirror && monitor.mirrorTarget) {
            var mirrorLine = "hl.monitor({ output = " + root.luaQuote(monitor.name)
                + ", mode = " + root.luaQuote(monitor.resW + "x" + monitor.resH + "@" + rate)
                + ", position = \"auto\", scale = " + monitor.sysScale
                + ", mirror = " + root.luaQuote(monitor.mirrorTarget);
            if (monitor.transform > 0)
                mirrorLine += ", transform = " + monitor.transform;
            return mirrorLine + " })";
        }

        var line = "hl.monitor({ output = " + root.luaQuote(monitor.name)
            + ", mode = " + root.luaQuote(monitor.resW + "x" + monitor.resH + "@" + rate)
            + ", position = " + root.luaQuote(monitor.layoutX + "x" + monitor.layoutY)
            + ", scale = " + monitor.sysScale;
        if (monitor.transform > 0)
            line += ", transform = " + monitor.transform;
        return line + " })";
    }

    function applyMonitorConfig(configContent) {
        var cmd = "profile=$(" + root.shellQuote(root.deviceProfileScriptPath) + " 2>/dev/null || printf desktop)" +
            " && target=" + root.shellQuote(root.profileConfigDir) + "/\"$profile\"/monitor.lua" +
            " && mkdir -p \"$(dirname \"$target\")\"" +
            " && cat > \"$target\" <<'QSMONEOF'\n" +
            configContent +
            "QSMONEOF\n" +
            "hyprctl reload";
        cmd += " && if [ -x " + root.shellQuote(root.wallpaperScriptPath) + " ] && [ -f " + root.shellQuote(root.activeWallpaperPath) + " ]; then ";
        cmd += root.shellQuote(root.wallpaperScriptPath) + " " + root.shellQuote(root.activeWallpaperPath) + " >/dev/null 2>&1 || true; ";
        cmd += "fi";
        Quickshell.execDetached(["bash", "-lc", cmd]);
        repollTimer.restart();
    }

    function triggerApplyAll() {
        if (monitorsModel.count === 0) return;
        root.commitPendingEditorState();

        var layout = root.normalizedMonitorLayout();
        var configLines = [
            "-- " + "-".repeat(53),
            "-- Monitor",
            "-- " + "-".repeat(53)
        ];
        var summaryParts = [];

        for (var i = 0; i < layout.length; i++) {
            var monitor = layout[i];
            configLines.push(root.monitorConfigLine(monitor));
            summaryParts.push(monitor.name);
        }

        var configContent = configLines.join("\n") + "\n";
        root.applyMonitorConfig(configContent);

        if (layout.length === 1) {
            var single = layout[0];
            Quickshell.execDetached(["notify-send", "-a", "Monitor Config", "-i", "preferences-desktop-display", "Display Update", "Applied: " + single.resW + "x" + single.resH + " @ " + single.rate + "Hz"]);
        } else {
            Quickshell.execDetached(["notify-send", "-a", "Monitor Config", "-i", "preferences-desktop-display", "Display Update", "Applied layout for: " + summaryParts.join(" ")]);
        }
    }

    NumberAnimation {
        id: applyFillAnim
        target: root
        property: "applyFillLevel"
        to: 1.0
        duration: root.applyHoldDuration * (1.0 - root.applyFillLevel)
        easing.type: Easing.InSine
        onFinished: {
            if (!root.applyTriggered) {
                root.applyTriggered = true;
                root.applyFlashOpacity = 0.6;
                applyFlashDrainAnim.start();
                root.triggerApplyAll();
                root.applyFillLevel = 0.0;
                root.applyTriggered = false;
                root.applyPressed = false;
            }
        }
    }

    NumberAnimation {
        id: applyDrainAnim
        target: root
        property: "applyFillLevel"
        to: 0.0
        duration: 800 * root.applyFillLevel
        easing.type: Easing.OutQuad
    }

    NumberAnimation {
        id: applyFlashDrainAnim
        target: root
        property: "applyFlashOpacity"
        to: 0.0
        duration: 450
        easing.type: Easing.OutExpo
    }

    onActiveEditIndexChanged: {
        menuTransitionAnim.restart();
        root.syncCustomInputs();
    }

    function isOverlapping(ax, ay, aw, ah, bx, by, bw, bh) {
        return ax < bx + bw && ax + aw > bx && ay < by + bh && ay + ah > by;
    }

    function isOverlappingAny(x, y, w, h, skipIdx) {
        for (var i = 0; i < monitorsModel.count; i++) {
            if (i === skipIdx) continue;
            var m = monitorsModel.get(i);
            var mW = (root.displayW(m) / m.sysScale) * root.uiScale;
            var mH = (root.displayH(m) / m.sysScale) * root.uiScale;
            if (isOverlapping(x, y, w, h, m.uiX, m.uiY, mW, mH)) return true;
        }
        return false;
    }

    function getPerimeterSnap(pX, pY, sX, sY, sW, sH, mW, mH, snapT) {
        var edges = [
            { x1: sX - mW, x2: sX + sW, y1: sY - mH, y2: sY - mH },
            { x1: sX - mW, x2: sX + sW, y1: sY + sH, y2: sY + sH },
            { x1: sX - mW, x2: sX - mW, y1: sY - mH, y2: sY + sH },
            { x1: sX + sW, x2: sX + sW, y1: sY - mH, y2: sY + sH }
        ];

        var bestX = pX, bestY = pY, minDist = 999999;
        for (var i = 0; i < 4; i++) {
            var e = edges[i];
            var cx = Math.max(e.x1, Math.min(pX, e.x2));
            var cy = Math.max(e.y1, Math.min(pY, e.y2));
            if (Math.abs(cx - sX) < snapT) cx = sX;
            if (Math.abs(cx - (sX + sW - mW)) < snapT) cx = sX + sW - mW;
            if (Math.abs(cx - (sX + sW / 2 - mW / 2)) < snapT) cx = sX + sW / 2 - mW / 2;
            if (Math.abs(cy - sY) < snapT) cy = sY;
            if (Math.abs(cy - (sY + sH - mH)) < snapT) cy = sY + sH - mH;
            if (Math.abs(cy - (sY + sH / 2 - mH / 2)) < snapT) cy = sY + sH / 2 - mH / 2;
            var dist = Math.hypot(pX - cx, pY - cy);
            if (dist < minDist) { minDist = dist; bestX = cx; bestY = cy; }
        }
        return { x: bestX, y: bestY };
    }

    function clampMonitorPosition(index, proposedX, proposedY, monitorWidth, monitorHeight) {
        if (monitorsModel.count < 2)
            return { x: proposedX, y: proposedY };

        var boundMinX = 999999;
        var boundMinY = 999999;
        var boundMaxX = -999999;
        var boundMaxY = -999999;
        for (var i = 0; i < monitorsModel.count; i++) {
            if (i === index)
                continue;
            var sibling = monitorsModel.get(i);
            var siblingWidth = (root.displayW(sibling) / sibling.sysScale) * root.uiScale;
            var siblingHeight = (root.displayH(sibling) / sibling.sysScale) * root.uiScale;
            boundMinX = Math.min(boundMinX, sibling.uiX - monitorWidth - root.dragBoundsPadding);
            boundMinY = Math.min(boundMinY, sibling.uiY - monitorHeight - root.dragBoundsPadding);
            boundMaxX = Math.max(boundMaxX, sibling.uiX + siblingWidth + root.dragBoundsPadding);
            boundMaxY = Math.max(boundMaxY, sibling.uiY + siblingHeight + root.dragBoundsPadding);
        }

        if (boundMinX === 999999)
            return { x: proposedX, y: proposedY };

        return {
            x: Math.max(boundMinX, Math.min(proposedX, boundMaxX)),
            y: Math.max(boundMinY, Math.min(proposedY, boundMaxY))
        };
    }

    function bestMonitorSnap(index, proposedX, proposedY, monitorWidth, monitorHeight) {
        var bestX = proposedX;
        var bestY = proposedY;
        var bestDist = 999999;
        var found = false;

        for (var i = 0; i < monitorsModel.count; i++) {
            if (i === index)
                continue;
            var sibling = monitorsModel.get(i);
            var siblingWidth = (root.displayW(sibling) / sibling.sysScale) * root.uiScale;
            var siblingHeight = (root.displayH(sibling) / sibling.sysScale) * root.uiScale;
            var snapped = root.getPerimeterSnap(
                proposedX,
                proposedY,
                sibling.uiX,
                sibling.uiY,
                siblingWidth,
                siblingHeight,
                monitorWidth,
                monitorHeight,
                root.monitorSnapThreshold
            );
            var dist = Math.hypot(proposedX - snapped.x, proposedY - snapped.y);
            if (dist < bestDist) {
                bestDist = dist;
                bestX = snapped.x;
                bestY = snapped.y;
                found = true;
            }
        }

        return {
            found: found,
            x: bestX,
            y: bestY,
            distance: bestDist
        };
    }

    function resolveMonitorPosition(index, proposedX, proposedY, monitorWidth, monitorHeight, snapDistance) {
        var clamped = root.clampMonitorPosition(index, proposedX, proposedY, monitorWidth, monitorHeight);
        var rawOverlaps = root.isOverlappingAny(clamped.x, clamped.y, monitorWidth, monitorHeight, index);
        var bestSnap = root.bestMonitorSnap(index, clamped.x, clamped.y, monitorWidth, monitorHeight);

        var targetX = clamped.x;
        var targetY = clamped.y;
        if (bestSnap.found && (bestSnap.distance <= snapDistance || rawOverlaps)) {
            targetX = bestSnap.x;
            targetY = bestSnap.y;
        }

        if (root.isOverlappingAny(targetX, targetY, monitorWidth, monitorHeight, index)) {
            var current = monitorsModel.get(index);
            targetX = current.uiX;
            targetY = current.uiY;
        }

        return { x: targetX, y: targetY };
    }

    function forceLayoutUpdate() {
        if (monitorsModel.count < 2) return;
        var mIdx = root.activeEditIndex;
        var mModel = monitorsModel.get(mIdx);
        var mW = (root.displayW(mModel) / mModel.sysScale) * root.uiScale;
        var mH = (root.displayH(mModel) / mModel.sysScale) * root.uiScale;
        var resolved = root.resolveMonitorPosition(mIdx, mModel.uiX, mModel.uiY, mW, mH, 999999);
        monitorsModel.setProperty(mIdx, "uiX", resolved.x);
        monitorsModel.setProperty(mIdx, "uiY", resolved.y);
    }

    function nudgeSelectedMonitor(deltaX, deltaY) {
        if (monitorsModel.count < 2 || root.activeEditIndex < 0 || root.activeEditIndex >= monitorsModel.count)
            return false;

        root.commitPendingEditorState();
        var selected = monitorsModel.get(root.activeEditIndex);
        var monitorWidth = (root.displayW(selected) / selected.sysScale) * root.uiScale;
        var monitorHeight = (root.displayH(selected) / selected.sysScale) * root.uiScale;
        var resolved = root.resolveMonitorPosition(
            root.activeEditIndex,
            selected.uiX + deltaX,
            selected.uiY + deltaY,
            monitorWidth,
            monitorHeight,
            root.monitorKeySnapDistance
        );

        if (Math.abs(resolved.x - selected.uiX) < 0.001 && Math.abs(resolved.y - selected.uiY) < 0.001)
            return false;

        monitorsModel.setProperty(root.activeEditIndex, "uiX", resolved.x);
        monitorsModel.setProperty(root.activeEditIndex, "uiY", resolved.y);
        return true;
    }

    Timer {
        id: delayedLayoutUpdate
        interval: 10; running: false; repeat: false
        onTriggered: root.forceLayoutUpdate()
    }

    Process {
        id: displayPoller
        command: ["hyprctl", "monitors", "-j"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text.trim());
                    monitorsModel.clear();
                    var minX = 999999, minY = 999999;
                    for (var i = 0; i < data.length; i++) {
                        if (data[i].x < minX) minX = data[i].x;
                        if (data[i].y < minY) minY = data[i].y;
                    }
                    root.originalLayoutOriginX = minX !== 999999 ? minX : 0;
                    root.originalLayoutOriginY = minY !== 999999 ? minY : 0;
                    for (var i = 0; i < data.length; i++) {
                        var scl = data[i].scale !== undefined ? data[i].scale : 1.0;
                        var normalizedX = (data[i].x - minX) * root.uiScale;
                        var normalizedY = (data[i].y - minY) * root.uiScale;
                        var xform = data[i].transform !== undefined ? data[i].transform : 0;
                        monitorsModel.append({
                            name: data[i].name,
                            resW: data[i].width,
                            resH: data[i].height,
                            sysScale: scl,
                            rate: root.formatRefreshRate(data[i].refreshRate),
                            uiX: normalizedX,
                            uiY: normalizedY,
                            transform: xform,
                            isMirror: false,
                            mirrorTarget: ""
                        });
                        if (data[i].focused) root.activeEditIndex = i;
                    }
                    root.syncCustomInputs();
                    root.forceLayoutUpdate();
                } catch (e) {}
            }
        }
    }

    Timer {
        id: repollTimer
        interval: 600; repeat: false
        onTriggered: displayPoller.running = true
    }

    function createVirtualMonitor() {
        Quickshell.execDetached(["hyprctl", "output", "create", "headless"]);
        repollTimer.start();
    }

    function removeVirtualMonitor(monName) {
        Quickshell.execDetached(["hyprctl", "output", "remove", monName]);
        repollTimer.start();
    }

    function otherMonitorNames() {
        var names = [];
        for (var i = 0; i < monitorsModel.count; i++) {
            if (i !== root.activeEditIndex)
                names.push(monitorsModel.get(i).name);
        }
        return names;
    }

    function isVirtual(monName) {
        return monName.indexOf("HEADLESS-") === 0;
    }

    Item {
        id: panelShell
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.rightMargin: root.panelMargin
        width: root.popupCardWidth
        height: root.popupCardHeight
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
            id: monitorPanel
            width: root.panelWidth
            height: root.panelHeight
            radius: 20
            color: root.base
            border.color: root.panelBorderColor
            border.width: 1
            clip: true
            anchors {
                top: parent.top
                right: parent.right
            }

            AnimatedBorder {
                anchors.fill: parent
                radius: parent.radius
                borderWidth: parent.border.width
                accentColor: root.accent
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onClicked: {}
            }

            Rectangle {
                width: parent.width * 0.8; height: width; radius: width / 2
                x: Math.round((parent.width / 2 - width / 2) + Math.cos(root.globalOrbitAngle * 2) * 150)
                y: Math.round((parent.height / 2 - height / 2) + Math.sin(root.globalOrbitAngle * 2) * 100)
                opacity: 0.04; color: root.selectedResAccent
                Behavior on color { ColorAnimation { duration: 1000 } }
            }
            Rectangle {
                width: parent.width * 0.9; height: width; radius: width / 2
                x: Math.round((parent.width / 2 - width / 2) + Math.sin(root.globalOrbitAngle * 1.5) * -150)
                y: Math.round((parent.height / 2 - height / 2) + Math.cos(root.globalOrbitAngle * 1.5) * -100)
                opacity: 0.04; color: root.selectedRateAccent
                Behavior on color { ColorAnimation { duration: 1000 } }
            }

            Item {
                id: leftVisualArea
                width: 440; height: 380
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 20

                Item {
                    anchors.fill: parent
                    visible: monitorsModel.count === 1

                    Item {
                        id: singleMonitorZoom
                        anchors.centerIn: parent
                        width: 440; height: 340
                        property real baseScale: Math.min(1.0, 2200 / root.currentSimW)
                        scale: baseScale * root.monitorScale
                        opacity: root.introProgress
                        Behavior on baseScale { NumberAnimation { duration: 600; easing.type: Easing.OutQuint } }

                        Rectangle {
                            width: 1000; height: 14; radius: 6
                            anchors.top: standBase.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: root.mantle; border.color: root.surface0; border.width: 1

                            Rectangle {
                                width: 24; height: 350; radius: 4; color: root.crust
                                anchors { top: parent.bottom; topMargin: -5; left: parent.left; leftMargin: 100 }
                                z: -1
                            }
                            Rectangle {
                                width: 24; height: 350; radius: 4; color: root.crust
                                anchors { top: parent.bottom; topMargin: -5; right: parent.right; rightMargin: 100 }
                                z: -1
                            }
                        }

                        Rectangle {
                            id: standBase
                            width: 130; height: 8; radius: 4
                            anchors { bottom: parent.bottom; bottomMargin: 20; horizontalCenter: parent.horizontalCenter }
                            color: root.surface1
                        }

                        Rectangle {
                            id: standNeck
                            width: 34; height: 70
                            anchors { bottom: standBase.top; horizontalCenter: parent.horizontalCenter }
                            color: root.surface0
                            Rectangle { width: 10; height: 30; radius: 5; anchors.centerIn: parent; color: root.base }
                        }

                        Rectangle {
                            id: screenBezel
                            width: 140 + (180 * (root.currentSimW / 1920))
                            height: 90 + (90 * (root.currentSimH / 1080))
                            anchors { bottom: standNeck.top; bottomMargin: -10; horizontalCenter: parent.horizontalCenter }
                            radius: 12; color: root.crust; border.color: root.surface2; border.width: 2
                            Behavior on width { NumberAnimation { duration: 600; easing.type: Easing.OutQuint } }
                            Behavior on height { NumberAnimation { duration: 600; easing.type: Easing.OutQuint } }

                            Rectangle {
                                anchors.fill: parent; anchors.margins: 10
                                radius: 6; color: root.surface0; clip: true

                                Rectangle {
                                    anchors.fill: parent; color: "transparent"
                                    opacity: root.screenLight
                                    gradient: Gradient {
                                        orientation: Gradient.Vertical
                                        GradientStop { position: 0.0; color: Qt.tint(root.surface0, Qt.alpha(root.selectedResAccent, 0.15)); Behavior on color { ColorAnimation { duration: 400 } } }
                                        GradientStop { position: 1.0; color: Qt.tint(root.surface0, Qt.alpha(root.selectedRateAccent, 0.1)); Behavior on color { ColorAnimation { duration: 400 } } }
                                    }

                                    Grid {
                                        anchors.centerIn: parent; rows: 10; columns: 15; spacing: 20
                                        Repeater { model: 150; Rectangle { width: 2; height: 2; radius: 1; color: Qt.alpha(root.text, 0.1) } }
                                    }

                                    Item {
                                        anchors.centerIn: parent
                                        scale: 1.0 / singleMonitorZoom.scale
                                        ColumnLayout {
                                            anchors.centerIn: parent; spacing: 4
                                            Text {
                                                Layout.alignment: Qt.AlignHCenter
                                                font.family: "CaskaydiaMono Nerd Font"; font.pixelSize: 38
                                                color: root.selectedResAccent; text: "󰍹"
                                                Behavior on color { ColorAnimation { duration: 400 } }
                                            }
                                            Text {
                                                Layout.alignment: Qt.AlignHCenter
                                                font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: 16
                                                color: root.text
                                                text: monitorsModel.count > 0 ? monitorsModel.get(0).name : "Unknown"
                                            }
                                            Text {
                                                Layout.alignment: Qt.AlignHCenter
                                                font.family: "JetBrains Mono"; font.pixelSize: 12; color: root.subtext0
                                                text: root.currentSimW + "x" + root.currentSimH + " @ " + (monitorsModel.count > 0 ? monitorsModel.get(0).rate : "60") + "Hz"
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Item {
                    anchors.fill: parent
                    visible: monitorsModel.count > 1

                    Item {
                        id: multiMonitorView
                        width: 440; height: 340
                        anchors.centerIn: parent; clip: true

                        Grid {
                            anchors.centerIn: parent; rows: 25; columns: 34; spacing: 18
                            Repeater { model: 850; Rectangle { width: 2; height: 2; radius: 1; color: Qt.alpha(root.text, 0.1) } }
                        }

                        property real targetScale: {
                            if (monitorsModel.count < 2) return 1.0;
                            var minX = 999999, minY = 999999, maxX = -999999, maxY = -999999;
                            for (var i = 0; i < monitorsModel.count; i++) {
                                var m = monitorsModel.get(i);
                                var w = (root.displayW(m) / m.sysScale) * root.uiScale;
                                var h = (root.displayH(m) / m.sysScale) * root.uiScale;
                                minX = Math.min(minX, m.uiX); minY = Math.min(minY, m.uiY);
                                maxX = Math.max(maxX, m.uiX + w); maxY = Math.max(maxY, m.uiY + h);
                            }
                            var requiredW = (maxX - minX) + 80;
                            var requiredH = (maxY - minY) + 80;
                            return Math.min(1.8, Math.min(400 / requiredW, 300 / requiredH));
                        }

                        property real offsetX: {
                            if (monitorsModel.count < 2) return 0;
                            var minX = 999999, maxX = -999999;
                            for (var i = 0; i < monitorsModel.count; i++) {
                                var m = monitorsModel.get(i);
                                var w = (root.displayW(m) / m.sysScale) * root.uiScale;
                                minX = Math.min(minX, m.uiX); maxX = Math.max(maxX, m.uiX + w);
                            }
                            return 220 - ((minX + (maxX - minX) / 2) * targetScale);
                        }

                        property real offsetY: {
                            if (monitorsModel.count < 2) return 0;
                            var minY = 999999, maxY = -999999;
                            for (var i = 0; i < monitorsModel.count; i++) {
                                var m = monitorsModel.get(i);
                                var h = (root.displayH(m) / m.sysScale) * root.uiScale;
                                minY = Math.min(minY, m.uiY); maxY = Math.max(maxY, m.uiY + h);
                            }
                            return 170 - ((minY + (maxY - minY) / 2) * targetScale);
                        }

                        Item {
                            id: transformNode
                            x: multiMonitorView.offsetX; y: multiMonitorView.offsetY
                            scale: multiMonitorView.targetScale; transformOrigin: Item.TopLeft
                            Behavior on x { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }
                            Behavior on y { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }
                            Behavior on scale { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }

                            Repeater {
                                id: monitorRepeater
                                model: monitorsModel

                                Item {
                                    property bool isActive: root.activeEditIndex === index

                                    Rectangle {
                                        id: monitorCard
                                        x: model.uiX; y: model.uiY
                                        width: (root.displayW(model) / model.sysScale) * root.uiScale
                                        height: (root.displayH(model) / model.sysScale) * root.uiScale
                                        radius: 8
                                        color: isActive ? root.surface1 : root.crust
                                        border.color: isActive ? root.selectedResAccent : root.surface2
                                        border.width: isActive ? 2 : 1
                                        z: isActive ? 5 : 0
                                        Behavior on x { enabled: !ghostMa.drag.active; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                                        Behavior on y { enabled: !ghostMa.drag.active; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                                        Behavior on border.color { ColorAnimation { duration: 300 } }
                                        Behavior on color { ColorAnimation { duration: 300 } }
                                        Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }
                                        Behavior on height { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }

                                        Item {
                                            anchors.centerIn: parent; width: 110; height: 80
                                            property real idealScale: Math.min(1.2, parent.width / 110, parent.height / 80) / transformNode.scale
                                            property real maxPhysicalScale: Math.min((parent.width * 0.9) / width, (parent.height * 0.9) / height)
                                            scale: Math.min(idealScale, maxPhysicalScale)
                                            layer.enabled: true
                                            layer.smooth: true
                                            layer.mipmap: true
                                            layer.textureSize: Qt.size(width * 2, height * 2)

                                            ColumnLayout {
                                                anchors.centerIn: parent; spacing: 2
                                                Text {
                                                    Layout.alignment: Qt.AlignHCenter
                                                    font.family: "CaskaydiaMono Nerd Font"; font.pixelSize: 32
                                                    color: isActive ? root.selectedResAccent : root.text; text: "󰍹"
                                                    Behavior on color { ColorAnimation { duration: 300 } }
                                                }
                                                Text {
                                                    Layout.alignment: Qt.AlignHCenter
                                                    font.family: "JetBrains Mono"; font.weight: Font.Black; font.pixelSize: 13
                                                    color: root.text; text: model.name
                                                }
                                                Text {
                                                    Layout.alignment: Qt.AlignHCenter
                                                    font.family: "JetBrains Mono"; font.pixelSize: 10; color: root.subtext0
                                                    text: model.resW + "x" + model.resH + " @ " + model.rate + "Hz"
                                                }
                                            }
                                        }
                                    }

                                    Item {
                                        id: ghostDrag
                                        x: model.uiX; y: model.uiY
                                        width: monitorCard.width; height: monitorCard.height
                                        z: isActive ? 10 : 1

                                        MouseArea {
                                            id: ghostMa
                                            anchors.fill: parent
                                            drag.target: ghostDrag
                                            drag.axis: Drag.XAndYAxis
                                            drag.threshold: 0
                                            drag.smoothed: false
                                            onPressed: {
                                                root.selectMonitor(index);
                                                root.forceActiveFocus();
                                                ghostDrag.x = model.uiX;
                                                ghostDrag.y = model.uiY;
                                            }
                                            onPositionChanged: {
                                                if (drag.active && monitorsModel.count >= 2) {
                                                    var mW = monitorCard.width;
                                                    var mH = monitorCard.height;
                                                    var resolved = root.resolveMonitorPosition(
                                                        index,
                                                        ghostDrag.x,
                                                        ghostDrag.y,
                                                        mW,
                                                        mH,
                                                        root.monitorDragSnapDistance
                                                    );
                                                    ghostDrag.x = resolved.x;
                                                    ghostDrag.y = resolved.y;
                                                    monitorsModel.setProperty(index, "uiX", resolved.x);
                                                    monitorsModel.setProperty(index, "uiY", resolved.y);
                                                }
                                            }
                                            onReleased: {
                                                ghostDrag.x = model.uiX;
                                                ghostDrag.y = model.uiY;
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Item {
                anchors.left: leftVisualArea.right
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 10
                anchors.rightMargin: 25
                height: 500

                opacity: root.introProgress
                transform: Translate { y: root.uiYOffset }

                SequentialAnimation {
                    id: menuTransitionAnim
                    ParallelAnimation {
                        ScaleAnimator { target: rightSideContainer; from: 0.99; to: 1.0; duration: 200; easing.type: Easing.OutSine }
                        NumberAnimation { target: highlightFlash; property: "opacity"; from: 0.05; to: 0.0; duration: 250; easing.type: Easing.OutQuad }
                    }
                }

                Rectangle {
                    id: highlightFlash
                    anchors.fill: rightSideContainer; anchors.margins: -10
                    color: root.selectedResAccent; opacity: 0.0; radius: 12
                }

                ColumnLayout {
                    id: rightSideContainer
                    anchors.fill: parent
                    spacing: 10

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2; columnSpacing: 8; rowSpacing: 8

                        Repeater {
                            model: [
                                { resW: 3840, resH: 2160, label: "4K",   accent: root.pink },
                                { resW: 2560, resH: 1440, label: "QHD",  accent: root.mauve },
                                { resW: 1920, resH: 1080, label: "FHD",  accent: root.blue },
                                { resW: 1600, resH: 900,  label: "HD+",  accent: root.teal },
                                { resW: 1366, resH: 768,  label: "WXGA", accent: root.yellow },
                                { resW: 1280, resH: 720,  label: "HD",   accent: root.peach },
                                { resW: 1024, resH: 768,  label: "XGA",  accent: root.green },
                                { resW: 800,  resH: 600,  label: "SVGA", accent: root.red }
                            ]

                            delegate: Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 44
                                radius: 12

                                property bool isSel: {
                                    if (monitorsModel.count === 0) return false;
                                    var activeMon = monitorsModel.get(root.activeEditIndex);
                                    return activeMon.resW === modelData.resW && activeMon.resH === modelData.resH;
                                }
                                property color accentColor: modelData.accent

                                color: isSel ? Qt.alpha(accentColor, 0.15) : (resMa.containsMouse ? root.surface0 : root.mantle)
                                border.color: isSel ? accentColor : (resMa.containsMouse ? root.surface1 : "transparent")
                                border.width: isSel ? 2 : 1
                                Behavior on color { ColorAnimation { duration: 200 } }
                                Behavior on border.color { ColorAnimation { duration: 200 } }

                                RowLayout {
                                    anchors.fill: parent; anchors.margins: 12; spacing: 8
                                    Text {
                                        font.family: "JetBrains Mono"
                                        font.weight: isSel ? Font.Black : Font.Bold
                                        font.pixelSize: 15; color: isSel ? accentColor : root.text; text: modelData.label
                                        Behavior on color { ColorAnimation { duration: 200 } }
                                    }
                                    Item { Layout.fillWidth: true }
                                    Text {
                                        font.family: "JetBrains Mono"; font.pixelSize: 11
                                        color: isSel ? root.text : root.overlay0
                                        text: modelData.resW + "x" + modelData.resH
                                        Behavior on color { ColorAnimation { duration: 200 } }
                                    }
                                }

                                scale: resMa.pressed ? 0.96 : 1.0
                                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutSine } }

                                MouseArea {
                                    id: resMa; anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (monitorsModel.count > 0) {
                                            root.selectedResAccent = accentColor;
                                            monitorsModel.setProperty(root.activeEditIndex, "resW", modelData.resW);
                                            monitorsModel.setProperty(root.activeEditIndex, "resH", modelData.resH);
                                            delayedLayoutUpdate.restart();
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Item { Layout.preferredHeight: 6 }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        Layout.leftMargin: 8; Layout.rightMargin: 8

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Custom"; font.family: "JetBrains Mono"; font.pixelSize: 12
                                font.weight: Font.Bold; color: root.subtext0
                            }

                            Rectangle {
                                width: 80; height: 30; radius: 8
                                color: customWInput.activeFocus ? Qt.alpha(root.accent, 0.15) : root.mantle
                                border.color: customWInput.activeFocus ? root.accent : root.surface1; border.width: 1
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on border.color { ColorAnimation { duration: 150 } }
                                TextInput {
                                    id: customWInput; anchors.fill: parent; anchors.margins: 6
                                    font.family: "JetBrains Mono"; font.pixelSize: 12; color: root.text
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                                    validator: IntValidator { bottom: 320; top: 7680 }
                                    text: monitorsModel.count > 0 ? monitorsModel.get(root.activeEditIndex).resW.toString() : "1920"
                                    selectByMouse: true; selectedTextColor: root.crust; selectionColor: root.accent
                                    onEditingFinished: {
                                        if (monitorsModel.count > 0 && acceptableInput) {
                                            monitorsModel.setProperty(root.activeEditIndex, "resW", parseInt(text));
                                            delayedLayoutUpdate.restart();
                                        }
                                    }
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "×"; font.family: "JetBrains Mono"; font.pixelSize: 14
                                font.weight: Font.Bold; color: root.overlay0
                            }

                            Rectangle {
                                width: 80; height: 30; radius: 8
                                color: customHInput.activeFocus ? Qt.alpha(root.accent, 0.15) : root.mantle
                                border.color: customHInput.activeFocus ? root.accent : root.surface1; border.width: 1
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on border.color { ColorAnimation { duration: 150 } }
                                TextInput {
                                    id: customHInput; anchors.fill: parent; anchors.margins: 6
                                    font.family: "JetBrains Mono"; font.pixelSize: 12; color: root.text
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                                    validator: IntValidator { bottom: 240; top: 4320 }
                                    text: monitorsModel.count > 0 ? monitorsModel.get(root.activeEditIndex).resH.toString() : "1080"
                                    selectByMouse: true; selectedTextColor: root.crust; selectionColor: root.accent
                                    onEditingFinished: {
                                        if (monitorsModel.count > 0 && acceptableInput) {
                                            monitorsModel.setProperty(root.activeEditIndex, "resH", parseInt(text));
                                            delayedLayoutUpdate.restart();
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                width: 30; height: 30; radius: 8
                                color: setResMa.containsMouse ? Qt.alpha(root.accent, 0.2) : root.mantle
                                border.color: setResMa.containsMouse ? root.accent : root.surface1; border.width: 1
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Text { anchors.centerIn: parent; text: "✓"; font.pixelSize: 13; font.weight: Font.Bold; color: root.accent }
                                MouseArea {
                                    id: setResMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        customWInput.focus = false; customHInput.focus = false;
                                        if (monitorsModel.count > 0) {
                                            var w = parseInt(customWInput.text) || 1920;
                                            var h = parseInt(customHInput.text) || 1080;
                                            monitorsModel.setProperty(root.activeEditIndex, "resW", w);
                                            monitorsModel.setProperty(root.activeEditIndex, "resH", h);
                                            delayedLayoutUpdate.restart();
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Item { Layout.preferredHeight: 4 }

                    Item {
                        id: sliderContainer
                        Layout.fillWidth: true
                        Layout.preferredHeight: 50
                        Layout.leftMargin: 8; Layout.rightMargin: 8

                        property var rates: [60, 75, 100, 120, 144, 165, 180, 240, 360]
                        property var rateColors: [root.red, root.mauve, root.blue, root.sapphire, root.teal, root.pink, root.yellow, root.green, root.peach]

                        property int currentIndex: {
                            if (monitorsModel.count === 0) return 0;
                            var currentVal = parseInt(monitorsModel.get(root.activeEditIndex).rate) || 60;
                            var closestIdx = 0, minDiff = 9999;
                            for (var i = 0; i < rates.length; i++) {
                                var diff = Math.abs(rates[i] - currentVal);
                                if (diff < minDiff) { minDiff = diff; closestIdx = i; }
                            }
                            return closestIdx;
                        }

                        property real visualPct: currentIndex / (rates.length - 1)
                        onCurrentIndexChanged: { if (!sliderMa.pressed) visualPct = currentIndex / (rates.length - 1); }

                        Rectangle {
                            id: track
                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; verticalCenterOffset: -10 }
                            height: 24; radius: 12
                            color: "#0dffffff"; border.color: "#1affffff"; border.width: 1
                            clip: true
                            Rectangle {
                                width: parent.width * sliderContainer.visualPct
                                height: parent.height; radius: parent.radius
                                opacity: sliderMa.containsMouse ? 1.0 : 0.85
                                Behavior on opacity { NumberAnimation { duration: 200 } }
                                Behavior on width { enabled: !sliderMa.pressed; NumberAnimation { duration: 300; easing.type: Easing.OutQuint } }

                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: root.selectedRateAccent; Behavior on color { ColorAnimation { duration: 300 } } }
                                    GradientStop { position: 1.0; color: Qt.lighter(root.selectedRateAccent, 1.25); Behavior on color { ColorAnimation { duration: 300 } } }
                                }
                            }
                        }

                        Repeater {
                            model: sliderContainer.rates.length
                            Item {
                                x: (index / (sliderContainer.rates.length - 1)) * track.width
                                y: track.y + track.height + 6
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: sliderContainer.rates[index]
                                    font.family: "JetBrains Mono"; font.pixelSize: 11
                                    font.weight: sliderContainer.currentIndex === index ? Font.Bold : Font.Normal
                                    color: sliderContainer.currentIndex === index ? root.selectedRateAccent : root.overlay0
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                }
                            }
                        }

                        MouseArea {
                            id: sliderMa; anchors.fill: parent; anchors.margins: -15
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            function updateSelection(mouseX, snapToGrid) {
                                if (monitorsModel.count === 0) return;
                                var pct = (mouseX - track.x) / track.width;
                                pct = Math.max(0, Math.min(1, pct));
                                var idx = Math.round(pct * (sliderContainer.rates.length - 1));
                                sliderContainer.visualPct = snapToGrid ? idx / (sliderContainer.rates.length - 1) : pct;
                                monitorsModel.setProperty(root.activeEditIndex, "rate", sliderContainer.rates[idx].toString());
                                root.selectedRateAccent = sliderContainer.rateColors[idx];
                            }
                            onPressed: (mouse) => updateSelection(mouse.x, false)
                            onPositionChanged: (mouse) => { if (pressed) updateSelection(mouse.x, false) }
                            onReleased: (mouse) => updateSelection(mouse.x, true)
                            onCanceled: () => sliderContainer.visualPct = sliderContainer.currentIndex / (sliderContainer.rates.length - 1)
                        }
                    }

                    Item { Layout.preferredHeight: 4 }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 34
                        Layout.leftMargin: 8; Layout.rightMargin: 8

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Rotation"; font.family: "JetBrains Mono"; font.pixelSize: 12
                                font.weight: Font.Bold; color: root.text
                            }

                            Repeater {
                                model: root.transformLabels.length
                                delegate: Rectangle {
                                    width: 44; height: 26; radius: 8
                                    property bool isSel: monitorsModel.count > 0 && monitorsModel.get(root.activeEditIndex).transform === root.transformValues[index]
                                    color: isSel ? Qt.alpha(root.accent, 0.2) : (rotBtnMa.containsMouse ? root.surface0 : root.mantle)
                                    border.color: isSel ? root.accent : "transparent"; border.width: isSel ? 1 : 0
                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: root.transformLabels[index]; font.family: "JetBrains Mono"; font.pixelSize: 11
                                        font.weight: isSel ? Font.Bold : Font.Normal
                                        color: isSel ? root.accent : root.subtext0
                                    }

                                    MouseArea {
                                        id: rotBtnMa; anchors.fill: parent; hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (monitorsModel.count > 0) {
                                                monitorsModel.setProperty(root.activeEditIndex, "transform", root.transformValues[index]);
                                                delayedLayoutUpdate.restart();
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 34
                        Layout.leftMargin: 8; Layout.rightMargin: 8
                        visible: monitorsModel.count > 1

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10

                            Rectangle {
                                id: mirrorCheckbox
                                width: 22; height: 22; radius: 6
                                color: {
                                    if (monitorsModel.count === 0) return root.mantle;
                                    var m = monitorsModel.get(root.activeEditIndex);
                                    return m.isMirror ? Qt.alpha(root.accent, 0.3) : (mirrorCbMa.containsMouse ? root.surface0 : root.mantle);
                                }
                                border.color: {
                                    if (monitorsModel.count === 0) return root.surface0;
                                    return monitorsModel.get(root.activeEditIndex).isMirror ? root.accent : root.surface1;
                                }
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 200 } }
                                Behavior on border.color { ColorAnimation { duration: 200 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "✓"; font.pixelSize: 14; font.weight: Font.Bold
                                    color: root.accent; visible: monitorsModel.count > 0 && monitorsModel.get(root.activeEditIndex).isMirror
                                }

                                MouseArea {
                                    id: mirrorCbMa; anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (monitorsModel.count === 0) return;
                                        var m = monitorsModel.get(root.activeEditIndex);
                                        var newVal = !m.isMirror;
                                        monitorsModel.setProperty(root.activeEditIndex, "isMirror", newVal);
                                        if (newVal && !m.mirrorTarget) {
                                            var others = root.otherMonitorNames();
                                            if (others.length > 0)
                                                monitorsModel.setProperty(root.activeEditIndex, "mirrorTarget", others[0]);
                                        }
                                    }
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Mirror"; font.family: "JetBrains Mono"; font.pixelSize: 12
                                font.weight: Font.Bold; color: root.text
                            }

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6
                                visible: monitorsModel.count > 0 && monitorsModel.get(root.activeEditIndex).isMirror

                                Repeater {
                                    model: {
                                        var arr = [];
                                        for (var i = 0; i < monitorsModel.count; i++) {
                                            if (i !== root.activeEditIndex) arr.push(monitorsModel.get(i).name);
                                        }
                                        return arr;
                                    }

                                    delegate: Rectangle {
                                        width: mirrorTargetText.implicitWidth + 16; height: 24; radius: 8
                                        property bool isSel: monitorsModel.count > 0 && monitorsModel.get(root.activeEditIndex).mirrorTarget === modelData
                                        color: isSel ? Qt.alpha(root.accent, 0.2) : (mirrorTargetMa.containsMouse ? root.surface0 : root.mantle)
                                        border.color: isSel ? root.accent : "transparent"; border.width: isSel ? 1 : 0
                                        Behavior on color { ColorAnimation { duration: 150 } }

                                        Text {
                                            id: mirrorTargetText; anchors.centerIn: parent
                                            text: modelData; font.family: "JetBrains Mono"; font.pixelSize: 10
                                            font.weight: isSel ? Font.Bold : Font.Normal
                                            color: isSel ? root.accent : root.subtext0
                                        }

                                        MouseArea {
                                            id: mirrorTargetMa; anchors.fill: parent; hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: monitorsModel.setProperty(root.activeEditIndex, "mirrorTarget", modelData)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }
                }
            }

            Row {
                anchors { bottom: parent.bottom; left: parent.left; margins: 20 }
                spacing: 10; z: 5
                opacity: root.introProgress
                transform: Translate { y: root.uiYOffset }

                Rectangle {
                    width: addVirtRow.implicitWidth + 20; height: 36; radius: 12
                    color: addVirtMa.containsMouse ? root.surface1 : root.mantle
                    border.color: addVirtMa.containsMouse ? root.accent : root.surface0; border.width: 1
                    Behavior on color { ColorAnimation { duration: 200 } }
                    Behavior on border.color { ColorAnimation { duration: 200 } }

                    Row {
                        id: addVirtRow; anchors.centerIn: parent; spacing: 6
                        Text { font.family: "CaskaydiaMono Nerd Font"; font.pixelSize: 16; color: root.accent; text: "󰐕"; anchors.verticalCenter: parent.verticalCenter }
                        Text { font.family: "JetBrains Mono"; font.pixelSize: 11; font.weight: Font.Bold; color: root.text; text: "Virtual Display"; anchors.verticalCenter: parent.verticalCenter }
                    }

                    scale: addVirtMa.pressed ? 0.95 : 1.0
                    Behavior on scale { NumberAnimation { duration: 150 } }
                    MouseArea { id: addVirtMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.createVirtualMonitor() }
                }

                Repeater {
                    model: {
                        var arr = [];
                        for (var i = 0; i < monitorsModel.count; i++) {
                            var n = monitorsModel.get(i).name;
                            if (root.isVirtual(n)) arr.push(n);
                        }
                        return arr;
                    }

                    delegate: Rectangle {
                        width: removeVirtRow.implicitWidth + 16; height: 36; radius: 12
                        color: removeVirtMa.containsMouse ? Qt.alpha(root.red, 0.15) : root.mantle
                        border.color: removeVirtMa.containsMouse ? root.red : root.surface0; border.width: 1
                        Behavior on color { ColorAnimation { duration: 200 } }
                        Behavior on border.color { ColorAnimation { duration: 200 } }

                        Row {
                            id: removeVirtRow; anchors.centerIn: parent; spacing: 4
                            Text { font.family: "CaskaydiaMono Nerd Font"; font.pixelSize: 14; color: root.red; text: "󰅖"; anchors.verticalCenter: parent.verticalCenter }
                            Text { font.family: "JetBrains Mono"; font.pixelSize: 10; font.weight: Font.Bold; color: root.subtext0; text: modelData; anchors.verticalCenter: parent.verticalCenter }
                        }

                        scale: removeVirtMa.pressed ? 0.95 : 1.0
                        Behavior on scale { NumberAnimation { duration: 150 } }
                        MouseArea { id: removeVirtMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.removeVirtualMonitor(modelData) }
                    }
                }
            }

            Item {
                id: applyButtonContainer
                anchors { bottom: parent.bottom; right: parent.right; margins: 22 }
                width: 160; height: 46; z: 5
                opacity: root.introProgress
                transform: Translate { y: root.uiYOffset }

                Rectangle {
                    id: applyBtn; anchors.fill: parent; radius: 23
                    readonly property bool isDanger: root.applyHovered || root.applyFillLevel > 0.0
                    border.width: 1
                    border.color: isDanger ? Qt.darker(root.red, 1.2) : Qt.lighter(root.accent, 1.1)

                    gradient: Gradient {
                        orientation: Gradient.Vertical
                        GradientStop { 
                            position: 0.0
                            color: applyBtn.isDanger ? Qt.lighter(root.red, 1.15) : Qt.lighter(root.accent, 1.15)
                            Behavior on color { ColorAnimation { duration: 300 } }
                        }
                        GradientStop { 
                            position: 1.0
                            color: applyBtn.isDanger ? root.red : root.accent
                            Behavior on color { ColorAnimation { duration: 300 } }
                        }
                    }

                    scale: root.applyPressed ? 0.94 : (root.applyHovered ? 1.04 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }

                    Rectangle {
                        anchors.fill: parent
                        radius: 23
                        color: "transparent"
                        clip: true

                        Canvas {
                            id: applyWaveCanvas
                            anchors.fill: parent
                            visible: root.applyFillLevel > 0.0
                            opacity: 0.92
                            property real wavePhase: 0.0

                            NumberAnimation on wavePhase {
                                running: root.applyFillLevel > 0.0 && root.applyFillLevel < 1.0
                                loops: Animation.Infinite; from: 0; to: Math.PI * 2; duration: 800
                            }

                            onWavePhaseChanged: requestPaint()
                            Connections {
                                target: root
                                function onApplyFillLevelChanged() { applyWaveCanvas.requestPaint() }
                            }

                            onPaint: {
                                const ctx = getContext("2d");
                                ctx.clearRect(0, 0, width, height);
                                if (root.applyFillLevel <= 0.001) return;

                                const currentW = width * root.applyFillLevel;
                                const waveAmpBase = 12 * Math.sin(root.applyFillLevel * Math.PI);
                                const waveAmp = Math.min(Math.max(0, currentW), waveAmpBase);
                                const r = 23;

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
                                if (root.applyFillLevel < 0.99) {
                                    const cp1x = currentW + Math.sin(wavePhase) * waveAmp;
                                    const cp2x = currentW + Math.cos(wavePhase + Math.PI) * waveAmp;
                                    ctx.lineTo(currentW, 0);
                                    ctx.bezierCurveTo(cp2x, height * 0.33, cp1x, height * 0.66, currentW, height);
                                    ctx.lineTo(0, height);
                                } else {
                                    ctx.lineTo(width, 0); ctx.lineTo(width, height); ctx.lineTo(0, height);
                                }
                                ctx.closePath();

                                const grad = ctx.createLinearGradient(0, 0, 0, height);
                                grad.addColorStop(0.0, root.surface1.toString());
                                grad.addColorStop(1.0, root.crust.toString());
                                ctx.fillStyle = grad;
                                ctx.fill();
                                ctx.restore();
                            }
                        }
                    }

                    Rectangle {
                        id: flashRect; anchors.fill: parent; radius: 23
                        color: "#ffffff"
                        opacity: root.applyFlashOpacity
                    }

                    RowLayout {
                        anchors.centerIn: parent; spacing: 8
                        z: 10
                        Text { 
                            font.family: "CaskaydiaMono Nerd Font"; font.pixelSize: 18
                            color: root.applyFillLevel > 0.05 ? root.text : root.crust
                            text: "󰸵" 
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                        Text {
                            font.family: "Fira Sans"; font.weight: Font.Black; font.pixelSize: 13
                            color: root.applyFillLevel > 0.05 ? root.text : root.crust
                            text: monitorsModel.count > 1 ? "Apply All" : "Apply"
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                    }
                }

                MouseArea {
                    id: applyMa; anchors.fill: parent; z: 10
                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onEntered: root.applyHovered = true
                    onExited: root.applyHovered = false
                    
                    onPressed: {
                        root.applyPressed = true;
                        if (!root.applyTriggered) {
                            applyDrainAnim.stop();
                            applyFillAnim.start();
                        }
                    }
                    onReleased: {
                        root.applyPressed = false;
                        if (!root.applyTriggered && root.applyFillLevel < 1.0) {
                            applyFillAnim.stop();
                            applyDrainAnim.start();
                        }
                    }
                    onCanceled: {
                        root.applyPressed = false;
                        if (!root.applyTriggered) {
                            applyFillAnim.stop();
                            applyDrainAnim.start();
                        }
                    }
                }
            }
        }
    }
}
