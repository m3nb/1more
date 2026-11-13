import 'package:flutter/material.dart';

import '../profile.dart';
import 'effects.dart';
import 'theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = Profile.I;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile & rewards'), backgroundColor: C.felt),
      body: TableBg(
        child: ListenableBuilder(
          listenable: p,
          builder: (context, _) => Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(padding: const EdgeInsets.all(16), children: [
                Panel(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Icon(Icons.monetization_on, color: C.saffron, size: 30),
                      const SizedBox(width: 8),
                      Text('${p.coins}', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
                      const SizedBox(width: 6),
                      const Text('coins', style: TextStyle(color: C.inkSoft)),
                    ]),
                    const SizedBox(height: 14),
                    const Label('Daily reward'),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      for (var i = 0; i < kDailyRewards.length; i++) _step(p, i),
                    ]),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: p.canClaim
                            ? () {
                                final got = p.claimDaily();
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(SnackBar(content: Text('+$got coins. Come back tomorrow for more.')));
                              }
                            : null,
                        child: Text(p.canClaim
                            ? 'Collect day ${p.nextStep + 1}: ${kDailyRewards[p.nextStep]} coins'
                            : 'Collected today. Day ${p.currentStep + 1} of 7.'),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text('Miss a day and the ladder starts again from day 1.',
                        style: TextStyle(color: C.inkSoft, fontSize: 12)),
                  ]),
                ),
                const SizedBox(height: 16),
                Panel(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Label('Your stats'),
                    Wrap(spacing: 22, runSpacing: 12, children: [
                      _stat('${p.games}', 'games'),
                      _stat('${p.wins}', 'wins'),
                      _stat(p.games == 0 ? '–' : '${(p.wins * 100 / p.games).round()}%', 'win rate'),
                      _stat('${p.bestRound}', 'best round'),
                      _stat('${p.sevens}', 'sevens'),
                      _stat('${p.busts}', 'busts'),
                      _stat('${p.todayBest}', 'daily today'),
                    ]),
                    const SizedBox(height: 8),
                    const Text('Counted on this device, for games with one player on it.',
                        style: TextStyle(color: C.inkSoft, fontSize: 12)),
                  ]),
                ),
                const SizedBox(height: 16),
                Panel(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Label('Achievements (${p.achievements.length}/${kAchievements.length})'),
                    for (final a in kAchievements)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          p.achievements.contains(a.id) ? Icons.emoji_events : Icons.lock_outline,
                          color: p.achievements.contains(a.id) ? C.saffron : C.inkSoft,
                        ),
                        title: Text(a.title,
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: p.achievements.contains(a.id) ? C.ink : C.inkSoft)),
                        subtitle: Text(a.how, style: const TextStyle(color: C.inkSoft, fontSize: 12)),
                      ),
                    const Text('Each one is worth 25 coins.', style: TextStyle(color: C.inkSoft, fontSize: 12)),
                  ]),
                ),
                const SizedBox(height: 16),
                Panel(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Label('Table colours'),
                    for (final t in kThemes)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(children: [
                          Container(
                            width: 54,
                            height: 36,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: p.theme == t.id ? C.saffron : C.line, width: 2),
                              gradient: LinearGradient(colors: t.colors),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Text(t.name, style: const TextStyle(fontWeight: FontWeight.w800))),
                          if (p.theme == t.id)
                            const Text('In use', style: TextStyle(color: C.saffron, fontWeight: FontWeight.w800))
                          else if (p.themes.contains(t.id))
                            OutlinedButton(onPressed: () => p.selectTheme(t.id), child: const Text('Use'))
                          else
                            FilledButton(
                              onPressed: p.coins >= t.cost ? () => p.buyTheme(t.id) : null,
                              child: Text('${t.cost} coins'),
                            ),
                        ]),
                      ),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _step(Profile p, int i) {
    final done = i <= p.currentStep;
    final next = p.canClaim && i == p.nextStep;
    return Container(
      width: 62,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: done ? C.saffron.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: next ? C.saffron : (done ? C.saffron.withValues(alpha: 0.6) : C.line), width: next ? 2.5 : 1),
      ),
      child: Column(children: [
        Text('Day ${i + 1}', style: const TextStyle(fontSize: 11, color: C.inkSoft)),
        Text('${kDailyRewards[i]}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
      ]),
    );
  }

  Widget _stat(String v, String l) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(v, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, height: 1.1)),
        Text(l, style: const TextStyle(color: C.inkSoft, fontSize: 12)),
      ]);
}
