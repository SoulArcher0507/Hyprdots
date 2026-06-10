pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property var devices: []
    property bool daemonAvailable: false
    property bool refreshing: false
    property bool deviceLoadInProgress: false
    property bool refreshQueued: false
    property int refreshGeneration: 0
    property int pendingDeviceCount: 0
    property var pendingDevices: []
    property var mainDevice: null
    property string mainDeviceId: ""
    property string busctlCmd: ""
    property string kdeconnectCliCmd: ""
    property bool anyDevicesConnected: false
    property string lastError: ""

    onDevicesChanged: updateMainDevice(false)

    Component.onCompleted: checkDaemon()

    function checkDaemon() {
        if (detectBusctlProc.running || detectKdeconnectCliProc.running || daemonCheckProc.running)
            return;

        if (root.busctlCmd === "")
            detectBusctlProc.running = true;
        else if (root.kdeconnectCliCmd === "")
            detectKdeconnectCliProc.running = true;
        else
            daemonCheckProc.running = true;
    }

    function refreshDevices() {
        if (!root.daemonAvailable) {
            checkDaemon();
            return;
        }

        if (getDevicesProc.running || root.deviceLoadInProgress) {
            root.refreshQueued = true;
            root.refreshing = true;
            return;
        }

        root.refreshQueued = false;
        root.refreshing = true;
        root.deviceLoadInProgress = false;
        root.pendingDevices = [];
        root.pendingDeviceCount = 0;
        root.refreshGeneration += 1;
        getDevicesProc.running = true;
    }

    function setMainDevice(deviceId) {
        root.mainDeviceId = String(deviceId || "");
        updateMainDevice(false);
    }

    function updateMainDevice(checkReachable) {
        var newMain = null;
        var list = Array.isArray(root.devices) ? root.devices : [];

        if (checkReachable) {
            newMain = list.find(device => device.id === root.mainDeviceId && device.reachable);
            if (newMain === undefined)
                newMain = list.find(device => device.reachable);
            if (newMain === undefined)
                newMain = list.length === 0 ? null : list[0];
        } else {
            newMain = list.find(device => device.id === root.mainDeviceId);
            if (newMain === undefined)
                newMain = list.length === 0 ? null : list[0];
        }

        root.mainDevice = newMain;
        root.anyDevicesConnected = list.find(device => device.reachable) !== undefined;
    }

    function triggerFindMyPhone(deviceId) {
        const proc = findMyPhoneComponent.createObject(root, { deviceId: String(deviceId || "") });
        proc.running = true;
    }

    function browseFiles(deviceId) {
        const proc = browseFilesComponent.createObject(root, { deviceId: String(deviceId || "") });
        proc.running = true;
    }

    function shareFile(deviceId, filePath) {
        const proc = shareComponent.createObject(root, {
            deviceId: String(deviceId || ""),
            filePath: String(filePath || "")
        });
        proc.running = true;
    }

    function requestPairing(deviceId) {
        const proc = requestPairingComponent.createObject(root, { deviceId: String(deviceId || "") });
        proc.running = true;
    }

    function unpairDevice(deviceId) {
        const proc = unpairingComponent.createObject(root, { deviceId: String(deviceId || "") });
        proc.running = true;
    }

    function busctlCall(obj, itf, method, params) {
        if (root.busctlCmd === "")
            return ["false"];

        let result = [root.busctlCmd, "--user", "call", "--json=short", "org.kde.kdeconnect", obj, itf, method];
        return result.concat(params || []);
    }

    function busctlGet(obj, itf, prop) {
        if (root.busctlCmd === "")
            return ["false"];

        return [root.busctlCmd, "--user", "get-property", "--json=short", "org.kde.kdeconnect", obj, itf, prop];
    }

    function cliCall(args) {
        if (root.kdeconnectCliCmd === "")
            return ["false"];

        return [root.kdeconnectCliCmd].concat(args || []);
    }

    function busctlData(text) {
        let raw = String(text || "").trim();
        if (raw === "")
            return null;

        try {
            let data = JSON.parse(raw)?.data;
            if (!Array.isArray(data))
                return data;

            if (data.length === 0)
                return [];

            if (data.length === 1)
                return Array.isArray(data[0]) ? data[0] : data[0];

            let allNestedArrays = true;
            for (let i = 0; i < data.length; i++) {
                if (!Array.isArray(data[i])) {
                    allNestedArrays = false;
                    break;
                }
            }

            if (allNestedArrays) {
                let flattened = [];
                for (let i = 0; i < data.length; i++) {
                    for (let j = 0; j < data[i].length; j++)
                        flattened.push(data[i][j]);
                }
                return flattened;
            }

            return data;
        } catch (e) {
            root.lastError = "Failed to parse busctl response";
            console.warn("KDEConnect: failed to parse busctl response:", raw);
            return null;
        }
    }

    function uniqueDeviceIds(ids) {
        let result = [];
        let seen = ({});
        for (let i = 0; i < ids.length; i++) {
            let id = String(ids[i] || "");
            if (id === "" || seen[id])
                continue;

            seen[id] = true;
            result.push(id);
        }
        return result;
    }

    function cliDeviceIds(text) {
        let result = [];
        let lines = String(text || "").split(/\r?\n/);
        for (let i = 0; i < lines.length; i++) {
            let match = String(lines[i] || "").match(/[0-9a-fA-F]{16,}/);
            if (match)
                result.push(match[0]);
        }
        return result;
    }

    function normalizedDevices(devices) {
        let byId = ({});
        for (let i = 0; i < devices.length; i++) {
            let device = devices[i];
            let id = String(device && device.id ? device.id : "");
            if (id === "")
                continue;

            let existing = byId[id];
            if (!existing) {
                byId[id] = device;
                continue;
            }

            if ((!existing.reachable && device.reachable) || (!existing.paired && device.paired))
                byId[id] = device;
        }

        let result = Object.keys(byId).map(id => byId[id]);
        result.sort((a, b) => String(a.name || "").localeCompare(String(b.name || "")));
        return result;
    }

    function finishDeviceRefresh(newDevices) {
        let previous = root.devices.find(device => device.id === root.mainDeviceId);
        let next = newDevices.find(device => device.id === root.mainDeviceId);
        let deviceNotReachableAnymore =
            previous === undefined ||
            ((previous?.reachable ?? false) && !(next?.reachable ?? false)) ||
            ((previous?.paired ?? false) && !(next?.paired ?? false));

        root.devices = newDevices;
        root.pendingDevices = [];
        root.pendingDeviceCount = 0;
        root.deviceLoadInProgress = false;
        root.refreshing = false;
        root.updateMainDevice(deviceNotReachableAnymore);

        if (root.refreshQueued) {
            root.refreshQueued = false;
            Qt.callLater(root.refreshDevices);
        }
    }

    property Process detectBusctlProc: Process {
        command: ["which", "busctl"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                let location = String(text || "").trim();
                if (location === "") {
                    root.busctlCmd = "";
                    root.daemonAvailable = false;
                    root.devices = [];
                    root.mainDevice = null;
                    root.refreshing = false;
                    root.lastError = "busctl was not found";
                    return;
                }

                root.busctlCmd = location;
                root.lastError = "";
                root.detectKdeconnectCliProc.running = true;
            }
        }
    }

    property Process detectKdeconnectCliProc: Process {
        command: ["which", "kdeconnect-cli"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                let location = String(text || "").trim();
                if (location === "") {
                    root.kdeconnectCliCmd = "";
                    root.daemonAvailable = false;
                    root.devices = [];
                    root.mainDevice = null;
                    root.refreshing = false;
                    root.lastError = "kdeconnect-cli was not found";
                    return;
                }

                root.kdeconnectCliCmd = location;
                root.lastError = "";
                root.daemonCheckProc.running = true;
            }
        }
    }

    property Process daemonCheckProc: Process {
        command: root.busctlCmd === "" ? ["false"] : [root.busctlCmd, "--user", "status", "org.kde.kdeconnect"]
        onExited: (exitCode, exitStatus) => {
            root.daemonAvailable = exitCode === 0;
            if (root.daemonAvailable) {
                root.lastError = "";
                if (!forceOnNetworkChange.running)
                    forceOnNetworkChange.running = true;
            } else {
                root.devices = [];
                root.mainDevice = null;
                root.refreshing = false;
                root.lastError = "kdeconnectd is not available";
            }
        }
    }

    property Process forceOnNetworkChange: Process {
        id: forceProc

        property bool refreshStarted: false

        command: root.cliCall(["--refresh"])

        function startDeviceList() {
            if (forceProc.refreshStarted)
                return;

            forceProc.refreshStarted = true;
            root.refreshDevices();
        }

        onRunningChanged: if (running)
            refreshStarted = false

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: forceProc.startDeviceList()
        }
        onExited: forceProc.startDeviceList()
    }

    property Process getDevicesProc: Process {
        command: root.cliCall(["--list-available", "--id-only"])
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                const ids = root.uniqueDeviceIds(root.cliDeviceIds(text));

                root.pendingDevices = [];
                root.pendingDeviceCount = ids.length;

                if (ids.length === 0) {
                    root.finishDeviceRefresh([]);
                    return;
                }

                root.deviceLoadInProgress = true;
                const generation = root.refreshGeneration;
                ids.forEach(deviceId => {
                    const loader = deviceLoaderComponent.createObject(root, {
                        deviceId: String(deviceId || ""),
                        generation: generation
                    });
                    loader.start();
                });
            }
        }
        onExited: if (exitCode !== 0) {
            root.deviceLoadInProgress = false;
            root.refreshing = false
        }
    }

    property Component deviceLoaderComponent: Component {
        QtObject {
            id: loader

            property string deviceId: ""
            property int generation: 0
            property var deviceData: ({
                id: deviceId,
                name: "",
                reachable: false,
                paired: false,
                pairRequested: false,
                verificationKey: "",
                charging: false,
                battery: -1,
                cellularNetworkType: "",
                cellularNetworkStrength: -1,
                notificationIds: []
            })

            function start() {
                if (loader.deviceId === "") {
                    finalize();
                    return;
                }

                nameProc.running = true;
            }

            property Process nameProc: Process {
                command: root.busctlGet("/modules/kdeconnect/devices/" + loader.deviceId, "org.kde.kdeconnect.device", "name")
                stdout: StdioCollector {
                    waitForEnd: true
                    onStreamFinished: {
                        loader.deviceData.name = root.busctlData(text) || loader.deviceId;
                        reachableProc.running = true;
                    }
                }
                onExited: if (exitCode !== 0)
                    reachableProc.running = true
            }

            property Process reachableProc: Process {
                command: root.busctlGet("/modules/kdeconnect/devices/" + loader.deviceId, "org.kde.kdeconnect.device", "isReachable")
                stdout: StdioCollector {
                    waitForEnd: true
                    onStreamFinished: {
                        loader.deviceData.reachable = !!root.busctlData(text);
                        pairingRequestedProc.running = true;
                    }
                }
                onExited: if (exitCode !== 0)
                    pairingRequestedProc.running = true
            }

            property Process pairingRequestedProc: Process {
                command: root.busctlGet("/modules/kdeconnect/devices/" + loader.deviceId, "org.kde.kdeconnect.device", "isPairRequested")
                stdout: StdioCollector {
                    waitForEnd: true
                    onStreamFinished: {
                        loader.deviceData.pairRequested = !!root.busctlData(text);
                        verificationKeyProc.running = true;
                    }
                }
                onExited: if (exitCode !== 0)
                    verificationKeyProc.running = true
            }

            property Process verificationKeyProc: Process {
                command: root.busctlGet("/modules/kdeconnect/devices/" + loader.deviceId, "org.kde.kdeconnect.device", "verificationKey")
                stdout: StdioCollector {
                    waitForEnd: true
                    onStreamFinished: {
                        loader.deviceData.verificationKey = root.busctlData(text) || "";
                        pairedProc.running = true;
                    }
                }
                onExited: if (exitCode !== 0)
                    pairedProc.running = true
            }

            property Process pairedProc: Process {
                command: root.busctlGet("/modules/kdeconnect/devices/" + loader.deviceId, "org.kde.kdeconnect.device", "isPaired")
                stdout: StdioCollector {
                    waitForEnd: true
                    onStreamFinished: {
                        loader.deviceData.paired = !!root.busctlData(text);
                        if (loader.deviceData.paired)
                            activeNotificationsProc.running = true;
                        else
                            finalize();
                    }
                }
                onExited: if (exitCode !== 0)
                    finalize()
            }

            property Process activeNotificationsProc: Process {
                command: root.busctlCall("/modules/kdeconnect/devices/" + loader.deviceId + "/notifications", "org.kde.kdeconnect.device.notifications", "activeNotifications")
                stdout: StdioCollector {
                    waitForEnd: true
                    onStreamFinished: {
                        let ids = root.busctlData(text);
                        loader.deviceData.notificationIds = Array.isArray(ids) ? ids : [];
                        cellularNetworkTypeProc.running = true;
                    }
                }
                onExited: if (exitCode !== 0)
                    cellularNetworkTypeProc.running = true
            }

            property Process cellularNetworkTypeProc: Process {
                command: root.busctlGet("/modules/kdeconnect/devices/" + loader.deviceId + "/connectivity_report", "org.kde.kdeconnect.device.connectivity_report", "cellularNetworkType")
                stdout: StdioCollector {
                    waitForEnd: true
                    onStreamFinished: {
                        loader.deviceData.cellularNetworkType = root.busctlData(text) || "";
                        cellularNetworkStrengthProc.running = true;
                    }
                }
                onExited: if (exitCode !== 0)
                    cellularNetworkStrengthProc.running = true
            }

            property Process cellularNetworkStrengthProc: Process {
                command: root.busctlGet("/modules/kdeconnect/devices/" + loader.deviceId + "/connectivity_report", "org.kde.kdeconnect.device.connectivity_report", "cellularNetworkStrength")
                stdout: StdioCollector {
                    waitForEnd: true
                    onStreamFinished: {
                        const strength = root.busctlData(text);
                        loader.deviceData.cellularNetworkStrength = Number.isFinite(Number(strength)) ? Number(strength) : -1;
                        isChargingProc.running = true;
                    }
                }
                onExited: if (exitCode !== 0)
                    isChargingProc.running = true
            }

            property Process isChargingProc: Process {
                command: root.busctlGet("/modules/kdeconnect/devices/" + loader.deviceId + "/battery", "org.kde.kdeconnect.device.battery", "isCharging")
                stdout: StdioCollector {
                    waitForEnd: true
                    onStreamFinished: {
                        loader.deviceData.charging = !!root.busctlData(text);
                        batteryProc.running = true;
                    }
                }
                onExited: if (exitCode !== 0)
                    batteryProc.running = true
            }

            property Process batteryProc: Process {
                command: root.busctlGet("/modules/kdeconnect/devices/" + loader.deviceId + "/battery", "org.kde.kdeconnect.device.battery", "charge")
                stdout: StdioCollector {
                    waitForEnd: true
                    onStreamFinished: {
                        const charge = root.busctlData(text);
                        loader.deviceData.battery = Number.isFinite(Number(charge)) ? Number(charge) : -1;
                        finalize();
                    }
                }
                onExited: if (exitCode !== 0)
                    finalize()
            }

            function finalize() {
                if (loader.generation !== root.refreshGeneration) {
                    loader.destroy();
                    return;
                }

                root.pendingDevices = root.pendingDevices.concat([loader.deviceData]);

                if (root.pendingDevices.length >= root.pendingDeviceCount) {
                    root.finishDeviceRefresh(root.normalizedDevices(root.pendingDevices));
                }

                loader.destroy();
            }
        }
    }

    property Component findMyPhoneComponent: Component {
        Process {
            id: proc
            property string deviceId: ""
            command: root.busctlCall("/modules/kdeconnect/devices/" + deviceId + "/findmyphone", "org.kde.kdeconnect.device.findmyphone", "ring")
            stdout: StdioCollector { waitForEnd: true }
            onExited: proc.destroy()
        }
    }

    property Component browseFilesComponent: Component {
        Process {
            id: mountProc
            property string deviceId: ""
            command: root.busctlCall("/modules/kdeconnect/devices/" + deviceId + "/sftp", "org.kde.kdeconnect.device.sftp", "mountAndWait")
            stdout: StdioCollector {
                waitForEnd: true
                onStreamFinished: rootDirProc.running = true
            }
            onExited: if (exitCode !== 0)
                mountProc.destroy()

            property Process rootDirProc: Process {
                command: root.busctlCall("/modules/kdeconnect/devices/" + mountProc.deviceId + "/sftp", "org.kde.kdeconnect.device.sftp", "getDirectories")
                stdout: StdioCollector {
                    waitForEnd: true
                    onStreamFinished: {
                        const dirs = root.busctlData(text);
                        let path = "";
                        if (Array.isArray(dirs) && dirs.length > 0 && dirs[0]) {
                            const keys = Object.keys(dirs[0]);
                            path = keys.length > 0 ? keys[0] : "";
                        }

                        if (path !== "")
                            Quickshell.execDetached(["dolphin", "--new-window", path]);

                        mountProc.destroy();
                    }
                }
                onExited: if (exitCode !== 0)
                    mountProc.destroy()
            }
        }
    }

    property Component requestPairingComponent: Component {
        Process {
            id: proc
            property string deviceId: ""
            command: root.busctlCall("/modules/kdeconnect/devices/" + deviceId, "org.kde.kdeconnect.device", "requestPairing")
            stdout: StdioCollector { waitForEnd: true }
            onExited: {
                refreshAfterAction.restart();
                proc.destroy();
            }
        }
    }

    property Component unpairingComponent: Component {
        Process {
            id: proc
            property string deviceId: ""
            command: root.busctlCall("/modules/kdeconnect/devices/" + deviceId, "org.kde.kdeconnect.device", "unpair")
            stdout: StdioCollector { waitForEnd: true }
            onExited: {
                root.refreshDevices();
                proc.destroy();
            }
        }
    }

    property Component shareComponent: Component {
        Process {
            id: proc
            property string deviceId: ""
            property string filePath: ""
            command: root.busctlCall("/modules/kdeconnect/devices/" + deviceId + "/share", "org.kde.kdeconnect.device.share", "shareUrl", ["s", "file://" + filePath])
            stdout: StdioCollector { waitForEnd: true }
            onExited: {
                proc.destroy();
            }
        }
    }

    property Timer refreshAfterAction: Timer {
        id: refreshAfterAction
        interval: 1200
        repeat: false
        onTriggered: root.refreshDevices()
    }

    property Timer refreshTimer: Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: root.checkDaemon()
    }
}
