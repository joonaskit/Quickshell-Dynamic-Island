#!/usr/bin/env python3
import sys
import os
import json
import subprocess

def list_sources():
    try:
        env = dict(os.environ, LC_ALL="C")
        sources = json.loads(subprocess.check_output(["pactl", "-f", "json", "list", "sources"], stderr=subprocess.DEVNULL, env=env))
        try:
            default_source = subprocess.check_output(["pactl", "get-default-source"], stderr=subprocess.DEVNULL, env=env).decode().strip()
        except Exception:
            default_source = ""

        result = []
        for s in sources:
            name = s.get("name", "")
            # Skip monitor sources (output loopbacks)
            if name.endswith(".monitor") or "monitor" in s.get("media.class", "").lower():
                continue

            desc = s.get("description", name)
            props = s.get("properties", {})
            nick = props.get("node.nick", "")
            active_port = s.get("active_port", "")

            # Generate friendly display name
            display_name = desc
            if "Analog Stereo" in desc:
                display_name = "Internal / Analog Mic"
            elif nick:
                display_name = nick
            elif "[" in desc and "]" in desc:
                b_start = desc.rfind("[")
                b_end = desc.rfind("]")
                if b_start != -1 and b_end > b_start:
                    display_name = desc[b_start+1:b_end]

            is_muted = bool(s.get("mute", False))
            vol_obj = s.get("volume", {})
            vol_pct = 100
            for ch in vol_obj.values():
                if isinstance(ch, dict) and "value_percent" in ch:
                    try:
                        vol_pct = int(ch["value_percent"].replace("%", "").strip())
                        break
                    except Exception:
                        pass

            result.append({
                "name": name,
                "description": desc,
                "displayName": display_name,
                "isDefault": (name == default_source),
                "isMuted": is_muted,
                "volume": vol_pct
            })

        print(json.dumps(result))
    except Exception:
        print("[]")

def set_source(source_name):
    if not source_name:
        return
    try:
        subprocess.run(["pactl", "set-default-source", source_name], check=True, stderr=subprocess.DEVNULL)
    except Exception as e:
        sys.stderr.write(f"Error setting source: {e}\n")

if __name__ == "__main__":
    action = sys.argv[1] if len(sys.argv) > 1 else "list"
    if action == "list":
        list_sources()
    elif action == "set" and len(sys.argv) > 2:
        set_source(sys.argv[2])
