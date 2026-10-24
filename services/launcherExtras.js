.pragma library

// Instant answers for the launcher's search box: a calculator, unit conversion
// and web search shortcuts. Pure functions, so tests/tst_launcherExtras.qml
// covers them. Nothing here uses eval: expressions go through a small parser.

var MAX_QUERY = 200;

// ----- Calculator -----

var CONSTANTS = { "pi": Math.PI, "e": Math.E, "tau": 2 * Math.PI };
var FUNCTIONS = {
    "sqrt": Math.sqrt, "cbrt": Math.cbrt, "abs": Math.abs,
    "sin": Math.sin, "cos": Math.cos, "tan": Math.tan,
    "asin": Math.asin, "acos": Math.acos, "atan": Math.atan,
    "ln": Math.log, "log": Math.log10, "log2": Math.log2, "exp": Math.exp,
    "round": Math.round, "floor": Math.floor, "ceil": Math.ceil
};

// Splits an expression into numbers, names and operators. Returns null for any other character.
function tokenize(text) {
    var tokens = [];
    var i = 0;
    while (i < text.length) {
        var c = text.charAt(i);
        if (c === " ") { i++; continue; }
        var m;
        if ((m = /^(\d+([.,]\d+)?|[.,]\d+)/.exec(text.slice(i)))) {
            tokens.push({ t: "num", v: parseFloat(m[0].replace(",", ".")) });
            i += m[0].length;
        } else if ((m = /^[a-z][a-z0-9]*/.exec(text.slice(i)))) {
            tokens.push({ t: "name", v: m[0] });
            i += m[0].length;
        } else if (text.substr(i, 2) === "**") {
            tokens.push({ t: "op", v: "^" });
            i += 2;
        } else if ("+-*/%^()×÷".indexOf(c) >= 0) {
            tokens.push({ t: "op", v: c === "×" ? "*" : (c === "÷" ? "/" : c) });
            i++;
        } else {
            return null;
        }
    }
    return tokens;
}

// Recursive descent: expr = term (+|- term)*, term = unary (*|/|% unary)*,
// unary = -unary | power, power = atom (^ unary)?, atom = number | name | name(expr) | (expr).
// `worked` is set once an operator or function was applied, so a bare number is not an answer.
function evaluate(text) {
    if (typeof text !== "string" || text.length === 0 || text.length > MAX_QUERY) return null;
    var tokens = tokenize(text.toLowerCase());
    if (!tokens || tokens.length === 0) return null;
    var pos = 0;
    var worked = false;

    function peek() { return pos < tokens.length ? tokens[pos] : null; }
    function isOp(v) { var t = peek(); return !!t && t.t === "op" && t.v === v; }

    function atom() {
        var t = peek();
        if (!t) throw "end";
        pos++;
        if (t.t === "num") return t.v;
        if (t.t === "name") {
            if (isOp("(")) {
                if (!FUNCTIONS.hasOwnProperty(t.v)) throw "function";
                pos++;
                var arg = expr();
                if (!isOp(")")) throw "paren";
                pos++;
                worked = true;
                return FUNCTIONS[t.v](arg);
            }
            if (CONSTANTS.hasOwnProperty(t.v)) return CONSTANTS[t.v];
            throw "name";
        }
        if (t.v === "(") {
            var inner = expr();
            if (!isOp(")")) throw "paren";
            pos++;
            return inner;
        }
        throw "token";
    }

    function power() {
        var base = atom();
        if (isOp("^")) {
            pos++;
            worked = true;
            return Math.pow(base, unary());
        }
        return base;
    }

    function unary() {
        if (isOp("-")) { pos++; return -unary(); }
        if (isOp("+")) { pos++; return unary(); }
        return power();
    }

    function term() {
        var left = unary();
        while (isOp("*") || isOp("/") || isOp("%")) {
            var op = tokens[pos++].v;
            var right = unary();
            worked = true;
            left = op === "*" ? left * right : (op === "/" ? left / right : left % right);
        }
        return left;
    }

    function expr() {
        var left = term();
        while (isOp("+") || isOp("-")) {
            var op = tokens[pos++].v;
            var right = term();
            worked = true;
            left = op === "+" ? left + right : left - right;
        }
        return left;
    }

    try {
        var value = expr();
        if (pos !== tokens.length || !worked || !isFinite(value)) return null;
        return value;
    } catch (e) {
        return null;
    }
}

// 10 significant digits, no trailing zeros, no exponent for ordinary sizes
function formatNumber(n) {
    if (!isFinite(n)) return "";
    if (n === 0) return "0";
    var abs = Math.abs(n);
    var s = (abs >= 1e15 || abs < 1e-9) ? n.toExponential(6) : String(parseFloat(n.toPrecision(10)));
    if (s.indexOf("e") >= 0) return s.replace(/\.?0+e/, "e");
    return s;
}

// ----- Unit conversion -----

// Each unit: [factor to the category's base unit, names it goes by]
var UNITS = {
    length: [
        [1, ["m", "meter", "meters", "metre", "metres"]],
        [1000, ["km", "kilometer", "kilometers", "kilometre", "kilometres"]],
        [0.01, ["cm", "centimeter", "centimeters", "centimetre", "centimetres"]],
        [0.001, ["mm", "millimeter", "millimeters", "millimetre", "millimetres"]],
        [1609.344, ["mi", "mile", "miles"]],
        [0.9144, ["yd", "yard", "yards"]],
        [0.3048, ["ft", "foot", "feet"]],
        [0.0254, ["in", "inch", "inches"]],
        [1852, ["nmi", "nauticalmile", "nauticalmiles"]]
    ],
    mass: [
        [1, ["kg", "kilogram", "kilograms", "kilo", "kilos"]],
        [0.001, ["g", "gram", "grams"]],
        [0.000001, ["mg", "milligram", "milligrams"]],
        [1000, ["t", "tonne", "tonnes"]],
        [0.45359237, ["lb", "lbs", "pound", "pounds"]],
        [0.028349523125, ["oz", "ounce", "ounces"]],
        [6.35029318, ["st", "stone"]]
    ],
    volume: [
        [1, ["l", "liter", "liters", "litre", "litres"]],
        [0.001, ["ml", "milliliter", "milliliters", "millilitre", "millilitres"]],
        [0.01, ["cl", "centiliter", "centiliters", "centilitre", "centilitres"]],
        [0.1, ["dl", "deciliter", "deciliters", "decilitre", "decilitres"]],
        [3.785411784, ["gal", "gallon", "gallons"]],
        [0.946352946, ["qt", "quart", "quarts"]],
        [0.473176473, ["pt", "pint", "pints"]],
        [0.2365882365, ["cup", "cups"]],
        [0.0295735295625, ["floz", "fluidounce", "fluidounces"]],
        [0.01478676478125, ["tbsp", "tablespoon", "tablespoons"]],
        [0.00492892159375, ["tsp", "teaspoon", "teaspoons"]]
    ],
    speed: [
        [1, ["m/s", "mps"]],
        [0.2777777778, ["km/h", "kph", "kmh"]],
        [0.44704, ["mph"]],
        [0.5144444444, ["kn", "kt", "knot", "knots"]]
    ],
    time: [
        [1, ["s", "sec", "second", "seconds"]],
        [0.001, ["ms", "millisecond", "milliseconds"]],
        [60, ["min", "minute", "minutes"]],
        [3600, ["h", "hr", "hour", "hours"]],
        [86400, ["d", "day", "days"]],
        [604800, ["wk", "week", "weeks"]]
    ],
    data: [
        [1, ["b", "byte", "bytes"]],
        [1000, ["kb", "kilobyte", "kilobytes"]],
        [1000000, ["mb", "megabyte", "megabytes"]],
        [1e9, ["gb", "gigabyte", "gigabytes"]],
        [1e12, ["tb", "terabyte", "terabytes"]],
        [1024, ["kib", "kibibyte", "kibibytes"]],
        [1048576, ["mib", "mebibyte", "mebibytes"]],
        [1073741824, ["gib", "gibibyte", "gibibytes"]],
        [1099511627776, ["tib", "tebibyte", "tebibytes"]]
    ],
    area: [
        [1, ["m2", "sqm"]],
        [1000000, ["km2", "sqkm"]],
        [10000, ["ha", "hectare", "hectares"]],
        [4046.8564224, ["acre", "acres"]],
        [0.09290304, ["ft2", "sqft"]],
        [2589988.110336, ["mi2", "sqmi"]]
    ]
};
var TEMPERATURES = {
    "c": "c", "celsius": "c", "°c": "c",
    "f": "f", "fahrenheit": "f", "°f": "f",
    "k": "k", "kelvin": "k"
};

var unitIndex = null;

function buildIndex() {
    unitIndex = {};
    for (var category in UNITS) {
        UNITS[category].forEach(function(entry) {
            entry[1].forEach(function(name) { unitIndex[name] = { category: category, factor: entry[0], label: entry[1][0] }; });
        });
    }
}

function lookupUnit(name) {
    if (!unitIndex) buildIndex();
    var key = name.toLowerCase();
    if (unitIndex.hasOwnProperty(key)) return unitIndex[key];
    if (TEMPERATURES.hasOwnProperty(key)) return { category: "temperature", id: TEMPERATURES[key], label: "°" + TEMPERATURES[key].toUpperCase() };
    return null;
}

function toCelsius(v, id) { return id === "c" ? v : (id === "f" ? (v - 32) * 5 / 9 : v - 273.15); }
function fromCelsius(v, id) { return id === "c" ? v : (id === "f" ? v * 9 / 5 + 32 : v + 273.15); }

// "5 km in mi" -> { value, from, to, text, copy }, or null
function convert(text) {
    if (typeof text !== "string" || text.length > MAX_QUERY) return null;
    var m = /^\s*(-?\d+(?:[.,]\d+)?)\s*([^\s\d][^\s]*)\s+(?:in|to|as|into)\s+([^\s]+)\s*$/i.exec(text);
    if (!m) return null;
    var amount = parseFloat(m[1].replace(",", "."));
    var from = lookupUnit(m[2]);
    var to = lookupUnit(m[3]);
    if (!from || !to || from.category !== to.category) return null;
    var result;
    if (from.category === "temperature") result = fromCelsius(toCelsius(amount, from.id), to.id);
    else result = amount * from.factor / to.factor;
    if (!isFinite(result)) return null;
    var shown = formatNumber(result);
    return { value: result, from: from.label, to: to.label, text: formatNumber(amount) + " " + from.label + " = " + shown + " " + to.label, copy: shown };
}

// ----- Web search shortcuts -----

var DEFAULT_SHORTCUTS = [
    { key: "g", name: "Google", url: "https://www.google.com/search?q=%s" },
    { key: "ddg", name: "DuckDuckGo", url: "https://duckduckgo.com/?q=%s" },
    { key: "w", name: "Wikipedia", url: "https://en.wikipedia.org/w/index.php?search=%s" },
    { key: "yt", name: "YouTube", url: "https://www.youtube.com/results?search_query=%s" }
];

function validUrl(url) {
    return typeof url === "string" && /^https?:\/\/[^\s]+$/i.test(url);
}

// "g some words" with a shortcut keyed "g" -> { name, url }, or null
function webSearch(text, shortcuts) {
    if (typeof text !== "string" || !Array.isArray(shortcuts)) return null;
    var m = /^\s*(\S+)\s+(\S.*?)\s*$/.exec(text);
    if (!m) return null;
    var key = m[1].toLowerCase();
    for (var i = 0; i < shortcuts.length; i++) {
        var s = shortcuts[i];
        if (!s || typeof s.key !== "string" || s.key.toLowerCase() !== key || !validUrl(s.url)) continue;
        var term = encodeURIComponent(m[2]);
        var url = s.url.indexOf("%s") >= 0 ? s.url.split("%s").join(term) : s.url + term;
        return { name: s.name || s.key, url: url, term: m[2] };
    }
    return null;
}

// One shortcut per line: "key | Name | https://example.com/search?q=%s".
// Lines that do not parse, or whose URL is not http(s), are dropped.
function parseShortcuts(text) {
    var out = [];
    var seen = {};
    String(text || "").split("\n").forEach(function(line) {
        var parts = line.split("|").map(function(p) { return p.trim(); });
        if (parts.length !== 3 || !/^[^\s|]+$/.test(parts[0]) || !validUrl(parts[2])) return;
        var key = parts[0].toLowerCase();
        if (seen[key]) return;
        seen[key] = true;
        out.push({ key: key, name: parts[1] || key, url: parts[2] });
    });
    return out;
}

function formatShortcuts(shortcuts) {
    return (shortcuts || []).map(function(s) { return s.key + " | " + s.name + " | " + s.url; }).join("\n");
}

// ----- File search -----

// "f report 2024" with the key "f" -> "report 2024", or null. A key alone is "" so that
// the launcher can show the file search is ready for its words.
function fileQuery(text, key) {
    if (typeof text !== "string" || typeof key !== "string" || key.length === 0 || text.length > MAX_QUERY) return null;
    var t = text.replace(/^\s+/, "");
    if (t.toLowerCase().indexOf(key.toLowerCase() + " ") !== 0) return null;
    return t.slice(key.length + 1).trim();
}

// One line of `filehouse --search` -> { path, name, folder, dir, type }, { done, more },
// { error }, or null for anything else
function parseFileLine(line) {
    var data;
    try { data = JSON.parse(line); } catch (e) { return null; }
    if (!data || typeof data !== "object") return null;
    if (typeof data.error === "string") return { error: data.error };
    if (data.done === true) return { done: true, more: !!data.more };
    if (typeof data.path !== "string" || data.path.length === 0) return null;
    return {
        path: data.path,
        name: typeof data.name === "string" && data.name ? data.name : data.path.split("/").pop(),
        folder: typeof data.folder === "string" ? data.folder : "",
        dir: !!data.dir,
        type: typeof data.type === "string" ? data.type : ""
    };
}

// The folder of a result as shown: the home folder as "~"
function shortFolder(folder, home) {
    if (!home || home.length < 2) return folder;
    if (folder === home) return "~";
    return folder.indexOf(home + "/") === 0 ? "~" + folder.slice(home.length) : folder;
}

// A path as a file:// URL, with every part encoded
function fileUrl(path) {
    return "file://" + path.split("/").map(encodeURIComponent).join("/");
}

// The icon theme's name for a result: "application/pdf" -> "application-pdf"
function fileIconName(result) {
    if (result.dir) return "folder";
    return result.type ? result.type.replace(/\//g, "-") : "text-x-generic";
}

// ----- System settings pages -----

// The pages of `pages` ({ name, comment, keywords }) that fit the typed text, best
// first, at most `limit`. Every word typed must be found in a page. A page ranks by
// where the first word hits: start of the name, start of a word in it, inside it,
// a keyword, then the description.
function matchSettingsPages(pages, text, limit) {
    if (typeof text !== "string" || !Array.isArray(pages)) return [];
    var words = text.trim().toLowerCase().split(/\s+/).filter(function(w) { return w.length > 0; });
    if (words.length === 0 || text.length > MAX_QUERY) return [];
    var scored = [];
    for (var i = 0; i < pages.length; i++) {
        var page = pages[i];
        var name = (page.name || "").toLowerCase();
        var keywords = (page.keywords || []).join(" ").toLowerCase();
        var comment = (page.comment || "").toLowerCase();
        var total = 0;
        var ok = true;
        for (var w = 0; w < words.length; w++) {
            var word = words[w];
            var at = name.indexOf(word);
            var rank;
            if (at === 0) rank = 0;
            else if (at > 0 && /[\s\-_\/]/.test(name.charAt(at - 1))) rank = 1;
            else if (at > 0) rank = 2;
            else if (keywords.indexOf(word) >= 0) rank = 3;
            else if (comment.indexOf(word) >= 0) rank = 4;
            else { ok = false; break; }
            total += rank;
        }
        if (ok) scored.push({ page: page, rank: total });
    }
    scored.sort(function(a, b) { return (a.rank - b.rank) || a.page.name.localeCompare(b.page.name); });
    return scored.slice(0, limit > 0 ? limit : 8).map(function(s) { return s.page; });
}

// ----- Together -----

// opts: { calculator, conversion, web, shortcuts }. The first extra that applies:
// { kind, title, subtitle, copy | url }, or null. Web shortcuts come first because
// the user typed their key on purpose.
function answer(text, opts) {
    if (typeof text !== "string" || text.trim().length === 0) return null;
    if (opts.web) {
        var found = webSearch(text, opts.shortcuts);
        if (found) return { kind: "web", title: "Search " + found.name + " for “" + found.term + "”", subtitle: "Press Enter to open in the browser", url: found.url };
    }
    if (opts.conversion) {
        var conv = convert(text);
        if (conv) return { kind: "convert", title: conv.text, subtitle: "Press Enter to copy " + conv.copy, copy: conv.copy };
    }
    if (opts.calculator) {
        var value = evaluate(text);
        if (value !== null) {
            var shown = formatNumber(value);
            return { kind: "calc", title: "= " + shown, subtitle: "Press Enter to copy the result", copy: shown };
        }
    }
    return null;
}
