pragma Singleton
import QtQuick
import QtCore
import Quickshell

QtObject {
    id: root

    readonly property string quickshellStateFile: Quickshell.env("HOME") + "/.cache/quickshell/state.ini"
    property bool dnd: false
    property bool soundEnabled: true
    property int notificationCount: 0
    property bool _hydrating: true

    readonly property Settings stateSettings: Settings {
        location: "file://" + root.quickshellStateFile
        category: "quickshell.notifications"
        property bool dnd: false
        property bool soundEnabled: true
    }

    Component.onCompleted: {
        root.dnd = stateSettings.dnd;
        root.soundEnabled = stateSettings.soundEnabled;
        root._hydrating = false;
    }

    onDndChanged: {
        if (!root._hydrating && stateSettings.dnd !== root.dnd)
            stateSettings.dnd = root.dnd;
    }

    onSoundEnabledChanged: {
        if (!root._hydrating && stateSettings.soundEnabled !== root.soundEnabled)
            stateSettings.soundEnabled = root.soundEnabled;
    }
}
