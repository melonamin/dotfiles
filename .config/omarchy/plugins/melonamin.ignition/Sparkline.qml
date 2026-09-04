import QtQuick
import qs.Commons

// Two-series sparkline: `values` drawn as a filled area, `values2` as a bare
// line. Each series is normalized to its own maximum — clicks would be a flat
// zero line on the impressions scale otherwise (85 vs 12k over the window).
Canvas {
  id: root

  property var values: []
  property var values2: []
  property color lineColor: Color.accent
  property color line2Color: Color.foreground
  property color fillColor: Util.alpha(lineColor, 0.12)

  antialiasing: true

  onValuesChanged: requestPaint()
  onValues2Changed: requestPaint()
  onLineColorChanged: requestPaint()
  onLine2ColorChanged: requestPaint()
  onFillColorChanged: requestPaint()
  onWidthChanged: requestPaint()
  onHeightChanged: requestPaint()

  function seriesMax(points) {
    var maximum = 1
    for (var i = 0; i < points.length; i++) {
      var candidate = Number(points[i])
      if (isFinite(candidate)) maximum = Math.max(maximum, candidate)
    }
    return maximum * 1.12
  }

  function yFor(value, maximum) {
    var normalized = Math.max(0, Math.min(1, Number(value || 0) / maximum))
    return height - normalized * Math.max(1, height - Style.spacing.hairline)
  }

  function tracePath(context, points, maximum) {
    var step = points.length > 1 ? width / (points.length - 1) : width
    for (var i = 0; i < points.length; i++) {
      var x = points.length > 1 ? i * step : width
      var y = yFor(points[i], maximum)
      if (i === 0) context.moveTo(x, y)
      else context.lineTo(x, y)
    }
  }

  onPaint: {
    var context = getContext("2d")
    context.clearRect(0, 0, width, height)
    if (width <= 0 || height <= 0) return

    var primary = Array.isArray(values) ? values : []
    var secondary = Array.isArray(values2) ? values2 : []

    if (primary.length > 0) {
      var max1 = seriesMax(primary)
      var step = primary.length > 1 ? width / (primary.length - 1) : width

      context.beginPath()
      context.moveTo(0, height)
      for (var i = 0; i < primary.length; i++)
        context.lineTo(primary.length > 1 ? i * step : width, yFor(primary[i], max1))
      context.lineTo(width, height)
      context.closePath()
      context.fillStyle = fillColor
      context.fill()

      context.beginPath()
      tracePath(context, primary, max1)
      context.strokeStyle = lineColor
      context.lineWidth = Math.max(1, Style.spaceReal(1.25))
      context.lineJoin = "round"
      context.lineCap = "round"
      context.stroke()
    }

    if (secondary.length > 0) {
      context.beginPath()
      tracePath(context, secondary, seriesMax(secondary))
      context.strokeStyle = line2Color
      context.lineWidth = Math.max(1, Style.spaceReal(1))
      context.lineJoin = "round"
      context.lineCap = "round"
      context.globalAlpha = 0.7
      context.stroke()
      context.globalAlpha = 1.0
    }
  }
}
