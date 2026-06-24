import QtQuick

Item {
    id: root

    property color accentColor: "#ffffff"
    property real radius: 12
    property real borderWidth: 1
    property real pixelsPerSecond: 72
    property bool active: true
    property bool animationsEnabled: true
    property int visualZ: 1000
    property real travel: 0
    property real lastTickMs: 0

    readonly property bool effectEnabled: active && animationsEnabled && borderWidth > 0 && width > 8 && height > 8
    readonly property real glowWidth: Math.max(4, borderWidth * 3)
    readonly property real coreWidth: Math.max(1, borderWidth * 1.35)
    readonly property real inset: (glowWidth / 2) + 1
    readonly property real frameWidth: Math.max(1, width - (inset * 2))
    readonly property real frameHeight: Math.max(1, height - (inset * 2))
    readonly property real cornerRadius: Math.max(0, Math.min(radius - inset, frameWidth / 2, frameHeight / 2))
    readonly property real perimeter: Math.max(1, (frameWidth * 2) + (frameHeight * 2) - ((8 - (Math.PI * 2)) * cornerRadius))
    readonly property real segmentLength: Math.max(24, Math.min(110, perimeter * 0.18))
    readonly property real effectivePixelsPerSecond: pixelsPerSecond * Math.max(0.38, Math.min(1, perimeter / 240))

    visible: effectEnabled
    z: visualZ

    function withAlpha(colorValue, alphaValue) {
        return Qt.rgba(colorValue.r, colorValue.g, colorValue.b, alphaValue);
    }

    function traceBorder(ctx) {
        const x = inset;
        const y = inset;
        const w = frameWidth;
        const h = frameHeight;
        const r = cornerRadius;

        ctx.beginPath();
        ctx.moveTo(x + r, y);
        ctx.lineTo(x + w - r, y);
        ctx.arcTo(x + w, y, x + w, y + r, r);
        ctx.lineTo(x + w, y + h - r);
        ctx.arcTo(x + w, y + h, x + w - r, y + h, r);
        ctx.lineTo(x + r, y + h);
        ctx.arcTo(x, y + h, x, y + h - r, r);
        ctx.lineTo(x, y + r);
        ctx.arcTo(x, y, x + r, y, r);
        ctx.closePath();
    }

    function drawSegment(ctx, lineWidth, alphaValue, offset) {
        traceBorder(ctx);
        ctx.setLineDash([segmentLength, Math.max(1, perimeter - segmentLength)]);
        ctx.lineDashOffset = -offset;
        ctx.lineWidth = lineWidth;
        ctx.strokeStyle = withAlpha(accentColor, alphaValue);
        ctx.stroke();
    }

    function advanceFrame() {
        const now = Date.now();
        if (lastTickMs > 0)
            travel = (travel + (effectivePixelsPerSecond * Math.min(0.2, (now - lastTickMs) / 1000))) % perimeter;

        lastTickMs = now;
        neonCanvas.requestPaint();
    }

    function resetFrameClock() {
        lastTickMs = 0;
        if (!effectEnabled)
            travel = 0;
        neonCanvas.requestPaint();
    }

    onEffectEnabledChanged: resetFrameClock()
    onPerimeterChanged: resetFrameClock()
    onAccentColorChanged: neonCanvas.requestPaint()
    onRadiusChanged: neonCanvas.requestPaint()
    onBorderWidthChanged: neonCanvas.requestPaint()

    Canvas {
        id: neonCanvas

        anchors.fill: parent
        antialiasing: true
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            if (ctx.reset)
                ctx.reset();

            ctx.clearRect(0, 0, width, height);
            if (!root.effectEnabled)
                return;

            ctx.lineCap = "round";
            ctx.lineJoin = "round";
            root.drawSegment(ctx, root.glowWidth, 0.24, root.travel * 1.6);
            root.drawSegment(ctx, root.coreWidth, 0.95, root.travel);
            ctx.setLineDash([]);
        }
    }

    Timer {
        interval: 40
        repeat: true
        running: root.effectEnabled
        onTriggered: root.advanceFrame()
    }
}
