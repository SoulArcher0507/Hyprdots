import QtQuick  
import Quickshell  
import Quickshell.Wayland  
  
PanelWindow {  
    id: root  
      
    property var targetScreen: Quickshell.screens[0]
    property alias contentItem: root.contentItem  
    readonly property var frozenView: screenCopyLoader.item

    screen: targetScreen

    anchors { 
        left: true  
        right: true  
        top: true  
        bottom: true  
    }  
  
    exclusionMode: ExclusionMode.Ignore  
    WlrLayershell.layer: WlrLayer.Overlay  
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand  
  
    Loader {
        id: screenCopyLoader
        anchors.fill: parent
        z: -1
        active: root.visible

        sourceComponent: ScreencopyView {
            captureSource: root.targetScreen
            anchors.fill: parent
        }
    }
}
