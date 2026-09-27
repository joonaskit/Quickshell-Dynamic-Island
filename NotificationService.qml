pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var notifications: []
    property int unreadCount: 0
    property var latestNotification: null
    property bool isAlerting: false
    readonly property int maxHistory: 30

    signal notificationReceived(var notification)

    // Timer to automatically finish the dynamic island alert expansion
    Timer {
        id: alertTimer
        interval: 4500
        repeat: false
        onTriggered: {
            root.isAlerting = false;
        }
    }

    // Process restart timer in case the python daemon exits
    Timer {
        id: restartTimer
        interval: 2000
        repeat: false
        onTriggered: {
            if (!trackerProc.running) {
                trackerProc.running = true;
            }
        }
    }

    // Process to run the DBus notification monitoring daemon
    Process {
        id: trackerProc
        command: ["python3", "-u", Quickshell.shellDir + "/notification_tracker.py"]
        running: true

        onRunningChanged: {
            if (!running) {
                restartTimer.start();
            }
        }

        stdout: SplitParser {
            onRead: function(line) {
                let t = line.trim();
                if (t.length > 0) {
                    root.handleNotificationJson(t);
                }
            }
        }
    }

    Component.onCompleted: {
        console.warn("[NotificationService] Initialized and monitoring notifications");
    }

    function handleNotificationJson(rawJson) {
        try {
            let data = JSON.parse(rawJson);
            if (!data || !data.summary && !data.body) return;

            root.latestNotification = data;
            root.unreadCount += 1;

            let list = (root.notifications || []).slice();
            list.unshift(data);
            if (list.length > root.maxHistory) {
                list = list.slice(0, root.maxHistory);
            }
            root.notifications = list;

            // Trigger island alert banner animation
            console.warn("[NotificationService] Received notification:", data.appName, "-", data.summary);
            root.isAlerting = true;
            alertTimer.restart();

            root.notificationReceived(data);
        } catch (e) {
            console.warn("Error parsing notification JSON: " + e);
        }
    }

    function dismissNotification(id) {
        let list = (root.notifications || []).slice();
        let idx = list.findIndex(n => n.id === id);
        if (idx !== -1) {
            list.splice(idx, 1);
            root.notifications = list;
            if (root.unreadCount > 0) {
                root.unreadCount = Math.max(0, root.unreadCount - 1);
            }
            if (root.latestNotification && root.latestNotification.id === id) {
                root.latestNotification = list.length > 0 ? list[0] : null;
            }
        }
    }

    function clearAll() {
        root.notifications = [];
        root.unreadCount = 0;
        root.latestNotification = null;
        root.isAlerting = false;
        alertTimer.stop();
    }

    function markAllRead() {
        root.unreadCount = 0;
    }
}
