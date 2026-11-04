import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Port of v8 ChartView.kt + GoalRingView + BodySilhouetteView, as Flutter
/// CustomPaint painters. Same colours, same Snake smoothing, same labels.

enum ChartType { snake, line, bar, area }

const List<Color> chartColors = [
  Color(0xFFC084FC),
  Color(0xFFF472B6),
  Color(0xFF22D3EE),
  Color(0xFFFACC15),
  Color(0xFF4ADE80),
];

class ChartPainter extends CustomPainter {
  final List<(String, List<double>)> seriesList;
  final ChartType type;
  final List<String>? xLabels;
  ChartPainter(this.seriesList, this.type, [this.xLabels]);

  @override
  void paint(Canvas canvas, Size size) {
    final all = seriesList.expand((e) => e.$2).toList();
    if (all.isEmpty) return;
    final maxV = math.max(all.reduce(math.max), 1.0);
    final maxLen = math.max(seriesList.map((e) => e.$2.length).reduce(math.max), 2);
    const left = 15.0;
    final right = size.width - 15;
    const top = 15.0;
    final bottom = size.height - 30;
    final grid = Paint()
      ..color = const Color(0xFF2A2140)
      ..strokeWidth = 2;
    for (int i = 0; i <= 3; i++) {
      final y = top + (bottom - top) * i / 3;
      canvas.drawLine(Offset(left, y), Offset(right, y), grid);
    }
    Offset pt(List<double> values, int i) {
      final x = left + (right - left) * i / math.max(maxLen - 1, 1);
      final y = bottom - (values[i] / maxV) * (bottom - top);
      return Offset(x, y);
    }

    for (int si = 0; si < seriesList.length; si++) {
      final values = seriesList[si].$2;
      if (values.isEmpty) continue;
      final color = chartColors[si % chartColors.length];
      final paint = Paint()
        ..color = color
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true;
      final fillPaint = Paint()
        ..color = color.withAlpha(50)
        ..style = PaintingStyle.fill;
      void dots() {
        for (int i = 0; i < values.length; i++) {
          final p = pt(values, i);
          canvas.drawCircle(
              p,
              8,
              Paint()
                ..color = const Color(0xFF0D0A1A)
                ..style = PaintingStyle.fill);
          canvas.drawCircle(
              p,
              8,
              Paint()
                ..color = color
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2.5);
        }
      }

      if (type == ChartType.bar) {
        final bw = (right - left) / maxLen * 0.5;
        for (int i = 0; i < values.length; i++) {
          final p = pt(values, i);
          canvas.drawRect(
              Rect.fromLTRB(p.dx - bw / 2, p.dy, p.dx + bw / 2, bottom),
              Paint()..color = color);
        }
      } else if (type == ChartType.snake || type == ChartType.line) {
        final path = Path();
        final pts = [for (int i = 0; i < values.length; i++) pt(values, i)];
        if (type == ChartType.snake) {
          path.moveTo(pts[0].dx, pts[0].dy);
          for (int i = 1; i < pts.length; i++) {
            final mid = Offset((pts[i - 1].dx + pts[i].dx) / 2,
                (pts[i - 1].dy + pts[i].dy) / 2);
            path.quadraticBezierTo(pts[i - 1].dx, pts[i - 1].dy, mid.dx, mid.dy);
          }
          if (pts.length > 1) path.lineTo(pts.last.dx, pts.last.dy);
        } else {
          for (int i = 0; i < pts.length; i++) {
            if (i == 0) {
              path.moveTo(pts[i].dx, pts[i].dy);
            } else {
              path.lineTo(pts[i].dx, pts[i].dy);
            }
          }
        }
        canvas.drawPath(path, paint);
        dots();
      } else {
        // area
        final path = Path();
        final fill = Path();
        for (int i = 0; i < values.length; i++) {
          final p = pt(values, i);
          if (i == 0) {
            path.moveTo(p.dx, p.dy);
            fill.moveTo(p.dx, bottom);
            fill.lineTo(p.dx, p.dy);
          } else {
            path.lineTo(p.dx, p.dy);
            fill.lineTo(p.dx, p.dy);
          }
        }
        fill.lineTo(pt(values, values.length - 1).dx, bottom);
        fill.close();
        canvas.drawPath(fill, fillPaint);
        canvas.drawPath(path, paint);
        dots();
      }
    }
    // x labels
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 0; i < maxLen; i++) {
      final x = left + (right - left) * i / math.max(maxLen - 1, 1);
      final label = (xLabels != null && i < xLabels!.length)
          ? xLabels![i]
          : 'DAY ${i + 1}';
      tp.text = TextSpan(
          text: label,
          style: const TextStyle(
              color: Color(0xFF8B7FB8),
              fontSize: 11,
              fontWeight: FontWeight.bold));
      tp.layout();
      tp.paint(canvas, Offset(x - 18, size.height - 16));
    }
  }

  @override
  bool shouldRepaint(covariant ChartPainter old) =>
      old.seriesList != seriesList || old.type != type || old.xLabels != xLabels;
}

/// Daily Goal ring: today's total as % of best day, capped at 100%.
/// fgColor defaults to the original purple so other callers are unaffected;
/// the homepage passes the user's Settings accent colour.
class GoalRingPainter extends CustomPainter {
  final int pct;
  final Color fgColor;
  GoalRingPainter(this.pct, [this.fgColor = const Color(0xFFA855F7)]);
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = (math.min(size.width, size.height) / 2) - 12;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
    final bg = Paint()
      ..color = const Color(0xFF33265A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..isAntiAlias = true;
    final fg = Paint()
      ..color = fgColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    canvas.drawCircle(Offset(cx, cy), r, bg);
    if (pct > 0) {
      canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * pct / 100, false, fg);
    }
    final tp = TextPainter(
        text: TextSpan(
            text: '$pct%',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr);
    tp.layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant GoalRingPainter old) =>
      old.pct != pct || old.fgColor != fgColor;
}

/// Original body silhouette drawn in code (not copied artwork): simple purple
/// figure — head, torso, arms, legs — used as the Muscle Focus visual.
/// Colours default to the original purple; the homepage passes the user's
/// Settings accent colour so a theme change recolours the silhouette.
class BodySilhouettePainter extends CustomPainter {
  final Color bodyColor;
  final Color glowColor;
  final Color darkColor;
  BodySilhouettePainter({
    this.bodyColor = const Color(0xFFA855F7),
    this.glowColor = const Color(0xFFC084FC),
    this.darkColor = const Color(0xFF7C3AED),
  });
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final body = Paint()
      ..color = bodyColor
      ..isAntiAlias = true;
    final glow = Paint()
      ..color = glowColor
      ..isAntiAlias = true;
    final dark = Paint()
      ..color = darkColor
      ..isAntiAlias = true;
    // head
    canvas.drawCircle(Offset(cx, h * 0.12), w * 0.075, glow);
    // torso (rounded, glowing centre)
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTRB(cx - w * 0.16, h * 0.24, cx + w * 0.16, h * 0.60),
            Radius.circular(w * 0.08)),
        body);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTRB(cx - w * 0.09, h * 0.28, cx + w * 0.09, h * 0.56),
            Radius.circular(w * 0.05)),
        glow);
    // arms
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTRB(cx - w * 0.27, h * 0.26, cx - w * 0.18, h * 0.58),
            Radius.circular(w * 0.04)),
        dark);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTRB(cx + w * 0.18, h * 0.26, cx + w * 0.27, h * 0.58),
            Radius.circular(w * 0.04)),
        dark);
    // legs
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTRB(cx - w * 0.14, h * 0.62, cx - w * 0.03, h * 0.95),
            Radius.circular(w * 0.04)),
        body);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTRB(cx + w * 0.03, h * 0.62, cx + w * 0.14, h * 0.95),
            Radius.circular(w * 0.04)),
        body);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// v9.10 body-map figure for Home Muscle Focus (user-picked preview 2:
/// faint -> green). A region is TRAINED (solid bright green) when at
/// least one logged entry exists for a category mapped to it, and
/// UNTRAINED (faint ghost outline only, never red) otherwise.
enum BodyRegion { neck, chest, shoulders, arms, core, legs }

/// Keyword mapping from a category name to the body regions it trains.
/// The name is lowercased and substring-matched; one name may match
/// several regions.
/// - back -> chest: a front-view figure cannot show a back, so back
///   training lights the chest zone as the closest front approximation.
/// - fullbody / calisthenics -> all regions.
/// - cardio / strength / flexibility and anything unmatched -> no
///   region (the category still shows in the % breakdown).
Set<BodyRegion> regionsForCategoryName(String name) {
  final n = name.toLowerCase();
  final out = <BodyRegion>{};
  if (n.contains('neck')) out.add(BodyRegion.neck);
  if (n.contains('chest') || n.contains('back')) out.add(BodyRegion.chest);
  if (n.contains('shoulder')) out.add(BodyRegion.shoulders);
  if (n.contains('arm') ||
      n.contains('bicep') ||
      n.contains('tricep') ||
      n.contains('forearm') ||
      n.contains('hand') ||
      n.contains('grip') ||
      n.contains('wrist')) {
    out.add(BodyRegion.arms);
  }
  if (n.contains('core') ||
      n.contains('abs') ||
      n.contains('six') ||
      n.contains('stomach')) {
    out.add(BodyRegion.core);
  }
  if (n.contains('leg') ||
      n.contains('quad') ||
      n.contains('hamstring') ||
      n.contains('calf') ||
      n.contains('glute') ||
      n.contains('thigh')) {
    out.add(BodyRegion.legs);
  }
  if (n.contains('fullbody') ||
      n.contains('full body') ||
      n.contains('calisthenic')) {
    out.addAll(BodyRegion.values);
  }
  return out;
}

/// Front-view body figure split into flat zones. Trained zones are
/// filled solid green (fixed colour, independent of theme presets, as
/// the user chose); untrained zones are a faint outline in [faintColor]
/// (callers pass the theme text colour at low opacity so the ghost
/// stays readable on every theme and gallery background).
class BodyMapPainter extends CustomPainter {
  final Set<BodyRegion> trained;
  final Color faintColor;
  static const Color trainedGreen = Color(0xFF00E676);

  const BodyMapPainter({required this.trained, required this.faintColor});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final faint = Paint()
      ..color = faintColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..isAntiAlias = true;
    final green = Paint()
      ..color = trainedGreen
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    void zone(BodyRegion region, Rect rect) {
      final r = RRect.fromRectAndRadius(rect, Radius.circular(w * 0.04));
      if (trained.contains(region)) {
        canvas.drawRRect(r, green);
      } else {
        canvas.drawRRect(r, faint);
      }
    }

    // Head: not a trainable region, always a faint outline.
    canvas.drawCircle(Offset(cx, h * 0.10), w * 0.075, faint);
    // Neck.
    zone(BodyRegion.neck,
        Rect.fromLTRB(cx - w * 0.055, h * 0.175, cx + w * 0.055, h * 0.225));
    // Chest.
    zone(BodyRegion.chest,
        Rect.fromLTRB(cx - w * 0.16, h * 0.225, cx + w * 0.16, h * 0.42));
    // Shoulders.
    zone(BodyRegion.shoulders,
        Rect.fromLTRB(cx - w * 0.27, h * 0.235, cx - w * 0.165, h * 0.35));
    zone(BodyRegion.shoulders,
        Rect.fromLTRB(cx + w * 0.165, h * 0.235, cx + w * 0.27, h * 0.35));
    // Arms (upper arm + forearm/hand as one zone, matching the preview).
    zone(BodyRegion.arms,
        Rect.fromLTRB(cx - w * 0.285, h * 0.355, cx - w * 0.19, h * 0.62));
    zone(BodyRegion.arms,
        Rect.fromLTRB(cx + w * 0.19, h * 0.355, cx + w * 0.285, h * 0.62));
    // Core / abs.
    zone(BodyRegion.core,
        Rect.fromLTRB(cx - w * 0.15, h * 0.425, cx + w * 0.15, h * 0.60));
    // Legs.
    zone(BodyRegion.legs,
        Rect.fromLTRB(cx - w * 0.145, h * 0.61, cx - w * 0.025, h * 0.95));
    zone(BodyRegion.legs,
        Rect.fromLTRB(cx + w * 0.025, h * 0.61, cx + w * 0.145, h * 0.95));
  }

  @override
  bool shouldRepaint(covariant BodyMapPainter oldDelegate) =>
      oldDelegate.trained != trained || oldDelegate.faintColor != faintColor;
}
