import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';

/// Port of v8 Store.kt — SAME JSON schema and SAME file (aura.json in the
/// app's filesDir) so the user's existing v8 data carries over unchanged.
/// No third-party plugins: filesDir comes from a tiny MethodChannel in the
/// Java host, storage is dart:io + dart:convert only.

class Category {
  final int id;
  String name;

  /// Optional bundled icon asset chosen in the Add Category dialog
  /// (e.g. 'assets/icons/icon_neck.png'). Null means "Auto": the card
  /// falls back to the keyword-based generic Material icon. Additive and
  /// backward-compatible — old aura.json files without this key load
  /// with iconAsset == null.
  String? iconAsset;
  Category(this.id, this.name, [this.iconAsset]);
  factory Category.fromJson(Map<String, dynamic> j) => Category(
      (j['id'] as num).toInt(),
      j['name'] as String,
      j['iconAsset'] as String?);
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (iconAsset != null) 'iconAsset': iconAsset,
      };
}

class Workout {
  final int id;
  final int categoryId;
  String name;
  String unit;
  Workout(this.id, this.categoryId, this.name, this.unit);
  factory Workout.fromJson(Map<String, dynamic> j) => Workout(
      (j['id'] as num).toInt(),
      (j['categoryId'] as num).toInt(),
      j['name'] as String,
      (j['unit'] as String?) ?? 'reps');
  Map<String, dynamic> toJson() =>
      {'id': id, 'categoryId': categoryId, 'name': name, 'unit': unit};
}

class LogEntry {
  final int id;
  final int workoutId;
  final String date; // yyyy-MM-dd
  final double value;
  LogEntry(this.id, this.workoutId, this.date, this.value);
  factory LogEntry.fromJson(Map<String, dynamic> j) => LogEntry(
      (j['id'] as num).toInt(),
      (j['workoutId'] as num).toInt(),
      j['date'] as String,
      (j['value'] as num).toDouble());
  Map<String, dynamic> toJson() =>
      {'id': id, 'workoutId': workoutId, 'date': date, 'value': value};
}

class AppSettings {
  String themePreset;
  String bgHex;
  String textHex;
  String accentHex;
  String bgPreset;
  String bgImageUri;
  bool animationOn;
  bool roastOn;
  String geminiKey;
  double bgOpacity;
  double textOpacity;
  double cardOpacity;
  AppSettings({
    this.themePreset = 'Raiden Purple',
    this.bgHex = '#0D0A1A',
    this.textHex = '#FFFFFF',
    this.accentHex = '#A855F7',
    this.bgPreset = 'Raiden Gradient',
    this.bgImageUri = '',
    this.animationOn = true,
    this.roastOn = true,
    this.geminiKey = '',
    this.bgOpacity = 1.0,
    this.textOpacity = 1.0,
    this.cardOpacity = 1.0,
  });
  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
        themePreset: (j['themePreset'] as String?) ?? 'Raiden Purple',
        bgHex: (j['bgHex'] as String?) ?? '#0D0A1A',
        textHex: (j['textHex'] as String?) ?? '#FFFFFF',
        accentHex: (j['accentHex'] as String?) ?? '#A855F7',
        bgPreset: (j['bgPreset'] as String?) ?? 'Raiden Gradient',
        bgImageUri: (j['bgImageUri'] as String?) ?? '',
        animationOn: (j['animationOn'] as bool?) ?? true,
        roastOn: (j['roastOn'] as bool?) ?? true,
        geminiKey: (j['geminiKey'] as String?) ?? '',
        bgOpacity: ((j['bgOpacity'] as num?)?.toDouble() ?? 1.0).clamp(0.0, 1.0),
        textOpacity: ((j['textOpacity'] as num?)?.toDouble() ?? 1.0).clamp(0.0, 1.0),
        cardOpacity: ((j['cardOpacity'] as num?)?.toDouble() ?? 1.0).clamp(0.0, 1.0),
      );
  Map<String, dynamic> toJson() => {
        'themePreset': themePreset,
        'bgHex': bgHex,
        'textHex': textHex,
        'accentHex': accentHex,
        'bgPreset': bgPreset,
        'bgImageUri': bgImageUri,
        'animationOn': animationOn,
        'roastOn': roastOn,
        'geminiKey': geminiKey,
        'bgOpacity': bgOpacity,
        'textOpacity': textOpacity,
        'cardOpacity': cardOpacity,
      };
}

String todayStr() {
  final n = DateTime.now();
  return '${n.year.toString().padLeft(4, '0')}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
}

DateTime parseDate(String s) => DateTime.parse(s);
String fmtDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class Store {
  static final Store instance = Store._();
  Store._();

  List<Category> categories = [];
  List<Workout> workouts = [];
  List<LogEntry> logs = [];
  AppSettings settings = AppSettings();
  int _nextId = 1;
  File? _file;
  bool _loaded = false;

  static const _channel = MethodChannel('aura/files');

  Future<void> init() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final dir = await _channel.invokeMethod<String>('getFilesDir');
      _file = File('$dir/aura.json');
      if (!_file!.existsSync()) return;
      final j = jsonDecode(await _file!.readAsString()) as Map<String, dynamic>;
      List<Map<String, dynamic>> arr(String n) =>
          ((j[n] as List?) ?? []).cast<Map<String, dynamic>>();
      categories = arr('categories').map(Category.fromJson).toList();
      workouts = arr('workouts').map(Workout.fromJson).toList();
      logs = arr('logs').map(LogEntry.fromJson).toList();
      final s = j['settings'];
      if (s is Map<String, dynamic>) settings = AppSettings.fromJson(s);
      int mx = 0;
      for (final c in categories) { if (c.id > mx) mx = c.id; }
      for (final w in workouts) { if (w.id > mx) mx = w.id; }
      for (final l in logs) { if (l.id > mx) mx = l.id; }
      _nextId = mx + 1;
    } catch (_) {
      // Same as v8: a corrupt file never crashes the app; start empty.
    }
  }

  Future<void> save() async {
    try {
      if (_file == null) return;
      final j = {
        'categories': categories.map((c) => c.toJson()).toList(),
        'workouts': workouts.map((w) => w.toJson()).toList(),
        'logs': logs.map((l) => l.toJson()).toList(),
        'settings': settings.toJson(),
      };
      await _file!.writeAsString(jsonEncode(j));
    } catch (_) {}
  }

  Future<void> addCategory(String name, [String? iconAsset]) async {
    categories.add(Category(_nextId++, name.trim(), iconAsset));
    await save();
  }

  Future<void> deleteCategory(int id) async {
    final wIds = workouts.where((w) => w.categoryId == id).map((w) => w.id).toSet();
    categories.removeWhere((c) => c.id == id);
    workouts.removeWhere((w) => w.categoryId == id);
    logs.removeWhere((l) => wIds.contains(l.workoutId));
    await save();
  }

  Future<void> addWorkout(int catId, String name, String unit) async {
    final u = unit.trim().isEmpty ? 'reps' : unit.trim();
    workouts.add(Workout(_nextId++, catId, name.trim(), u));
    await save();
  }

  Future<void> deleteWorkout(int id) async {
    workouts.removeWhere((w) => w.id == id);
    logs.removeWhere((l) => l.workoutId == id);
    await save();
  }

  Future<void> editWorkout(int id, String name, String unit) async {
    final i = workouts.indexWhere((w) => w.id == id);
    if (i >= 0) {
      workouts[i].name = name.trim();
      workouts[i].unit = unit.trim().isEmpty ? 'reps' : unit.trim();
      await save();
    }
  }

  List<LogEntry> logsForDate(String date) {
    final list = logs.where((l) => l.date == date).toList();
    list.sort((a, b) => a.workoutId.compareTo(b.workoutId));
    return list;
  }

  Future<void> saveDayLog(Map<int, double> values, [String? date]) async {
    final d = date ?? todayStr();
    logs.removeWhere((l) => values.containsKey(l.workoutId) && l.date == d);
    values.forEach((wid, v) => logs.add(LogEntry(_nextId++, wid, d, v)));
    await save();
  }
}

class DayTotal {
  final int day;
  final String date;
  final double total;
  DayTotal(this.day, this.date, this.total);
}

List<DayTotal> dayTotalsForCategory(int categoryId) {
  final s = Store.instance;
  final wIds = s.workouts.where((w) => w.categoryId == categoryId).map((w) => w.id).toSet();
  final byDate = <String, List<LogEntry>>{};
  for (final l in s.logs) {
    if (wIds.contains(l.workoutId)) (byDate[l.date] ??= []).add(l);
  }
  final dates = byDate.keys.toList()..sort();
  return [
    for (int i = 0; i < dates.length; i++)
      DayTotal(i + 1, dates[i],
          byDate[dates[i]]!.fold<double>(0, (a, l) => a + l.value))
  ];
}

List<DayTotal> dayTotalsOverall() {
  final s = Store.instance;
  final byDate = <String, List<LogEntry>>{};
  for (final l in s.logs) (byDate[l.date] ??= []).add(l);
  final dates = byDate.keys.toList()..sort();
  return [
    for (int i = 0; i < dates.length; i++)
      DayTotal(i + 1, dates[i],
          byDate[dates[i]]!.fold<double>(0, (a, l) => a + l.value))
  ];
}

List<(String, double)> workoutSeries(int workoutId) {
  final list = Store.instance.logs.where((l) => l.workoutId == workoutId).toList();
  list.sort((a, b) => a.date.compareTo(b.date));
  return [for (final l in list) (l.date, l.value)];
}

// ---- v7 homepage helpers (computed from existing logs; log format unchanged) ----

int streakDays() {
  final dates = Store.instance.logs.map((l) => l.date).toSet();
  var d = DateTime.now();
  if (!dates.contains(fmtDate(d))) d = d.subtract(const Duration(days: 1));
  if (!dates.contains(fmtDate(d))) return 0;
  var n = 0;
  while (dates.contains(fmtDate(d))) {
    n++;
    d = d.subtract(const Duration(days: 1));
  }
  return n;
}

DateTime weekMonday(DateTime d) => d.subtract(Duration(days: d.weekday - 1));

List<DateTime> thisWeekDates() {
  final mon = weekMonday(DateTime.now());
  return [for (int i = 0; i < 7; i++) mon.add(Duration(days: i))];
}

double weekTotal(DateTime mon) {
  final dates = {for (int i = 0; i < 7; i++) fmtDate(mon.add(Duration(days: i)))};
  return Store.instance.logs
      .where((l) => dates.contains(l.date))
      .fold<double>(0, (a, l) => a + l.value);
}

/// (category name, sum, percent of all logged) sorted by sum desc.
List<(String, double, int)> categoryShares() {
  final s = Store.instance;
  final total = s.logs.fold<double>(0, (a, l) => a + l.value);
  if (total <= 0) return [for (final c in s.categories) (c.name, 0.0, 0)];
  final list = <(String, double, int)>[];
  for (final c in s.categories) {
    final wIds = s.workouts.where((w) => w.categoryId == c.id).map((w) => w.id).toSet();
    final sum = s.logs.where((l) => wIds.contains(l.workoutId)).fold<double>(0, (a, l) => a + l.value);
    list.add((c.name, sum, (sum / total * 100).toInt()));
  }
  list.sort((a, b) => b.$2.compareTo(a.$2));
  return list;
}

enum GraphPeriod { day, week, month }

/// (series, x labels) — series entries are (name, values), plus Overall last.
(List<(String, List<double>)>, List<String>) periodSeries(GraphPeriod period) {
  final s = Store.instance;
  if (s.categories.isEmpty) return (<(String, List<double>)>[], <String>[]);
  if (period == GraphPeriod.day) {
    final series = <(String, List<double>)>[
      for (final c in s.categories)
        (c.name, dayTotalsForCategory(c.id).map((d) => d.total).toList())
    ];
    final all = [...series, ('Overall', dayTotalsOverall().map((d) => d.total).toList())];
    final maxLen = all.map((e) => e.$2.length).reduce((a, b) => a > b ? a : b);
    return (all, [for (int i = 1; i <= maxLen; i++) 'DAY $i']);
  }
  if (period == GraphPeriod.week) {
    final keys = s.logs.map((l) => weekMonday(parseDate(l.date))).toSet().toList()..sort();
    List<double> vals(int? catId) => [
      for (final mon in keys)
        (() {
          final dates = {for (int i = 0; i < 7; i++) fmtDate(mon.add(Duration(days: i)))};
          final wIds = catId == null
              ? null
              : s.workouts.where((w) => w.categoryId == catId).map((w) => w.id).toSet();
          return s.logs
              .where((l) => dates.contains(l.date) && (wIds == null || wIds.contains(l.workoutId)))
              .fold<double>(0, (a, l) => a + l.value);
        })()
    ];
    final all = <(String, List<double>)>[
      for (final c in s.categories) (c.name, vals(c.id)),
      ('Overall', vals(null)),
    ];
    return (all, [for (int i = 0; i < keys.length; i++) 'WK ${i + 1}']);
  }
  // month
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final keys = s.logs.map((l) => l.date.substring(0, 7)).toSet().toList()..sort();
  List<double> valsM(int? catId) => [
    for (final k in keys)
      (() {
        final wIds = catId == null
            ? null
            : s.workouts.where((w) => w.categoryId == catId).map((w) => w.id).toSet();
        return s.logs
            .where((l) => l.date.startsWith(k) && (wIds == null || wIds.contains(l.workoutId)))
            .fold<double>(0, (a, l) => a + l.value);
      })()
  ];
  final allM = <(String, List<double>)>[
    for (final c in s.categories) (c.name, valsM(c.id)),
    ('Overall', valsM(null)),
  ];
  final labels = [for (final k in keys) months[int.parse(k.substring(5, 7)) - 1]];
  return (allM, labels);
}
