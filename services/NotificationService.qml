pragma Singleton
import ".."
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Singleton {
    id: root

    property var notifications: []
    property int unreadCount: 0
    property var latestNotification: null
    property bool isAlerting: false
    readonly property int maxHistory: 30

    signal notificationReceived(var notification)

    // Timer to automatically finish the island alert expansion
    Timer {
        id: alertTimer
        interval: 4500
        repeat: false
        onTriggered: {
            root.isAlerting = false;
        }
    }

    // Native Quickshell Notification Server: claims org.freedesktop.Notifications with 0ms delay
    NotificationServer {
        id: server
        keepOnReload: true
        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true

        onNotification: (notif) => {
            root.handleNotification(notif);
        }
    }

    Component.onCompleted: {
        console.info("[NotificationService] Initialized native NotificationServer");
    }

    function handleNotification(notif) {
        if (!notif) return;
        let summary = notif.summary || "";
        let body = notif.body || "";
        if (!summary && !body) return;

        notif.tracked = true;

        let now = new Date();
        let hours = String(now.getHours()).padStart(2, '0');
        let minutes = String(now.getMinutes()).padStart(2, '0');
        let timeStr = hours + ":" + minutes;
        let uid = notif.id ? String(notif.id) : ("notif_" + Date.now() + "_" + Math.floor(Math.random() * 900 + 100));

        let data = {
            "id": uid,
            "appName": notif.appName || "System",
            "appIcon": notif.appIcon || "",
            "summary": summary,
            "body": body,
            "time": timeStr,
            "timestamp": Date.now(),
            "_raw": notif
        };

        // When closed by sender or expiry
        notif.closed.connect(function() {
            root.dismissNotification(uid, false);
        });

        root.latestNotification = data;
        root.unreadCount += 1;

        let list = (root.notifications || []).slice();
        list.unshift(data);
        if (list.length > root.maxHistory) {
            list = list.slice(0, root.maxHistory);
        }
        root.notifications = list;

        // Trigger island alert banner animation
        console.debug("[NotificationService] Received notification:", data.appName, "-", data.summary);
        root.isAlerting = true;
        alertTimer.restart();

        root.notificationReceived(data);
    }

    function dismissNotification(id, callDismiss) {
        if (callDismiss === undefined) callDismiss = true;
        let list = (root.notifications || []).slice();
        let idx = list.findIndex(n => n.id === id);
        if (idx !== -1) {
            let item = list[idx];
            if (callDismiss && item && item._raw && typeof item._raw.dismiss === "function") {
                try { item._raw.dismiss(); } catch(e) {}
            }
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
        let list = (root.notifications || []).slice();
        for (let i = 0; i < list.length; i++) {
            let item = list[i];
            if (item && item._raw && typeof item._raw.dismiss === "function") {
                try { item._raw.dismiss(); } catch(e) {}
            }
        }
        root.notifications = [];
        root.unreadCount = 0;
        root.latestNotification = null;
        root.isAlerting = false;
        alertTimer.stop();
    }

    function markAllRead() {
        root.unreadCount = 0;
    }

    function getUnreadCountForApp(appId, appName) {
        if (!root.notifications || root.notifications.length === 0) return 0;
        let count = 0;
        let idLower = (appId || "").toLowerCase().replace(/\.desktop$/, "");
        let nameLower = (appName || "").toLowerCase();
        for (let i = 0; i < root.notifications.length; i++) {
            let n = root.notifications[i];
            let nApp = (n.appName || "").toLowerCase();
            let nIcon = (n.appIcon || "").toLowerCase();
            if (idLower && (nApp.indexOf(idLower) >= 0 || idLower.indexOf(nApp) >= 0 || nIcon.indexOf(idLower) >= 0)) {
                count++;
            } else if (nameLower && (nApp.indexOf(nameLower) >= 0 || nameLower.indexOf(nApp) >= 0)) {
                count++;
            }
        }
        return count;
    }
}
