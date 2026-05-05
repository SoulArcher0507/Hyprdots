import QtQuick  
import Quickshell  
import Quickshell.Wayland  
  
PanelWindow {  
    id: root  
      
    property var targetScreen: Quickshell.screens[0]
    property alias contentItem: root.contentItem  
    readonly property var frozenView: screenCopyLoader.item
    property string frozenImagePath: ""

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
        active: root.visible && root.frozenImagePath === ""

        sourceComponent: ScreencopyView {
            captureSource: root.targetScreen
            anchors.fill: parent
        }
    }

    Image {
        anchors.fill: parent
        z: -1
        visible: root.visible && root.frozenImagePath !== ""
        source: visible ? "file://" + root.frozenImagePath : ""
        fillMode: Image.Stretch
        cache: false
        asynchronous: false
    }
}
