pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Singleton {
    id: root
    property bool overviewOpen: false
    property int overviewTargetMonitorId: -1
    property string overviewTargetMonitorName: ""
    property bool superReleaseMightTrigger: true
}
