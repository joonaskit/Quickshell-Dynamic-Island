"""Whether niri blurs the shell's surfaces, read from niri's config text, with no file
or process access (niri_blur.py reads the files). tests/test_niri_blur_core.py runs it.

niri 26.04 blurs a layer surface that asks for it through ext-background-effect, which
the shell's glass style does, unless the config turns blur off (`blur { off }`) or a
layer-rule matching the surface sets `background-effect { blur false; }`. Blur shows
only the wallpaper (xray) unless a rule sets `xray false`. Later rules win, as in niri.
"""
import re

import niri_binds_core as kdl

# The layer-shell namespaces of the shell's windows (WlrLayershell.namespace)
NAMESPACES = [
    "quickshell-island", "quickshell-dock", "quickshell-spotlight", "quickshell-dial",
    "quickshell-clipboard", "quickshell-settings", "quickshell-onboarding",
]

# Blurs the windows behind the shell too, not only the wallpaper (costs more GPU)
SUGGESTED_RULE = """layer-rule {
    match namespace="^quickshell-"
    background-effect {
        xray false
    }
}"""


def _bool(node, default=True):
    """A flag's value: `blur` alone is true, `blur false` and `blur #false` are false."""
    if not node.args:
        return default
    return node.args[0].text.lstrip("#") != "false"


def _live(nodes):
    return [n for n in nodes if not n.skipped]


def _matcher_holds(node, namespace, layer):
    """Every property of one match or exclude line holds for the surface."""
    props = {k.value: v for k, v in node.props}
    if not props:
        return False
    for key, tok in props.items():
        if key == "namespace":
            try:
                if not re.search(tok.value if tok.kind == "string" else tok.text, namespace):
                    return False
            except re.error:
                return False
        elif key == "layer":
            if (tok.value if tok.kind == "string" else tok.text) != layer:
                return False
        else:
            # at-startup and matchers this does not know: assume they do not hold
            return False
    return True


def rule_applies(rule, namespace, layer="top"):
    """As niri: any match line holds (or there is none) and no exclude line holds."""
    children = _live(rule.children)
    matches = [c for c in children if c.name.value == "match"]
    excludes = [c for c in children if c.name.value == "exclude"]
    if matches and not any(_matcher_holds(m, namespace, layer) for m in matches):
        return False
    return not any(_matcher_holds(e, namespace, layer) for e in excludes)


def analyze(texts):
    """texts: the config file, then the files it includes (niri reads an include in place;
    rules and blur blocks seldom depend on that).
    Returns {enabled, blurred: [ns], blockedBy: [ns], xrayOff: [ns], suggestedRule}."""
    enabled = True
    rules = []
    for text in texts:
        nodes, _ = kdl.parse_nodes(kdl.tokenize(text))
        for node in _live(nodes):
            name = node.name.value
            if name == "blur":
                enabled = not any(c.name.value == "off" for c in _live(node.children))
            elif name == "layer-rule":
                rules.append(node)

    blurred, blocked, xray_off = [], [], []
    for ns in NAMESPACES:
        blur = None
        xray = None
        for rule in rules:
            if not rule_applies(rule, ns):
                continue
            for effect in _live(rule.children):
                if effect.name.value != "background-effect":
                    continue
                for prop in _live(effect.children):
                    if prop.name.value == "blur":
                        blur = _bool(prop)
                    elif prop.name.value == "xray":
                        xray = _bool(prop)
        if blur is False:
            blocked.append(ns)
        elif enabled:
            blurred.append(ns)
        if xray is False:
            xray_off.append(ns)
    return {
        "enabled": enabled,
        "blurred": blurred,
        "blockedBy": blocked,
        "xrayOff": xray_off,
        "suggestedRule": SUGGESTED_RULE,
    }


def includes(text):
    """The paths a config includes, as written, in order."""
    nodes, _ = kdl.parse_nodes(kdl.tokenize(text))
    return [n.args[0].value for n in _live(nodes)
            if n.name.value == "include" and n.args and n.args[0].kind == "string"]
