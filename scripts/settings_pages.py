#!/usr/bin/env python3
"""Lists the pages of KDE System Settings for the launcher's settings search.

Every page is a hidden desktop entry (kcm_*.desktop, NoDisplay=true), so the normal
app list never shows them. This prints them once as a JSON array and exits:
[{"id", "name", "comment", "keywords", "icon", "command"}]. The pure parsing is
kept apart from the file reading so tests/test_settings_pages.py can run it.
"""
import json
import os
import sys

PREFIXES = ("kcm_", "kcm-")
# Only pages System Settings itself opens; anything else with a kcm_ name is skipped
LAUNCHERS = ("systemsettings", "systemsettings5", "kcmshell6", "kcmshell5")


def locale_names():
    """Locale keys to try for a translated key, most specific first: de_DE, de."""
    raw = os.environ.get("LC_ALL") or os.environ.get("LC_MESSAGES") or os.environ.get("LANG") or ""
    raw = raw.split(".")[0].split("@")[0]
    if not raw or raw in ("C", "POSIX"):
        return []
    names = [raw]
    if "_" in raw:
        names.append(raw.split("_")[0])
    return names


def parse_entry(text, locales):
    """The [Desktop Entry] group as a dict, with translated keys already resolved.

    A key that has a translation for one of the locales takes that value in place of
    the plain one, so callers just read "Name" or "Keywords"."""
    fields = {}
    translated = {}
    in_group = False
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("["):
            if in_group:
                break
            in_group = line == "[Desktop Entry]"
            continue
        if not in_group or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip()
        if key.endswith("]") and "[" in key:
            base, loc = key[:-1].split("[", 1)
            translated[(base, loc)] = value
        else:
            fields[key] = value
    for base in ("Name", "Comment", "Keywords"):
        for loc in locales:
            if (base, loc) in translated:
                fields[base] = translated[(base, loc)]
                break
    return fields


def split_exec(exec_line):
    """The command words of an Exec line, with the %f style field codes removed."""
    words = []
    for word in exec_line.split():
        if len(word) == 2 and word[0] == "%":
            continue
        words.append(word.strip('"'))
    return words


def page_from_entry(file_name, fields):
    """One settings page for a desktop entry, or None when it is not one."""
    if not file_name.startswith(PREFIXES) or not file_name.endswith(".desktop"):
        return None
    if fields.get("Type") != "Application" or fields.get("Hidden", "").lower() == "true":
        return None
    name = fields.get("Name", "").strip()
    command = split_exec(fields.get("Exec", ""))
    if not name or not command or os.path.basename(command[0]) not in LAUNCHERS:
        return None
    keywords = [k.strip() for k in fields.get("Keywords", "").split(";") if k.strip()]
    return {
        "id": file_name[: -len(".desktop")],
        "name": name,
        "comment": fields.get("Comment", "").strip(),
        "keywords": keywords,
        "icon": fields.get("Icon", "").strip(),
        "command": command,
    }


def data_dirs():
    home = os.environ.get("XDG_DATA_HOME") or os.path.join(os.path.expanduser("~"), ".local", "share")
    system = os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share"
    return [home] + [d for d in system.split(":") if d]


def collect(dirs, locales):
    """Pages from every applications folder; an earlier folder wins over a later one."""
    pages = {}
    for base in dirs:
        folder = os.path.join(base, "applications")
        try:
            names = sorted(os.listdir(folder))
        except OSError:
            continue
        for file_name in names:
            if file_name in pages or not file_name.startswith(PREFIXES):
                continue
            try:
                with open(os.path.join(folder, file_name), encoding="utf-8") as f:
                    fields = parse_entry(f.read(), locales)
            except (OSError, UnicodeDecodeError):
                continue
            page = page_from_entry(file_name, fields)
            if page:
                pages[file_name] = page
    return sorted(pages.values(), key=lambda p: p["name"].lower())


def main():
    json.dump(collect(data_dirs(), locale_names()), sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
