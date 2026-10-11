#!/usr/bin/env python3
"""Philips Hue Bridge helper for HueService.

Talks to the Hue Bridge v2 API (HTTPS on the LAN). The bridge uses a
self-signed certificate, so certificate checks are off for the bridge only.
The application key is read from the HUE_KEY environment variable so it never
shows up in the process list. The bridge address comes from HUE_BRIDGE.

Commands (output is JSON lines on stdout):
  discover                    ask discovery.meethue.com for bridges on this network
  pair                        create an application key (press the bridge link button first)
  lights                      print the lights once
  stream                      print the lights now and again after every change
  set <id> [--on|--off] [--brightness 0-100] [--mirek N]
"""
import argparse
import json
import os
import ssl
import sys
import urllib.error
import urllib.request

DEVICE_TYPE = "quickshell#island"
TIMEOUT = 6
# The bridge sends a keep-alive about every 2 minutes; give up a bit after that
STREAM_TIMEOUT = 150

_CONTEXT = ssl.create_default_context()
_CONTEXT.check_hostname = False
_CONTEXT.verify_mode = ssl.CERT_NONE


def normalize_light(raw):
    """Flatten a v2 light resource into the fields the shell uses."""
    dimming = raw.get("dimming") or {}
    temp = raw.get("color_temperature") or {}
    schema = temp.get("mirek_schema") or {}
    has_temp = "mirek" in temp or bool(schema)
    return {
        "id": raw.get("id", ""),
        "name": (raw.get("metadata") or {}).get("name", "Light"),
        "on": bool((raw.get("on") or {}).get("on", False)),
        "hasBrightness": "brightness" in dimming,
        "brightness": float(dimming.get("brightness", 100.0)),
        "hasColorTemp": has_temp,
        # mirek is null when the lamp is showing a colour rather than white
        "mirek": temp.get("mirek") or 0,
        "mirekMin": schema.get("mirek_minimum", 153),
        "mirekMax": schema.get("mirek_maximum", 500),
    }


def build_light_body(on=None, brightness=None, mirek=None):
    """Build the PUT body for a light; unset values are left out."""
    body = {}
    if on is not None:
        body["on"] = {"on": bool(on)}
    if brightness is not None:
        # The bridge rejects anything below 1 and keeps 0 for "off"
        body["dimming"] = {"brightness": max(1.0, min(100.0, float(brightness)))}
    if mirek is not None:
        body["color_temperature"] = {"mirek": int(mirek)}
    return body


def parse_pair_response(data):
    """Return (key, error) from the answer to the pairing request."""
    if isinstance(data, list) and data:
        entry = data[0]
        if "success" in entry:
            return entry["success"].get("username"), None
        if "error" in entry:
            if entry["error"].get("type") == 101:
                return None, "link_button"
            return None, entry["error"].get("description", "pairing failed")
    return None, "unexpected answer from the bridge"


def request(method, url, key=None, body=None, timeout=TIMEOUT, context=_CONTEXT):
    headers = {"Content-Type": "application/json"}
    if key:
        headers["hue-application-key"] = key
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    with urllib.request.urlopen(req, timeout=timeout, context=context) as resp:
        return json.load(resp)


def emit(obj):
    print(json.dumps(obj), flush=True)


def get_lights(bridge, key):
    data = request("GET", f"https://{bridge}/clip/v2/resource/light", key)
    return [normalize_light(light) for light in data.get("data", [])]


def cmd_discover(_args):
    data = request("GET", "https://discovery.meethue.com", context=ssl.create_default_context())
    emit({"bridges": [b["internalipaddress"] for b in data if "internalipaddress" in b]})


def cmd_pair(args):
    body = {"devicetype": DEVICE_TYPE, "generateclientkey": True}
    data = request("POST", f"https://{args.bridge}/api", body=body)
    key, error = parse_pair_response(data)
    emit({"key": key} if key else {"error": error})


def cmd_lights(args):
    emit({"lights": get_lights(args.bridge, args.key)})


def cmd_stream(args):
    emit({"lights": get_lights(args.bridge, args.key)})
    req = urllib.request.Request(
        f"https://{args.bridge}/eventstream/clip/v2",
        headers={"hue-application-key": args.key, "Accept": "text/event-stream"},
    )
    with urllib.request.urlopen(req, timeout=STREAM_TIMEOUT, context=_CONTEXT) as resp:
        for raw in resp:
            line = raw.decode("utf-8", "replace").strip()
            if not line.startswith("data:"):
                continue
            try:
                events = json.loads(line[5:])
            except ValueError:
                continue
            # Fetch the whole list again: cheap, and keeps lights without a diff in sync
            touched = any(
                item.get("type") == "light"
                for event in events
                for item in event.get("data", [])
            )
            if touched:
                emit({"lights": get_lights(args.bridge, args.key)})


def cmd_set(args):
    on = True if args.on else (False if args.off else None)
    body = build_light_body(on, args.brightness, args.mirek)
    if not body:
        return
    request("PUT", f"https://{args.bridge}/clip/v2/resource/light/{args.light}", args.key, body)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("discover").set_defaults(func=cmd_discover)
    sub.add_parser("pair").set_defaults(func=cmd_pair)
    sub.add_parser("lights").set_defaults(func=cmd_lights)
    sub.add_parser("stream").set_defaults(func=cmd_stream)
    setter = sub.add_parser("set")
    setter.add_argument("light")
    setter.add_argument("--on", action="store_true")
    setter.add_argument("--off", action="store_true")
    setter.add_argument("--brightness", type=float)
    setter.add_argument("--mirek", type=int)
    setter.set_defaults(func=cmd_set)
    args = parser.parse_args()

    args.bridge = os.environ.get("HUE_BRIDGE", "")
    args.key = os.environ.get("HUE_KEY", "")
    if args.command != "discover" and not args.bridge:
        emit({"error": "no bridge address"})
        return 1
    if args.command in ("lights", "stream", "set") and not args.key:
        emit({"error": "not paired"})
        return 1

    try:
        args.func(args)
    except urllib.error.HTTPError as exc:
        emit({"error": f"bridge answered {exc.code}"})
        return 1
    except (urllib.error.URLError, OSError, ValueError) as exc:
        emit({"error": str(getattr(exc, "reason", exc))})
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
