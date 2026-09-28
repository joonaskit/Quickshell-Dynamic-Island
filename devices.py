#!/usr/bin/env python3
import sys
import os
import time
import json
import signal
import subprocess
import threading

def handle_sigterm(signum, frame):
    sys.exit(0)

signal.signal(signal.SIGTERM, handle_sigterm)
signal.signal(signal.SIGINT, handle_sigterm)

def format_bytes(b):
    if b is None or b < 0:
        return ""
    for unit in ["B", "KB", "MB", "GB", "TB"]:
        if b < 1024.0:
            return f"{b:.1f} {unit}" if unit in ["GB", "TB"] else f"{int(b)} {unit}"
        b /= 1024.0
    return f"{b:.1f} PB"

def scan_devices():
    try:
        cmd = [
            "lsblk", "-J", "-b",
            "-o", "NAME,PATH,LABEL,UUID,FSTYPE,SIZE,MOUNTPOINTS,MODEL,HOTPLUG,RM,RO,TYPE,TRAN,SUBSYSTEMS,VENDOR,SERIAL,FSAVAIL,FSUSE%,FSUSED"
        ]
        out = subprocess.check_output(cmd, stderr=subprocess.DEVNULL).decode("utf-8")
        data = json.loads(out)
    except Exception:
        return []

    devices = []

    for dev in data.get("blockdevices", []):
        tran = str(dev.get("tran") or "").lower()
        subsystems = str(dev.get("subsystems") or "").lower()
        is_usb = tran == "usb" or "usb" in subsystems
        is_rm = bool(dev.get("rm")) or bool(dev.get("hotplug"))

        # Must be detachable/removable or USB transport
        if not (is_usb or is_rm):
            continue

        dev_name = dev.get("name", "")
        # Filter out virtual, loop, swap, and zram devices
        if dev_name.startswith("zram") or dev_name.startswith("loop") or dev_name.startswith("dm-"):
            continue

        dev_path = dev.get("path") or f"/dev/{dev_name}"
        model = (dev.get("model") or "").strip()
        vendor = (dev.get("vendor") or "").strip()
        serial = (dev.get("serial") or "").strip()

        # Build clean, user-friendly device title
        if vendor and model:
            if vendor.lower() in model.lower():
                device_title = model
            else:
                device_title = f"{vendor} {model}"
        elif model:
            device_title = model
        elif vendor:
            device_title = vendor
        else:
            device_title = f"Removable Drive ({dev_name})"

        raw_size = dev.get("size") or 0
        size_str = format_bytes(raw_size)

        raw_children = dev.get("children", [])
        partitions = []

        system_mounts = {"/", "/home", "/boot", "/boot/efi", "/var", "[SWAP]"}
        has_system_mount = False

        if raw_children:
            for child in raw_children:
                child_name = child.get("name", "")
                child_path = child.get("path") or f"/dev/{child_name}"
                mountpoints = [m for m in (child.get("mountpoints") or []) if m]
                is_mounted = len(mountpoints) > 0
                mountpoint = mountpoints[0] if is_mounted else ""

                if any(m in system_mounts for m in mountpoints):
                    has_system_mount = True
                    break

                child_label = (child.get("label") or "").strip()
                child_fstype = (child.get("fstype") or "").strip()
                child_uuid = child.get("uuid") or ""
                child_size = child.get("size") or 0
                child_size_str = format_bytes(child_size)

                fsused = child.get("fsused")
                fsavail = child.get("fsavail")
                raw_pct = child.get("fsuse%") or ""
                use_pct = 0
                try:
                    if raw_pct:
                        use_pct = int(raw_pct.replace("%", "").strip())
                except Exception:
                    use_pct = 0

                # Calculate use percentage if not provided by lsblk
                if use_pct == 0 and fsused is not None and fsavail is not None and (fsused + fsavail) > 0:
                    use_pct = int(round((fsused / (fsused + fsavail)) * 100))

                if child_label:
                    part_title = child_label
                elif child_fstype:
                    part_title = f"{child_fstype.upper()} ({child_name})"
                else:
                    part_title = child_name

                partitions.append({
                    "name": child_name,
                    "path": child_path,
                    "label": child_label,
                    "title": part_title,
                    "uuid": child_uuid,
                    "fstype": child_fstype,
                    "size": child_size,
                    "sizeFormatted": child_size_str,
                    "isMounted": is_mounted,
                    "mountpoint": mountpoint,
                    "mountpoints": mountpoints,
                    "used": fsused if fsused is not None else 0,
                    "usedFormatted": format_bytes(fsused) if fsused is not None else "",
                    "avail": fsavail if fsavail is not None else 0,
                    "availFormatted": format_bytes(fsavail) if fsavail is not None else "",
                    "usePercent": use_pct
                })
        else:
            # Whole disk without separate partitions
            mountpoints = [m for m in (dev.get("mountpoints") or []) if m]
            is_mounted = len(mountpoints) > 0
            mountpoint = mountpoints[0] if is_mounted else ""

            if any(m in system_mounts for m in mountpoints):
                has_system_mount = True

            if not has_system_mount:
                child_label = (dev.get("label") or "").strip()
                child_fstype = (dev.get("fstype") or "").strip()
                child_uuid = dev.get("uuid") or ""
                fsused = dev.get("fsused")
                fsavail = dev.get("fsavail")
                raw_pct = dev.get("fsuse%") or ""
                use_pct = 0
                try:
                    if raw_pct:
                        use_pct = int(raw_pct.replace("%", "").strip())
                except Exception:
                    use_pct = 0

                if use_pct == 0 and fsused is not None and fsavail is not None and (fsused + fsavail) > 0:
                    use_pct = int(round((fsused / (fsused + fsavail)) * 100))

                if child_label:
                    part_title = child_label
                elif child_fstype:
                    part_title = f"{child_fstype.upper()} ({dev_name})"
                else:
                    part_title = dev_name

                partitions.append({
                    "name": dev_name,
                    "path": dev_path,
                    "label": child_label,
                    "title": part_title,
                    "uuid": child_uuid,
                    "fstype": child_fstype,
                    "size": raw_size,
                    "sizeFormatted": size_str,
                    "isMounted": is_mounted,
                    "mountpoint": mountpoint,
                    "mountpoints": mountpoints,
                    "used": fsused if fsused is not None else 0,
                    "usedFormatted": format_bytes(fsused) if fsused is not None else "",
                    "avail": fsavail if fsavail is not None else 0,
                    "availFormatted": format_bytes(fsavail) if fsavail is not None else "",
                    "usePercent": use_pct
                })

        # Do not allow unmounting internal OS system installations
        if has_system_mount:
            continue

        has_mounted_part = any(p["isMounted"] for p in partitions)

        devices.append({
            "name": dev_name,
            "path": dev_path,
            "title": device_title,
            "model": model,
            "vendor": vendor,
            "serial": serial,
            "size": raw_size,
            "sizeFormatted": size_str,
            "isRemovable": is_rm,
            "isUsb": is_usb,
            "isMounted": has_mounted_part,
            "partitions": partitions
        })

    return devices

def mount_device(target):
    try:
        dev = target if target.startswith("/dev/") else f"/dev/{target}"
        res = subprocess.run(["udisksctl", "mount", "-b", dev, "--no-user-interaction"], capture_output=True, text=True)
        if res.returncode == 0:
            return {"success": True, "output": res.stdout.strip()}
        # Fallback to gio mount
        res2 = subprocess.run(["gio", "mount", "-d", dev], capture_output=True, text=True)
        if res2.returncode == 0:
            return {"success": True, "output": res2.stdout.strip()}
        return {"success": False, "error": res.stderr.strip() or res2.stderr.strip()}
    except Exception as e:
        return {"success": False, "error": str(e)}

def unmount_device(target):
    try:
        dev = target if target.startswith("/dev/") else f"/dev/{target}"
        res = subprocess.run(["udisksctl", "unmount", "-b", dev, "--no-user-interaction"], capture_output=True, text=True)
        if res.returncode == 0:
            return {"success": True, "output": res.stdout.strip()}
        # Fallback to gio mount -u
        res2 = subprocess.run(["gio", "mount", "-u", "-d", dev], capture_output=True, text=True)
        if res2.returncode == 0:
            return {"success": True, "output": res2.stdout.strip()}
        return {"success": False, "error": res.stderr.strip() or res2.stderr.strip()}
    except Exception as e:
        return {"success": False, "error": str(e)}

def power_off_device(target):
    try:
        dev = target if target.startswith("/dev/") else f"/dev/{target}"
        # First safely unmount any mounted partitions on the drive
        try:
            lsblk_out = subprocess.check_output(
                ["lsblk", "-J", "-o", "NAME,PATH,MOUNTPOINTS", dev],
                stderr=subprocess.DEVNULL
            ).decode("utf-8")
            data = json.loads(lsblk_out)
            for d in data.get("blockdevices", []):
                for child in d.get("children", []):
                    c_path = child.get("path")
                    if child.get("mountpoints") and any(child.get("mountpoints")):
                        subprocess.run(["udisksctl", "unmount", "-b", c_path, "--no-user-interaction"], capture_output=True)
                if d.get("mountpoints") and any(d.get("mountpoints")):
                    subprocess.run(["udisksctl", "unmount", "-b", d.get("path"), "--no-user-interaction"], capture_output=True)
        except Exception:
            pass

        res = subprocess.run(["udisksctl", "power-off", "-b", dev, "--no-user-interaction"], capture_output=True, text=True)
        if res.returncode == 0:
            return {"success": True, "output": res.stdout.strip()}
        return {"success": False, "error": res.stderr.strip()}
    except Exception as e:
        return {"success": False, "error": str(e)}

def open_mount(target):
    try:
        subprocess.Popen(["xdg-open", target], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return {"success": True}
    except Exception as e:
        return {"success": False, "error": str(e)}

def get_mounts_hash():
    try:
        with open("/proc/mounts", "r") as f:
            m = f.read()
        with open("/proc/partitions", "r") as f:
            p = f.read()
        return hash(m + p)
    except Exception:
        return 0

def monitor_loop():
    last_hash = None
    last_json = None
    last_full_scan = 0

    while True:
        now = time.time()
        curr_hash = get_mounts_hash()

        # Rescan if /proc/mounts or /proc/partitions changed, or at least every 3 seconds
        if curr_hash != last_hash or (now - last_full_scan) >= 3.0:
            last_hash = curr_hash
            last_full_scan = now
            devs = scan_devices()
            devs_json = json.dumps(devs)
            if devs_json != last_json:
                last_json = devs_json
                sys.stdout.write(devs_json + "\n")
                sys.stdout.flush()

        time.sleep(1.0)

def main():
    if len(sys.argv) < 2 or sys.argv[1] == "list":
        print(json.dumps(scan_devices()))
    elif sys.argv[1] == "monitor":
        monitor_loop()
    elif sys.argv[1] == "mount" and len(sys.argv) > 2:
        print(json.dumps(mount_device(sys.argv[2])))
    elif sys.argv[1] == "unmount" and len(sys.argv) > 2:
        print(json.dumps(unmount_device(sys.argv[2])))
    elif sys.argv[1] == "power-off" and len(sys.argv) > 2:
        print(json.dumps(power_off_device(sys.argv[2])))
    elif sys.argv[1] == "open" and len(sys.argv) > 2:
        print(json.dumps(open_mount(sys.argv[2])))
    else:
        print(json.dumps(scan_devices()))

if __name__ == "__main__":
    main()
