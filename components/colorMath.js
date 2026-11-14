.pragma library

// Colour maths kept free of Quickshell types so it can be tested with qmltestrunner (see tests/).

// `top` drawn over `bottom`, both translucent
function over(top, bottom) {
    let a = top.a + bottom.a * (1 - top.a);
    if (a <= 0) return Qt.rgba(0, 0, 0, 0);
    let mix = (t, b) => (t * top.a + b * bottom.a * (1 - top.a)) / a;
    return Qt.rgba(mix(top.r, bottom.r), mix(top.g, bottom.g), mix(top.b, bottom.b), a);
}
