import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Achievement {
  final String id;
  final String title;
  final String how;
  const Achievement(this.id, this.title, this.how);
}

const kAchievements = [
  Achievement('first_win', 'First Win', 'Win a game.'),
  Achievement('seven', 'Lucky Seven', 'Collect seven different numbers in one round.'),
  Achievement('big_round', 'High Roller', 'Score 60 or more in one round.'),
  Achievement('comeback', 'From the Ashes', 'Win a game after being below zero.'),
  Achievement('ten_games', 'Regular', 'Play 10 games.'),
  Achievement('five_wins', 'On a Roll', 'Win 5 games.'),
  Achievement('unlucky', 'Unlucky', 'Bust 10 times.'),
  Achievement('streak3', 'Three in a Row', 'Collect the daily reward 3 days running.'),
  Achievement('daily100', 'Daily Hundred', 'Score 100 or more in a daily challenge.'),
];

class TableTheme {
  final String id;
  final String name;
  final int cost;
  final List<Color> colors;
  const TableTheme(this.id, this.name, this.cost, this.colors);
}

const kThemes = [
  TableTheme('crimson', 'Crimson', 0, [Color(0xFF6E1024), Color(0xFF2A0811), Color(0xFF12050A)]),
  TableTheme('midnight', 'Midnight', 150, [Color(0xFF1D2F7A), Color(0xFF0B1030), Color(0xFF05060F)]),
  TableTheme('emerald', 'Emerald', 300, [Color(0xFF0F6A4E), Color(0xFF08261E), Color(0xFF03100C)]),
  TableTheme('royal', 'Royal', 500, [Color(0xFF65208A), Color(0xFF250B33), Color(0xFF0C0412)]),
  TableTheme('inferno', 'Inferno', 800, [Color(0xFFA34400), Color(0xFF3A1200), Color(0xFF120500)]),
];

/// Coins for each day of a streak. Day 7 is worth more than the six before it.
const kDailyRewards = [10, 15, 20, 30, 40, 60, 200];

String _two(int n) => n < 10 ? '0$n' : '$n';
String dayKey(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';
int daySeed(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

/// What this device remembers about its player: stats, coins, unlocks.
class Profile extends ChangeNotifier {
  Profile._();
  static final Profile I = Profile._();

  int games = 0;
  int wins = 0;
  int bestRound = 0;
  int busts = 0;
  int sevens = 0;
  int coins = 0;
  int streak = 0;
  String lastClaim = '';
  String dailyDate = '';
  int dailyBest = 0;
  String theme = 'crimson';
  Set<String> achievements = {};
  Set<String> themes = {'crimson'};

  SharedPreferences? _sp;

  Future<void> load() async {
    try {
      _sp = await SharedPreferences.getInstance();
      final raw = _sp!.getString('profile');
      if (raw != null) {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        int n(String k) => (m[k] as num?)?.toInt() ?? 0;
        games = n('games');
        wins = n('wins');
        bestRound = n('bestRound');
        busts = n('busts');
        sevens = n('sevens');
        coins = n('coins');
        streak = n('streak');
        dailyBest = n('dailyBest');
        lastClaim = m['lastClaim'] as String? ?? '';
        dailyDate = m['dailyDate'] as String? ?? '';
        theme = m['theme'] as String? ?? 'crimson';
        achievements = {...(m['achievements'] as List? ?? const []).map((e) => '$e')};
        themes = {'crimson', ...(m['themes'] as List? ?? const []).map((e) => '$e')};
      }
    } catch (_) {
      // Storage can be unavailable (private browsing); the game still works.
    }
    notifyListeners();
  }

  void _save() {
    try {
      _sp?.setString(
          'profile',
          jsonEncode({
            'games': games,
            'wins': wins,
            'bestRound': bestRound,
            'busts': busts,
            'sevens': sevens,
            'coins': coins,
            'streak': streak,
            'dailyBest': dailyBest,
            'lastClaim': lastClaim,
            'dailyDate': dailyDate,
            'theme': theme,
            'achievements': achievements.toList(),
            'themes': themes.toList(),
          }));
    } catch (_) {}
    notifyListeners();
  }

  TableTheme get tableTheme => kThemes.firstWhere((t) => t.id == theme, orElse: () => kThemes.first);

  int get todayBest => dailyDate == dayKey(DateTime.now()) ? dailyBest : 0;
  bool get playedToday => dailyDate == dayKey(DateTime.now());

  // ---------------- daily reward ----------------

  bool get canClaim => lastClaim != dayKey(DateTime.now());

  int get _streakIfClaimed {
    final yesterday = dayKey(DateTime.now().subtract(const Duration(days: 1)));
    return lastClaim == yesterday ? streak + 1 : 1;
  }

  /// Which step of the 7-day ladder the next claim lands on (0-6).
  int get nextStep => (_streakIfClaimed - 1) % kDailyRewards.length;

  /// Step reached by the last claim, or -1 when the streak is broken.
  int get currentStep => canClaim ? nextStep - 1 : (streak - 1) % kDailyRewards.length;

  int claimDaily() {
    if (!canClaim) return 0;
    streak = _streakIfClaimed;
    final reward = kDailyRewards[(streak - 1) % kDailyRewards.length];
    coins += reward;
    lastClaim = dayKey(DateTime.now());
    if (streak >= 3) achievements.add('streak3');
    _save();
    return reward;
  }

  // ---------------- records ----------------

  List<String> _unlock(List<String> ids) {
    final fresh = <String>[];
    for (final id in ids) {
      if (achievements.add(id)) {
        fresh.add(kAchievements.firstWhere((a) => a.id == id).title);
        coins += 25;
      }
    }
    return fresh;
  }

  /// Each record returns the titles of achievements it just unlocked.
  List<String> recordRound({required int points, required bool bust, required bool seven}) {
    if (points > bestRound) bestRound = points;
    if (bust) busts++;
    if (seven) sevens++;
    final fresh = _unlock([
      if (seven) 'seven',
      if (points >= 60) 'big_round',
      if (busts >= 10) 'unlucky',
    ]);
    _save();
    return fresh;
  }

  List<String> recordGame({required bool won, required bool wasNegative}) {
    games++;
    coins += 5;
    if (won) {
      wins++;
      coins += 20;
    }
    final fresh = _unlock([
      if (won) 'first_win',
      if (won && wasNegative) 'comeback',
      if (games >= 10) 'ten_games',
      if (wins >= 5) 'five_wins',
    ]);
    _save();
    return fresh;
  }

  List<String> recordDaily(int score) {
    final today = dayKey(DateTime.now());
    if (dailyDate != today) {
      dailyDate = today;
      dailyBest = score;
      coins += score > 0 ? score ~/ 10 : 0;
    } else if (score > dailyBest) {
      dailyBest = score;
    }
    final fresh = _unlock([if (score >= 100) 'daily100']);
    _save();
    return fresh;
  }

  // ---------------- table themes ----------------

  bool buyTheme(String id) {
    final t = kThemes.firstWhere((x) => x.id == id);
    if (themes.contains(id) || coins < t.cost) return false;
    coins -= t.cost;
    themes.add(id);
    theme = id;
    _save();
    return true;
  }

  void selectTheme(String id) {
    if (!themes.contains(id)) return;
    theme = id;
    _save();
  }
}
