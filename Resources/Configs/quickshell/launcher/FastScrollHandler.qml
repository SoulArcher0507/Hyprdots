import QtQuick

MouseArea {
    id: root

    acceptedButtons: Qt.NoButton
    hoverEnabled: false
    propagateComposedEvents: true

    property var flickable
    property real wheelStep: 120
    property real touchpadMultiplier: 2.4
    property bool scrollEnabled: !!flickable
        && flickable.contentHeight > flickable.height
        && flickable.interactive !== false

    function clamp(value, minValue, maxValue) {
        return Math.max(minValue, Math.min(maxValue, value));
    }

    function minContentY() {
        if (!flickable)
            return 0;
        return Number(flickable.originY || 0);
    }

    function maxContentY() {
        if (!flickable)
            return 0;
        const minY = root.minContentY();
        return Math.max(minY, minY + Number(flickable.contentHeight || 0) - Number(flickable.height || 0));
    }

    onWheel: (wheel) => {
        if (!root.scrollEnabled || !root.flickable)
            return;

        const pixelDeltaY = Number(wheel.pixelDelta ? wheel.pixelDelta.y : 0);
        const angleDeltaY = Number(wheel.angleDelta ? wheel.angleDelta.y : 0);

        let scrollDelta = 0;
        if (pixelDeltaY !== 0)
            scrollDelta = pixelDeltaY * root.touchpadMultiplier;
        else if (angleDeltaY !== 0)
            scrollDelta = (angleDeltaY / 120) * root.wheelStep;

        if (scrollDelta === 0)
            return;

        if (root.flickable.cancelFlick)
            root.flickable.cancelFlick();

        root.flickable.contentY = root.clamp(
            root.flickable.contentY - scrollDelta,
            root.minContentY(),
            root.maxContentY()
        );
        wheel.accepted = true;
    }
}
