import QtQuick

MouseArea {
    id: root

    acceptedButtons: Qt.NoButton
    hoverEnabled: false
    propagateComposedEvents: true

    property var flickable
    property int orientation: Qt.Vertical
    property real wheelStep: 120
    property real touchpadMultiplier: 2.4
    property bool scrollEnabled: !!flickable
        && ((root.orientation === Qt.Horizontal)
            ? (flickable.contentWidth > flickable.width)
            : (flickable.contentHeight > flickable.height))
        && flickable.interactive !== false

    function clamp(value, minValue, maxValue) {
        return Math.max(minValue, Math.min(maxValue, value));
    }

    function minContentPosition() {
        if (!flickable)
            return 0;
        return Number(
            (root.orientation === Qt.Horizontal)
                ? (flickable.originX || 0)
                : (flickable.originY || 0)
        );
    }

    function maxContentPosition() {
        if (!flickable)
            return 0;
        const minPosition = root.minContentPosition();
        return Math.max(
            minPosition,
            minPosition
                + (
                    (root.orientation === Qt.Horizontal)
                        ? Number(flickable.contentWidth || 0) - Number(flickable.width || 0)
                        : Number(flickable.contentHeight || 0) - Number(flickable.height || 0)
                )
        );
    }

    onWheel: (wheel) => {
        if (!root.scrollEnabled || !root.flickable)
            return;

        const pixelDelta = Number(
            wheel.pixelDelta
                ? ((root.orientation === Qt.Horizontal && wheel.pixelDelta.x !== 0)
                    ? wheel.pixelDelta.x
                    : wheel.pixelDelta.y)
                : 0
        );
        const angleDelta = Number(
            wheel.angleDelta
                ? ((root.orientation === Qt.Horizontal && wheel.angleDelta.x !== 0)
                    ? wheel.angleDelta.x
                    : wheel.angleDelta.y)
                : 0
        );

        let scrollDelta = 0;
        if (pixelDelta !== 0)
            scrollDelta = pixelDelta * root.touchpadMultiplier;
        else if (angleDelta !== 0)
            scrollDelta = (angleDelta / 120) * root.wheelStep;

        if (scrollDelta === 0)
            return;

        if (root.flickable.cancelFlick)
            root.flickable.cancelFlick();

        if (root.orientation === Qt.Horizontal) {
            root.flickable.contentX = root.clamp(
                root.flickable.contentX - scrollDelta,
                root.minContentPosition(),
                root.maxContentPosition()
            );
        } else {
            root.flickable.contentY = root.clamp(
                root.flickable.contentY - scrollDelta,
                root.minContentPosition(),
                root.maxContentPosition()
            );
        }
        wheel.accepted = true;
    }
}
