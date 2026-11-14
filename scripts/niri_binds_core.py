"""Reads and edits the binds block of niri's config.kdl, with no file or process access.

niri_binds.py does the reading, validating and writing; this module only works on text,
so tests/test_niri_binds_core.py can run it. Edits are made in place on the original
text: changing a key rewrites only the key, removing a bind drops only its line, and a
new bind goes on its own line before the block's closing brace. Comments, spacing and
bind properties (repeat=false, allow-when-locked=true, ...) stay as they were.

Each row of the page is an action, which may have several keys. Its id is the action
written canonically (`focus-workspace 1`, `spawn "konsole"`), or `shell:<id>` for one
of this shell's IPC commands, which may be spelled several ways in the config.
"""
import json
import re
import shlex

import shortcuts

GROUPS = ["Shell", "Apps", "Windows", "Layout", "Workspaces", "Monitors", "System"]

# Shell IPC commands, as in shortcuts.py, plus the dial, which KDE opens from its own key
SHELL_ACTIONS = shortcuts.ACTIONS + [
    ("dial.toggle", "Launcher", "Toggle the dial", "dial", "toggle", ()),
]
SHELL_BY_COMMAND = {(a[3], a[4], *a[5]): a for a in SHELL_ACTIONS}


def _directions(template, title, names):
    return [(template % n, title % n.replace("-", " ")) for n in names]


# (action, title) per group: listed even while unbound, so they can be given a key
CATALOGUE = {
    "Windows": [
        ("close-window", "Close window"),
        *_directions("focus-column-%s", "Focus column %s", ("left", "right", "first", "last")),
        *_directions("focus-window-%s", "Focus window %s", ("up", "down", "previous")),
        *_directions("move-column-%s", "Move column %s", ("left", "right")),
        *_directions("move-column-to-%s", "Move column to %s", ("first", "last")),
        *_directions("move-window-%s", "Move window %s", ("up", "down")),
        ("consume-or-expel-window-left", "Consume or expel window left"),
        ("consume-or-expel-window-right", "Consume or expel window right"),
        ("consume-window-into-column", "Consume window into column"),
        ("expel-window-from-column", "Expel window from column"),
        ("toggle-window-floating", "Toggle floating"),
        ("switch-focus-between-floating-and-tiling", "Switch focus between floating and tiling"),
        ("fullscreen-window", "Fullscreen window"),
        ("toggle-windowed-fullscreen", "Toggle windowed fullscreen"),
    ],
    "Layout": [
        ("maximize-column", "Maximize column"),
        ("maximize-window-to-edges", "Maximize window to edges"),
        ("expand-column-to-available-width", "Expand column to available width"),
        ("center-column", "Center column"),
        ("center-visible-columns", "Center visible columns"),
        ("switch-preset-column-width", "Next preset column width"),
        ("switch-preset-column-width-back", "Previous preset column width"),
        ("switch-preset-window-height", "Next preset window height"),
        ("reset-window-height", "Reset window height"),
        ('set-column-width "-10%"', "Narrower column"),
        ('set-column-width "+10%"', "Wider column"),
        ('set-window-height "-10%"', "Shorter window"),
        ('set-window-height "+10%"', "Taller window"),
        ("toggle-column-tabbed-display", "Toggle tabbed column"),
    ],
    "Workspaces": [
        *_directions("focus-workspace-%s", "Focus workspace %s", ("up", "down", "previous")),
        *_directions("move-column-to-workspace-%s", "Move column to workspace %s", ("up", "down")),
        *_directions("move-window-to-workspace-%s", "Move window to workspace %s", ("up", "down")),
        *_directions("move-workspace-%s", "Move workspace %s", ("up", "down")),
        *[("focus-workspace %d" % n, "Focus workspace %d" % n) for n in range(1, 10)],
        *[("move-column-to-workspace %d" % n, "Move column to workspace %d" % n) for n in range(1, 10)],
    ],
    "Monitors": [
        *_directions("focus-monitor-%s", "Focus monitor %s", ("left", "right", "up", "down")),
        *_directions("move-column-to-monitor-%s", "Move column to monitor %s", ("left", "right", "up", "down")),
        *_directions("move-workspace-to-monitor-%s", "Move workspace to monitor %s", ("left", "right")),
    ],
    "System": [
        ("toggle-overview", "Toggle overview"),
        ("show-hotkey-overlay", "Show hotkey overlay"),
        ("screenshot", "Screenshot"),
        ("screenshot-screen", "Screenshot screen"),
        ("screenshot-window", "Screenshot window"),
        ('switch-layout "next"', "Next keyboard layout"),
        ('switch-layout "prev"', "Previous keyboard layout"),
        ("toggle-keyboard-shortcuts-inhibit", "Toggle shortcut inhibit"),
        ("power-off-monitors", "Power off monitors"),
        ("quit", "Quit niri"),
    ],
}
CATALOGUE_BY_ACTION = {a: (g, t) for g, rows in CATALOGUE.items() for a, t in rows}

# Modifier spellings niri accepts, by what they mean. Mod is Super in a real session.
MODIFIERS = {
    "mod": "super", "super": "super", "win": "super",
    "ctrl": "ctrl", "control": "ctrl",
    "alt": "alt", "shift": "shift",
    "iso_level3_shift": "level3", "mod5": "level3",
    "iso_level5_shift": "level5",
}

BARE_KEY = re.compile(r"^[A-Za-z0-9_+\-.]+$")
STRING_START = re.compile(r'(r?#*)"')


# --- Tokens ----------------------------------------------------------------

class Token:
    __slots__ = ("kind", "text", "value", "start", "end")

    def __init__(self, kind, text, value, start, end):
        self.kind = kind    # word, string, open, close, semi, eq, newline, slashdash
        self.text = text    # as written
        self.value = value  # unescaped, for strings
        self.start = start
        self.end = end


ESCAPES = {"n": "\n", "r": "\r", "t": "\t", "\\": "\\", '"': '"', "/": "/", "b": "\b", "f": "\f", "s": " "}
WORD_STOP = set(' \t\r\n{}();="\\')


def _unescape(body):
    out = []
    i = 0
    while i < len(body):
        c = body[i]
        if c == "\\" and i + 1 < len(body):
            n = body[i + 1]
            if n == "u" and body[i + 2:i + 3] == "{":
                close = body.find("}", i)
                out.append(chr(int(body[i + 3:close], 16)))
                i = close + 1
                continue
            out.append(ESCAPES.get(n, n))
            i += 2
            continue
        out.append(c)
        i += 1
    return "".join(out)


def tokenize(text):
    """KDL tokens of the text, with comments dropped. Raises ValueError on an unclosed string."""
    tokens = []
    i = 0
    n = len(text)
    while i < n:
        c = text[i]
        if c == "\n":
            tokens.append(Token("newline", c, c, i, i + 1))
            i += 1
        elif c in " \t\r﻿":
            i += 1
        elif text.startswith("//", i):
            end = text.find("\n", i)
            i = n if end < 0 else end
        elif text.startswith("/*", i):
            depth = 0
            while i < n:
                if text.startswith("/*", i):
                    depth += 1
                    i += 2
                elif text.startswith("*/", i):
                    depth -= 1
                    i += 2
                    if depth == 0:
                        break
                else:
                    i += 1
        elif text.startswith("/-", i):
            tokens.append(Token("slashdash", "/-", "/-", i, i + 2))
            i += 2
        elif c == "\\":
            # Line continuation: the newline after it does not end the node
            end = text.find("\n", i)
            i = n if end < 0 else end + 1
        elif c == '"' or (c in "r#" and STRING_START.match(text, i)):
            prefix = STRING_START.match(text, i).group(1)
            hashes = prefix.count("#")
            raw = prefix.startswith("r") or hashes > 0
            j = i + len(prefix) + 1
            if raw:
                close = '"' + "#" * hashes
                end = text.find(close, j)
                if end < 0:
                    raise ValueError("unclosed string")
                value = text[j:end]
                end += len(close)
            else:
                k = j
                while k < n and text[k] != '"':
                    k += 2 if text[k] == "\\" else 1
                if k >= n:
                    raise ValueError("unclosed string")
                value = _unescape(text[j:k])
                end = k + 1
            tokens.append(Token("string", text[i:end], value, i, end))
            i = end
        elif c == "{":
            tokens.append(Token("open", c, c, i, i + 1))
            i += 1
        elif c == "}":
            tokens.append(Token("close", c, c, i, i + 1))
            i += 1
        elif c == ";":
            tokens.append(Token("semi", c, c, i, i + 1))
            i += 1
        elif c == "=":
            tokens.append(Token("eq", c, c, i, i + 1))
            i += 1
        elif c == "(":
            # Type annotation such as (u8): not used by niri's binds, skipped
            end = text.find(")", i)
            i = n if end < 0 else end + 1
        else:
            j = i
            while j < n and text[j] not in WORD_STOP and not text.startswith("//", j) and not text.startswith("/*", j):
                j += 1
            tokens.append(Token("word", text[i:j], text[i:j], i, j))
            i = j
    return tokens


# --- Nodes -----------------------------------------------------------------

class Node:
    def __init__(self, name):
        self.name = name        # Token
        self.args = []          # Tokens
        self.props = []         # (key Token, value Token)
        self.children = []      # Nodes
        self.skipped = False    # commented out with /-
        self.start = name.start
        self.end = name.end
        self.close = None       # offset of the children's closing brace


def parse_nodes(tokens, pos=0, nested=False):
    """Nodes from tokens[pos:], up to the closing brace when nested. Returns (nodes, pos)."""
    nodes = []
    skip_next = False
    while pos < len(tokens):
        tok = tokens[pos]
        if tok.kind in ("newline", "semi"):
            pos += 1
            continue
        if tok.kind == "close":
            if nested:
                return nodes, pos
            pos += 1
            continue
        if tok.kind == "slashdash":
            skip_next = True
            pos += 1
            continue
        if tok.kind not in ("word", "string"):
            pos += 1
            continue
        node = Node(tok)
        node.skipped = skip_next
        skip_next = False
        pos += 1
        skip_entry = False
        while pos < len(tokens):
            tok = tokens[pos]
            if tok.kind in ("newline", "semi"):
                break
            if tok.kind == "close":
                break
            if tok.kind == "slashdash":
                skip_entry = True
                pos += 1
                continue
            if tok.kind == "open":
                children, pos = parse_nodes(tokens, pos + 1, nested=True)
                if skip_entry:
                    skip_entry = False
                else:
                    node.children = children
                if pos < len(tokens):
                    node.close = tokens[pos].start
                    node.end = tokens[pos].end
                    pos += 1
                continue
            if tok.kind in ("word", "string"):
                if pos + 2 < len(tokens) and tokens[pos + 1].kind == "eq":
                    if not skip_entry:
                        node.props.append((tok, tokens[pos + 2]))
                    node.end = tokens[pos + 2].end
                    pos += 3
                else:
                    if not skip_entry:
                        node.args.append(tok)
                    node.end = tok.end
                    pos += 1
                skip_entry = False
                continue
            pos += 1
        nodes.append(node)
    return nodes, pos


def value_text(tok):
    """A value written back canonically: strings quoted, everything else as written."""
    if tok.kind == "string":
        return json.dumps(tok.value, ensure_ascii=False)
    return tok.text


def action_text(node):
    """The action of a bind's child node, written canonically."""
    parts = [node.name.value]
    parts += [value_text(a) for a in node.args]
    parts += [k.value + "=" + value_text(v) for k, v in node.props]
    return " ".join(parts)


def humanize(action):
    return action[:1].upper() + action[1:].replace("-", " ")


class Bind:
    def __init__(self, node, action_node):
        self.node = node
        self.key = node.name.value
        self.action_node = action_node
        self.action = action_text(action_node)
        self.props = {k.value: v for k, v in node.props}


def find_binds(text):
    """(blocks, binds): the top-level binds nodes and the binds inside them, in order."""
    nodes, _ = parse_nodes(tokenize(text))
    blocks = [n for n in nodes if n.name.value == "binds" and not n.skipped and n.close is not None]
    binds = []
    for block in blocks:
        for child in block.children:
            if child.skipped:
                continue
            actions = [c for c in child.children if not c.skipped]
            if actions:
                binds.append(Bind(child, actions[0]))
    return blocks, binds


# --- Keys ------------------------------------------------------------------

def normalize_key(key):
    """A key as niri compares it: modifiers as a set, the key name ignoring case."""
    parts = key.split("+")
    name = parts[-1].lower()
    mods = frozenset(MODIFIERS.get(p.lower(), p.lower()) for p in parts[:-1])
    return mods, name


def key_literal(key):
    return key if BARE_KEY.match(key) else json.dumps(key)


# --- Actions ---------------------------------------------------------------

def shell_command(args):
    """The IPC command a spawn of this shell runs, (target, function, *args), or None."""
    line = " ".join(shlex.quote(a) for a in args)
    if len(args) == 1:  # spawn-sh "..." or a single word
        line = args[0]
    if not shortcuts.runs_this_shell(line):
        return None
    return shortcuts.parse_exec(line)


def classify(bind, shell_dir):
    """(id, group, title, detail) for a bind found in the config."""
    node = bind.action_node
    name = node.name.value
    if name in ("spawn", "spawn-sh"):
        args = [a.value for a in node.args]
        command = shell_command(args)
        if command in SHELL_BY_COMMAND:
            action = SHELL_BY_COMMAND[command]
            return "shell:" + action[0], "Shell", action[2], " ".join(command)
        detail = args[0] if name == "spawn-sh" and args else " ".join(shlex.quote(a) for a in args)
        title_tok = bind.props.get("hotkey-overlay-title")
        if title_tok is not None and title_tok.kind == "string" and title_tok.value:
            return bind.action, "Apps", title_tok.value, detail
        return bind.action, "Apps", detail, ""
    if bind.action in CATALOGUE_BY_ACTION:
        group, title = CATALOGUE_BY_ACTION[bind.action]
        return bind.action, group, title, bind.action
    if "monitor" in name:
        group = "Monitors"
    elif "workspace" in name:
        group = "Workspaces"
    elif "window" in name or "column" in name:
        group = "Windows"
    else:
        group = "System"
    return bind.action, group, humanize(bind.action), bind.action


def list_actions(text, shell_dir):
    """Rows for the page: {"groups": [{"name", "actions": [{id, title, detail, keys}]}]}.

    Catalogue actions come first in each group, bound or not, then the config's other
    binds in the order they are written."""
    _blocks, binds = find_binds(text)
    rows = {}
    order = {g: [] for g in GROUPS}

    def row(action_id, group, title, detail):
        if action_id not in rows:
            rows[action_id] = {"id": action_id, "title": title, "detail": detail, "keys": []}
            order[group].append(action_id)
        return rows[action_id]

    for a in SHELL_ACTIONS:
        row("shell:" + a[0], "Shell", a[2], " ".join((a[3], a[4], *a[5])))
    for group, entries in CATALOGUE.items():
        for action, title in entries:
            row(action, group, title, action)
    for bind in binds:
        row(*classify(bind, shell_dir))["keys"].append(bind.key)
    return {"groups": [{"name": g, "actions": [rows[i] for i in order[g]]} for g in GROUPS]}


def new_action_text(action_id, shell_dir):
    """What to write for an action that has no bind yet, or None if it is unknown."""
    if action_id.startswith("shell:"):
        for a in SHELL_ACTIONS:
            if "shell:" + a[0] == action_id:
                words = ["quickshell", "ipc", "-p", shell_dir, "call", a[3], a[4], *a[5]]
                return "spawn " + " ".join(json.dumps(w, ensure_ascii=False) for w in words)
        return None
    return action_id if action_id in CATALOGUE_BY_ACTION else None


class EditError(Exception):
    def __init__(self, message, conflict=None):
        super().__init__(message)
        self.conflict = conflict


def _line_bounds(text, start, end):
    """The span to delete for a node: its whole lines when nothing else is on them."""
    line_start = text.rfind("\n", 0, start) + 1
    line_end = text.find("\n", end)
    line_end = len(text) if line_end < 0 else line_end
    before = text[line_start:start]
    after = text[end:line_end].strip()
    if before.strip() == "" and (after == "" or after.startswith("//") or after == ";"):
        return line_start, min(len(text), line_end + 1)
    return start, end


def _bind_id(bind, shell_dir):
    return classify(bind, shell_dir)[0]


def remove_key(text, action_id, key, shell_dir):
    """The text without the bind of `key` for this action."""
    _blocks, binds = find_binds(text)
    target = normalize_key(key)
    for bind in binds:
        if normalize_key(bind.key) == target and _bind_id(bind, shell_dir) == action_id:
            start, end = _line_bounds(text, bind.node.start, bind.node.end)
            return text[:start] + text[end:]
    raise EditError("%s is no longer bound to this action" % key)


def set_key(text, action_id, old_key, new_key, shell_dir, force=False):
    """The text with `new_key` bound to the action, in place of `old_key` when given.

    Raises EditError with a conflict ({id, key, title}) when another action has the key,
    unless `force`, which first removes that other bind."""
    if not new_key or new_key.endswith("+") or " " in new_key:
        raise EditError("Not a key niri can bind: %r" % new_key)
    _blocks, binds = find_binds(text)
    wanted = normalize_key(new_key)
    old = normalize_key(old_key) if old_key else None

    for bind in binds:
        if normalize_key(bind.key) != wanted:
            continue
        bind_id, _group, title, _detail = classify(bind, shell_dir)
        if bind_id == action_id:
            if old is not None and old != wanted:
                # Already has the new key: dropping the old one is all that is left
                return remove_key(text, action_id, old_key, shell_dir)
            return text
        if not force:
            raise EditError("%s is already used by %s" % (bind.key, title),
                            {"id": bind_id, "key": bind.key, "title": title})
        start, end = _line_bounds(text, bind.node.start, bind.node.end)
        text = text[:start] + text[end:]
        return set_key(text, action_id, old_key, new_key, shell_dir)

    own = [b for b in binds if _bind_id(b, shell_dir) == action_id]
    if old is not None:
        for bind in own:
            if normalize_key(bind.key) == old:
                name = bind.node.name
                return text[:name.start] + key_literal(new_key) + text[name.end:]
        raise EditError("%s is no longer bound to this action" % old_key)

    if own:
        first = own[0]
        props = [k.text + "=" + v.text for k, v in first.node.props if k.value != "hotkey-overlay-title"]
        body = text[first.action_node.start:first.action_node.end]
    else:
        body = new_action_text(action_id, shell_dir)
        if body is None:
            raise EditError("Unknown action: %s" % action_id)
        props = ["repeat=false"] if action_id.startswith("shell:") else []
    line = " ".join([key_literal(new_key), *props, "{", body.rstrip(";") + ";", "}"])
    if own:
        # Beside the action's other keys, on the line after the last of them
        node = own[-1].node
        line_start = text.rfind("\n", 0, node.start) + 1
        indent = text[line_start:node.start]
        line_end = text.find("\n", node.end)
        if indent.strip() == "" and line_end >= 0:
            return text[:line_end + 1] + indent + line + "\n" + text[line_end + 1:]
    return _insert_bind(text, line)


def _insert_bind(text, line):
    """The text with the line added at the end of the last binds block, or a new block."""
    blocks, binds = find_binds(text)
    if not blocks:
        sep = "" if text.endswith("\n") or text == "" else "\n"
        return text + sep + "\nbinds {\n    " + line + "\n}\n"
    block = blocks[-1]
    indent = "    "
    inside = [b for b in binds if block.start < b.node.start < block.close]
    if inside:
        last = inside[-1].node.start
        line_start = text.rfind("\n", 0, last) + 1
        indent = text[line_start:last] if text[line_start:last].strip() == "" else indent
    close_line = text.rfind("\n", 0, block.close) + 1
    if text[close_line:block.close].strip() == "":
        return text[:close_line] + indent + line + "\n" + text[close_line:]
    return text[:block.close] + "\n" + indent + line + "\n" + text[block.close:]


def validate_error(stderr):
    """The reason in `niri validate`'s report, such as "invalid key: Bogus123"."""
    clean = re.sub(r"\x1b\[[0-9;]*m", "", stderr)
    reasons = re.findall(r"[╰├]─▶\s*(.+)", clean)
    if reasons:
        return reasons[-1].strip()
    heads = re.findall(r"×\s*(.+)", clean)
    if heads:
        return heads[-1].strip()
    lines = [ln.strip() for ln in clean.splitlines() if ln.strip()]
    return lines[-1] if lines else "niri rejected the change"
