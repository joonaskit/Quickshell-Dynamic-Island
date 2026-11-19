// How fast the shell animates, as a factor on every duration (Theme.duration): 1 as
// designed, 0 for no animation, 2 for twice as slow. It follows the compositor's own
// setting: KDE's Animation speed (System Settings, General Behavior) or niri's
// `animations` block.

// KDE keeps Animation speed as AnimationDurationFactor in the [KDE] group of kdeglobals.
// It is left out at the default speed; "Instant" writes 0.
function kdeFactor(text) {
    let group = "";
    let lines = (text || "").split("\n");
    for (let i = 0; i < lines.length; i++) {
        let line = lines[i].trim();
        let header = /^\[(.*)\]$/.exec(line);
        if (header) {
            group = header[1];
            continue;
        }
        if (group !== "KDE") continue;
        let entry = /^AnimationDurationFactor\s*=\s*(.*)$/.exec(line);
        if (entry) return clamp(parseFloat(entry[1]));
    }
    return 1;
}

// niri turns animations off with `off`, and slows them all with `slowdown <factor>`,
// both directly in the `animations` block of config.kdl. Blocks inside it set single
// animations and are skipped. Files the config includes are not read.
function niriFactor(text) {
    let source = stripComments(text || "");
    let start = /(^|[\s;}])animations\s*\{/.exec(source);
    if (!start) return 1;
    let depth = 1;
    let statement = "";
    let statements = [];
    for (let i = start.index + start[0].length; i < source.length && depth > 0; i++) {
        let c = source[i];
        if (c === "{") {
            depth++;
            statement = "";
        } else if (c === "}") {
            depth--;
            if (depth === 1) statement = "";
            else if (depth === 0 && statement.trim() !== "") statements.push(statement.trim());
        } else if (depth === 1 && (c === "\n" || c === ";")) {
            if (statement.trim() !== "") statements.push(statement.trim());
            statement = "";
        } else if (depth === 1) {
            statement += c;
        }
    }
    let factor = 1;
    for (let j = 0; j < statements.length; j++) {
        let words = statements[j].split(/\s+/);
        if (words[0] === "off" && words.length === 1) return 0;
        if (words[0] === "slowdown" && words.length === 2) factor = clamp(parseFloat(words[1]));
    }
    return factor;
}

// Drops // line comments, /* */ block comments and /- (a commented-out node, up to the
// end of its line or its block)
function stripComments(text) {
    let out = text.replace(/\/\*[\s\S]*?\*\//g, " ");
    out = out.replace(/\/\/[^\n]*/g, "");
    // A slashdash node with a block: drop it to its closing brace
    let result = "";
    for (let i = 0; i < out.length; i++) {
        if (out[i] === "/" && out[i + 1] === "-") {
            let j = i + 2;
            while (j < out.length && out[j] !== "\n" && out[j] !== "{" && out[j] !== ";") j++;
            if (out[j] === "{") {
                let depth = 1;
                j++;
                while (j < out.length && depth > 0) {
                    if (out[j] === "{") depth++;
                    else if (out[j] === "}") depth--;
                    j++;
                }
            }
            i = j - 1;
            continue;
        }
        result += out[i];
    }
    return result;
}

// Negative or unreadable values count as the default; very slow ones are capped
function clamp(value) {
    if (isNaN(value) || value < 0) return 1;
    return Math.min(value, 20);
}

// Milliseconds scaled by the factor, as a whole number
function scale(ms, factor) {
    return Math.round(ms * factor);
}
