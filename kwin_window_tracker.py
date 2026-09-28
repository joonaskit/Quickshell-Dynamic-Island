#!/usr/bin/env python3
import sys
import os
import time
import signal
import atexit
import dbus
import dbus.service
import dbus.mainloop.glib
import json
from gi.repository import GLib

BUS_NAME = "org.quickshell.IslandBridge"
OBJECT_PATH = "/Bridge"
SCRIPT_NAME = "quickshell_island_tracker"

class WindowBridge(dbus.service.Object):
    def __init__(self, bus):
        super().__init__(bus, OBJECT_PATH)
        self.bus = bus
        self.last_state = {
            "is_max": 0,
            "is_full": 0,
            "app": "",
            "title": "",
            "screen": "",
            "wins": "[]"
        }
        self.vdm_obj = None
        self.vdm_props = None
        self.vdm_iface = None
        self.setup_vdm()

    def setup_vdm(self):
        try:
            self.vdm_obj = self.bus.get_object("org.kde.KWin", "/VirtualDesktopManager")
            self.vdm_props = dbus.Interface(self.vdm_obj, "org.freedesktop.DBus.Properties")
            self.vdm_iface = dbus.Interface(self.vdm_obj, "org.kde.KWin.VirtualDesktopManager")

            self.bus.add_signal_receiver(
                self.on_vdm_signal,
                signal_name="currentChanged",
                dbus_interface="org.kde.KWin.VirtualDesktopManager",
                bus_name="org.kde.KWin"
            )
            self.bus.add_signal_receiver(
                self.on_vdm_signal,
                signal_name="countChanged",
                dbus_interface="org.kde.KWin.VirtualDesktopManager",
                bus_name="org.kde.KWin"
            )
            self.bus.add_signal_receiver(
                self.on_vdm_signal,
                signal_name="desktopCreated",
                dbus_interface="org.kde.KWin.VirtualDesktopManager",
                bus_name="org.kde.KWin"
            )
            self.bus.add_signal_receiver(
                self.on_vdm_signal,
                signal_name="desktopRemoved",
                dbus_interface="org.kde.KWin.VirtualDesktopManager",
                bus_name="org.kde.KWin"
            )
            self.bus.add_signal_receiver(
                self.on_vdm_signal,
                signal_name="desktopDataChanged",
                dbus_interface="org.kde.KWin.VirtualDesktopManager",
                bus_name="org.kde.KWin"
            )
        except Exception as e:
            sys.stderr.write(f"setup_vdm error: {e}\n")

    def get_desktops_json(self):
        if not self.vdm_props:
            return "[]"
        try:
            all_props = self.vdm_props.GetAll("org.kde.KWin.VirtualDesktopManager")
            cur = str(all_props.get("current", ""))
            raw = list(all_props.get("desktops", []))
            desktops = []
            for d in raw:
                idx = int(d[0])
                did = str(d[1])
                name = str(d[2])
                desktops.append({
                    "index": idx,
                    "id": did,
                    "name": name,
                    "isCurrent": (did == cur)
                })
            return json.dumps(desktops)
        except Exception as e:
            sys.stderr.write(f"get_desktops_json error: {e}\n")
            return "[]"

    def emit_state(self):
        s = self.last_state
        d_json = self.get_desktops_json()
        sys.stdout.write(f"{s['is_max']}|{s['is_full']}|{s['app']}|{s['title']}|{s['screen']}|{s['wins']}|{d_json}\n")
        sys.stdout.flush()

    def on_vdm_signal(self, *args, **kwargs):
        self.emit_state()

    @dbus.service.method(BUS_NAME, in_signature="bbssss", out_signature="")
    def notifyState(self, is_maximized, is_fullscreen, title, app_id, screen_name, win_list_json):
        self.last_state = {
            "is_max": 1 if is_maximized else 0,
            "is_full": 1 if is_fullscreen else 0,
            "app": str(app_id).replace("\n", " ").replace("|", " "),
            "title": str(title).replace("\n", " ").replace("|", " "),
            "screen": str(screen_name).replace("\n", " ").replace("|", " "),
            "wins": str(win_list_json).replace("\n", " ")
        }
        self.emit_state()

    def run_kwin_code(self, js_code):
        import tempfile
        with tempfile.NamedTemporaryFile("w", suffix=".js", delete=False) as f:
            f.write(js_code)
            path = f.name
        try:
            kwin_obj = self.bus.get_object("org.kde.KWin", "/Scripting")
            kwin_iface = dbus.Interface(kwin_obj, "org.kde.kwin.Scripting")
            plugin_name = f"action_{os.getpid()}_{int(time.time()*1000)%100000}"
            s_id = kwin_iface.loadScript(path, plugin_name, signature="ss")
            s_obj = self.bus.get_object("org.kde.KWin", f"/Scripting/Script{s_id}")
            s_iface = dbus.Interface(s_obj, "org.kde.kwin.Script")
            s_iface.run()
            GLib.timeout_add(200, lambda: self._unload_script(kwin_iface, plugin_name))
        except Exception as e:
            sys.stderr.write(f"run_kwin_code error: {e}\n")
        finally:
            try:
                os.remove(path)
            except Exception:
                pass

    def _unload_script(self, kwin_iface, plugin_name):
        try:
            kwin_iface.unloadScript(plugin_name)
        except Exception:
            pass
        return False

    @dbus.service.method(BUS_NAME, in_signature="s", out_signature="")
    def activateWindow(self, target_id_or_app):
        escaped = str(target_id_or_app).replace('"', '\\"').lower()
        code = f"""
        var target = "{escaped}";
        var wins = workspace.windowList();
        for (var i = 0; i < wins.length; i++) {{
            var w = wins[i];
            if (!w) continue;
            var wId = String(w.internalId).toLowerCase();
            var wApp = String(w.resourceClass || w.desktopFileName || "").toLowerCase();
            if (wId === target || wApp === target || wApp.indexOf(target) >= 0 || target.indexOf(wApp) >= 0) {{
                w.minimized = false;
                workspace.activeWindow = w;
                break;
            }}
        }}
        """
        self.run_kwin_code(code)

    @dbus.service.method(BUS_NAME, in_signature="s", out_signature="")
    def closeWindow(self, target_id_or_app):
        escaped = str(target_id_or_app).replace('"', '\\"').lower()
        code = f"""
        var target = "{escaped}";
        var wins = workspace.windowList();
        for (var i = 0; i < wins.length; i++) {{
            var w = wins[i];
            if (!w) continue;
            var wId = String(w.internalId).toLowerCase();
            var wApp = String(w.resourceClass || w.desktopFileName || "").toLowerCase();
            if (wId === target || wApp === target || wApp.indexOf(target) >= 0 || target.indexOf(wApp) >= 0) {{
                w.closeWindow();
                break;
            }}
        }}
        """
        self.run_kwin_code(code)

    @dbus.service.method(BUS_NAME, in_signature="s", out_signature="")
    def minimizeWindow(self, target_id_or_app):
        escaped = str(target_id_or_app).replace('"', '\\"').lower()
        code = f"""
        var target = "{escaped}";
        var wins = workspace.windowList();
        for (var i = 0; i < wins.length; i++) {{
            var w = wins[i];
            if (!w) continue;
            var wId = String(w.internalId).toLowerCase();
            var wApp = String(w.resourceClass || w.desktopFileName || "").toLowerCase();
            if (wId === target || wApp === target || wApp.indexOf(target) >= 0 || target.indexOf(wApp) >= 0) {{
                w.minimized = true;
                break;
            }}
        }}
        """
        self.run_kwin_code(code)

    @dbus.service.method(BUS_NAME, in_signature="s", out_signature="")
    def maximizeWindow(self, target_id_or_app):
        escaped = str(target_id_or_app).replace('"', '\\"').lower()
        code = f"""
        var target = "{escaped}";
        var win = null;
        if (target && target.length > 0) {{
            var wins = workspace.windowList();
            for (var i = 0; i < wins.length; i++) {{
                var w = wins[i];
                if (!w) continue;
                var wId = String(w.internalId).toLowerCase();
                var wApp = String(w.resourceClass || w.desktopFileName || "").toLowerCase();
                if (wId === target || wApp === target || wApp.indexOf(target) >= 0 || target.indexOf(wApp) >= 0) {{
                    win = w;
                    break;
                }}
            }}
        }}
        if (!win) {{
            win = workspace.activeWindow;
        }}
        if (win) {{
            if (typeof win.setMaximize === "function") {{
                win.setMaximize(true, true);
            }} else {{
                win.maximized = true;
            }}
        }}
        """
        self.run_kwin_code(code)

    @dbus.service.method(BUS_NAME, in_signature="s", out_signature="")
    def unmaximizeWindow(self, target_id_or_app):
        escaped = str(target_id_or_app).replace('"', '\\"').lower()
        code = f"""
        var target = "{escaped}";
        var win = null;
        if (target && target.length > 0) {{
            var wins = workspace.windowList();
            for (var i = 0; i < wins.length; i++) {{
                var w = wins[i];
                if (!w) continue;
                var wId = String(w.internalId).toLowerCase();
                var wApp = String(w.resourceClass || w.desktopFileName || "").toLowerCase();
                if (wId === target || wApp === target || wApp.indexOf(target) >= 0 || target.indexOf(wApp) >= 0) {{
                    win = w;
                    break;
                }}
            }}
        }}
        if (!win) {{
            win = workspace.activeWindow;
        }}
        if (win) {{
            if (typeof win.setMaximize === "function") {{
                win.setMaximize(false, false);
            }} else {{
                win.maximized = false;
            }}
        }}
        """
        self.run_kwin_code(code)

    @dbus.service.method(BUS_NAME, in_signature="s", out_signature="")
    def toggleMaximizeWindow(self, target_id_or_app):
        escaped = str(target_id_or_app).replace('"', '\\"').lower()
        code = f"""
        var target = "{escaped}";
        var win = null;
        if (target && target.length > 0) {{
            var wins = workspace.windowList();
            for (var i = 0; i < wins.length; i++) {{
                var w = wins[i];
                if (!w) continue;
                var wId = String(w.internalId).toLowerCase();
                var wApp = String(w.resourceClass || w.desktopFileName || "").toLowerCase();
                if (wId === target || wApp === target || wApp.indexOf(target) >= 0 || target.indexOf(wApp) >= 0) {{
                    win = w;
                    break;
                }}
            }}
        }}
        if (!win) {{
            win = workspace.activeWindow;
        }}
        if (win) {{
            var isMax = (win.maximizeMode === 3 || win.maximized === true);
            if (typeof win.setMaximize === "function") {{
                win.setMaximize(!isMax, !isMax);
            }} else {{
                win.maximized = !isMax;
            }}
        }}
        """
        self.run_kwin_code(code)

    @dbus.service.method(BUS_NAME, in_signature="s", out_signature="")
    def toggleKeepAbove(self, target_id_or_app):
        escaped = str(target_id_or_app).replace('"', '\\"').lower()
        code = f"""
        var target = "{escaped}";
        var wins = workspace.windowList();
        for (var i = 0; i < wins.length; i++) {{
            var w = wins[i];
            if (!w) continue;
            var wId = String(w.internalId).toLowerCase();
            var wApp = String(w.resourceClass || w.desktopFileName || "").toLowerCase();
            if (wId === target || wApp === target || wApp.indexOf(target) >= 0 || target.indexOf(wApp) >= 0) {{
                w.keepAbove = !w.keepAbove;
                break;
            }}
        }}
        """
        self.run_kwin_code(code)

    @dbus.service.method(BUS_NAME, in_signature="s", out_signature="")
    def moveToNextDesktop(self, target_id_or_app):
        escaped = str(target_id_or_app).replace('"', '\\"').lower()
        code = f"""
        var target = "{escaped}";
        var wins = workspace.windowList();
        for (var i = 0; i < wins.length; i++) {{
            var w = wins[i];
            if (!w) continue;
            var wId = String(w.internalId).toLowerCase();
            var wApp = String(w.resourceClass || w.desktopFileName || "").toLowerCase();
            if (wId === target || wApp === target || wApp.indexOf(target) >= 0 || target.indexOf(wApp) >= 0) {{
                try {{
                    if (workspace.desktops && workspace.desktops.length > 1) {{
                        var curIdx = workspace.desktops.indexOf(workspace.currentDesktop);
                        var nextIdx = (curIdx + 1) % workspace.desktops.length;
                        w.desktops = [workspace.desktops[nextIdx]];
                        workspace.currentDesktop = workspace.desktops[nextIdx];
                    }} else if (typeof workspace.slotWindowToNextDesktop === "function") {{
                        workspace.activeWindow = w;
                        workspace.slotWindowToNextDesktop();
                    }}
                }} catch(e) {{}}
                break;
            }}
        }}
        """
        self.run_kwin_code(code)

    @dbus.service.method(BUS_NAME, in_signature="s", out_signature="")
    def quitApplication(self, target_app):
        escaped = str(target_app).replace('"', '\\"').lower()
        code = f"""
        var target = "{escaped}";
        var wins = workspace.windowList();
        for (var i = 0; i < wins.length; i++) {{
            var w = wins[i];
            if (!w) continue;
            var wApp = String(w.resourceClass || w.desktopFileName || "").toLowerCase();
            if (wApp === target || wApp.indexOf(target) >= 0 || target.indexOf(wApp) >= 0) {{
                w.closeWindow();
            }}
        }}
        """
        self.run_kwin_code(code)

    @dbus.service.method(BUS_NAME, in_signature="s", out_signature="")
    def switchDesktop(self, target):
        if not self.vdm_props:
            return
        try:
            t = str(target).strip()
            all_props = self.vdm_props.GetAll("org.kde.KWin.VirtualDesktopManager")
            raw = list(all_props.get("desktops", []))
            matched_id = None
            for d in raw:
                idx = int(d[0])
                did = str(d[1])
                name = str(d[2])
                if str(idx) == t or did == t or name.lower() == t.lower():
                    matched_id = did
                    break
            if matched_id:
                self.vdm_props.Set("org.kde.KWin.VirtualDesktopManager", "current", dbus.String(matched_id))
        except Exception as e:
            sys.stderr.write(f"switchDesktop error: {e}\n")

    @dbus.service.method(BUS_NAME, in_signature="", out_signature="")
    def nextDesktop(self):
        if not self.vdm_props:
            return
        try:
            all_props = self.vdm_props.GetAll("org.kde.KWin.VirtualDesktopManager")
            cur = str(all_props.get("current", ""))
            raw = list(all_props.get("desktops", []))
            if not raw:
                return
            for i, d in enumerate(raw):
                if str(d[1]) == cur:
                    next_d = raw[(i + 1) % len(raw)]
                    self.vdm_props.Set("org.kde.KWin.VirtualDesktopManager", "current", dbus.String(str(next_d[1])))
                    break
        except Exception as e:
            sys.stderr.write(f"nextDesktop error: {e}\n")

    @dbus.service.method(BUS_NAME, in_signature="", out_signature="")
    def previousDesktop(self):
        if not self.vdm_props:
            return
        try:
            all_props = self.vdm_props.GetAll("org.kde.KWin.VirtualDesktopManager")
            cur = str(all_props.get("current", ""))
            raw = list(all_props.get("desktops", []))
            if not raw:
                return
            for i, d in enumerate(raw):
                if str(d[1]) == cur:
                    prev_d = raw[(i - 1 + len(raw)) % len(raw)]
                    self.vdm_props.Set("org.kde.KWin.VirtualDesktopManager", "current", dbus.String(str(prev_d[1])))
                    break
        except Exception as e:
            sys.stderr.write(f"previousDesktop error: {e}\n")

    @dbus.service.method(BUS_NAME, in_signature="s", out_signature="")
    def createDesktop(self, name):
        if not self.vdm_iface or not self.vdm_props:
            return
        try:
            all_props = self.vdm_props.GetAll("org.kde.KWin.VirtualDesktopManager")
            count = int(all_props.get("count", 1))
            d_name = str(name).strip() if str(name).strip() else f"Desktop {count + 1}"
            self.vdm_iface.createDesktop(dbus.UInt32(count), dbus.String(d_name))
        except Exception as e:
            sys.stderr.write(f"createDesktop error: {e}\n")

    @dbus.service.method(BUS_NAME, in_signature="s", out_signature="")
    def removeDesktop(self, desktop_id):
        if not self.vdm_iface:
            return
        try:
            self.vdm_iface.removeDesktop(dbus.String(str(desktop_id).strip()))
        except Exception as e:
            sys.stderr.write(f"removeDesktop error: {e}\n")

def main():
    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    try:
        bus = dbus.SessionBus()
    except Exception as e:
        sys.stderr.write(f"Failed to connect to session bus: {e}\n")
        sys.exit(1)

    try:
        bus_name = dbus.service.BusName(BUS_NAME, bus)
    except Exception as e:
        sys.stderr.write(f"Bus name note: {e}\n")

    bridge = WindowBridge(bus)
    bridge.emit_state()

    script_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "kwin_script.js")
    
    kwin_script_id = None
    try:
        kwin_obj = bus.get_object("org.kde.KWin", "/Scripting")
        kwin_iface = dbus.Interface(kwin_obj, "org.kde.kwin.Scripting")
        
        try:
            kwin_iface.unloadScript(SCRIPT_NAME)
        except Exception:
            pass

        # Specify signature="ss" because loadScript is overloaded in KWin DBus API
        kwin_script_id = kwin_iface.loadScript(script_path, SCRIPT_NAME, signature="ss")
        
        script_obj = bus.get_object("org.kde.KWin", f"/Scripting/Script{kwin_script_id}")
        script_iface = dbus.Interface(script_obj, "org.kde.kwin.Script")
        script_iface.run()
    except Exception as e:
        sys.stderr.write(f"KWin Scripting error: {e}\n")

    loop = GLib.MainLoop()

    def cleanup(*args):
        try:
            if kwin_script_id is not None:
                kwin_obj = bus.get_object("org.kde.KWin", "/Scripting")
                kwin_iface = dbus.Interface(kwin_obj, "org.kde.kwin.Scripting")
                kwin_iface.unloadScript(SCRIPT_NAME)
        except Exception:
            pass
        loop.quit()

    signal.signal(signal.SIGINT, cleanup)
    signal.signal(signal.SIGTERM, cleanup)
    atexit.register(cleanup)

    loop.run()

if __name__ == "__main__":
    main()
