.pragma library

// How long to wait before starting a helper again. Kept free of Quickshell types so it can
// be tested with qmltestrunner (see tests/).

// A helper that ran for less than this died right away, for example without python-dbus
var QUICK_EXIT_MS = 5000;
var MAX_DOUBLINGS = 5;
var MAX_DELAY_MS = 30000;

// The new count of exits in a row that came right after a start
function countQuickExits(quickExits, ranMs) {
    return ranMs < QUICK_EXIT_MS ? quickExits + 1 : 0;
}

// Doubles for each quick exit, so a helper that keeps dying is not started over and over
function delay(baseMs, quickExits) {
    return Math.min(MAX_DELAY_MS, baseMs * Math.pow(2, Math.min(quickExits, MAX_DOUBLINGS)));
}
