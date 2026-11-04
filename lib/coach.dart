import 'dart:convert';
import 'dart:io';
import 'store.dart';

/// Port of v8 Coach.kt — same rules, same roast style.

String offlineCoachText() {
  final s = Store.instance;
  if (s.logs.isEmpty) {
    return 'No logs yet, bro. Create a category, add a workout, log Day 1. Greatness starts with one logged day. Stay hard.';
  }
  final sb = StringBuffer();
  var weakestName = '';
  var weakestDrop = 0.0;
  var strongestName = '';
  var strongestGain = 0.0;
  for (final w in s.workouts) {
    final series = workoutSeries(w.id);
    if (series.length >= 2) {
      final last = series.last.$2;
      final prev = series[series.length - 2].$2;
      if (prev > 0) {
        final pct = (last - prev) / prev * 100;
        if (pct < weakestDrop) {
          weakestDrop = pct;
          weakestName = w.name;
        }
        if (pct > strongestGain) {
          strongestGain = pct;
          strongestName = w.name;
        }
      }
    }
  }
  if (weakestName.isNotEmpty && weakestDrop < 0) {
    sb.write('Weakness found: $weakestName is down ${(-weakestDrop).toStringAsFixed(0)}% from yesterday. ');
    if (s.settings.roastOn) {
      sb.write('Bro, you are getting comfortable. Great power comes with consistency, not comfort. ');
    }
    sb.write('Fix it tomorrow, even by +1. ');
  } else {
    sb.write('No workout is falling right now. Good. ');
  }
  if (strongestName.isNotEmpty && strongestGain > 0) {
    sb.write('Strongest right now: $strongestName, up ${strongestGain.toStringAsFixed(0)}%. Keep that fire. ');
  }
  sb.write('David Goggins style reminder: stay hard, do the hard thing when you don\'t feel like it, and the results will follow. ');
  if (s.settings.roastOn) sb.write('Comfort is the enemy. One more rep than yesterday.');
  return sb.toString();
}

String offlineChatReply(String question) {
  final s = Store.instance;
  final q = question.toLowerCase();
  Workout? matched;
  for (final w in s.workouts) {
    if (q.contains(w.name.toLowerCase())) {
      matched = w;
      break;
    }
  }
  if (matched != null) {
    final series = workoutSeries(matched.id);
    if (series.length >= 2) {
      final last = series.last;
      final prev = series[series.length - 2];
      final diff = last.$2 - prev.$2;
      if (diff < 0) {
        return 'Your ${matched.name} went from ${prev.$2} to ${last.$2} - down ${-diff}. ${s.settings.roastOn ? 'That is comfort talking. ' : ''}Tomorrow, beat ${prev.$2}. Small win, every day.';
      }
      return 'Your ${matched.name} went from ${prev.$2} to ${last.$2} - up $diff. That is progress. Keep it up, stay hard.';
    }
    return 'You have logged ${matched.name} ${series.length} time(s). Log it again tomorrow so I can compare days.';
  }
  return offlineCoachText();
}

Future<String> geminiReply(String apiKey, String question, String summary) async {
  // Every failure return is: one short error line, a blank line, then the
  // offline coach reply — so the chat never dead-ends on a cryptic error.
  // v9.16 fix: the old code did `j['candidates'] as List` without checking
  // the HTTP status, so a Gemini error body ({"error": ...}, no
  // 'candidates' key) threw a null-cast error that was shown raw.
  String withFallback(String line) => '$line\n\n${offlineChatReply(question)}';
  try {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 20);
    final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash:generateContent?key=$apiKey');
    final req = await client.postUrl(uri);
    req.headers.contentType = ContentType.json;
    final prompt =
        'You are Aura, a tough workout coach in the style of David Goggins: direct, no soft motivation, but helpful and specific. User workout summary: $summary. User question: $question. Answer in 3-5 short lines, mention actual numbers, say what is weak and what to do tomorrow.';
    req.write(jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ]
    }));
    final res = await req.close().timeout(const Duration(seconds: 30));
    final text = await res.transform(utf8.decoder).join();
    client.close();
    final j = jsonDecode(text) as Map<String, dynamic>?;
    if (res.statusCode != 200) {
      final error = j?['error'] as Map<String, dynamic>?;
      final message = error?['message'] as String?;
      if (message != null && message.isNotEmpty) {
        // v9.17 cosmetic: API messages already end with '.', so strip any
        // trailing dots/whitespace first, otherwise the line ends with '..'.
        final clean = message.trim().replaceAll(RegExp(r'\.+$'), '');
        if (clean.isNotEmpty) {
          return withFallback('Gemini error (HTTP ${res.statusCode}): $clean.');
        }
      }
      return withFallback('Gemini returned an error (HTTP ${res.statusCode}).');
    }
    final candidates = j?['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      final feedback = j?['promptFeedback'] as Map<String, dynamic>?;
      final blockReason = feedback?['blockReason'] as String?;
      if (blockReason != null && blockReason.isNotEmpty) {
        return withFallback(
            'Gemini returned no answer. It may have blocked the reply ($blockReason).');
      }
      return withFallback('Gemini returned no answer.');
    }
    final content = candidates[0] as Map<String, dynamic>?;
    final parts = content?['parts'] as List?;
    if (parts == null || parts.isEmpty) {
      return withFallback('Gemini returned no answer.');
    }
    final answer = (parts[0] as Map<String, dynamic>?)?['text'] as String?;
    if (answer == null || answer.isEmpty) {
      return withFallback('Gemini returned no answer.');
    }
    return answer;
  } catch (e) {
    return withFallback("Couldn't reach Gemini. Check your internet.");
  }
}
