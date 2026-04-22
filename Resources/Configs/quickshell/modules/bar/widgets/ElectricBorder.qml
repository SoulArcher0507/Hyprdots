import QtQuick
import "../../theme" as ThemePkg

Item {
    id: root

    property color accentColor: "#ffffff"
    property real radius: 12
    property real borderWidth: 1
    property real pixelsPerSecond: 120
    property bool active: true
    property int visualZ: 1000

    readonly property bool effectEnabled: active && ThemePkg.Theme.edgeAnimationsEnabled && borderWidth > 0 && width > 8 && height > 8
    readonly property real inset: Math.max(1.0, (borderWidth * 0.5) + 0.5)
    readonly property real frameWidth: Math.max(1, width - (inset * 2))
    readonly property real frameHeight: Math.max(1, height - (inset * 2))
    readonly property real cornerRadius: Math.max(0, Math.min(radius - inset, frameWidth / 2, frameHeight / 2))
    readonly property real topLength: Math.max(0, frameWidth - (cornerRadius * 2))
    readonly property real sideLength: Math.max(0, frameHeight - (cornerRadius * 2))
    readonly property real arcLength: cornerRadius > 0 ? ((Math.PI * cornerRadius) / 2) : 0
    readonly property real perimeter: Math.max(4, (topLength * 2) + (sideLength * 2) + (arcLength * 4))
    readonly property real segmentLength: Math.max(10, Math.min(22, perimeter * 0.032))
    readonly property real segmentThickness: Math.max(2.0, borderWidth * 1.7)
    readonly property real glowThickness: Math.max(6.0, segmentThickness * 2.2)

    property real travel: 0

    visible: effectEnabled
    z: visualZ
    clip: true

    property real _lastPerimeter: perimeter
    onPerimeterChanged: {
        if (_lastPerimeter > 0 && perimeter > 0) {
            travel = travel * (perimeter / _lastPerimeter);
        }
        _lastPerimeter = perimeter;
    }

    property real timeElapsed: 0
    property real _lastTimeElapsed: 0

    readonly property real effectiveSpeed: {
        if (root.perimeter <= 0) return root.pixelsPerSecond;
        var targetDuration = (root.perimeter / Math.max(70, root.pixelsPerSecond)) * 1000;
        var actualDuration = Math.max(2000, targetDuration);
        return (root.perimeter / actualDuration) * 1000;
    }

    NumberAnimation on timeElapsed {
        from: 0
        to: 100000000
        duration: 100000000
        loops: Animation.Infinite
        running: root.effectEnabled && root.perimeter > 0
    }

    onTimeElapsedChanged: {
        var dt = (timeElapsed - _lastTimeElapsed) / 1000.0;
        if (dt < 0) {
            dt = 0;
        }
        travel = (travel + (effectiveSpeed * dt)) % Math.max(1, root.perimeter);
        _lastTimeElapsed = timeElapsed;
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
            x: inset + x,
            y: inset + y
        };
    }

    function tangentAt(distance) {
        var p0 = pointAt(distance);
        var p1 = pointAt(distance + 2);
        var dx = p1.x - p0.x;
        var dy = p1.y - p0.y;
        var len = Math.hypot(dx, dy);

        if (len <= 0.0001) {
            return {
                x: 1,
                y: 0
            };
        }

        return {
            x: dx / len,
            y: dy / len
        };
    }

    function stateAt(distance) {
        var point = pointAt(distance);
        var tangent = tangentAt(distance);
        return {
            x: point.x,
            y: point.y,
            rotation: Math.atan2(tangent.y, tangent.x) * 180 / Math.PI
        };
    }

    Repeater {
        model: root.effectEnabled ? 6 : 0

        delegate: Item {
            required property int index

            readonly property real tailT: index / Math.max(1, (root.effectEnabled ? 5 : 1))
            readonly property real offset: index * root.segmentLength * 0.44
            readonly property real alphaScale: 1.0 - (tailT * 0.82)
            readonly property real shrinkScale: 1.0 - (tailT * 0.42)
            readonly property var sparkState: root.stateAt(root.travel - offset)

            width: root.segmentLength * (0.62 + (0.38 * shrinkScale))
            height: root.glowThickness * shrinkScale
            x: Math.round(sparkState.x - (width / 2))
            y: Math.round(sparkState.y - (height / 2))
            rotation: sparkState.rotation
            transformOrigin: Item.Center
            opacity: alphaScale

            Rectangle {
                anchors.centerIn: parent
                width: parent.width
                height: parent.height
                radius: height / 2
                color: ThemePkg.Theme.withAlpha(root.accentColor, 0.10 * parent.opacity)
            }

            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 0.82
                height: root.segmentThickness * shrinkScale
                radius: height / 2
                color: ThemePkg.Theme.withAlpha(root.accentColor, index === 0 ? 0.86 : (0.28 * alphaScale))
            }

            Rectangle {
                visible: index === 0
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(4, root.segmentThickness * 1.8)
                height: width
                radius: width / 2
                color: root.accentColor
            }

            Rectangle {
                visible: index === 0
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: Math.max(2, root.segmentThickness)
                width: parent.width * 0.34
                height: Math.max(1.0, root.borderWidth)
                radius: height / 2
                rotation: 32
                color: ThemePkg.Theme.withAlpha(root.accentColor, 0.65)
            }

            Rectangle {
                visible: index === 0
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: Math.max(2, root.segmentThickness * 1.1)
                width: parent.width * 0.24
                height: Math.max(1.0, root.borderWidth)
                radius: height / 2
                rotation: -27
                color: ThemePkg.Theme.withAlpha(root.accentColor, 0.48)
            }
        }
    }
}
