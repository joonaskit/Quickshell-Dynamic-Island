#!/usr/bin/env python3
import os
import sys
import subprocess
import json

def get_downloads_dir():
    # 1. Try xdg-user-dir
    try:
        p = subprocess.check_output(['xdg-user-dir', 'DOWNLOAD'], text=True).strip()
        if p and os.path.exists(p):
            return p
    except Exception:
        pass

    # 2. Check common paths
    for cand in [
        os.path.expanduser('~/Downloads'),
        os.path.expanduser('~/Lataukset'),
        os.path.expanduser('~/Desktop'),
        os.path.expanduser('~/Työpöytä'),
        os.path.expanduser('~/code')
    ]:
        if os.path.exists(cand):
            return cand

    return os.path.expanduser('~')

def format_size(size_bytes):
    if size_bytes < 1024:
        return f"{size_bytes} B"
    elif size_bytes < 1024 * 1024:
        return f"{size_bytes / 1024:.1f} KB"
    elif size_bytes < 1024 * 1024 * 1024:
        return f"{size_bytes / (1024 * 1024):.1f} MB"
    else:
        return f"{size_bytes / (1024 * 1024 * 1024):.1f} GB"

def get_icon(name, is_dir):
    if is_dir:
        return "folder"
    ext = os.path.splitext(name)[1].lower()
    if ext in ['.png', '.jpg', '.jpeg', '.svg', '.webp', '.gif', '.ico']:
        return "image"
    elif ext in ['.mp4', '.mkv', '.webm', '.avi', '.mov']:
        return "video"
    elif ext in ['.mp3', '.flac', '.wav', '.ogg', '.m4a', '.opus']:
        return "music"
    elif ext in ['.zip', '.tar', '.gz', '.7z', '.bz2', '.xz', '.rar']:
        return "archive"
    elif ext in ['.pdf', '.doc', '.docx', '.odt', '.txt', '.md']:
        return "file-text"
    elif ext in ['.sh', '.py', '.js', '.ts', '.qml', '.json', '.c', '.cpp', '.rs']:
        return "code"
    return "file"

def scan():
    dl_dir = get_downloads_dir()
    items = []
    try:
        if os.path.isdir(dl_dir):
            entries = [os.path.join(dl_dir, f) for f in os.listdir(dl_dir) if not f.startswith('.')]
            entries.sort(key=lambda x: os.path.getmtime(x) if os.path.exists(x) else 0, reverse=True)
            for path in entries[:12]:
                if not os.path.exists(path):
                    continue
                name = os.path.basename(path)
                is_dir = os.path.isdir(path)
                try:
                    size_bytes = os.path.getsize(path) if not is_dir else 0
                except Exception:
                    size_bytes = 0

                size_str = "Folder" if is_dir else format_size(size_bytes)
                icon = get_icon(name, is_dir)

                items.append({
                    "name": name,
                    "path": path,
                    "isDir": is_dir,
                    "size": size_str,
                    "icon": icon
                })
    except Exception as e:
        sys.stderr.write(f"Error scanning downloads: {e}\n")

    return {
        "dir": dl_dir,
        "files": items
    }

if __name__ == '__main__':
    print(json.dumps(scan()))
