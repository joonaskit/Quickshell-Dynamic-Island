.pragma library

// Builds the theme document the shell writes for companion apps
// (docs/THEME.md). Kept free of Quickshell types so it can be tested with
// qmltestrunner (see tests/).

// Bump when a field is removed or changes meaning. Adding fields does not
// need a bump; readers must ignore fields they do not know.
const formatVersion = 1;

// "Cantarell, Noto Sans, sans-serif" -> ["Cantarell", "Noto Sans", "sans-serif"]
function fontFamilies(fontFamily) {
    return (fontFamily || "").split(",").map(f => f.trim()).filter(f => f.length > 0);
}

// `t` holds the shell's theme values as plain strings and numbers; see
// ThemeExportService for the mapping from Theme.qml.
function build(t) {
    return {
        "version": formatVersion,
        "scheme": "dark",
        "colors": {
            "background": t.background,
            "surface": t.surface,
            "surfaceRaised": t.surfaceRaised,
            "textPrimary": t.textPrimary,
            "textSecondary": t.textSecondary,
            "textTertiary": t.textTertiary,
            "onAccent": t.onAccent,
            "accent": t.accent,
            "success": t.accentGreen,
            "warning": t.accentOrange,
            "danger": t.accentRed,
            "palette": {
                "green": t.accentGreen,
                "blue": t.accentBlue,
                "orange": t.accentOrange,
                "yellow": t.accentYellow,
                "red": t.accentRed,
                "purple": t.accentPurple,
                "cyan": t.accentCyan,
                "indigo": t.accentIndigo
            }
        },
        "fonts": {
            "families": fontFamilies(t.fontFamily),
            "displayFamilies": fontFamilies(t.fontDisplay)
        },
        "radius": {
            "small": t.radiusSmall,
            "medium": t.radiusMedium,
            "large": t.radiusLarge
        },
        "scale": {
            "ui": t.uiScale,
            "font": t.fontScale
        }
    };
}
