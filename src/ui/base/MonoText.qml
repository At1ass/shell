import QtQuick
import qs.src.core.config

// Monospace variant of MaterialText for code, IPC signatures and keybinds.
// Same token contract; only the family differs.
MaterialText {
    font.family: Tokens.typography.monoFamily
}
