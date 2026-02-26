import QtQuick

Canvas {
    id: root

    property var values: []
    property color lineColor: "#4CAF50"
    property color fillColor: Qt.rgba(lineColor.r, lineColor.g, lineColor.b, 0.15)
    property real lineWidth: 1.5
    property bool showFill: true

    onValuesChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onLineColorChanged: requestPaint()

    onPaint: {
        var ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);

        if (!values || values.length < 2)
            return;

        var len = values.length;
        var stepX = width / (len - 1);
        var h = height;

        // Build path
        ctx.beginPath();
        ctx.moveTo(0, h - values[0] * h);
        for (var i = 1; i < len; i++) {
            ctx.lineTo(i * stepX, h - values[i] * h);
        }

        // Stroke line
        ctx.strokeStyle = lineColor;
        ctx.lineWidth = lineWidth;
        ctx.lineJoin = "round";
        ctx.stroke();

        // Fill area under the line
        if (showFill) {
            ctx.lineTo((len - 1) * stepX, h);
            ctx.lineTo(0, h);
            ctx.closePath();
            ctx.fillStyle = fillColor;
            ctx.fill();
        }
    }
}
