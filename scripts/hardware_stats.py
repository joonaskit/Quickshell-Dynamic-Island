#!/usr/bin/env python3
import glob
import json
import signal
import sys
import time


def handle_sigterm(signum, frame):
    sys.exit(0)

signal.signal(signal.SIGTERM, handle_sigterm)
signal.signal(signal.SIGINT, handle_sigterm)

def read_cpu_times():
    try:
        with open("/proc/stat", "r") as f:
            line = f.readline()
            fields = [float(x) for x in line.strip().split()[1:]]
            idle = fields[3] + fields[4] # idle + iowait
            total = sum(fields)
            return idle, total
    except Exception:
        return 0, 0

def read_mem():
    try:
        mem = {}
        with open("/proc/meminfo", "r") as f:
            for line in f:
                parts = line.split(":")
                if len(parts) == 2:
                    mem[parts[0].strip()] = int(parts[1].strip().split()[0])
        tot_mb = mem.get("MemTotal", 0) / 1024.0
        avail_mb = mem.get("MemAvailable", 0) / 1024.0
        used_mb = max(0.0, tot_mb - avail_mb)
        pct = int(round((used_mb / tot_mb) * 100)) if tot_mb > 0 else 0
        return pct, round(used_mb / 1024.0, 1), round(tot_mb / 1024.0, 1)
    except Exception:
        return 0, 0.0, 0.0

def read_temp():
    # Prefer k10temp / coretemp
    try:
        for name_path in glob.glob("/sys/class/hwmon/hwmon*/name"):
            with open(name_path, "r") as nf:
                hwname = nf.read().strip()
                if hwname in ("k10temp", "coretemp", "zenpower", "cpu_thermal"):
                    hwdir = name_path[:-4]
                    for tf in glob.glob(f"{hwdir}/temp*_input"):
                        with open(tf, "r") as f:
                            v = int(f.read().strip()) / 1000.0
                            if 15 <= v <= 115:
                                return int(round(v))
    except Exception:
        pass

    # Fallback to any valid thermal zone / hwmon
    try:
        for tf in glob.glob("/sys/class/hwmon/hwmon*/temp*_input") + glob.glob("/sys/class/thermal/thermal_zone*/temp"):
            try:
                with open(tf, "r") as f:
                    v = int(f.read().strip()) / 1000.0
                    if 25 <= v <= 110:
                        return int(round(v))
            except Exception:
                pass
    except Exception:
        pass
    return 0

def main():
    prev_idle, prev_total = read_cpu_times()
    while True:
        time.sleep(2.0)
        curr_idle, curr_total = read_cpu_times()
        diff_total = curr_total - prev_total
        diff_idle = curr_idle - prev_idle
        prev_idle, prev_total = curr_idle, curr_total

        cpu_pct = 0
        if diff_total > 0:
            cpu_pct = int(round(max(0.0, min(100.0, (1.0 - (diff_idle / diff_total)) * 100.0))))

        ram_pct, ram_used, ram_tot = read_mem()
        temp_c = read_temp()

        data = {
            "cpu": cpu_pct,
            "ram": ram_pct,
            "ramUsed": ram_used,
            "ramTotal": ram_tot,
            "temp": temp_c
        }
        sys.stdout.write(json.dumps(data) + "\n")
        sys.stdout.flush()

if __name__ == "__main__":
    main()
