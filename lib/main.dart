import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'config.dart';
import 'engine/model.dart';
import 'net/session.dart';
import 'ui/card_view.dart';
import 'ui/effects.dart';
import 'ui/lobby_screen.dart';
import 'ui/setup_screen.dart';
import 'ui/theme.dart';

void main() {
  runApp(const OneMoreApp());
}

class OneMoreApp extends StatelessWidget {
  const OneMoreApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: '1More',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const HomeScreen(),
      );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _name = TextEditingController(text: 'Player');
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // A web invite link looks like .../?room=ABC12
    if (kIsWeb) {
      final room = Uri.base.queryParameters['room'];
      if (room != null && room.isNotEmpty) _code.text = normalizeCode(room);
    }
  }

  Future<void> _online(bool host) async {
    final name = _name.text.trim().isEmpty ? 'Player' : _name.text.trim();
    final code = normalizeCode(_code.text);
    if (!host && code.length < 4) {
      setState(() => _error = 'Enter the room code your friend sent you.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = host ? await OnlineSession.host(name) : await OnlineSession.join(code, name);
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => LobbyScreen(session: session)));
    } catch (e) {
      setState(() => _error = 'Could not connect. Check your internet and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fan = const [GameCard(-1, CardType.num, 7), GameCard(-2, CardType.x2), GameCard(-3, CardType.freeze)];
    return Scaffold(
      body: TableBg(
        child: SafeArea(child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(padding: const EdgeInsets.all(16), children: [
              const SizedBox(height: 12),
              Row(children: [
                SizedBox(
                  width: 112,
                  height: 72,
                  child: Stack(clipBehavior: Clip.none, children: [
                    for (var i = 0; i < fan.length; i++)
                      Positioned(
                        left: 4.0 + i * 26,
                        bottom: 0,
                        child: Transform.rotate(
                          angle: (i - 1) * 0.24,
                          alignment: Alignment.bottomCenter,
                          child: CardView(fan[i]),
                        ),
                      ),
                  ]),
                ),
                const SizedBox(width: 12),
                const Text('1More', style: titleStyle),
              ]),
              const SizedBox(height: 10),
              const Text(
                'Keep drawing or stay and bank your points. Draw a number you already have and your round is gone.',
                style: TextStyle(color: C.inkSoft, fontSize: 15),
              ),
              const SizedBox(height: 24),
              Panel(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  FilledButton(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1),
                    ),
                    onPressed: () =>
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LocalSetupScreen())),
                    child: const Text('Start'),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              Panel(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Label('Play online with friends'),
                  if (!onlineConfigured)
                    const Text('Online play isn\'t set up in this build yet.', style: TextStyle(color: C.inkSoft))
                  else ...[
                    TextField(
                      controller: _name,
                      maxLength: 16,
                      decoration: const InputDecoration(labelText: 'Your name', counterText: ''),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _busy ? null : () => _online(true),
                      icon: const Icon(Icons.add),
                      label: const Text('Create a room'),
                    ),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: _code,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(labelText: 'Room code'),
                          onSubmitted: (_) => _online(false),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(onPressed: _busy ? null : () => _online(false), child: const Text('Join')),
                    ]),
                    if (_busy) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(_error!, style: const TextStyle(color: C.coral)),
                      ),
                  ],
                ]),
              ),
              const SizedBox(height: 16),
              const Panel(child: _Rules()),
            ]),
          ),
        )),
      ),
    );
  }
}

class _Rules extends StatelessWidget {
  const _Rules();
  static const rules = [
    '93 cards: one 0, one 1, two 2s… up to twelve 12s. Plus one each of +2, +4, +6, +8, +10 and ×2, and two of each action card.',
    'Your first draw each round is mandatory. After that, on your turn you either draw or stay and bank your points.',
    'Draw a number you already have and you score 0 this round. A Second Chance saves you once: the duplicate and the Second Chance are discarded and you carry on.',
    'Scoring: sum of your numbers, doubled if you have ×2 (numbers only), then add + cards, then +15 for seven different numbers. A Negative flips the sign last. Two Negatives cancel out.',
    'If you have a Negative and draw a duplicate, you don\'t score 0: your total before the duplicate is deducted from your score.',
    'Flip 3: pick a player (or yourself) to draw 3 cards in a row. Any action card among them is played right away.',
    'Freeze: the frozen player leaves the round with their current points.',
    'Freeze and Negative only go to players still in the round. If you\'re the only one left, they land on you.',
    'After seven numbers you may keep going. A duplicate after that loses the whole round, bonus included.',
    'When someone reaches the target at the end of a round, the highest total wins.',
    'Before a game you choose the deck: every card, no action cards, numbers only, or Chaos.',
    'Chaos adds: Steal (take a rival\'s best number), Swap (your lowest for their highest), ÷2 and minus cards (aimed at a rival), One More (one card, then they must stop) and Shield (blocks one card aimed at you).',
  ];

  @override
  Widget build(BuildContext context) => Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('Quick rules', style: TextStyle(color: C.saffron, fontWeight: FontWeight.w800)),
          children: [
            for (final r in rules)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('•  ', style: TextStyle(color: C.saffron)),
                  Expanded(child: Text(r, style: const TextStyle(fontSize: 14, height: 1.4))),
                ]),
              ),
          ],
        ),
      );
}
