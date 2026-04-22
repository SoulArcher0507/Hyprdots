import QtQuick

Item {
    id: root

    signal regionSelected(var selection)

    property real dimOpacity: 0.6
    property real borderRadius: 10.0
    property real outlineThickness: 2.0
    property color outlineColor: "white"
    property string selectionShape: "rectangle"

    property point startPos: Qt.point(0, 0)
    property real selectionX: 0
    property real selectionY: 0
    property real selectionWidth: 0
    property real selectionHeight: 0
    property var freehandPoints: []

    onSelectionXChanged: overlay.requestPaint()
    onSelectionYChanged: overlay.requestPaint()
    onSelectionWidthChanged: overlay.requestPaint()
    onSelectionHeightChanged: overlay.requestPaint()
    onFreehandPointsChanged: overlay.requestPaint()
    onSelectionShapeChanged: {
        root.resetSelection()
        overlay.requestPaint()
    }

    function resetSelection() {
        root.selectionX = 0
        root.selectionY = 0
        root.selectionWidth = 0
        root.selectionHeight = 0
        root.freehandPoints = []
    }

    function roundedRectPath(ctx, x, y, width, height, radius) {
        const r = Math.max(0, Math.min(radius, width / 2, height / 2))
        ctx.beginPath()
        ctx.moveTo(x + r, y)
        ctx.lineTo(x + width - r, y)
        ctx.quadraticCurveTo(x + width, y, x + width, y + r)
        ctx.lineTo(x + width, y + height - r)
        ctx.quadraticCurveTo(x + width, y + height, x + width - r, y + height)
        ctx.lineTo(x + r, y + height)
        ctx.quadraticCurveTo(x, y + height, x, y + height - r)
        ctx.lineTo(x, y + r)
        ctx.quadraticCurveTo(x, y, x + r, y)
        ctx.closePath()
    }

    function ellipsePath(ctx, x, y, width, height) {
        const rx = width / 2
        const ry = height / 2
        const cx = x + rx
        const cy = y + ry
        ctx.save()
        ctx.beginPath()
        ctx.translate(cx, cy)
        ctx.scale(Math.max(rx, 0.001), Math.max(ry, 0.001))
        ctx.arc(0, 0, 1, 0, Math.PI * 2, false)
        ctx.restore()
        ctx.closePath()
    }

    function freehandPath(ctx) {
        if (!root.freehandPoints || root.freehandPoints.length < 2)
            return false

        ctx.beginPath()
        ctx.moveTo(root.freehandPoints[0].x, root.freehandPoints[0].y)
        for (let i = 1; i < root.freehandPoints.length; ++i)
            ctx.lineTo(root.freehandPoints[i].x, root.freehandPoints[i].y)
        ctx.closePath()
        return true
    }

    function traceSelectionPath(ctx) {
        if (root.selectionShape === "freehand")
            return root.freehandPath(ctx)

        if (root.selectionWidth <= 0 || root.selectionHeight <= 0)
            return false

        if (root.selectionShape === "circle")
            root.ellipsePath(ctx, root.selectionX, root.selectionY, root.selectionWidth, root.selectionHeight)
        else
            root.roundedRectPath(ctx, root.selectionX, root.selectionY, root.selectionWidth, root.selectionHeight, root.borderRadius)

        return true
    }

    function normalizedDrag(mouseX, mouseY) {
        const dx = mouseX - root.startPos.x
        const dy = mouseY - root.startPos.y

        if (root.selectionShape === "circle") {
            const side = Math.min(Math.abs(dx), Math.abs(dy))
            return {
                x: root.startPos.x + (dx < 0 ? -side : 0),
                y: root.startPos.y + (dy < 0 ? -side : 0),
                width: side,
                height: side
            }
        }

        return {
            x: Math.min(root.startPos.x, mouseX),
            y: Math.min(root.startPos.y, mouseY),
            width: Math.abs(dx),
            height: Math.abs(dy)
        }
    }

    function updateSelectionFromDrag(mouseX, mouseY) {
        const nextRect = root.normalizedDrag(mouseX, mouseY)
        root.selectionX = nextRect.x
        root.selectionY = nextRect.y
        root.selectionWidth = nextRect.width
        root.selectionHeight = nextRect.height
    }

    function updateFreehandBounds() {
        if (!root.freehandPoints || root.freehandPoints.length === 0) {
            root.selectionX = 0
            root.selectionY = 0
            root.selectionWidth = 0
            root.selectionHeight = 0
            return
        }

        let minX = root.freehandPoints[0].x
        let minY = root.freehandPoints[0].y
        let maxX = root.freehandPoints[0].x
        let maxY = root.freehandPoints[0].y

        for (let i = 1; i < root.freehandPoints.length; ++i) {
            const point = root.freehandPoints[i]
            minX = Math.min(minX, point.x)
            minY = Math.min(minY, point.y)
            maxX = Math.max(maxX, point.x)
            maxY = Math.max(maxY, point.y)
        }

        root.selectionX = minX
        root.selectionY = minY
        root.selectionWidth = Math.max(1, maxX - minX)
        root.selectionHeight = Math.max(1, maxY - minY)
    }

    function pushFreehandPoint(mouseX, mouseY) {
        const points = root.freehandPoints ? root.freehandPoints.slice(0) : []
        const lastPoint = points.length > 0 ? points[points.length - 1] : null

        if (lastPoint && Math.hypot(lastPoint.x - mouseX, lastPoint.y - mouseY) < 3)
            return

        points.push({
            x: mouseX,
            y: mouseY
        })
        root.freehandPoints = points
        root.updateFreehandBounds()
    }

    function buildSelection() {
        if (root.selectionShape === "freehand") {
            if (!root.freehandPoints || root.freehandPoints.length < 3 || root.selectionWidth <= 1 || root.selectionHeight <= 1)
                return null

            return {
                x: Math.round(root.selectionX),
                y: Math.round(root.selectionY),
                width: Math.round(root.selectionWidth),
                height: Math.round(root.selectionHeight),
                shape: "freehand",
                points: root.freehandPoints.map(point => ({
                    x: Math.round(point.x - root.selectionX),
                    y: Math.round(point.y - root.selectionY)
                }))
            }
        }

        if (root.selectionWidth <= 0 || root.selectionHeight <= 0)
            return null

        return {
            x: Math.round(root.selectionX),
            y: Math.round(root.selectionY),
            width: Math.round(root.selectionWidth),
            height: Math.round(root.selectionHeight),
            shape: root.selectionShape
        }
    }

    Canvas {
        id: overlay
        anchors.fill: parent
        z: 0
        antialiasing: true

        onPaint: {
            const ctx = getContext("2d")
            if (ctx.reset)
                ctx.reset()
            ctx.clearRect(0, 0, width, height)

            ctx.fillStyle = Qt.rgba(0, 0, 0, root.dimOpacity)
            ctx.fillRect(0, 0, width, height)

            if (!root.traceSelectionPath(ctx))
                return

            ctx.save()
            ctx.globalCompositeOperation = "destination-out"
            ctx.fill()
            ctx.restore()

            if (!root.traceSelectionPath(ctx))
                return

            ctx.save()
            ctx.globalCompositeOperation = "source-over"
            ctx.lineWidth = root.outlineThickness
            ctx.strokeStyle = root.outlineColor
            ctx.lineJoin = "round"
            ctx.lineCap = "round"
            ctx.stroke()
            ctx.restore()
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        z: 3

        onPressed: (mouse) => {
            root.startPos = Qt.point(mouse.x, mouse.y)
            root.resetSelection()

            if (root.selectionShape === "freehand")
                root.pushFreehandPoint(mouse.x, mouse.y)
            else
                root.updateSelectionFromDrag(mouse.x, mouse.y)
        }

        onPositionChanged: (mouse) => {
            if (!pressed)
                return

            if (root.selectionShape === "freehand")
                root.pushFreehandPoint(mouse.x, mouse.y)
            else
                root.updateSelectionFromDrag(mouse.x, mouse.y)
        }

        onReleased: (mouse) => {
            if (root.selectionShape === "freehand")
                root.pushFreehandPoint(mouse.x, mouse.y)
            else
                root.updateSelectionFromDrag(mouse.x, mouse.y)

            const selection = root.buildSelection()
            if (selection)
                root.regionSelected(selection)
        }
    }
}
