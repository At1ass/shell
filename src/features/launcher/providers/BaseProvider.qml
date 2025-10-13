import QtQuick

// Базовый класс для всех провайдеров
QtObject {
    id: root

    // Имя провайдера (для отладки)
    property string name: "BaseProvider"

    // Приоритет (чем выше, тем раньше в результатах)
    property int priority: 0

    // Префиксы которые обрабатывает провайдер (например ["=", "calc"])
    // Пустой массив = обрабатывает все запросы
    property var prefixes: []

    // Проверка - может ли провайдер обработать запрос
    function canHandle(query) {
        if (!query) return false

        // Если нет префиксов - обрабатываем всё
        if (prefixes.length === 0) return true

        // Проверяем префиксы
        for (let i = 0; i < prefixes.length; i++) {
            if (query.startsWith(prefixes[i])) {
                return true
            }
        }

        return false
    }

    // Поиск результатов (должен быть переопределен в наследниках)
    // Возвращает массив объектов вида:
    // {
    //   text: "Result text",
    //   description: "Result description",
    //   icon: "icon-name",
    //   type: "calculator|application|file|action",
    //   score: 100,
    //   data: {...},  // дополнительные данные
    //   action: function() { ... }  // что выполнить
    // }
    function search(query) {
        console.warn(name + ": search() not implemented")
        return []
    }

    // Хелпер для удаления префикса из запроса
    function removePrefix(query) {
        for (let i = 0; i < prefixes.length; i++) {
            if (query.startsWith(prefixes[i])) {
                return query.slice(prefixes[i].length).trim()
            }
        }
        return query
    }
}
