#!/usr/bin/env python3
import json
import subprocess
import sys


def list_sinks():
    try:
        sinks = json.loads(subprocess.check_output(["pactl", "-f", "json", "list", "sinks"], stderr=subprocess.DEVNULL))
        try:
            default_sink = subprocess.check_output(["pactl", "get-default-sink"], stderr=subprocess.DEVNULL).decode().strip()
        except Exception:
            default_sink = ""

        result = []
        for s in sinks:
            name = s.get("name", "")
            desc = s.get("description", name)
            props = s.get("properties", {})
            nick = props.get("node.nick", "")
            form_factor = props.get("device.form_factor", "")
            icon_name = props.get("device.icon_name", "")

            # Generate concise, friendly display name
            display_name = desc
            if "[" in desc and "]" in desc:
                b_start = desc.rfind("[")
                b_end = desc.rfind("]")
                if b_start != -1 and b_end > b_start:
                    display_name = desc[b_start+1:b_end]
            elif nick and nick != "ALC897 Digital":
                display_name = nick
            elif "IEC958" in desc:
                display_name = "Digital Output (S/PDIF)"
            elif "Analog Stereo" in desc:
                display_name = "Line Out / Speakers"

            is_headphones = any(k in x.lower() for k in ["head", "ear", "airpod"] for x in [icon_name, form_factor, desc, name])

            result.append({
                "name": name,
                "description": desc,
                "displayName": display_name,
                "isDefault": (name == default_sink),
                "icon": "headphones" if is_headphones else "volume-high"
            })

        print(json.dumps(result))
    except Exception:
        print("[]")

def set_sink(sink_name):
    if not sink_name:
        return
    try:
        subprocess.run(["pactl", "set-default-sink", sink_name], check=True, stderr=subprocess.DEVNULL)
    except Exception as e:
        sys.stderr.write(f"Error setting sink: {e}\n")

if __name__ == "__main__":
    action = sys.argv[1] if len(sys.argv) > 1 else "list"
    if action == "list":
        list_sinks()
    elif action == "set" and len(sys.argv) > 2:
        set_sink(sys.argv[2])
    else:
        list_sinks()
