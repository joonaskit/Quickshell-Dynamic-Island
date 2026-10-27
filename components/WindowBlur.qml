import ".."
import QtQuick

// Blurs the desktop behind some items of a window: the frosted half of the glass look
// (Theme.glass). It uses Quickshell's BackgroundEffect, which came with Quickshell 0.3,
// and does nothing on older versions (Theme.blurAvailable false). The effect is
// compiled at runtime so the shell still loads, and lints, without the type.
QtObject {
    id: root

    // The window to blur behind
    property QtObject target: null
    // What to blur behind. Each entry is an item, which lends its own corner radii
    // (a Rectangle), or { item, topLeftRadius, topRightRadius, bottomLeftRadius,
    // bottomRightRadius } for an item without them. A null item drops out, and so does
    // one that is hidden or faded out, itself or through a parent.
    // Set once: the region is built for this many entries.
    property var items: []
    property bool active: Theme.glass && Theme.blurAvailable

    property QtObject effect: null

    function regionSource(index) {
        let corner = name => name + ': blur.radius(' + index + ', "' + name + '"); ';
        return 'Region { ' + corner("topLeftRadius") + corner("topRightRadius")
            + corner("bottomLeftRadius") + corner("bottomRightRadius") + '}';
    }

    // A Region that follows an item only updates when the item's own geometry changes,
    // not when a parent moves it or a transform slides it. So each region is a plain
    // rectangle instead, placed where the item is drawn after every frame that animates.
    // It is assigned only when it moved, since each change asks for another frame.
    function createEffect() {
        if (root.effect || !root.active || !root.target) return;
        let regions = [];
        for (let i = 0; i < root.items.length; i++) regions.push(regionSource(i));
        try {
            root.effect = Qt.createQmlObject(
                'import QtQuick; import Quickshell; import Quickshell.Wayland; QtObject { id: blur; '
                + 'property QtObject target: null; property var items: []; property bool active: false; '
                + 'readonly property var frameWindow: blur.target && blur.target.contentItem ? blur.target.contentItem.Window.window : null; '
                + 'property Region region: Region { ' + regions.join(' ') + ' } '
                + 'property Connections frames: Connections { target: blur.active ? blur.frameWindow : null; function onAfterAnimating() { blur.sync(); } } '
                + 'function entryItem(entry) { return !entry ? null : (entry.visible !== undefined ? entry : (entry.item ?? null)); } '
                + 'function shown(item) { for (let p = item; p; p = p.parent) { if (!p.visible || p.opacity < 0.02) return false; } return true; } '
                + 'function radius(index, corner) { let entry = blur.items[index]; return entry && entry[corner] !== undefined ? entry[corner] : 0; } '
                + 'function sync() { '
                + '  for (let i = 0; i < blur.region.regions.length; i++) { '
                + '    let r = blur.region.regions[i]; let item = blur.entryItem(blur.items[i]); '
                + '    let x = 0, y = 0, w = 0, h = 0; '
                + '    if (item && item.width > 0 && item.height > 0 && blur.shown(item)) { '
                + '      let a = item.mapToItem(null, 0, 0); let b = item.mapToItem(null, item.width, item.height); '
                + '      x = Math.floor(Math.min(a.x, b.x)); y = Math.floor(Math.min(a.y, b.y)); '
                + '      w = Math.ceil(Math.max(a.x, b.x)) - x; h = Math.ceil(Math.max(a.y, b.y)) - y; '
                + '    } '
                + '    if (r.x !== x) r.x = x; if (r.y !== y) r.y = y; if (r.width !== w) r.width = w; if (r.height !== h) r.height = h; '
                + '  } '
                + '} '
                + 'function apply() { blur.sync(); if (blur.target) blur.target.BackgroundEffect.blurRegion = blur.active ? blur.region : null; } '
                + 'onActiveChanged: apply(); onTargetChanged: apply(); onItemsChanged: sync() }',
                root, "WindowBlur");
        } catch (e) {
            console.warn("WindowBlur: could not create the blur:", e);
            return;
        }
        root.effect.items = Qt.binding(() => root.items);
        root.effect.target = root.target;
        root.effect.active = Qt.binding(() => root.active);
    }

    onActiveChanged: createEffect()
    onTargetChanged: createEffect()
    Component.onCompleted: createEffect()
}
