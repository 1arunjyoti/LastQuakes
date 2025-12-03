import 'package:flutter/material.dart';
import 'package:lastquakes/services/earthquake_statistics.dart';
import 'dart:math' as math;

class SimpleLineChart extends StatelessWidget {
  final List<DailyTrendPoint> data;
  final bool showMovingAverage;
  final Color lineColor;
  final Color? fillColor;

  const SimpleLineChart({
    super.key,
    required this.data,
    this.showMovingAverage = false,
    this.lineColor = Colors.blue,
    this.fillColor,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text('No data available'),
        ),
      );
    }

    return CustomPaint(
      painter: _LineChartPainter(
        data: data,
        showMovingAverage: showMovingAverage,
        lineColor: lineColor,
        fillColor: fillColor,
        theme: Theme.of(context),
      ),
      size: const Size(double.infinity, 180),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<DailyTrendPoint> data;
  final bool showMovingAverage;
  final Color lineColor;
  final Color? fillColor;
  final ThemeData theme;

  _LineChartPainter({
    required this.data,
    required this.showMovingAverage,
    required this.lineColor,
    required this.fillColor,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint =
        Paint()
          ..color = lineColor
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

    final fillPaint =
        Paint()
          ..color = (fillColor ?? lineColor).withValues(alpha: 0.1)
          ..style = PaintingStyle.fill;

    final gridPaint =
        Paint()
          ..color = theme.colorScheme.onSurface.withValues(alpha: 0.1)
          ..strokeWidth = 1.0;

    final maxCount = data.map((p) => p.count).reduce(math.max).toDouble();
    final minCount = data.map((p) => p.count).reduce(math.min).toDouble();
    final range = maxCount - minCount;

    // Add padding
    final paddingLeft = 40.0;
    final paddingRight = 20.0;
    final paddingTop = 20.0;
    final paddingBottom = 30.0;

    final chartWidth = size.width - paddingLeft - paddingRight;
    final chartHeight = size.height - paddingTop - paddingBottom;

    // Draw grid lines (5 horizontal lines)
    for (int i = 0; i <= 4; i++) {
      final y = paddingTop + (chartHeight / 4) * i;
      canvas.drawLine(
        Offset(paddingLeft, y),
        Offset(size.width - paddingRight, y),
        gridPaint,
      );
    }

    // Calculate points
    final path = Path();
    final fillPath = Path();
    final points = <Offset>[];

    for (int i = 0; i < data.length; i++) {
      final x = paddingLeft + (chartWidth / (data.length - 1)) * i;
      final normalizedValue =
          range > 0 ? (data[i].count - minCount) / range : 0.5;
      final y = paddingTop + chartHeight - (normalizedValue * chartHeight);

      points.add(Offset(x, y));

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, paddingTop + chartHeight);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    // Close fill path
    if (points.isNotEmpty) {
      fillPath.lineTo(points.last.dx, paddingTop + chartHeight);
      fillPath.close();
    }

    // Draw filled area
    if (fillColor != null && points.isNotEmpty) {
      canvas.drawPath(fillPath, fillPaint);
    }

    // Draw line
    canvas.drawPath(path, paint);

    // Draw points
    final pointPaint =
        Paint()
          ..color = lineColor
          ..style = PaintingStyle.fill;

    for (final point in points) {
      canvas.drawCircle(point, 3.0, pointPaint);
    }

    // Draw moving average if enabled
    if (showMovingAverage && data.length > 3) {
      const windowSize = 3;
      final movingAvg = EarthquakeStatistics.calculateMovingAverage(
        data,
        windowSize,
      );

      if (movingAvg.isNotEmpty) {
        final avgPaint =
            Paint()
              ..color = lineColor.withValues(alpha: 0.5)
              ..strokeWidth = 1.5
              ..style = PaintingStyle.stroke
              ..strokeCap = StrokeCap.round;

        final avgPath = Path();

        for (int i = 0; i < movingAvg.length; i++) {
          final dataIndex = i + windowSize - 1;
          final x = paddingLeft + (chartWidth / (data.length - 1)) * dataIndex;
          final normalizedValue =
              range > 0 ? (movingAvg[i] - minCount) / range : 0.5;
          final y = paddingTop + chartHeight - (normalizedValue * chartHeight);

          if (i == 0) {
            avgPath.moveTo(x, y);
          } else {
            avgPath.lineTo(x, y);
          }
        }

        canvas.drawPath(avgPath, avgPaint);
      }
    }

    // Draw Y-axis labels
    final textStyle = TextStyle(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
      fontSize: 10,
    );

    for (int i = 0; i <= 4; i++) {
      final value = maxCount - (range / 4 * i);
      final y = paddingTop + (chartHeight / 4) * i;

      final textSpan = TextSpan(
        text: value.toInt().toString(),
        style: textStyle,
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(5, y - textPainter.height / 2));
    }
  }

  @override
  bool shouldRepaint(_LineChartPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.showMovingAverage != showMovingAverage ||
        oldDelegate.lineColor != lineColor;
  }
}
