import 'dart:io';
import 'package:flutter/material.dart';
import 'store.dart';
import 'chart.dart';

Color parseHex(String s, [Color fallback = Colors.white]) {
  try {
    var h = s.replaceAll('#', '');
    if (h.length == 6) h = 'FF$h';
    return Color(int.parse(h, radix: 16));
  } catch (_) {
    return fallback;
  }
}

double _clampOp(double v) => v.clamp(0.0, 1.0);

/// Theme colours with the user's Settings opacity applied centrally, so
/// every page respects them. The background IMAGE is never faded here —
/// pageBackground draws it at full opacity; only colours/boxes fade.
Color get bgColor => parseHex(Store.instance.settings.bgHex, const Color(0xFF0D0A1A))
    .withOpacity(_clampOp(Store.instance.settings.bgOpacity));
Color get textColor => parseHex(Store.instance.settings.textHex, Colors.white)
    .withOpacity(_clampOp(Store.instance.settings.textOpacity));
Color get accentColor => parseHex(Store.instance.settings.accentHex, const Color(0xFFA855F7));
Color get cardColor => const Color(0xFF1E1433)
    .withOpacity(_clampOp(Store.instance.settings.cardOpacity));
const Color mutedColor = Color(0xFF9A8FC0);
const Color ghostColor = Color(0xFF33265A);

/// Deterministic violet gradient identity per category (stable across
/// rebuilds — cycled by category id, never random).
(Color, Color) categoryGradientPair(int id) {
  const pairs = [
    (Color(0xFF7C3AED), Color(0xFFC026D3)),
    (Color(0xFF6D28D9), Color(0xFFA855F7)),
    (Color(0xFF4C1D95), Color(0xFF8B5CF6)),
    (Color(0xFF9333EA), Color(0xFFDB2777)),
    (Color(0xFF5B21B6), Color(0xFFA855F7)),
  ];
  return pairs[id % pairs.length];
}

/// Generic Material icon for a category, chosen by keyword (never copied art).
IconData categoryIcon(String name) {
  final n = name.toLowerCase();
  if (n.contains('six') || n.contains('abs') || n.contains('core')) {
    return Icons.fitness_center;
  }
  if (n.contains('neck')) return Icons.person;
  if (n.contains('calis')) return Icons.accessibility_new;
  if (n.contains('hand') || n.contains('grip') || n.contains('power')) {
    return Icons.back_hand;
  }
  if (n.contains('leg') || n.contains('run') || n.contains('cardio')) {
    return Icons.directions_run;
  }
  if (n.contains('chest')) return Icons.fitness_center;
  return Icons.sports_gymnastics;
}

/// All bundled category icon assets (41, v9.9). The first entry of the
/// picker is "Auto" (null) and is NOT in this list — it means "use the
/// keyword icon above". Icons are per-category, not per-exercise: one
/// image stands for the whole category's focus (neck, six-pack, legs…).
const List<String> categoryIconAssets = [
  'assets/icons/icon_neck.png',
  'assets/icons/icon_sixpack.png',
  'assets/icons/icon_chest.png',
  'assets/icons/icon_back.png',
  'assets/icons/icon_shoulders.png',
  'assets/icons/icon_biceps.png',
  'assets/icons/icon_triceps.png',
  'assets/icons/icon_forearm.png',
  'assets/icons/icon_hand.png',
  'assets/icons/icon_gripper.png',
  'assets/icons/icon_wrist.png',
  'assets/icons/icon_legs.png',
  'assets/icons/icon_quads.png',
  'assets/icons/icon_hamstrings.png',
  'assets/icons/icon_calves.png',
  'assets/icons/icon_glutes.png',
  'assets/icons/icon_legpress.png',
  'assets/icons/icon_core.png',
  'assets/icons/icon_crunch.png',
  'assets/icons/icon_fullbody.png',
  'assets/icons/icon_face.png',
  'assets/icons/icon_muscleup.png',
  'assets/icons/icon_handstand.png',
  'assets/icons/icon_pushup.png',
  'assets/icons/icon_pullup.png',
  'assets/icons/icon_squat.png',
  'assets/icons/icon_plank.png',
  'assets/icons/icon_deadlift.png',
  'assets/icons/icon_benchpress.png',
  'assets/icons/icon_dips.png',
  'assets/icons/icon_row.png',
  'assets/icons/icon_overheadpress.png',
  'assets/icons/icon_lunge.png',
  'assets/icons/icon_running.png',
  'assets/icons/icon_cycling.png',
  'assets/icons/icon_jumprope.png',
  'assets/icons/icon_burpee.png',
  'assets/icons/icon_kettlebell.png',
  'assets/icons/icon_boxing.png',
  'assets/icons/icon_strength.png',
  'assets/icons/icon_flexibility.png',
];

/// Category icon chip: the chosen bundled image when the category has
/// one, otherwise the padded keyword Material icon. The image is shown
/// inside a ClipRRect so the rounded tile corners stay clean; if an
/// asset ever fails to load it falls back to the keyword icon.
Widget categoryIconChip(Category cat,
    {required Color bg, required Color fg}) {
  final asset = cat.iconAsset;
  if (asset != null && asset.isNotEmpty) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.asset(asset,
          width: 46,
          height: 46,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(categoryIcon(cat.name), color: fg, size: 22),
              )),
    );
  }
  return Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Icon(categoryIcon(cat.name), color: fg, size: 22),
  );
}

/// ONE shared delete-category confirmation, used by BOTH the Home page and
/// the Categories page so they cannot drift apart again. Nothing is deleted
/// unless the user taps Delete; after confirmation the existing
/// deleteCategory() logic runs unchanged.
Future<void> confirmDeleteCategory(
    BuildContext context, Category cat, VoidCallback onDeleted) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Delete this category?',
          style: TextStyle(color: Colors.white)),
      content: Text(
          'This will permanently delete the category, its exercises, and all associated workout records. This action cannot be undone.',
          style: const TextStyle(color: mutedColor)),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
        TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(color: Colors.redAccent))),
      ],
    ),
  );
  if (ok == true) {
    await Store.instance.deleteCategory(cat.id);
    onDeleted();
  }
}

/// Reusable premium category card (Categories page). Gradient identity,
/// icon chip, stats, Log / Exercises / red Delete, InkWell press ripple.
/// Card background honours the card-opacity setting; buttons keep full
/// accent/ghost opacity so they stay tappable and readable.
Widget premiumCategoryCard({
  required Category cat,
  required int exerciseCount,
  required int daysLogged,
  required double totalLogged,
  required VoidCallback onOpen,
  required VoidCallback onLog,
  required VoidCallback onExercises,
  required VoidCallback onDelete,
}) {
  final op = _clampOp(Store.instance.settings.cardOpacity);
  final grad = categoryGradientPair(cat.id);
  return Container(
    margin: const EdgeInsets.only(bottom: 14),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [grad.$1.withOpacity(op), grad.$2.withOpacity(op)],
      ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: accentColor.withAlpha(45)),
      boxShadow: const [
        BoxShadow(color: Colors.black45, blurRadius: 12, offset: Offset(0, 4))
      ],
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  categoryIconChip(cat,
                      bg: Colors.white.withAlpha(35), fg: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(cat.name,
                            style: TextStyle(
                                color: textColor,
                                fontSize: 20,
                                fontWeight: FontWeight.bold)),
                        Text(
                            '$exerciseCount exercises  •  $daysLogged days logged  •  Total: ${fmtNum(totalLogged)}',
                            style: const TextStyle(
                                color: mutedColor, fontSize: 13)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    tooltip: 'Delete category',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        onPressed: exerciseCount == 0 ? null : onLog,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: accentColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12))),
                        child: const Text('Log'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        onPressed: onExercises,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: ghostColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12))),
                        child: const Text('Exercises'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Gradient button (header / empty-state Add Category) — 52dp, not oversized.
Widget gradientBtn(String text, IconData icon, VoidCallback onPressed) {
  return SizedBox(
    width: double.infinity,
    height: 52,
    child: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accentColor, const Color(0xFFC026D3)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 4))
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(text,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    ),
  );
}

String fmtNum(double v) => v.toString();

Widget auraCard({required List<Widget> children, EdgeInsets? padding}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: padding ?? const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: cardColor,
      borderRadius: BorderRadius.circular(20),
      boxShadow: const [
        BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 3))
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );
}

Widget sectionLabel(String text) {
  return Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 6),
    child: Text(
      text,
      style: const TextStyle(
          color: mutedColor,
          fontSize: 13,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5),
    ),
  );
}

Widget purpleBtn(String text, VoidCallback onPressed) {
  return SizedBox(
    width: double.infinity,
    height: 56,
    child: ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: accentColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 6,
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
      ),
      child: Text(text),
    ),
  );
}

Widget ghostBtn(String text, VoidCallback onPressed) {
  return SizedBox(
    width: double.infinity,
    height: 52,
    child: ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: ghostColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
        textStyle: const TextStyle(fontSize: 16),
      ),
      child: Text(text),
    ),
  );
}

Widget pillBtn(String text, bool selected, VoidCallback onPressed) {
  return Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: selected ? accentColor : ghostColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: selected ? 4 : 1,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        textStyle: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal),
      ),
      child: Text(text),
    ),
  );
}

Widget statCard(String label, String value) {
  return Expanded(
    child: Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: TextStyle(
                  color: accentColor,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: mutedColor, fontSize: 11)),
        ],
      ),
    ),
  );
}

/// Label + value row with a purple progress track (v8 progressRow).
Widget progressRow(String label, String value, double fraction) {
  final f = fraction.clamp(0.0, 1.0);
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Column(
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(color: mutedColor, fontSize: 13)),
            const Spacer(),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 5),
        Container(
          height: 10,
          decoration: BoxDecoration(
              color: ghostColor, borderRadius: BorderRadius.circular(6)),
          child: Row(
            children: [
              Flexible(
                flex: (f < 0.02 ? 0.02 : f * 100).round(),
                child: Container(
                  decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(6)),
                ),
              ),
              if (f < 1.0) Flexible(flex: ((1 - f) * 100).round(), child: Container()),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget chartPills(ChartType current, void Function(ChartType) onSel) {
  return Wrap(
    children: [
      pillBtn('Snake', current == ChartType.snake, () => onSel(ChartType.snake)),
      pillBtn('Line', current == ChartType.line, () => onSel(ChartType.line)),
      pillBtn('Bars', current == ChartType.bar, () => onSel(ChartType.bar)),
      pillBtn('Area', current == ChartType.area, () => onSel(ChartType.area)),
    ],
  );
}

Widget periodPills(GraphPeriod current, void Function(GraphPeriod) onSel) {
  return Wrap(
    children: [
      pillBtn('Day', current == GraphPeriod.day, () => onSel(GraphPeriod.day)),
      pillBtn('Week', current == GraphPeriod.week, () => onSel(GraphPeriod.week)),
      pillBtn('Month', current == GraphPeriod.month, () => onSel(GraphPeriod.month)),
    ],
  );
}

Widget chartBox(List<(String, List<double>)> series, ChartType type,
    [List<String>? labels]) {
  return SizedBox(
    height: 220,
    width: double.infinity,
    child: CustomPaint(
      painter: ChartPainter(series, type, labels),
    ),
  );
}

Future<void> addCategoryDialog(BuildContext context, VoidCallback onDone) async {
  final input = TextEditingController();
  // Null = "Auto": fall back to the keyword icon. Any other value is the
  // bundled asset chosen in the picker grid below the name field.
  String? picked;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDlg) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Add Category',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: input,
              autofocus: true,
              onChanged: (_) => setDlg(() {}),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Category name, e.g. Calisthenics',
                hintStyle: const TextStyle(color: mutedColor),
                filled: true,
                fillColor: ghostColor,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: accentColor)),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Pick an icon for this category',
                style: TextStyle(color: Colors.white, fontSize: 15,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('One image for the whole category. Auto keeps the automatic icon.',
                style: TextStyle(color: mutedColor, fontSize: 13)),
            const SizedBox(height: 10),
            SizedBox(
              height: 210,
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8),
                itemCount: 1 + categoryIconAssets.length,
                itemBuilder: (_, i) {
                  if (i == 0) {
                    // "Auto" tile: no asset, keyword icon is used.
                    final selected = picked == null;
                    return InkWell(
                      onTap: () => setDlg(() => picked = null),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: ghostColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: selected
                                  ? accentColor
                                  : Colors.white24,
                              width: selected ? 2 : 1),
                        ),
                        child: Stack(
                          children: [
                            const Center(
                                child: Icon(Icons.auto_awesome,
                                    color: Colors.white, size: 22)),
                            if (selected)
                              const Positioned(
                                  right: 2,
                                  top: 2,
                                  child: Icon(Icons.check_circle,
                                      color: Colors.white, size: 14)),
                          ],
                        ),
                      ),
                    );
                  }
                  final asset = categoryIconAssets[i - 1];
                  final selected = picked == asset;
                  return InkWell(
                    onTap: () => setDlg(() => picked = asset),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color:
                                selected ? accentColor : Colors.white24,
                            width: selected ? 2 : 1),
                      ),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(9),
                            child: Image.asset(asset,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity),
                          ),
                          if (selected)
                            const Positioned(
                                right: 2,
                                top: 2,
                                child: Icon(Icons.check_circle,
                                    color: Colors.white, size: 14)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: input.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              child: const Text('Create Category')),
        ],
      ),
    ),
  );
  if (ok == true && input.text.trim().isNotEmpty) {
    await Store.instance.addCategory(input.text, picked);
    onDone();
  }
}

Future<void> addWorkoutDialog(
    BuildContext context, int catId, VoidCallback onDone) async {
  final name = TextEditingController();
  final unit = TextEditingController(text: 'reps');
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: cardColor,
      title: const Text('New Workout', style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: name,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Workout name, e.g. Push-ups',
              hintStyle: TextStyle(color: mutedColor),
            ),
          ),
          TextField(
            controller: unit,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Unit: reps / seconds / kg',
              hintStyle: TextStyle(color: mutedColor),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
        TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Create')),
      ],
    ),
  );
  if (ok == true && name.text.trim().isNotEmpty) {
    await Store.instance.addWorkout(catId, name.text, unit.text);
    onDone();
  }
}

/// Page background: solid bg colour, gallery image if set, gradient presets.
Widget pageBackground({required Widget child}) {
  final s = Store.instance.settings;
  Decoration? deco;
  if (s.bgPreset == 'Gallery' && s.bgImageUri.isNotEmpty) {
    // NOTE: the background image is drawn at FULL opacity on purpose —
    // the Settings opacity sliders fade colours and boxes only, never the image.
    return Stack(
      children: [
        Positioned.fill(
          child: Image.file(
            // ignore: avoid_dynamic_calls
            File(s.bgImageUri),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(color: bgColor),
          ),
        ),
        Positioned.fill(child: Container(color: Colors.black.withAlpha(140))),
        child,
      ],
    );
  }
  if (s.bgPreset == 'Storm Gradient') {
    deco = const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF1A0A2E), Color(0xFF3B0764), Color(0xFF0D0A1A)],
      ),
    );
  } else if (s.bgPreset == 'Raiden Gradient') {
    deco = const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF0D0A1A), Color(0xFF2A1A4A), Color(0xFF0D0A1A)],
      ),
    );
  } else {
    deco = BoxDecoration(color: bgColor);
  }
  return Container(decoration: deco, child: child);
}
