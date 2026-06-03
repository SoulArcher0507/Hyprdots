pragma Singleton
import QtQuick

QtObject {
    id: root

    property int unreadNews: 0
    property int unreadDotfiles: 0
    property int updatePacman: 0
    property int updateAur: 0
    property int updateFlatpak: 0
    property int updateTotal: 0
    property string updatesLastTs: ""
    property real updatesLastMs: 0
}
