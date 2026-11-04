import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'store.dart';
import 'coach.dart';
import 'chart.dart';
import 'widgets.dart';

const _urlChannel = MethodChannel('aura/files');

Future<bool> openUrl(String url) async {
  try {
    await _urlChannel.invokeMethod('openUrl', {'url': url});
    return true;
  } catch (_) {
    return false;
  }
}

Future<bool> mailTo(String email) async {
  try {
    await _urlChannel.invokeMethod('mailto', {'email': email});
    return true;
  } catch (_) {
    return false;
  }
}

// ---------------- Categories ----------------

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});
  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final s = Store.instance;
    final op = Store.instance.settings.cardOpacity.clamp(0.0, 1.0);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Premium header: gradient banner, title, subtitle, count chip.
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accentColor.withOpacity(op),
                const Color(0xFFC026D3).withOpacity(op),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black45, blurRadius: 12, offset: Offset(0, 4))
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CATEGORIES',
                        style: TextStyle(
                            color: textColor,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2)),
                    const SizedBox(height: 4),
                    Text('Your training. Your categories.',
                        style: TextStyle(
                            color: textColor.withOpacity(0.85), fontSize: 15)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(40),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                    s.categories.length == 1
                        ? '1 category'
                        : '${s.categories.length} categories',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        gradientBtn('Add Category', Icons.add,
            () => addCategoryDialog(context, _refresh)),
        const SizedBox(height: 14),
        if (s.categories.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  cardColor,
                  Color.lerp(cardColor, accentColor, 0.16) ?? cardColor,
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: accentColor.withAlpha(45)),
            ),
            child: Column(
              children: [
                // Code-drawn workout illustration: fitness icon in a
                // gradient circle with a thin lightning accent — no art/photo.
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [accentColor, const Color(0xFFC026D3)],
                    ),
                  ),
                  child: const Icon(Icons.fitness_center,
                      color: Colors.white, size: 40),
                ),
                const SizedBox(height: 16),
                Text('Your training starts here.',
                    style: TextStyle(
                        color: textColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center),
                const SizedBox(height: 6),
                const Text('Create your first category to organize your workouts.',
                    style: TextStyle(color: mutedColor, fontSize: 15),
                    textAlign: TextAlign.center),
                const SizedBox(height: 16),
                gradientBtn('Add Category', Icons.add,
                    () => addCategoryDialog(context, _refresh)),
              ],
            ),
          ),
        for (final cat in s.categories)
          _categoryCard(context, cat, _refresh),
      ],
    );
  }

  Widget _categoryCard(BuildContext context, Category cat, VoidCallback refresh) {
    final s = Store.instance;
    final ws = s.workouts.where((w) => w.categoryId == cat.id).toList();
    final totals = dayTotalsForCategory(cat.id);
    final totalLogged = totals.fold<double>(0, (a, d) => a + d.total);
    void open() {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ExercisesScreen(catId: cat.id))).then((_) => refresh());
    }

    return premiumCategoryCard(
      cat: cat,
      exerciseCount: ws.length,
      daysLogged: totals.length,
      totalLogged: totalLogged,
      onOpen: open,
      onLog: () {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => LogScreen(catId: cat.id))).then((_) => refresh());
      },
      onExercises: open,
      onDelete: () => confirmDeleteCategory(context, cat, refresh),
    );
  }
}

// ---------------- Progress ----------------

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});
  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  ChartType _type = ChartType.snake;
  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final s = Store.instance;
    final totals = dayTotalsOverall();
    final best = totals.isEmpty
        ? 0.0
        : totals.map((d) => d.total).reduce((a, b) => a > b ? a : b);
    final totalSum = s.logs.fold<double>(0, (a, l) => a + l.value);
    final series = <(String, List<double>)>[
      for (final c in s.categories)
        (c.name, dayTotalsForCategory(c.id).map((d) => d.total).toList())
    ];
    final all = s.categories.isEmpty
        ? <(String, List<double>)>[]
        : [...series, ('Overall', totals.map((d) => d.total).toList())];
    final op = s.settings.cardOpacity.clamp(0.0, 1.0);
    final animOn = s.settings.animationOn;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Premium header: gradient banner matching the v9.4 Categories
        // header. No nested Scaffold/AppBar — the Shell in main.dart
        // already wraps this tab body in pageBackground + bottom nav.
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accentColor.withOpacity(op),
                const Color(0xFFC026D3).withOpacity(op),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black45, blurRadius: 12, offset: Offset(0, 4))
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PROGRESS',
                        style: TextStyle(
                            color: textColor,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2)),
                    const SizedBox(height: 4),
                    Text('All categories together, plus every day you logged.',
                        style: TextStyle(
                            color: textColor.withOpacity(0.85), fontSize: 15)),
                  ],
                ),
              ),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(40),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.show_chart,
                    color: Colors.white, size: 26),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            _premiumStatCard(
                Icons.calendar_month, 'DAYS', '${totals.length}'),
            const SizedBox(width: 8),
            _premiumStatCard(Icons.emoji_events, 'BEST DAY', fmtNum(best)),
            const SizedBox(width: 8),
            _premiumStatCard(
                Icons.fitness_center, 'TOTAL', '${totalSum.toInt()}'),
          ],
        ),
        const SizedBox(height: 14),
        // Graph card with a subtle purple glow. Text always sits on a
        // card background (cardColor, honouring cardOpacity), never bare
        // over a busy gallery image.
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: accentColor.withOpacity(0.22),
                  blurRadius: 18,
                  offset: const Offset(0, 6)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              chartPills(_type, (t) => setState(() => _type = t)),
              const SizedBox(height: 8),
              if (all.any((e) => e.$2.isNotEmpty)) ...[
                animOn
                    ? AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: Container(
                          key: ValueKey(_type),
                          child: chartBox(all, _type),
                        ),
                      )
                    : chartBox(all, _type),
                const SizedBox(height: 10),
                // Clear category labels as chips. Dot colours match
                // ChartPainter's series order (chartColors[i % len]);
                // the Overall series is last, as in the chart.
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (int i = 0; i < all.length; i++)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: ghostColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: chartColors[i % chartColors.length],
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(all[i].$1,
                                style: TextStyle(
                                    color: textColor, fontSize: 12)),
                          ],
                        ),
                      ),
                  ],
                ),
              ] else
                const Text('Log your first day to see your graph here.',
                    style: TextStyle(color: mutedColor, fontSize: 16)),
            ],
          ),
        ),
        sectionLabel('PROGRESS STREAM'),
        if (totals.isEmpty)
          auraCard(children: const [
            Text('Your days will appear here, newest first.',
                style: TextStyle(color: mutedColor, fontSize: 15)),
          ]),
        for (final d in totals.reversed)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                    color: Colors.black45, blurRadius: 8, offset: Offset(0, 3))
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => DayDetailScreen(date: d.date))).then((_) => _refresh());
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [accentColor, const Color(0xFFC026D3)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text('${d.day}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('DAY ${d.day}',
                              style: TextStyle(
                                  color: textColor,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                          Text(d.date,
                              style: const TextStyle(
                                  color: mutedColor, fontSize: 13)),
                        ],
                      ),
                      const Spacer(),
                      Text(fmtNum(d.total),
                          style: TextStyle(
                              color: accentColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(width: 2),
                      Icon(Icons.chevron_right,
                          color: accentColor, size: 22),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// Premium stat card used ONLY by the Progress page. The shared statCard
// in widgets.dart is left untouched, so no other page changes appearance.
Widget _premiumStatCard(IconData icon, String label, String value) {
  return Expanded(
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cardColor,
            Color.lerp(cardColor, accentColor, 0.18) ?? cardColor,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: accentColor.withOpacity(0.18),
              blurRadius: 14,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.25),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accentColor, size: 18),
          ),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  color: textColor,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: mutedColor, fontSize: 11)),
        ],
      ),
    ),
  );
}

// ---------------- Day detail ----------------

class DayDetailScreen extends StatelessWidget {
  final String date;
  const DayDetailScreen({super.key, required this.date});
  @override
  Widget build(BuildContext context) {
    final s = Store.instance;
    final entries = s.logsForDate(date);
    final dayNum =
        dayTotalsOverall().where((d) => d.date == date).map((d) => d.day).fold(1, (a, b) => b);
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
          title: Text('DAY $dayNum  •  $date'),
          backgroundColor: const Color(0xFF150E28),
          foregroundColor: Colors.white),
      body: pageBackground(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (entries.isEmpty)
              const Text('No records for this day.',
                  style: TextStyle(color: mutedColor, fontSize: 16)),
            for (final e in entries)
              Builder(builder: (_) {
                final w = s.workouts.where((x) => x.id == e.workoutId).firstOrNull;
                if (w == null) return const SizedBox.shrink();
                return auraCard(children: [
                  Row(
                    children: [
                      Text(w.name,
                          style: TextStyle(
                              color: textColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      const Spacer(),
                      Text('${fmtNum(e.value)} ${w.unit}',
                          style: TextStyle(
                              color: accentColor,
                              fontSize: 17,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ]);
              }),
            if (entries.isNotEmpty)
              purpleBtn('EDIT RECORD', () {
                final first = entries.first;
                final w = s.workouts.where((x) => x.id == first.workoutId).firstOrNull;
                if (w == null) return;
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            LogScreen(catId: w.categoryId, date: date)));
              }),
          ],
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

// ---------------- Exercises (per category) ----------------

class ExercisesScreen extends StatefulWidget {
  final int catId;
  const ExercisesScreen({super.key, required this.catId});
  @override
  State<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends State<ExercisesScreen> {
  ChartType _type = ChartType.snake;
  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final s = Store.instance;
    final cat = s.categories.where((c) => c.id == widget.catId).firstOrNull;
    if (cat == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
      return const Scaffold(body: SizedBox.shrink());
    }
    final totals = dayTotalsForCategory(widget.catId);
    final ws = s.workouts.where((w) => w.categoryId == widget.catId).toList();
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
          title: Text('EXERCISES  •  ${cat.name}'),
          backgroundColor: const Color(0xFF150E28),
          foregroundColor: Colors.white),
      floatingActionButton: FloatingActionButton(
        backgroundColor: accentColor,
        onPressed: () => addWorkoutDialog(context, widget.catId, _refresh),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: pageBackground(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (totals.isNotEmpty)
              auraCard(children: [
                chartPills(_type, (t) => setState(() => _type = t)),
                const SizedBox(height: 8),
                chartBox([(cat.name, totals.map((d) => d.total).toList())], _type),
              ]),
            purpleBtn('Log Today', () {
              if (ws.isNotEmpty) {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => LogScreen(catId: widget.catId))).then((_) => _refresh());
              }
            }),
            const SizedBox(height: 14),
            for (final w in ws)
              auraCard(children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(w.name,
                              style: TextStyle(
                                  color: textColor,
                                  fontSize: 19,
                                  fontWeight: FontWeight.bold)),
                          Builder(builder: (_) {
                            final ls = s.logs.where((l) => l.workoutId == w.id).toList();
                            ls.sort((a, b) => a.date.compareTo(b.date));
                            final last = ls.isEmpty ? null : ls.last;
                            return Text(
                                last != null
                                    ? 'Unit: ${w.unit}  •  Last: ${fmtNum(last.value)} ${w.unit}'
                                    : 'Unit: ${w.unit}  •  Not logged yet',
                                style: const TextStyle(
                                    color: mutedColor, fontSize: 14));
                          }),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _editWorkout(context, w, _refresh),
                      icon: const Icon(Icons.edit, color: Colors.white70),
                    ),
                    IconButton(
                      onPressed: () async {
                        await Store.instance.deleteWorkout(w.id);
                        _refresh();
                      },
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                    ),
                  ],
                ),
              ]),
            if (ws.isEmpty)
              auraCard(children: const [
                Text('No exercises yet. Tap + below to add your first one.',
                    style: TextStyle(color: mutedColor, fontSize: 15)),
              ]),
            ghostBtn('+ Add Exercise',
                () => addWorkoutDialog(context, widget.catId, _refresh)),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Future<void> _editWorkout(
      BuildContext context, Workout w, VoidCallback refresh) async {
    final name = TextEditingController(text: w.name);
    final unit = TextEditingController(text: w.unit);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardColor,
        title: const Text('Edit Workout', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: name,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                    hintText: 'Workout name',
                    hintStyle: TextStyle(color: mutedColor))),
            TextField(
                controller: unit,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                    hintText: 'Unit',
                    hintStyle: TextStyle(color: mutedColor))),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty) {
      await Store.instance.editWorkout(w.id, name.text, unit.text);
      refresh();
    }
  }
}

// ---------------- Log wizard ----------------

class LogScreen extends StatefulWidget {
  final int catId;
  final String? date;
  const LogScreen({super.key, required this.catId, this.date});
  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  int _step = 0;
  final Map<int, String> _values = {};
  late final String _date;
  late final TextEditingController _input;

  @override
  void initState() {
    super.initState();
    _date = widget.date ?? todayStr();
    _input = TextEditingController();
    final s = Store.instance;
    for (final e in s.logsForDate(_date)) {
      final w = s.workouts.where((x) => x.id == e.workoutId).firstOrNull;
      if (w != null && w.categoryId == widget.catId) {
        _values[e.workoutId] = e.value % 1 == 0
            ? e.value.toInt().toString()
            : e.value.toString();
      }
    }
    _syncInput();
  }

  void _syncInput() {
    final ws = Store.instance.workouts
        .where((w) => w.categoryId == widget.catId)
        .toList();
    if (ws.isNotEmpty) _input.text = _values[ws[_step].id] ?? '';
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ws = Store.instance.workouts
        .where((w) => w.categoryId == widget.catId)
        .toList();
    if (ws.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
      return const Scaffold(body: SizedBox.shrink());
    }
    final w = ws[_step];
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
          title: Text('LOG  •  $_date'),
          backgroundColor: const Color(0xFF150E28),
          foregroundColor: Colors.white),
      body: pageBackground(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            auraCard(children: [
              Text('Workout ${_step + 1} of ${ws.length}',
                  style: const TextStyle(color: mutedColor, fontSize: 14)),
              Text(w.name,
                  style: TextStyle(
                      color: textColor,
                      fontSize: 26,
                      fontWeight: FontWeight.bold)),
              Text('Enter count in ${w.unit} — number keyboard only',
                  style: const TextStyle(color: mutedColor, fontSize: 15)),
              const SizedBox(height: 10),
              TextField(
                controller: _input,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(color: textColor, fontSize: 22),
                decoration: InputDecoration(
                  hintText: '${w.name} (${w.unit})',
                  hintStyle: const TextStyle(color: mutedColor),
                  filled: true,
                  fillColor: cardColor,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _step > 0
                          ? () {
                              _values[w.id] = _input.text;
                              setState(() {
                                _step--;
                                _syncInput();
                              });
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: ghostColor,
                          foregroundColor: Colors.white),
                      child: const Text('Previous'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        _values.remove(w.id);
                        if (_step < ws.length - 1) {
                          setState(() {
                            _step++;
                            _syncInput();
                          });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: ghostColor,
                          foregroundColor: Colors.white),
                      child: const Text('Skip'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _step < ws.length - 1
                        ? ElevatedButton(
                            onPressed: () {
                              if (_input.text.trim().isNotEmpty) {
                                _values[w.id] = _input.text;
                                setState(() {
                                  _step++;
                                  _syncInput();
                                });
                              }
                            },
                            style: ElevatedButton.styleFrom(
                                backgroundColor: accentColor,
                                foregroundColor: Colors.white),
                            child: const Text('Next  →'),
                          )
                        : ElevatedButton(
                            onPressed: () async {
                              _values[w.id] = _input.text;
                              final map = <int, double>{};
                              _values.forEach((id, s) {
                                final v = double.tryParse(s.trim());
                                if (v != null) map[id] = v;
                              });
                              await Store.instance.saveDayLog(map, _date);
                              if (mounted) Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                                backgroundColor: accentColor,
                                foregroundColor: Colors.white),
                            child: const Text('Save All'),
                          ),
                  ),
                ],
              ),
            ]),
            const Text(
                'Previous lets you fix the last workout. Save only saves numbers you entered.',
                style: TextStyle(color: mutedColor, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

// ---------------- Coach ----------------

class CoachScreen extends StatefulWidget {
  const CoachScreen({super.key});
  @override
  State<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends State<CoachScreen> {
  final List<(bool, String)> _chat = [];
  final _input = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = Store.instance;
    final online = !s.settings.geminiKey.isBlank;
    final animOn = s.settings.animationOn;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Gradient header banner, matching the Progress/Categories headers.
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [accentColor, const Color(0xFFC026D3)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: accentColor.withOpacity(0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 6)),
            ],
          ),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('AI COACH',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2)),
                    SizedBox(height: 4),
                    Text('Your personal fitness assistant.',
                        style: TextStyle(
                            color: Colors.white70, fontSize: 14)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.psychology,
                    color: Colors.white, size: 26),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // Coach status card: Offline / Online indicator + real insights.
        // Status texts and the insights text are unchanged — only styling.
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: accentColor.withOpacity(0.22),
                  blurRadius: 18,
                  offset: const Offset(0, 6)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        accentColor,
                        const Color(0xFFC026D3)
                      ]),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.smart_toy,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                        online
                            ? 'Online Gemini chatbot is ready (key saved on this phone).'
                            : 'Offline coach is working now. Add a Gemini key in Settings for the real online chatbot.',
                        style: const TextStyle(
                            color: mutedColor, fontSize: 15)),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: online
                          ? Colors.green.withOpacity(0.2)
                          : ghostColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: online
                                ? Colors.greenAccent
                                : accentColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(online ? 'ONLINE' : 'OFFLINE',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(offlineCoachText(),
                  style: TextStyle(color: textColor, fontSize: 16)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (!online)
          ghostBtn('How to get a Gemini API key  →', () {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ApiStepsScreen()));
          }),
        if (!online) const SizedBox(height: 10),
        // Chat card with proper bubbles. Text always sits on a bubble /
        // card background, never bare over a busy gallery image.
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: accentColor.withOpacity(0.18),
                  blurRadius: 16,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_chat.isEmpty)
                const Text('Ask coach anything about your workouts below.',
                    style: TextStyle(color: mutedColor, fontSize: 15)),
              for (int i = 0; i < _chat.length; i++)
                _chatBubble(_chat[i].$1, _chat[i].$2, animOn,
                    key: ValueKey('msg$i-${_chat[i].$2.hashCode}')),
              if (_busy)
                _chatBubble(false, 'Aura Coach: thinking…', false,
                    showLabel: false),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // Input + Send row. Send behaviour is unchanged: empty input
        // and taps while busy are ignored, input clears on send.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _input,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  hintText: 'Ask coach, e.g. why is my handstand dropping?',
                  hintStyle: const TextStyle(color: mutedColor),
                  filled: true,
                  fillColor: cardColor,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 16),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide:
                          BorderSide(color: accentColor, width: 1.5)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () async {
                final q = _input.text.trim();
                if (q.isEmpty || _busy) return;
                setState(() {
                  _chat.add((true, q));
                  _input.clear();
                  _busy = true;
                });
                final summary =
                    'Categories: ${s.categories.length}, Workouts: ${s.workouts.length}, Logs: ${s.logs.length}. ' +
                        s.workouts
                            .map((w) =>
                                '${w.name}: ${workoutSeries(w.id).take(3).map((e) => '${e.$1}=${e.$2}').join(', ')}')
                            .join('; ');
                final reply = !s.settings.geminiKey.isBlank
                    ? await geminiReply(s.settings.geminiKey, q, summary)
                    : offlineChatReply(q);
                if (mounted) {
                  setState(() {
                    _chat.add((false, reply));
                    _busy = false;
                  });
                }
              },
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    accentColor,
                    const Color(0xFFC026D3)
                  ]),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: accentColor.withOpacity(0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4)),
                  ],
                ),
                child: const Icon(Icons.send, color: Colors.white),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  /// One chat bubble. User messages go right on an accent gradient;
  /// coach messages go left on a ghost-tone bubble. When animations are
  /// on, new messages fade/slide in; otherwise they appear directly.
  /// The thinking indicator is a labelless coach bubble whose text is
  /// exactly 'Aura Coach: thinking…' as before.
  Widget _chatBubble(bool isUser, String text, bool animOn,
      {Key? key, bool showLabel = true}) {
    final bubble = Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          gradient: isUser
              ? LinearGradient(
                  colors: [accentColor, const Color(0xFFC026D3)])
              : null,
          color: isUser ? null : ghostColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showLabel)
              Text(isUser ? 'You' : 'Aura Coach',
                  style: TextStyle(
                      color: isUser
                          ? Colors.white.withOpacity(0.85)
                          : mutedColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5)),
            if (showLabel) const SizedBox(height: 3),
            Text(text,
                style: TextStyle(
                    color: !showLabel
                        ? mutedColor
                        : isUser
                            ? Colors.white
                            : textColor,
                    fontSize: 16)),
          ],
        ),
      ),
    );
    if (!animOn) return Container(key: key, child: bubble);
    return TweenAnimationBuilder<double>(
      key: key,
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 250),
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
            offset: Offset(0, 8 * (1 - v)), child: child),
      ),
      child: bubble,
    );
  }
}

extension _IsBlank on String {
  bool get isBlank => trim().isEmpty;
}

// ---------------- Settings ----------------

// ---------------- Settings (premium Material 3 redesign, v9.8) ----------------
// Presentation only: every tap/save/navigate below runs the exact logic the
// old Settings page ran. No setting key, default, or data model changed.

/// Gradient button used by the Settings page (gallery pick + API key save).
Widget _gradientBtn(
    {required IconData icon,
    required String label,
    required VoidCallback onTap}) {
  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [accentColor, const Color(0xFFC026D3)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: accentColor.withOpacity(0.35),
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    ),
  );
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final s = Store.instance.settings;
    final themes = {
      'Raiden Purple': ['#0D0A1A', '#FFFFFF', '#A855F7'],
      'Crimson Storm': ['#1A0A0A', '#FFFFFF', '#E63946'],
      'Ocean Wave': ['#0A1E2E', '#FFFFFF', '#00B4D8'],
      'Golden Thunder': ['#1A1400', '#FFF8E1', '#FFB703'],
      'Midnight Black': ['#000000', '#FFFFFF', '#888888'],
      'Forest': ['#0A1F14', '#FFFFFF', '#2ECC71'],
    };
    Future<void> applyPreset(String name, List<String> hexes) async {
      s.themePreset = name;
      s.bgHex = hexes[0];
      s.textHex = hexes[1];
      s.accentHex = hexes[2];
      await Store.instance.save();
      _refresh();
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Gradient header banner, matching the redesigned Home, Categories,
        // Progress and Coach pages. No nested Scaffold/AppBar — the Shell
        // in main.dart already wraps this tab body in pageBackground +
        // the 5-tab bottom nav.
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [accentColor, const Color(0xFFC026D3)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: accentColor.withOpacity(0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 6)),
            ],
          ),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SETTINGS',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2)),
                    SizedBox(height: 4),
                    Text('Make Aura yours.',
                        style:
                            TextStyle(color: Colors.white70, fontSize: 14)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.settings,
                    color: Colors.white, size: 26),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _settingsSection(
          icon: Icons.palette_outlined,
          title: 'THEME PRESETS',
          children: [
            for (final e in themes.entries)
              _presetCard(
                name: e.key,
                hexes: e.value,
                selected: s.themePreset == e.key,
                onTap: () => applyPreset(e.key, e.value),
              ),
          ],
        ),
        _settingsSection(
          icon: Icons.color_lens_outlined,
          title: 'BACKGROUND COLOUR',
          children: [
            _swatchRow(s.bgHex, (h) async {
              s.bgHex = h;
              await Store.instance.save();
              _refresh();
            }),
          ],
        ),
        _settingsSection(
          icon: Icons.text_fields,
          title: 'TEXT COLOUR',
          children: [
            _swatchRow(s.textHex, (h) async {
              s.textHex = h;
              await Store.instance.save();
              _refresh();
            }),
          ],
        ),
        _settingsSection(
          icon: Icons.colorize_outlined,
          title: 'ACCENT COLOUR',
          children: [
            _swatchRow(s.accentHex, (h) async {
              s.accentHex = h;
              await Store.instance.save();
              _refresh();
            }),
          ],
        ),
        _settingsSection(
          icon: Icons.image_outlined,
          title: 'BACKGROUND IMAGE',
          children: [
            _bgOptionRow(
              icon: Icons.gradient,
              label: 'Raiden Gradient',
              selected: s.bgPreset == 'Raiden Gradient',
              onTap: () async {
                s.bgPreset = 'Raiden Gradient';
                await Store.instance.save();
                _refresh();
              },
            ),
            _bgOptionRow(
              icon: Icons.bolt,
              label: 'Storm Gradient',
              selected: s.bgPreset == 'Storm Gradient',
              onTap: () async {
                s.bgPreset = 'Storm Gradient';
                await Store.instance.save();
                _refresh();
              },
            ),
            _bgOptionRow(
              icon: Icons.crop_square,
              label: 'Plain',
              selected: s.bgPreset == 'Plain',
              onTap: () async {
                s.bgPreset = 'Plain';
                await Store.instance.save();
                _refresh();
              },
            ),
            const SizedBox(height: 2),
            _gradientBtn(
              icon: Icons.photo_library_outlined,
              label: 'Choose from Gallery',
              onTap: () async {
                try {
                  final path =
                      await _urlChannel.invokeMethod<String>('pickImage');
                  if (path != null && path.isNotEmpty) {
                    s.bgImageUri = path;
                    s.bgPreset = 'Gallery';
                    await Store.instance.save();
                    _refresh();
                  }
                } catch (_) {}
              },
            ),
            if (s.bgImageUri.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text('Gallery photo is set as your background.',
                  style: TextStyle(color: mutedColor, fontSize: 13)),
              const SizedBox(height: 10),
              _bgOptionRow(
                icon: Icons.delete_outline,
                label: 'Clear gallery image',
                selected: false,
                onTap: () async {
                  s.bgImageUri = '';
                  s.bgPreset = 'Raiden Gradient';
                  await Store.instance.save();
                  _refresh();
                },
              ),
            ],
          ],
        ),
        _settingsSection(
          icon: Icons.opacity_outlined,
          title: 'OPACITY',
          children: [
            const Text(
                'Background image stays full opacity — these fade colours and boxes so it shows through.',
                style: TextStyle(color: mutedColor, fontSize: 14)),
            const SizedBox(height: 4),
            _opacitySlider('Background colour', Icons.wallpaper_outlined,
                s.bgOpacity, (v) async {
              s.bgOpacity = v;
              await Store.instance.save();
              _refresh();
            }),
            _opacitySlider('Text', Icons.text_fields, s.textOpacity,
                (v) async {
              s.textOpacity = v;
              await Store.instance.save();
              _refresh();
            }),
            _opacitySlider('Cards / boxes', Icons.dashboard_outlined,
                s.cardOpacity, (v) async {
              s.cardOpacity = v;
              await Store.instance.save();
              _refresh();
            }),
          ],
        ),
        _settingsSection(
          icon: Icons.tune_outlined,
          title: 'EFFECTS',
          children: [
            _switchRow(
              icon: Icons.bolt,
              title: 'Lightning animation',
              value: s.animationOn,
              onChanged: (v) async {
                s.animationOn = v;
                await Store.instance.save();
                _refresh();
              },
            ),
            const SizedBox(height: 10),
            _switchRow(
              icon: Icons.local_fire_department,
              title: 'Roast mode (harsh coach)',
              value: s.roastOn,
              onChanged: (v) async {
                s.roastOn = v;
                await Store.instance.save();
                _refresh();
              },
            ),
          ],
        ),
        _settingsSection(
          icon: Icons.key_outlined,
          title: 'GEMINI AI — REAL CHATBOT',
          children: [
            const Text(
                'Paste your Gemini API key here. It stays only on this phone.',
                style: TextStyle(color: mutedColor, fontSize: 15)),
            const SizedBox(height: 12),
            _KeyField(
              initial: s.geminiKey,
              onSave: (v) async {
                s.geminiKey = v.trim();
                await Store.instance.save();
                _refresh();
              },
            ),
            const SizedBox(height: 10),
            ghostBtn('How to get a Gemini API key  →', () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ApiStepsScreen()));
            }),
          ],
        ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AboutScreen()));
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black45,
                      blurRadius: 8,
                      offset: Offset(0, 3))
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.info_outlined,
                        color: accentColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('About Aura',
                        style: TextStyle(
                            color: textColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                  ),
                  const Icon(Icons.chevron_right, color: mutedColor),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  /// One elegant section card with an icon + letter-spaced title.
  Widget _settingsSection(
      {required IconData icon,
      required String title,
      required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        color: mutedColor,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  /// Theme preset preview card: three colour dots + name + selected check.
  Widget _presetCard(
      {required String name,
      required List<String> hexes,
      required bool selected,
      required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ghostColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: selected ? accentColor : Colors.white12,
                  width: selected ? 2 : 1),
            ),
            child: Row(
              children: [
                for (final h in hexes)
                  Container(
                    width: 26,
                    height: 26,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: parseHex(h),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24),
                    ),
                  ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(name,
                      style: TextStyle(
                          color: textColor,
                          fontSize: 16,
                          fontWeight: selected
                              ? FontWeight.bold
                              : FontWeight.normal)),
                ),
                if (selected)
                  Icon(Icons.check_circle, color: accentColor, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Selectable background-image option row (same labels/logic as before).
  Widget _bgOptionRow(
      {required IconData icon,
      required String label,
      required bool selected,
      required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: ghostColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: selected ? accentColor : Colors.white12,
                  width: selected ? 2 : 1),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: accentColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(label,
                      style: TextStyle(
                          color: textColor,
                          fontSize: 16,
                          fontWeight: selected
                              ? FontWeight.bold
                              : FontWeight.normal)),
                ),
                if (selected)
                  Icon(Icons.check_circle, color: accentColor, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Opacity slider row: icon + label + prominent % pill + slider.
  /// No fixed label width — the row flexes, so narrow screens stay intact.
  Widget _opacitySlider(String label, IconData icon, double value,
      Future<void> Function(double) set) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: accentColor, size: 20),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(label,
                          style:
                              TextStyle(color: textColor, fontSize: 15)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: ghostColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('${(value * 100).round()}%',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                Slider(
                  value: value.clamp(0.0, 1.0),
                  min: 0,
                  max: 1,
                  divisions: 20,
                  activeColor: accentColor,
                  onChanged: (v) => set(v),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Switch row card: icon + label + Switch (same behaviour as before).
  Widget _switchRow(
      {required IconData icon,
      required String title,
      required bool value,
      required Future<void> Function(bool) onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: ghostColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accentColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title,
                style: TextStyle(color: textColor, fontSize: 16)),
          ),
          Switch(
            value: value,
            activeColor: accentColor,
            onChanged: (v) => onChanged(v),
          ),
        ],
      ),
    );
  }

  /// The exact same 11 colour swatches as before, now with an accent ring
  /// on the currently selected colour. Wrap keeps narrow screens intact.
  Widget _swatchRow(
      String current, Future<void> Function(String) set) {
    const hexes = [
      '#0D0A1A',
      '#000000',
      '#1A0A0A',
      '#0A1E2E',
      '#FFFFFF',
      '#FFF8E1',
      '#A855F7',
      '#E63946',
      '#00B4D8',
      '#FFB703',
      '#2ECC71'
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final h in hexes)
          InkWell(
            onTap: () => set(h),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: parseHex(h),
                shape: BoxShape.circle,
                border: Border.all(
                    color: current == h ? accentColor : Colors.white24,
                    width: current == h ? 3 : 1),
              ),
            ),
          ),
      ],
    );
  }
}

class _KeyField extends StatefulWidget {
  final String initial;
  final Future<void> Function(String) onSave;
  const _KeyField({required this.initial, required this.onSave});
  @override
  State<_KeyField> createState() => _KeyFieldState();
}

class _KeyFieldState extends State<_KeyField> {
  late final TextEditingController _c;
  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: _c,
          obscureText: true,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            hintText: 'Gemini API key',
            hintStyle: const TextStyle(color: mutedColor),
            filled: true,
            fillColor: ghostColor,
            prefixIcon: const Icon(Icons.key_outlined, color: mutedColor),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: accentColor, width: 1.5)),
          ),
        ),
        const SizedBox(height: 12),
        _gradientBtn(
          icon: Icons.save_outlined,
          label: 'Save API Key',
          onTap: () => widget.onSave(_c.text),
        ),
      ],
    );
  }
}

// ---------------- About / API steps ----------------

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
          title: const Text('ABOUT AURA'),
          backgroundColor: const Color(0xFF150E28),
          foregroundColor: Colors.white),
      body: pageBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accentColor, const Color(0xFFC026D3)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.black45,
                          blurRadius: 12,
                          offset: Offset(0, 4))
                    ],
                  ),
                  child: const Icon(Icons.bolt, color: Colors.white, size: 34),
                ),
                const SizedBox(height: 24),
                Text('About Aura',
                    style: TextStyle(
                        color: textColor,
                        fontSize: 28,
                        fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Text(
                    'Aura is a workout tracker with a Raiden-inspired purple lightning theme. The theme is fan-inspired, not official Genshin Impact art.',
                    style: TextStyle(
                        color: textColor, fontSize: 16, height: 1.5),
                    textAlign: TextAlign.center),
                const SizedBox(height: 32),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accentColor, const Color(0xFFC026D3)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.black45,
                          blurRadius: 10,
                          offset: Offset(0, 4))
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () async {
                        if (!await openUrl(
                            'https://github.com/oxsh0gunX')) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text("Couldn't open the link")),
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 16),
                        child: Row(
                          children: [
                            const Icon(Icons.code,
                                color: Colors.white, size: 22),
                            const SizedBox(width: 14),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('GitHub',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                                SizedBox(height: 2),
                                Text('github.com/oxsh0gunX',
                                    style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: accentColor.withAlpha(90)),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () async {
                        if (!await mailTo('safvanmbn@gmail.com')) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text("Couldn't open email")),
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 16),
                        child: Row(
                          children: [
                            Icon(Icons.email_outlined,
                                color: accentColor, size: 22),
                            const SizedBox(width: 14),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Email',
                                    style: TextStyle(
                                        color: textColor,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 2),
                                const Text('safvanmbn@gmail.com',
                                    style: TextStyle(
                                        color: mutedColor, fontSize: 13)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ApiStepsScreen extends StatelessWidget {
  const ApiStepsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    const steps = [
      "1. Tap the link below. It opens Google AI Studio in your browser.",
      "2. Sign in with your Google account, if asked.",
      "3. Tap 'Create API key'.",
      "4. Copy the key. It looks like a long mix of letters and numbers.",
      "5. Come back to Aura → Settings → Gemini AI, paste the key, tap Save API Key.",
      "6. Now open AI Coach and ask a question — it will work online.",
    ];
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
          title: const Text('GET A GEMINI KEY'),
          backgroundColor: const Color(0xFF150E28),
          foregroundColor: Colors.white),
      body: pageBackground(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            for (final st in steps)
              auraCard(children: [
                Text(st, style: TextStyle(color: textColor, fontSize: 16)),
              ]),
            purpleBtn('Open Google AI Studio  →', () async {
              if (!await openUrl('https://aistudio.google.com/app/apikey')) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Couldn't open the link")),
                );
              }
            }),
            const SizedBox(height: 14),
            const Text(
                'Important: Your key stays only on your phone. Never share it in a chat or screenshot. If someone else gets it, delete it in AI Studio and create a new one.',
                style: TextStyle(color: mutedColor, fontSize: 15)),
            const SizedBox(height: 8),
            const Text(
                'No key? No problem — the offline coach in Aura still works, with no internet and no key.',
                style: TextStyle(color: mutedColor, fontSize: 15)),
          ],
        ),
      ),
    );
  }
}
