import 'package:flutter/material.dart';
import 'store.dart';
import 'coach.dart';
import 'chart.dart';
import 'widgets.dart';
import 'screens.dart';

void main() {
  runApp(const AuraApp());
}

// v9.15: animated-picture splash. Native video failed three times on the
// user's phone (v9.12 VideoView overlay, v9.13 SplashActivity VideoView,
// v9.14 TextureView MediaPlayer), so Android MediaPlayer is abandoned
// entirely. The splash is now an animated WebP played by Flutter's own
// image pipeline (the same pipeline that already renders the icons and
// launcher portrait). The clip is muted anyway, so nothing is lost.
// The splash shows once on cold start: _showSplash starts true and is
// set false by a 2s timer (guarded by `mounted`, and the timer fires even
// if the image fails to load, so the app can never get stuck here). A
// warm resume keeps the existing widget state, so it shows Home directly
// with no replay. Back from Home cannot return to the splash: it is
// plain startup state, not a route.
class AuraApp extends StatefulWidget {
  const AuraApp({super.key});
  @override
  State<AuraApp> createState() => _AuraAppState();
}

class _AuraAppState extends State<AuraApp> {
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) setState(() => _showSplash = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aura',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D0A1A),
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFA855F7), brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: _showSplash
          ? const SplashScreen()
          : FutureBuilder<void>(
              future: Store.instance.init(),
              builder: (ctx, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Scaffold(
                    backgroundColor: Color(0xFF0D0A1A),
                    body: Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFFA855F7))),
                  );
                }
                return const Shell();
              },
            ),
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF150E28),
      body: SizedBox.expand(
        child: Image.asset(
          'assets/videos/splash.webp',
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        ),
      ),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _index = 0;
  void goTab(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomeScreen(goTab: goTab),
      const CategoriesScreen(),
      const ProgressScreen(),
      const CoachScreen(),
      const SettingsScreen(),
    ];
    return Scaffold(
      backgroundColor: bgColor,
      body: pageBackground(
        child: IndexedStack(index: _index, children: pages),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: goTab,
        backgroundColor: const Color(0xFF150E28),
        selectedItemColor: accentColor,
        unselectedItemColor: mutedColor,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.folder), label: 'Categories'),
          BottomNavigationBarItem(icon: Icon(Icons.show_chart), label: 'Progress'),
          BottomNavigationBarItem(icon: Icon(Icons.psychology), label: 'Coach'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

// ---------------- Home dashboard (v9.3 premium redesign) ----------------

/// v9.10: body regions with at least one logged entry for a mapped
/// category. Reads the existing Store logs/workouts/categories only;
/// no schema change, no new field. Region mapping lives in
/// regionsForCategoryName() in chart.dart.
Set<BodyRegion> trainedBodyRegions() {
  final s = Store.instance;
  final workoutCategory = {for (final w in s.workouts) w.id: w.categoryId};
  final loggedCategoryIds = <int>{};
  for (final l in s.logs) {
    final cid = workoutCategory[l.workoutId];
    if (cid != null) loggedCategoryIds.add(cid);
  }
  final trained = <BodyRegion>{};
  for (final c in s.categories) {
    if (loggedCategoryIds.contains(c.id)) {
      trained.addAll(regionsForCategoryName(c.name));
    }
  }
  return trained;
}
// Same data, same handlers, same navigation as v9.2 — only the presentation
// changed: gradient cards, section headers with icons, a gradient Start
// Workout button, a tappable streak pill, and a delete-confirmation dialog.
// All colours derive from the user's Settings (accentColor/textColor), so
// a theme change still recolours the homepage. No artwork, no photos, no
// copied art: decoration is gradients + thin code-drawn lightning lines.

class HomeScreen extends StatefulWidget {
  final void Function(int) goTab;
  const HomeScreen({super.key, required this.goTab});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  ChartType _type = ChartType.snake;
  GraphPeriod _period = GraphPeriod.day;
  void _refresh() => setState(() {});

  void _openLog(BuildContext context, int catId) {
    Navigator.push(context,
            MaterialPageRoute(builder: (_) => LogScreen(catId: catId)))
        .then((_) => _refresh());
  }

  void _openExercises(BuildContext context, int catId) {
    Navigator.push(context,
            MaterialPageRoute(builder: (_) => ExercisesScreen(catId: catId)))
        .then((_) => _refresh());
  }

  // Shared confirmation (widgets.dart) — same dialog as the Categories page.
  Future<void> _confirmDelete(BuildContext context, Category cat) async {
    await confirmDeleteCategory(context, cat, _refresh);
  }

  @override
  Widget build(BuildContext context) {
    final s = Store.instance;
    final totalsAll = dayTotalsOverall();
    final best = totalsAll.isEmpty
        ? 0.0
        : totalsAll.map((d) => d.total).reduce((a, b) => a > b ? a : b);
    final today = todayStr();
    final todayLogs = s.logs.where((l) => l.date == today).toList();
    final todayTotal =
        todayLogs.fold<double>(0, (a, l) => a + l.value);
    final todayExercises = todayLogs.map((l) => l.workoutId).toSet().length;
    final todayCats = todayLogs
        .map((e) =>
            s.workouts.where((w) => w.id == e.workoutId).firstOrNull?.categoryId)
        .whereType<int>()
        .toSet()
        .length;
    final streak = streakDays();
    final goalPct =
        best > 0 ? (todayTotal / best * 100).toInt().clamp(0, 100) : 0;

    final mon = weekMonday(DateTime.now());
    final thisWeekTotal = weekTotal(mon);
    final lastWeekTotal = weekTotal(mon.subtract(const Duration(days: 7)));
    final weekDates = thisWeekDates().map(fmtDate).toSet();
    final weekEntries =
        s.logs.where((l) => weekDates.contains(l.date)).length;
    final loggedDates = s.logs.map((l) => l.date).toSet();

    final (seriesAll, labels) = periodSeries(_period);
    final hasGraph = seriesAll.any((e) => e.$2.isNotEmpty);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        // 1. Header banner: gradient + lightning motif (code-drawn, no photo)
        Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(cardColor, accentColor, 0.35) ?? cardColor,
                cardColor,
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accentColor.withAlpha(60)),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(painter: _LightningPainter(accentColor)),
              ),
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('A U R A',
                          style: TextStyle(
                              color: textColor,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 6)),
                      const SizedBox(height: 2),
                      const Text('Workout  •  Track  •  Improve',
                          style: TextStyle(
                              color: mutedColor,
                              fontSize: 12,
                              letterSpacing: 1.2)),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    decoration: BoxDecoration(
                      color: accentColor.withAlpha(40),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      onPressed: () => widget.goTab(4),
                      icon: const Icon(Icons.settings, color: Colors.white),
                      tooltip: 'Settings',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. Greeting + tappable streak pill
        Text('Hey! 💪',
            style: TextStyle(
                color: textColor, fontSize: 28, fontWeight: FontWeight.bold)),
        const Text("Let's crush your goals today! 🔥",
            style: TextStyle(color: mutedColor, fontSize: 16)),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: InkWell(
            onTap: () => widget.goTab(2),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: accentColor.withAlpha(35),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: accentColor.withAlpha(80)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.local_fire_department,
                      color: accentColor, size: 16),
                  const SizedBox(width: 6),
                  Text(
                      streak > 0
                          ? '$streak day streak  ›'
                          : 'No streak yet — log today to start one  ›',
                      style: TextStyle(
                          color: accentColor,
                          fontSize: 14,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 3. Daily Goal card
        _premiumCard(children: [
          Row(
            children: [
              _iconChip(Icons.track_changes),
              const SizedBox(width: 8),
              const Text('DAILY GOAL',
                  style: TextStyle(
                      color: mutedColor,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5)),
              const Spacer(),
              const Text('vs your best day',
                  style: TextStyle(color: mutedColor, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 140,
                height: 140,
                child: CustomPaint(
                    painter: GoalRingPainter(goalPct, accentColor)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Today',
                        style: TextStyle(color: mutedColor, fontSize: 13)),
                    Text(fmtNum(todayTotal),
                        style: TextStyle(
                            color: textColor,
                            fontSize: 26,
                            fontWeight: FontWeight.bold)),
                    Text(
                        best > 0
                            ? 'Best day: ${fmtNum(best)} total'
                            : 'Log Day 1 to set your best day',
                        style:
                            const TextStyle(color: mutedColor, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _iconProgressRow(Icons.flag, "Today's total", fmtNum(todayTotal),
              best > 0 ? todayTotal / best : 0),
          _iconProgressRow(Icons.fitness_center, 'Exercises logged today',
              '$todayExercises',
              s.workouts.isNotEmpty ? todayExercises / s.workouts.length : 0),
          _iconProgressRow(Icons.layers, 'Categories logged today',
              '$todayCats',
              s.categories.isNotEmpty ? todayCats / s.categories.length : 0),
        ]),

        // 4. Three stat cards
        Row(
          children: [
            _statCard(Icons.calendar_month, 'THIS WEEK', '$weekEntries'),
            const SizedBox(width: 8),
            _statCard(Icons.local_fire_department, 'STREAK', '$streak'),
            const SizedBox(width: 8),
            _statCard(Icons.emoji_events, 'BEST DAY', fmtNum(best)),
          ],
        ),
        const SizedBox(height: 16),

        // 5. This Week calendar
        _premiumCard(children: [
          _cardTitle(Icons.calendar_month, 'THIS WEEK'),
          const SizedBox(height: 12),
          Row(
            children: [
              for (int i = 0; i < 7; i++)
                Expanded(child: _weekCircle(i, loggedDates, today)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
              thisWeekTotal == 0 && lastWeekTotal == 0
                  ? 'Log Day 1 — your week starts here.'
                  : lastWeekTotal == 0
                      ? 'Total this week: ${fmtNum(thisWeekTotal)} — new this week!'
                      : (() {
                          final pct = ((thisWeekTotal - lastWeekTotal) /
                                  lastWeekTotal *
                                  100)
                              .toInt();
                          return 'Total this week: ${fmtNum(thisWeekTotal)}  •  ${pct >= 0 ? '+$pct%' : '$pct%'} vs last week';
                        })(),
              style: const TextStyle(color: mutedColor, fontSize: 14)),
        ]),

        // 6. Muscle Focus
        _premiumCard(children: [
          _cardTitle(Icons.accessibility_new, 'MUSCLE FOCUS  •  THIS WEEK'),
          const SizedBox(height: 8),
          // v9.10 body-map figure (user-picked preview 2: faint ->
          // green). The figure IS the graph: a region turns solid
          // green once any mapped category has a logged entry, and
          // stays a faint ghost outline until then. Never red. The
          // category % breakdown below is unchanged.
          Center(
            child: CustomPaint(
              size: const Size(200, 230),
              painter: BodyMapPainter(
                trained: trainedBodyRegions(),
                faintColor: textColor.withOpacity(0.18),
              ),
            ),
          ),
          if (s.logs.isEmpty)
            const Text(
                'No focus yet — log Day 1 and your categories will show here as percentages.',
                style: TextStyle(color: mutedColor, fontSize: 15))
          else ...[
            for (final sh in categoryShares())
              progressRow(sh.$1, '${sh.$3}%  •  ${fmtNum(sh.$2)} total',
                  sh.$3 / 100),
            const Text(
                'Your own categories, shown as share of everything you logged.',
                style: TextStyle(color: mutedColor, fontSize: 13)),
          ],
        ]),

        // 7. Progress Graph
        _premiumCard(children: [
          _cardTitle(Icons.show_chart, 'PROGRESS GRAPH'),
          const SizedBox(height: 12),
          Wrap(
            children: [
              _pill('Day', _period == GraphPeriod.day,
                  () => setState(() => _period = GraphPeriod.day)),
              _pill('Week', _period == GraphPeriod.week,
                  () => setState(() => _period = GraphPeriod.week)),
              _pill('Month', _period == GraphPeriod.month,
                  () => setState(() => _period = GraphPeriod.month)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            children: [
              _pill('Snake', _type == ChartType.snake,
                  () => setState(() => _type = ChartType.snake)),
              _pill('Line', _type == ChartType.line,
                  () => setState(() => _type = ChartType.line)),
              _pill('Bars', _type == ChartType.bar,
                  () => setState(() => _type = ChartType.bar)),
              _pill('Area', _type == ChartType.area,
                  () => setState(() => _type = ChartType.area)),
            ],
          ),
          const SizedBox(height: 8),
          if (hasGraph) ...[
            chartBox(seriesAll, _type, labels),
            Text(seriesAll.map((e) => e.$1).join('   •   '),
                style: const TextStyle(color: mutedColor, fontSize: 13)),
            Text(
                _period == GraphPeriod.day
                    ? 'Day 1 = your first logged day.'
                    : _period == GraphPeriod.week
                        ? 'Week 1 = your first logged week (totals summed per week).'
                        : 'Totals summed per month.',
                style: const TextStyle(color: mutedColor, fontSize: 13)),
          ] else
            const Row(
              children: [
                Icon(Icons.bar_chart, color: mutedColor, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Log your first day to see your graph here.',
                      style: TextStyle(color: mutedColor, fontSize: 15)),
                ),
              ],
            ),
        ]),

        // 8. Your Categories (first 3, vertical cards for readability)
        _sectionHeader(Icons.layers, 'YOUR CATEGORIES', 'See All  →',
            () => widget.goTab(1)),
        if (s.categories.isEmpty)
          _premiumCard(children: const [
            Text('No categories yet.',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text('Create your own — nothing is preloaded.',
                style: TextStyle(color: mutedColor, fontSize: 15)),
          ]),
        for (final cat in s.categories.take(3))
          Builder(builder: (_) {
            final ws = s.workouts.where((w) => w.categoryId == cat.id).toList();
            final todayCatTotal = ws.fold<double>(
                0,
                (a, w) =>
                    a +
                    s.logs
                        .where((l) => l.workoutId == w.id && l.date == today)
                        .fold<double>(0, (b, l) => b + l.value));
            return _premiumCard(children: [
              Row(
                children: [
                  categoryIconChip(cat,
                      bg: accentColor.withAlpha(35), fg: accentColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(cat.name,
                            style: TextStyle(
                                color: textColor,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                        Text(
                            '${ws.length} exercises  •  Today: ${fmtNum(todayCatTotal)}  •  ${dayTotalsForCategory(cat.id).length} days logged',
                            style: const TextStyle(
                                color: mutedColor, fontSize: 13)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _confirmDelete(context, cat),
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
                        onPressed: ws.isEmpty
                            ? null
                            : () => _openLog(context, cat.id),
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
                        onPressed: () => _openExercises(context, cat.id),
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
            ]);
          }),
        _dashedAddCard(() => addCategoryDialog(context, _refresh)),
        const SizedBox(height: 6),

        // 9. Progress Stream (latest 3)
        _sectionHeader(Icons.list_alt, 'PROGRESS STREAM', 'See Full  →',
            () => widget.goTab(2)),
        if (totalsAll.isEmpty)
          _premiumCard(children: const [
            Row(
              children: [
                Icon(Icons.calendar_today, color: mutedColor, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Your days will appear here, newest first.',
                      style: TextStyle(color: mutedColor, fontSize: 15)),
                ),
              ],
            ),
          ]),
        for (final d in totalsAll.reversed.take(3))
          _premiumCard(children: [
            InkWell(
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => DayDetailScreen(date: d.date))).then((_) => _refresh());
              },
              borderRadius: BorderRadius.circular(20),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('DAY ${d.day}',
                          style: TextStyle(
                              color: textColor,
                              fontSize: 19,
                              fontWeight: FontWeight.bold)),
                      Text(d.date,
                          style: const TextStyle(
                              color: mutedColor, fontSize: 14)),
                    ],
                  ),
                  const Spacer(),
                  Text(fmtNum(d.total),
                      style: TextStyle(
                          color: accentColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, color: mutedColor),
                ],
              ),
            ),
          ]),

        // 10. Coach Says (with a beautiful empty state, not hidden)
        _sectionHeader(Icons.psychology, 'COACH SAYS', null, null),
        _premiumCard(children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.chat_bubble_outline,
                  color: accentColor, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                    s.logs.isNotEmpty
                        ? offlineCoachText()
                        : 'Start logging to get personalized tips from your coach.',
                    style: TextStyle(color: textColor, fontSize: 15)),
              ),
            ],
          ),
        ]),

        // 11. Big gradient Start Workout button
        _gradientBtn('Start Workout', () {
          Category? first;
          for (final cat in s.categories) {
            if (s.workouts.any((w) => w.categoryId == cat.id)) {
              first = cat;
              break;
            }
          }
          if (first != null) {
            _openLog(context, first.id);
          } else {
            widget.goTab(1);
          }
        }),
        const SizedBox(height: 10),

        // 12. About Aura
        ghostBtn('About Aura', () {
          Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AboutScreen()))
              .then((_) => _refresh());
        }),
      ],
    );
  }

  Widget _weekCircle(int i, Set<String> loggedDates, String today) {
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final d = fmtDate(thisWeekDates()[i]);
    final logged = loggedDates.contains(d);
    final isToday = d == today;
    return Center(
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: logged ? accentColor : Colors.transparent,
          border: logged
              ? null
              : Border.all(
                  color: isToday ? accentColor : ghostColor, width: 2),
        ),
        alignment: Alignment.center,
        child: Text(letters[i],
            style: const TextStyle(color: Colors.white, fontSize: 15)),
      ),
    );
  }
}

// ---------- v9.3 homepage-only helpers (other pages untouched) ----------

Widget _premiumCard({required List<Widget> children}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(cardColor, accentColor, 0.16) ?? cardColor,
          cardColor,
        ],
      ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: accentColor.withAlpha(45)),
      boxShadow: const [
        BoxShadow(color: Colors.black45, blurRadius: 12, offset: Offset(0, 4))
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );
}

Widget _iconChip(IconData icon) {
  return Container(
    padding: const EdgeInsets.all(7),
    decoration: BoxDecoration(
      color: accentColor.withAlpha(35),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Icon(icon, color: accentColor, size: 18),
  );
}

Widget _cardTitle(IconData icon, String title) {
  return Row(
    children: [
      _iconChip(icon),
      const SizedBox(width: 8),
      Text(title,
          style: const TextStyle(
              color: mutedColor,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2)),
    ],
  );
}

Widget _sectionHeader(
    IconData icon, String title, String? action, VoidCallback? onAction) {
  return Padding(
    padding: const EdgeInsets.only(top: 6, bottom: 10),
    child: Row(
      children: [
        _iconChip(icon),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                color: mutedColor,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2)),
        const Spacer(),
        if (action != null && onAction != null)
          InkWell(
            onTap: onAction,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(action,
                  style: TextStyle(
                      color: accentColor,
                      fontSize: 14,
                      fontWeight: FontWeight.bold)),
            ),
          ),
      ],
    ),
  );
}

Widget _statCard(IconData icon, String label, String value) {
  return Expanded(
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(cardColor, accentColor, 0.16) ?? cardColor,
            cardColor,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _iconChip(icon),
          const SizedBox(height: 10),
          Text(value,
              style: TextStyle(
                  color: textColor,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  color: mutedColor, fontSize: 11, letterSpacing: 0.8)),
        ],
      ),
    ),
  );
}

Widget _iconProgressRow(
    IconData icon, String label, String value, double fraction) {
  final f = fraction.clamp(0.0, 1.0);
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Column(
      children: [
        Row(
          children: [
            Icon(icon, color: accentColor, size: 18),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(color: mutedColor, fontSize: 13)),
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
          height: 8,
          decoration: BoxDecoration(
              color: ghostColor, borderRadius: BorderRadius.circular(5)),
          child: Row(
            children: [
              Flexible(
                flex: (f < 0.02 ? 2 : (f * 100).round()),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      accentColor,
                      Color.lerp(accentColor, const Color(0xFFF472B6), 0.5) ??
                          accentColor,
                    ]),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
              if (f < 1.0)
                Flexible(flex: ((1 - f) * 100).round(), child: Container()),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _pill(String text, bool selected, VoidCallback onTap) {
  return Padding(
    padding: const EdgeInsets.only(right: 8, bottom: 4),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? accentColor : ghostColor,
          borderRadius: BorderRadius.circular(20),
          border: selected
              ? null
              : Border.all(color: accentColor.withAlpha(50)),
        ),
        child: Text(text,
            style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight:
                    selected ? FontWeight.bold : FontWeight.normal)),
      ),
    ),
  );
}

Widget _gradientBtn(String text, VoidCallback onPressed) {
  return Container(
    height: 60,
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: [
        accentColor,
        Color.lerp(accentColor, const Color(0xFFF472B6), 0.45) ?? accentColor,
      ]),
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
            color: accentColor.withAlpha(80),
            blurRadius: 16,
            offset: const Offset(0, 6))
      ],
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.play_arrow, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Text(text,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _dashedAddCard(VoidCallback onTap) {
  return Container(
    margin: const EdgeInsets.only(bottom: 16),
    height: 72,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: CustomPaint(
          painter: _DashedBorderPainter(accentColor),
          child: const Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add, color: Colors.white, size: 22),
                SizedBox(width: 8),
                Text('Add Category',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Thin original lightning polylines (code-drawn decoration only).
class _LightningPainter extends CustomPainter {
  final Color color;
  _LightningPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final p1 = Paint()
      ..color = Colors.white.withAlpha(35)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final path1 = Path()
      ..moveTo(w * 0.88, 0)
      ..lineTo(w * 0.74, h * 0.45)
      ..lineTo(w * 0.84, h * 0.45)
      ..lineTo(w * 0.64, h);
    canvas.drawPath(path1, p1);
    final p2 = Paint()
      ..color = color.withAlpha(55)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final path2 = Path()
      ..moveTo(w * 0.97, h * 0.2)
      ..lineTo(w * 0.88, h * 0.55)
      ..lineTo(w * 0.95, h * 0.55)
      ..lineTo(w * 0.80, h * 0.95);
    canvas.drawPath(path2, p2);
  }

  @override
  bool shouldRepaint(covariant _LightningPainter old) => old.color != color;
}

/// Dashed rounded-rectangle border for the Add Category card.
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  _DashedBorderPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Offset.zero & size, const Radius.circular(18)));
    for (final metric in path.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 8), paint);
        d += 14;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) =>
      old.color != color;
}
