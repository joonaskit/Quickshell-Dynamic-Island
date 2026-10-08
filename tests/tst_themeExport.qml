import QtQuick
import QtTest
import "../services/themeExport.js" as ThemeExport

TestCase {
    name: "ThemeExport"

    readonly property var input: ({
        "background": "#000000",
        "surface": "#1c1c1e",
        "surfaceRaised": "#2c2c2e",
        "textPrimary": "#ffffff",
        "textSecondary": "#98989d",
        "textTertiary": "#636366",
        "accent": "#bf5af2",
        "onAccent": "#ffffff",
        "accentGreen": "#30d158",
        "accentBlue": "#0a84ff",
        "accentOrange": "#ff9f0a",
        "accentYellow": "#ffd60a",
        "accentRed": "#ff453a",
        "accentPurple": "#bf5af2",
        "accentCyan": "#64d2ff",
        "accentIndigo": "#5e5ce6",
        "fontFamily": "Cantarell, Noto Sans, sans-serif",
        "fontDisplay": "Inter",
        "radiusSmall": 6,
        "radiusMedium": 10,
        "radiusLarge": 14,
        "uiScale": 1.05,
        "fontScale": 1.1
    })

    function test_versionAndScheme() {
        let theme = ThemeExport.build(input);
        compare(theme.version, 1);
        compare(theme.version, ThemeExport.formatVersion);
        compare(theme.scheme, "dark");
    }

    function test_scheme() {
        compare(ThemeExport.build(Object.assign({}, input, { "scheme": "light" })).scheme, "light");
        compare(ThemeExport.build(Object.assign({}, input, { "scheme": "dark" })).scheme, "dark");
        // Anything else, including a missing value, is exported as dark
        compare(ThemeExport.build(Object.assign({}, input, { "scheme": "sepia" })).scheme, "dark");
    }

    // The documented top-level layout; removing or renaming one of these
    // breaks readers and needs a version bump
    function test_topLevelKeys() {
        compare(Object.keys(ThemeExport.build(input)).sort(), ["colors", "fonts", "radius", "scale", "scheme", "version"]);
    }

    function test_surfaceAndTextColors() {
        let colors = ThemeExport.build(input).colors;
        compare(colors.background, "#000000");
        compare(colors.surface, "#1c1c1e");
        compare(colors.surfaceRaised, "#2c2c2e");
        compare(colors.textPrimary, "#ffffff");
        compare(colors.textSecondary, "#98989d");
        compare(colors.textTertiary, "#636366");
        compare(colors.onAccent, "#ffffff");
    }

    function test_semanticColorsMapToAccents() {
        let colors = ThemeExport.build(input).colors;
        // The accent is the user's choice, independent of the palette's blue
        compare(colors.accent, "#bf5af2");
        compare(colors.palette.blue, input.accentBlue);
        compare(colors.success, input.accentGreen);
        compare(colors.warning, input.accentOrange);
        compare(colors.danger, input.accentRed);
    }

    function test_palette() {
        compare(ThemeExport.build(input).colors.palette, {
            "green": "#30d158",
            "blue": "#0a84ff",
            "orange": "#ff9f0a",
            "yellow": "#ffd60a",
            "red": "#ff453a",
            "purple": "#bf5af2",
            "cyan": "#64d2ff",
            "indigo": "#5e5ce6"
        });
    }

    function test_everyColorIsSet() {
        let colors = ThemeExport.build(input).colors;
        let all = Object.assign({}, colors, colors.palette);
        delete all.palette;
        for (let key in all) {
            verify(/^#[0-9a-f]{6}$/.test(all[key]), key + " should be a #rrggbb color, got " + all[key]);
        }
    }

    function test_fontFamiliesAreSplitIntoLists() {
        let fonts = ThemeExport.build(input).fonts;
        compare(fonts.families, ["Cantarell", "Noto Sans", "sans-serif"]);
        compare(fonts.displayFamilies, ["Inter"]);
    }

    function test_fontFamiliesHandlesOddInput() {
        compare(ThemeExport.fontFamilies(""), []);
        compare(ThemeExport.fontFamilies(undefined), []);
        compare(ThemeExport.fontFamilies(" Inter ,, Noto Sans ,"), ["Inter", "Noto Sans"]);
    }

    function test_radiusAndScale() {
        let theme = ThemeExport.build(input);
        compare(theme.radius, { "small": 6, "medium": 10, "large": 14 });
        compare(theme.scale, { "ui": 1.05, "font": 1.1 });
    }
}
