pragma ComponentBehavior: Bound

import QtQuick  
import Quickshell.Io
import Quickshell.Hyprland

Item {  
    id: root

    property var monitor: Hyprland.focusedMonitor
    property var workspace: monitor?.activeWorkspace
    property var windows: []
    readonly property int activeWorkspaceId: Number(workspace?.id ?? 0)
    readonly property real animationSpring: 12.0
    readonly property real animationDamping: 0.86

    signal regionSelected(real x, real y, real width, real height)  
      
    property real dimOpacity: 0.6  
    property real borderRadius: 10.0  
    property real outlineThickness: 2.0  
    property color outlineColor: "white"
    property url fragmentShader: Qt.resolvedUrl("dimming.frag.qsb")  
      
    property point startPos  
    property real selectionX: 0  
    property real selectionY: 0  
    property real selectionWidth: 0  
    property real selectionHeight: 0  

    function resetSelection() {
        root.selectionX = 0
        root.selectionY = 0
        root.selectionWidth = 0
        root.selectionHeight = 0
    }

    function monitorData() {
        return root.monitor?.lastIpcObject ?? root.monitor ?? {}
    }

    function monitorX() {
        return Number(root.monitorData().x ?? 0)
    }

    function monitorY() {
        return Number(root.monitorData().y ?? 0)
    }

    function monitorId() {
        return Number(root.monitorData().id ?? -1)
    }

    function monitorName() {
        return String(root.monitorData().name ?? root.monitor?.name ?? "")
    }

    function windowIsOnActiveTarget(win) {
        if (!win)
            return false

        const workspaceId = Number(win.workspace?.id ?? 0)
        if (root.activeWorkspaceId > 0 && workspaceId !== root.activeWorkspaceId)
            return false

        const winMonitor = win.monitor
        if (typeof winMonitor === "number")
            return root.monitorId() < 0 || winMonitor === root.monitorId()

        if (typeof winMonitor === "string")
            return root.monitorName() === "" || winMonitor === root.monitorName()

        return true
    }

    function windowRect(win) {
        if (!root.windowIsOnActiveTarget(win))
            return null

        const at = win.at ?? []
        const size = win.size ?? []
        const width = Number(size[0] ?? 0)
        const height = Number(size[1] ?? 0)
        if (width <= 0 || height <= 0)
            return null

        return {
            x: Number(at[0] ?? 0) - root.monitorX(),
            y: Number(at[1] ?? 0) - root.monitorY(),
            width: width,
            height: height
        }
    }

    function refreshWindows() {
        if (!root.visible || clientsProcess.running)
            return

        clientsProcess.running = true
    }

    function updateHoveredWindow(mouseX, mouseY) {
        let bestRect = null
        let bestArea = Number.POSITIVE_INFINITY

        for (const win of root.windows) {
            const rect = root.windowRect(win)
            if (!rect)
                continue

            if (mouseX < rect.x || mouseX > rect.x + rect.width ||
                mouseY < rect.y || mouseY > rect.y + rect.height)
                continue

            const area = rect.width * rect.height
            if (area < bestArea) {
                bestRect = rect
                bestArea = area
            }
        }

        if (!bestRect) {
            root.resetSelection()
            return
        }

        root.selectionX = bestRect.x
        root.selectionY = bestRect.y
        root.selectionWidth = bestRect.width
        root.selectionHeight = bestRect.height
    }

    onVisibleChanged: {
        if (visible)
            root.refreshWindows()
        else
            root.resetSelection()
    }

    onMonitorChanged: root.refreshWindows()
    onActiveWorkspaceIdChanged: root.refreshWindows()

    Connections {
        target: Hyprland
        enabled: root.visible

        function onRawEvent(event) {
            const eventName = `${event?.name ?? event?.event ?? event?.type ?? ""}`
            if (["openwindow", "closewindow", "movewindow", "movewindowv2", "resizewindow", "activewindow", "activewindowv2", "workspace", "workspacev2", "focusedmon", "focusedmonv2"].includes(eventName))
                root.refreshWindows()
        }
    }

    Process {
        id: clientsProcess
        command: ["hyprctl", "clients", "-j"]

        stdout: StdioCollector {
            id: clientsStdout

            onStreamFinished: {
                try {
                    root.windows = JSON.parse(clientsStdout.text || "[]")
                    if (mouseArea.containsMouse)
                        root.updateHoveredWindow(mouseArea.mouseX, mouseArea.mouseY)
                } catch (e) {
                    console.warn("HyprQuickshot: failed to parse hyprctl clients:", e)
                    root.windows = []
                }
            }
        }
    }

    Behavior on selectionX { SpringAnimation { spring: root.animationSpring; damping: root.animationDamping } }  
    Behavior on selectionY { SpringAnimation { spring: root.animationSpring; damping: root.animationDamping } }  
    Behavior on selectionHeight { SpringAnimation { spring: root.animationSpring; damping: root.animationDamping } }  
    Behavior on selectionWidth { SpringAnimation { spring: root.animationSpring; damping: root.animationDamping } }  
      
    ShaderEffect {  
        anchors.fill: parent  
        z: 0  
          
        property vector4d selectionRect: Qt.vector4d(  
            root.selectionX,  
            root.selectionY,  
            root.selectionWidth,  
            root.selectionHeight  
        )  
        property real dimOpacity: root.dimOpacity  
        property vector2d screenSize: Qt.vector2d(root.width, root.height)  
        property real borderRadius: root.borderRadius  
        property real outlineThickness: root.outlineThickness  
        property color outlineColor: root.outlineColor
          
        fragmentShader: root.fragmentShader  
    }  

    MouseArea {  
        id: mouseArea  
        anchors.fill: parent  
        z: 3
        hoverEnabled: true

        onPositionChanged: (mouse) => { 
            root.updateHoveredWindow(mouse.x, mouse.y)
        }  

        onPressed: (mouse) => {
            root.updateHoveredWindow(mouse.x, mouse.y)
        }

        onReleased: (mouse) => {  
            if (mouse.x >= root.selectionX && mouse.x <= root.selectionX + root.selectionWidth &&
                mouse.y >= root.selectionY && mouse.y <= root.selectionY + root.selectionHeight) {
                root.regionSelected(  
                    Math.round(root.selectionX),  
                    Math.round(root.selectionY),  
                    Math.round(root.selectionWidth),  
                    Math.round(root.selectionHeight)  
                )  
            }
        }  
    }  
}
