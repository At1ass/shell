import QtQuick
import Qalculate

// Провайдер для математических вычислений с libqalculate
BaseProvider {
    id: root

    name: "Calculator"
    priority: 100  // Высокий приоритет
    prefixes: ["="]

    // Throttle кэш для предотвращения UI блокировки при быстром наборе
    property string _lastQuery: ""
    property var _lastResult: null
    property real _lastEvalTime: 0
    readonly property int _throttleMs: 150  // Минимальный интервал между eval

    function search(query) {
        // Убираем префикс если есть
        let expr = removePrefix(query)
        let normalizedExpr = expr ? expr.trim() : ""

        // Если пустое выражение
        if (!normalizedExpr) {
            _lastQuery = ""
            _lastResult = null
            return []
        }

        // Проверяем кэш - если тот же запрос, возвращаем сразу
        if (normalizedExpr === _lastQuery && _lastResult !== null) {
            return _lastResult
        }

        // Throttle: если eval был меньше 150ms назад, возвращаем старый результат
        const now = Date.now()
        const timeSinceLastEval = now - _lastEvalTime
        if (timeSinceLastEval < _throttleMs && _lastResult !== null) {
            // Слишком рано для нового eval, возвращаем старый результат
            return _lastResult
        }

        // Достаточно времени прошло - делаем eval
        _lastEvalTime = now
        _lastQuery = normalizedExpr

        // Используем Qalculate для вычисления
        let result = QalculateWrapper.eval(expr, false)

        // Проверяем на ошибки
        if (!result || result.startsWith("error:") || result.startsWith("warning:")) {
            // Показываем ошибку только если был явный префикс "="
            if (query.startsWith("=")) {
                const errorResult = [{
                    id: "calculator:error:" + normalizedExpr,
                    text: "Error",
                    description: result || "Invalid expression",
                    icon: "dialog-error",
                    type: "calculator",
                    score: 0,
                    action: function() {}
                }]
                _lastResult = errorResult
                return errorResult
            }
            _lastResult = []
            return []
        }

        // Успешное вычисление
        const successResult = [{
            id: "calculator:" + normalizedExpr,
            text: result,
            description: expr + " = " + result,
            icon: "accessories-calculator",
            type: "calculator",
            score: 100,
            data: { result: result, expression: expr },
            action: function() {
                console.log("Calculator result:", result)
                // TODO: Копировать в clipboard
            }
        }]

        _lastResult = successResult
        return successResult
    }
}
