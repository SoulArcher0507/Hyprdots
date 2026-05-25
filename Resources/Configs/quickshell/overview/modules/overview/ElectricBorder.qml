import QtQuick

Item {
    id: root

    property color accentColor: "#ffffff"
    property real radius: 12
    property real borderWidth: 1
    property real pixelsPerSecond: 120
    property bool active: true
    property bool animationsEnabled: true
    property int visualZ: 1000
    readonly property bool effectEnabled: active && animationsEnabled && borderWidth > 0 && width > 8 && height > 8
    readonly property real inset: Math.max(1, (borderWidth * 0.5) + 0.5)
    readonly property real frameWidth: Math.max(1, width - (inset * 2))
    readonly property real frameHeight: Math.max(1, height - (inset * 2))
    readonly property real cornerRadius: Math.max(0, Math.min(radius - inset, frameWidth / 2, frameHeight / 2))
    readonly property real topLength: Math.max(0, frameWidth - (cornerRadius * 2))
    readonly property real sideLength: Math.max(0, frameHeight - (cornerRadius * 2))
    readonly property real arcLength: cornerRadius > 0 ? ((Math.PI * cornerRadius) / 2) : 0
    readonly property real perimeter: Math.max(4, (topLength * 2) + (sideLength * 2) + (arcLength * 4))
    readonly property real segmentThickness: Math.max(1.6, borderWidth * 1.55)
    readonly property real glowThickness: Math.max(8, segmentThickness * 3.25)
    readonly property bool compactMode: perimeter < 260
    readonly property int frameInterval: compactMode ? 28 : (perimeter > 900 ? 20 : 16)
    readonly property real outwardBias: Math.max(0.45, borderWidth * 0.65)
    readonly property real lightningJitter: Math.max(1.6, segmentThickness * 1.35)
    readonly property real lightningStep: Math.max(compactMode ? 18 : 14, Math.min(compactMode ? 30 : 26, perimeter / 42))
    readonly property real lightningBoltLength: Math.max(compactMode ? 28 : 46, Math.min(compactMode ? 72 : 138, perimeter * 0.2))
    readonly property int lightningBoltCount: 1
    readonly property int shapeFrame: Math.floor(timeElapsed / 280)
    property real travel: 0
    property real _lastPerimeter: perimeter
    property real timeElapsed: 0
    property real _lastTickMs: 0
    readonly property real effectiveSpeed: {
        if (root.perimeter <= 0)
            return root.pixelsPerSecond;

        var calmSpeed = Math.max(36, Math.min(132, root.pixelsPerSecond * 0.86));
        var targetDuration = (root.perimeter / calmSpeed) * 1000;
        var minimumDuration = root.perimeter < 180 ? 3600 : 5000;
        var actualDuration = Math.max(minimumDuration, targetDuration);
        return (root.perimeter / actualDuration) * 1000;
    }

    function clamp(value, low, high) {
        return Math.max(low, Math.min(high, value));
    }

    function fract(value) {
        return value - Math.floor(value);
    }

    function noise(seed) {
        return fract(Math.sin(seed * 12.9898) * 43758.5);
    }

    function pulse(salt, speed, sharpness) {
        var wave = (Math.sin(((timeElapsed / 1000) * speed) + salt) + 1) * 0.5;
        return Math.pow(wave, sharpness);
    }

    function withAlpha(colorValue, alphaValue) {
        return Qt.rgba(colorValue.r || 0, colorValue.g || 0, colorValue.b || 0, clamp(alphaValue, 0, 1));
    }

    function advanceFrame() {
        if (!effectEnabled || perimeter <= 0)
            return;

        var now = Date.now();
        if (_lastTickMs <= 0) {
            _lastTickMs = now;
            boltCanvas.requestPaint();
            return;
        }

        var dt = clamp((now - _lastTickMs) / 1000, 0, 0.16);
        _lastTickMs = now;
        timeElapsed += dt * 1000;
        travel = (travel + (effectiveSpeed * dt)) % Math.max(1, root.perimeter);
        boltCanvas.requestPaint();
    }

    function wrapDistance(distance) {
        if (perimeter <= 0)
            return 0;

        var wrapped = distance % perimeter;
        return wrapped < 0 ? wrapped + perimeter : wrapped;
    }

    function pointAt(distance) {
        var d = wrapDistance(distance);
        var r = cornerRadius;
        var w = frameWidth;
        var h = frameHeight;
        var x = 0;
        var y = 0;
        if (d <= topLength) {
            x = r + d;
            y = 0;
        } else {
            d -= topLength;
            if (d <= arcLength && r > 0) {
                var a1 = (-Math.PI / 2) + ((d / arcLength) * (Math.PI / 2));
                x = (w - r) + Math.cos(a1) * r;
                y = r + Math.sin(a1) * r;
            } else {
                d -= arcLength;
                if (d <= sideLength) {
                    x = w;
                    y = r + d;
                } else {
                    d -= sideLength;
                    if (d <= arcLength && r > 0) {
                        var a2 = (d / arcLength) * (Math.PI / 2);
                        x = (w - r) + Math.cos(a2) * r;
                        y = (h - r) + Math.sin(a2) * r;
                    } else {
                        d -= arcLength;
                        if (d <= topLength) {
                            x = (w - r) - d;
                            y = h;
                        } else {
                            d -= topLength;
                            if (d <= arcLength && r > 0) {
                                var a3 = (Math.PI / 2) + ((d / arcLength) * (Math.PI / 2));
                                x = r + Math.cos(a3) * r;
                                y = (h - r) + Math.sin(a3) * r;
                            } else {
                                d -= arcLength;
                                if (d <= sideLength) {
                                    x = 0;
                                    y = (h - r) - d;
                                } else if (arcLength > 0 && r > 0) {
                                    d -= sideLength;
                                    var a4 = Math.PI + ((d / arcLength) * (Math.PI / 2));
                                    x = r + Math.cos(a4) * r;
                                    y = r + Math.sin(a4) * r;
                                }
                            }
                        }
                    }
                }
            }
        }
        return {
            "x": inset + x,
            "y": inset + y
        };
    }

    function tangentAt(distance) {
        var p0 = pointAt(distance);
        var p1 = pointAt(distance + 2);
        var dx = p1.x - p0.x;
        var dy = p1.y - p0.y;
        var len = Math.hypot(dx, dy);
        if (len <= 0.0001)
            return {
                "x": 1,
                "y": 0
            };

        return {
            "x": dx / len,
            "y": dy / len
        };
    }

    function pointWithOffset(distance, inwardOffset) {
        var point = pointAt(distance);
        var tangent = tangentAt(distance);
        return {
            "x": point.x - (tangent.y * inwardOffset),
            "y": point.y + (tangent.x * inwardOffset)
        };
    }

    function tracePath(ctx, points) {
        if (points.length <= 0)
            return;

        ctx.beginPath();
        ctx.moveTo(points[0].x, points[0].y);
        for (var i = 1; i < points.length; ++i)
            ctx.lineTo(points[i].x, points[i].y);
    }

    function strokeTrace(ctx, points, widthValue, colorValue) {
        tracePath(ctx, points);
        ctx.lineWidth = widthValue;
        ctx.strokeStyle = colorValue;
        ctx.stroke();
    }

    function jaggedOffset(distance, stepIndex, progress, salt) {
        var taper = Math.sin(progress * Math.PI);
        var snap = (noise((shapeFrame * 3.17) + (salt * 21.31) + (stepIndex * 7.73)) - 0.5) * 2;
        var alternating = (stepIndex % 2 === 0 ? -1 : 1) * (0.36 + (noise((salt * 11.9) + stepIndex) * 0.36));
        var slowDrift = Math.sin((timeElapsed / 1000 * 0.95) + (distance * 0.046) + salt + stepIndex) * 0.26;
        var offset = -outwardBias + ((alternating + (snap * 0.28) + slowDrift) * lightningJitter * taper);
        return clamp(offset, -outwardBias - (lightningJitter * 0.8), Math.max(0.2, borderWidth * 0.28));
    }

    function buildBoltPoints(headDistance, lengthValue, salt) {
        var points = [];
        var steps = Math.max(compactMode ? 4 : 6, Math.ceil(lengthValue / lightningStep));
        for (var i = 0; i <= steps; ++i) {
            var progress = i / steps;
            var distance = headDistance - lengthValue + (lengthValue * progress);
            points.push(pointWithOffset(distance, jaggedOffset(distance, i, progress, salt)));
        }
        return points;
    }

    function drawFork(ctx, distance, salt, intensity) {
        if (compactMode)
            return;

        var branchPulse = pulse(salt + 1.9, 2.15, 5);
        if (branchPulse < 0.12)
            return;

        var tangent = tangentAt(distance);
        var normalX = tangent.y;
        var normalY = -tangent.x;
        var direction = noise((shapeFrame * 0.71) + salt) > 0.5 ? 1 : -1;
        var reach = Math.max(4.5, glowThickness * (0.34 + (noise(salt * 9.1) * 0.24))) * (0.65 + branchPulse * 0.36);
        var origin = pointWithOffset(distance, -outwardBias - (lightningJitter * 0.2));
        var mid = {
            "x": origin.x + (normalX * reach * 0.52) + (tangent.x * reach * 0.26 * direction),
            "y": origin.y + (normalY * reach * 0.52) + (tangent.y * reach * 0.26 * direction)
        };
        var tip = {
            "x": origin.x + (normalX * reach) - (tangent.x * reach * 0.18 * direction),
            "y": origin.y + (normalY * reach) - (tangent.y * reach * 0.18 * direction)
        };
        var branchPoints = [origin, mid, tip];
        var branchIntensity = intensity * branchPulse;
        strokeTrace(ctx, branchPoints, Math.max(1.4, segmentThickness * 1.25), withAlpha(accentColor, 0.12 * branchIntensity));
        strokeTrace(ctx, branchPoints, Math.max(0.75, borderWidth * 0.82), withAlpha(Qt.lighter(accentColor, 1.62), 0.72 * branchIntensity));
    }

    function drawSpark(ctx, point, salt, intensity) {
        if (compactMode)
            return;

        var sparkPulse = pulse(salt, 2.4, 4);
        if (sparkPulse < 0.1)
            return;

        var radiusValue = Math.max(1.1, segmentThickness * (0.42 + sparkPulse * 0.28));
        ctx.beginPath();
        ctx.arc(point.x, point.y, radiusValue * 2.5, 0, Math.PI * 2);
        ctx.fillStyle = withAlpha(accentColor, 0.055 * intensity * sparkPulse);
        ctx.fill();
        ctx.beginPath();
        ctx.arc(point.x, point.y, radiusValue, 0, Math.PI * 2);
        ctx.fillStyle = withAlpha(Qt.lighter(accentColor, 1.7), 0.72 * intensity * sparkPulse);
        ctx.fill();
    }

    function drawBolt(ctx, headDistance, lengthValue, salt, intensity) {
        var points = buildBoltPoints(headDistance, lengthValue, salt);
        if (!compactMode)
            strokeTrace(ctx, points, glowThickness * (0.62 + intensity * 0.2), withAlpha(accentColor, 0.045 + intensity * 0.055));
        strokeTrace(ctx, points, Math.max(1.4, segmentThickness * (compactMode ? 1.45 : 1.7)), withAlpha(accentColor, compactMode ? 0.3 : 0.18 + intensity * 0.2));
        strokeTrace(ctx, points, Math.max(0.8, borderWidth), withAlpha(Qt.lighter(accentColor, 1.72), compactMode ? 0.78 : 0.68 + intensity * 0.18));
        var head = points[points.length - 1];
        var tailForkDistance = headDistance - (lengthValue * 0.68);
        var midForkDistance = headDistance - (lengthValue * 0.34);
        drawFork(ctx, midForkDistance, salt + 1.2, intensity);
        drawFork(ctx, tailForkDistance, salt + 3.8, intensity * 0.72);
        drawSpark(ctx, head, salt + 5.4, intensity);
        if (points.length > 5)
            drawSpark(ctx, points[Math.floor(points.length * 0.58)], salt + 7.1, intensity * 0.74);

    }

    visible: effectEnabled
    z: visualZ
    clip: true
    onPerimeterChanged: {
        if (_lastPerimeter > 0 && perimeter > 0)
            travel = travel * (perimeter / _lastPerimeter);

        _lastPerimeter = perimeter;
    }
    onEffectEnabledChanged: {
        _lastTickMs = 0;
    }

    Canvas {
        id: boltCanvas

        anchors.fill: parent
        antialiasing: true
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onVisibleChanged: {
            if (visible) {
                requestPaint();
            }
        }
        onPaint: {
            var ctx = getContext("2d");
            if (ctx.reset)
                ctx.reset();

            ctx.clearRect(0, 0, width, height);
            if (!root.effectEnabled)
                return;

            ctx.lineCap = "round";
            ctx.lineJoin = "round";
            ctx.globalAlpha = 1;
            for (var i = 0; i < root.lightningBoltCount; ++i) {
                var salt = 1.6 + (i * 3.7);
                var arcBreath = Math.sin((root.timeElapsed / 1900) + salt) * root.lightningBoltLength * 0.09;
                var headDistance = root.travel + ((root.perimeter / root.lightningBoltCount) * i) + arcBreath;
                var intensity = 0.55 + (root.pulse(salt + 0.8, 1.85, 3.4) * 0.38);
                var lengthValue = root.lightningBoltLength * (0.86 + (root.pulse(salt + 2.2, 1.35, 3) * 0.24));
                root.drawBolt(ctx, headDistance, lengthValue, salt, intensity);
            }
        }

    }

    Timer {
        interval: root.frameInterval
        repeat: true
        running: root.effectEnabled && root.perimeter > 0
        onTriggered: root.advanceFrame()
    }

}
