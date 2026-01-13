import QtQuick
import Quickshell
import Quickshell.Hyprland

pragma Singleton
pragma ComponentBehavior: Bound

/**
 * Сервис для работы с окнами Hyprland
 * Предоставляет утилиты для получения информации об окнах на воркспейсах
 */
Singleton {
    id: root

    /**
     * Получить все окна для указанного воркспейса
     * @param workspaceId - ID воркспейса
     * @return Array<HyprlandToplevel> - массив окон
     */
    function getWindowsForWorkspace(workspaceId) {
        if (!Hyprland.toplevels || !Hyprland.toplevels.values) {
            return []
        }

        return Hyprland.toplevels.values.filter(function(toplevel) {
            return toplevel.workspace?.id === workspaceId
        })
    }

    /**
     * Получить самое большое окно на воркспейсе (по площади)
     * Используется гибридный подход: нативное API + алгоритм из ii
     * @param workspaceId - ID воркспейса
     * @return HyprlandToplevel|null - самое большое окно или null
     */
    function getBiggestWindowForWorkspace(workspaceId) {
        const windows = getWindowsForWorkspace(workspaceId)

        if (windows.length === 0) {
            return null
        }

        return windows.reduce(function(maxWin, win) {
            // Получаем размеры из IPC объекта
            const maxSize = maxWin?.lastIpcObject?.size ?? [0, 0]
            const winSize = win?.lastIpcObject?.size ?? [0, 0]

            const maxArea = maxSize[0] * maxSize[1]
            const winArea = winSize[0] * winSize[1]

            return winArea > maxArea ? win : maxWin
        }, windows[0])
    }

    /**
     * Получить количество окон на воркспейсе
     * @param workspaceId - ID воркспейса
     * @return int - количество окон
     */
    function getWindowCountForWorkspace(workspaceId) {
        return getWindowsForWorkspace(workspaceId).length
    }

    /**
     * Проверить, занят ли воркспейс
     * @param workspaceId - ID воркспейса
     * @return bool - true если есть окна
     */
    function isWorkspaceOccupied(workspaceId) {
        return getWindowCountForWorkspace(workspaceId) > 0
    }

    /**
     * Получить массив классов всех окон на воркспейсе
     * Полезно для отладки
     * @param workspaceId - ID воркспейса
     * @return Array<string> - массив классов окон
     */
    function getWindowClassesForWorkspace(workspaceId) {
        const windows = getWindowsForWorkspace(workspaceId)
        return windows.map(function(win) {
            return win.lastIpcObject?.class ?? "unknown"
        })
    }
}
