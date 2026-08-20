pragma Singleton

import QtQuick
import Quickshell

// Layout-independent keyboard matching.
//
// THE PROBLEM. `event.key` and `event.text` carry the SYMBOL the layout
// produces, not the key that was pressed. Every vi-style binding in this shell
// (j/k to move, x to delete, g/G to jump, hjkl to nudge) therefore worked only
// on a Latin layout: with a Cyrillic layout active, pressing the physical J key
// delivers Qt.Key_O and text "о", and the handler simply never fires. The
// notification centre was the visible case — its navigation died the moment the
// layout switched.
//
// THE FIX. Match on the physical key position instead. Qt on Wayland exposes it
// as `event.nativeScanCode`, which is the XKB keycode — evdev code + 8 — and is
// identical on every layout. `key(event)` maps that back to the Qt.Key_* the
// binding was written against, so call sites keep reading naturally:
//
//     Keys.onPressed: (event) => {
//         switch (Keycodes.key(event)) {          // NOT event.key
//             case Qt.Key_J: moveDown(); break
//         }
//     }
//
// Non-letter, non-digit keys (Escape, arrows, Return, Delete, F1…) are already
// layout-independent in `event.key`, so they fall through untouched and need no
// entry here.
//
// WHY THIS LIVES IN core/config. It is a constant table with zero dependencies,
// the same shape as Tokens, and this is the only layer every other layer is
// allowed to import (ui → config is legal, ui → services is not).
Singleton {
    id: root

    // XKB keycode (evdev + 8) → Qt.Key_*. Rows as they sit on the keyboard.
    readonly property var _scanToKey: ({
        24: Qt.Key_Q, 25: Qt.Key_W, 26: Qt.Key_E, 27: Qt.Key_R, 28: Qt.Key_T,
        29: Qt.Key_Y, 30: Qt.Key_U, 31: Qt.Key_I, 32: Qt.Key_O, 33: Qt.Key_P,

        38: Qt.Key_A, 39: Qt.Key_S, 40: Qt.Key_D, 41: Qt.Key_F, 42: Qt.Key_G,
        43: Qt.Key_H, 44: Qt.Key_J, 45: Qt.Key_K, 46: Qt.Key_L,

        52: Qt.Key_Z, 53: Qt.Key_X, 54: Qt.Key_C, 55: Qt.Key_V, 56: Qt.Key_B,
        57: Qt.Key_N, 58: Qt.Key_M,

        // Digits are included because they are NOT universally safe either:
        // on AZERTY the unshifted digit row produces &é"'( and `event.key`
        // reports those instead of Qt.Key_1…
        10: Qt.Key_1, 11: Qt.Key_2, 12: Qt.Key_3, 13: Qt.Key_4, 14: Qt.Key_5,
        15: Qt.Key_6, 16: Qt.Key_7, 17: Qt.Key_8, 18: Qt.Key_9, 19: Qt.Key_0
    })

    // XKB keycode → uppercase Latin character, for call sites that match against
    // letters given as data (PowerMenu takes its hotkeys from action defs).
    readonly property var _scanToChar: ({
        24: "Q", 25: "W", 26: "E", 27: "R", 28: "T",
        29: "Y", 30: "U", 31: "I", 32: "O", 33: "P",
        38: "A", 39: "S", 40: "D", 41: "F", 42: "G",
        43: "H", 44: "J", 45: "K", 46: "L",
        52: "Z", 53: "X", 54: "C", 55: "V", 56: "B", 57: "N", 58: "M"
    })

    // The Qt.Key_* for the PHYSICAL key pressed. Use instead of `event.key`.
    function key(event) {
        return root._scanToKey[event.nativeScanCode] ?? event.key
    }

    // The Latin letter for the PHYSICAL key pressed, or "" if it is not a
    // letter. Never falls back to `event.text` — that is the layout-dependent
    // read this whole file exists to avoid.
    function letter(event) {
        return root._scanToChar[event.nativeScanCode] ?? ""
    }
}
