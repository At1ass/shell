import QtQuick
import Qalculate

// Провайдер для математических вычислений с libqalculate
BaseProvider {
    id: root

    name: "Calculator"
    priority: 100  // Высокий приоритет
    prefixes: ["="]

    function search(query) {
        // Убираем префикс если есть
        let expr = removePrefix(query)

        // Если пустое выражение
        if (!expr || expr.trim() === "") {
            return []
        }

        // Используем Qalculate для вычисления
        let result = QalculateWrapper.eval(expr, false)

        // Проверяем на ошибки
        if (!result || result.startsWith("error:") || result.startsWith("warning:")) {
            // Показываем ошибку только если был явный префикс "="
            if (query.startsWith("=")) {
                return [{
                    text: "Error",
                    description: result || "Invalid expression",
                    icon: "dialog-error",
                    type: "calculator",
                    score: 0,
                    action: function() {}
                }]
            }
            return []
        }

        // Успешное вычисление
        return [{
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
    }
}
