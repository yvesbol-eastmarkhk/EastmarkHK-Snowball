import 'package:flutter/material.dart';
import '../calculator.dart';

/// A dependency-free line chart of balance growth over time, drawn with a
/// CustomPainter so the project has no extra pub dependencies to resolve.
///
/// Shows a marker dot at every single year (not just the endpoints), and a
/// compact value label above a spread of points so growth is readable at a
/// glance — the exact figures are always available in the table below.
class GrowthChart extends StatelessWidget {
  final List<YearlyBreakdown> yearly;
  final double principal;

  const GrowthChart({
    super.key,
    required this.yearly,
    required this.principal,
  });

  @override
  Widget build(BuildContext context) {
    if (yearly.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 240,
      child: CustomPaint(
        painter: _GrowthChartPainter(
          yearly: yearly,
          principal: principal,
          lineColor: scheme.primary,
          fillColor: scheme.primary.withValues(alpha: 0.12),
          gridColor: scheme.outlineVariant,
          textColor: scheme.onSurfaceVariant,
          dotColor: scheme.primary,
        ),
        child: Container(),
      ),
    );
  }
}

/// Short, currency-agnostic form for a chart label, e.g. 12345 -> "12.3K".
String _compact(double value) {
  final sign = value < 0 ? '-' : '';
  final v = value.abs();
  if (v >= 1000000) return '$sign${(v / 1000000).toStringAsFixed(1)}M';
  if (v >= 1000) return '$sign${(v / 1000).toStringAsFixed(1)}K';
  return '$sign${v.toStringAsFixed(0)}';
}

class _GrowthChartPainter extends CustomPainter {
  final List<YearlyBreakdown> yearly;
  final double principal;
  final Color lineColor;
  final Color fillColor;
  final Color gridColor;
  final Color textColor;
  final Color dotColor;

  _GrowthChartPainter({
    required this.yearly,
    required this.principal,
    required this.lineColor,
    required this.fillColor,
    required this.gridColor,
    required this.textColor,
    required this.dotColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double leftPad = 8;
    const double bottomPad = 20;
    const double topPad = 22; // room for value labels above the top dots
    final double chartWidth = size.width - leftPad;
    final double chartHeight = size.height - bottomPad - topPad;

    final double maxValue = yearly
        .map((y) => y.balanceEnd)
        .fold<double>(principal, (a, b) => a > b ? a : b);
    const double minValue = 0;

    double xFor(int index) =>
        leftPad + (chartWidth) * (index / (yearly.length));
    double yFor(double value) =>
        topPad +
        chartHeight -
        (chartHeight) *
            ((value - minValue) / (maxValue - minValue == 0 ? 1 : maxValue - minValue));

    // Grid lines (4 horizontal bands).
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (int i = 0; i <= 3; i++) {
      final double y = topPad + chartHeight * (i / 3);
      canvas.drawLine(Offset(leftPad, y), Offset(size.width, y), gridPaint);
    }

    // Build the path: start at principal (year 0).
    final path = Path();
    final fillPath = Path();
    final start = Offset(xFor(0), yFor(principal));
    path.moveTo(start.dx, start.dy);
    fillPath.moveTo(start.dx, topPad + chartHeight);
    fillPath.lineTo(start.dx, start.dy);

    final points = <Offset>[start];
    for (int i = 0; i < yearly.length; i++) {
      final p = Offset(xFor(i + 1), yFor(yearly[i].balanceEnd));
      path.lineTo(p.dx, p.dy);
      fillPath.lineTo(p.dx, p.dy);
      points.add(p);
    }
    fillPath.lineTo(xFor(yearly.length), topPad + chartHeight);
    fillPath.close();

    canvas.drawPath(fillPath, Paint()..color = fillColor);
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    // A small dot at every year, so each intermediate value is visible on
    // the line, not just the start and the end.
    final dotPaint = Paint()..color = dotColor;
    for (int i = 0; i < points.length; i++) {
      final isEndpoint = i == 0 || i == points.length - 1;
      canvas.drawCircle(points[i], isEndpoint ? 4 : 2.5, dotPaint);
    }

    // Value labels above a spread of points (at most ~6) so it stays
    // readable even with many years — always including year 0 and the
    // final year.
    final labelStep = (points.length / 6).ceil().clamp(1, points.length);
    for (int i = 0; i < points.length; i++) {
      final isLast = i == points.length - 1;
      if (i % labelStep != 0 && !isLast) continue;
      final value = i == 0 ? principal : yearly[i - 1].balanceEnd;
      final tp = TextPainter(
        text: TextSpan(
          text: _compact(value),
          style: TextStyle(
              color: textColor, fontSize: 10, fontWeight: FontWeight.w600),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      double dx = points[i].dx - tp.width / 2;
      dx = dx.clamp(0, size.width - tp.width);
      tp.paint(canvas, Offset(dx, (points[i].dy - tp.height - 6).clamp(0, size.height)));
    }

    // X-axis year numbers — every year if there aren't too many, otherwise
    // a spread, always including year 0 and the final year.
    final xLabelStep = (yearly.length / 8).ceil().clamp(1, yearly.length);
    for (int y = 0; y <= yearly.length; y++) {
      final isLast = y == yearly.length;
      if (y != 0 && !isLast && y % xLabelStep != 0) continue;
      final tp = TextPainter(
        text: TextSpan(
          text: '$y',
          style: TextStyle(color: textColor, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      double dx = xFor(y) - tp.width / 2;
      dx = dx.clamp(0, size.width - tp.width);
      tp.paint(canvas, Offset(dx, topPad + chartHeight + 4));
    }
  }

  @override
  bool shouldRepaint(covariant _GrowthChartPainter oldDelegate) {
    return oldDelegate.yearly != yearly || oldDelegate.principal != principal;
  }
}
