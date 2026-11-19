pragma Singleton
import ".."
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import "desktopConflicts.js" as Conflicts

Singleton {
    id: root

    property var notifications: []
    property int unreadCount: 0
    property var latestNotification: null
    property bool isAlerting: false
    readonly property int maxHistory: 30

    // Notifications grouped by app, ordered by each group's newest notification
    readonly property var groups: {
        let order = [];
        let map = {};
        let list = root.notifications || [];
        for (let i = 0; i < list.length; i++) {
            let n = list[i];
            let key = n.appName || "System";
            if (!map[key]) {
                map[key] = { "appName": key, "appIcon": n.appIcon || "", "items": [] };
                order.push(key);
            }
            map[key].items.push(n);
        }
        return order.map(k => map[k]);
    }

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

    // ---- Other programs in the shell's place (desktopConflicts.js) ----

    // { notificationOwner, ownsNotifications, waybar }, null until checked.
    // notificationOwner is the process name of another daemon that owns the name.
    property var conflicts: null

    function checkConflicts() {
        conflictProc.running = true;
    }

    // The shell runs sh, so $PPID is the shell's own process
    Process {
        id: conflictProc
        command: ["sh", "-c",
            "pid=$(busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus "
            + "GetConnectionUnixProcessID s org.freedesktop.Notifications 2>/dev/null | cut -d' ' -f2); "
            + "if [ -z \"$pid\" ]; then echo owner=; "
            + "elif [ \"$pid\" = \"$PPID\" ]; then echo owner=self; "
            + "else echo \"owner=$(cat /proc/$pid/comm 2>/dev/null)\"; fi; "
            + "pgrep -x waybar >/dev/null && echo waybar=1; true"]
        stdout: StdioCollector {
            onStreamFinished: {
                let c = Conflicts.parse(text);
                root.conflicts = c;
                let lines = Conflicts.summary(c);
                for (let i = 0; i < lines.length; i++) console.warn("[NotificationService] " + lines[i]);
            }
        }
    }

    // After the session's autostart has had time to start mako or waybar
    Timer {
        running: true
        interval: 5000
        onTriggered: root.checkConflicts()
    }

    // ---- niri's config errors ----

    readonly property string niriConfigId: "niri-config-error"

    function showNiriConfigError() {
        root.dismissNotification(root.niriConfigId, false);
        if (!NiriService.configFailed) return;
        let actions = [];
        if (!DepsService.noneUsable(["niri-settings"])) {
            actions.push({
                "identifier": "open",
                "text": "Open niri Settings",
                "invoke": function() { WindowService.openNiriSettings("files"); }
            });
        }
        root.postLocal(root.niriConfigId, "niri", "io.github.joonaskit.NiriSettings",
            "niri could not load its config",
            "niri keeps the last config that worked. Run niri validate to see the error.", actions);
    }

    Connections {
        target: NiriService.active ? NiriService : null
        function onConfigFailedChanged() { root.showNiriConfigError(); }
        function onConfigReloadsChanged() { if (NiriService.configFailed) root.showNiriConfigError(); }
    }

    // A notification from the shell itself. actions: [{ identifier, text, invoke }]
    function postLocal(id, appName, appIcon, summary, body, actions) {
        let raw = { "actions": actions || [], "dismiss": function() {} };
        root.pushNotification({
            "id": id,
            "appName": appName,
            "appIcon": appIcon || "",
            "summary": summary,
            "body": body || "",
            "time": Qt.formatTime(new Date(), "hh:mm"),
            "timestamp": Date.now(),
            "_raw": raw
        });
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

        root.pushNotification(data);
    }

    // Adds a notification to the history and starts the island alert
    function pushNotification(data) {
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
        // Do Not Disturb keeps the notification in history but suppresses the banner
        if (SettingsService.dndEnabled) return;

        root.isAlerting = true;
        alertTimer.restart();

        root.notificationReceived(data);
    }

    // Keeps the alert from timing out while the notification is open in the island
    function holdAlert() {
        alertTimer.stop();
    }

    // Ends a held alert, unless a newer notification has restarted the timer
    function releaseAlert() {
        if (!alertTimer.running) root.isAlerting = false;
    }

    function toggleDnd() {
        SettingsService.setSetting("dndEnabled", !SettingsService.dndEnabled);
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

    function dismissGroup(appName) {
        let key = appName || "System";
        let ids = (root.notifications || []).filter(n => (n.appName || "System") === key).map(n => n.id);
        for (let i = 0; i < ids.length; i++) {
            root.dismissNotification(ids[i]);
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
