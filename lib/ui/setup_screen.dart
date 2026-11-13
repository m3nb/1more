import 'package:flutter/material.dart';

import '../engine/engine.dart';
import '../engine/model.dart';
import '../game/controller.dart';
import 'game_screen.dart';
import 'theme.dart';

class SeatDraft {
  final TextEditingController name;
  String type;
  SeatDraft(String n, this.type) : name = TextEditingController(text: n);
}

/// Shared widgets for choosing the target score.
class TargetPicker extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const TargetPicker({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Wrap(spacing: 8, runSpacing: 8, children: [
        for (final t in kTargets)
          ChoiceChip(
            label: Text('$t', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            selected: t == value,
            selectedColor: C.saffron,
            labelStyle: TextStyle(color: t == value ? C.stockInk : C.ink),
            onSelected: (_) => onChanged(t),
          ),
      ]);
}

/// Which cards are in the deck.
class DeckModePicker extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const DeckModePicker({super.key, required this.value, required this.onChanged});

  static const _help = [
    'Everything: bonus cards and all four action cards.',
    'Numbers plus the +2 to +10 and ×2 bonus cards. No Freeze, Flip 3, Second Chance or Negative.',
    'Only the number cards 0 to 12. Pure luck and nerve.',
  ];

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (var i = 0; i < kDeckModes.length; i++)
            ChoiceChip(
              label: Text(kDeckModes[i], style: const TextStyle(fontWeight: FontWeight.w800)),
              selected: i == value,
              selectedColor: C.saffron,
              labelStyle: TextStyle(color: i == value ? C.stockInk : C.ink),
              onSelected: (_) => onChanged(i),
            ),
        ]),
        const SizedBox(height: 6),
        Text(_help[value], style: const TextStyle(color: C.inkSoft, fontSize: 12)),
      ]);
}

/// Computer characters, as "Name · Title".
final Map<String, String> cpuTypes = {
  for (final e in kPersonas.entries) e.key: '${e.value.name} · ${e.value.title}',
};

/// A persona's name, numbered if that name is already taken.
String personaName(String type, Iterable<String> taken) {
  final base = kPersonas[type]?.name ?? 'CPU';
  if (!taken.contains(base)) return base;
  var n = 2;
  while (taken.contains('$base $n')) {
    n++;
  }
  return '$base $n';
}


class LocalSetupScreen extends StatefulWidget {
  const LocalSetupScreen({super.key});
  @override
  State<LocalSetupScreen> createState() => _LocalSetupScreenState();
}

class _LocalSetupScreenState extends State<LocalSetupScreen> {
  final seats = <SeatDraft>[
    SeatDraft('You', 'human'),
    SeatDraft('Rocky', 'rocky'),
    SeatDraft('Vex', 'vex'),
  ];
  int target = 200;
  int deckMode = 0;
  bool fast = false;

  void _start() {
    final players = [
      for (var i = 0; i < seats.length; i++)
        Player(
          name: seats[i].name.text.trim().isEmpty ? 'Player ${i + 1}' : seats[i].name.text.trim(),
          type: seats[i].type,
        )
    ];
    final ctl = EngineController(Engine.newGame(players, target, deckMode: deckMode), fast: fast);
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => GameScreen(controller: ctl)))
        .then((_) => ctl.dispose());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Local game'), backgroundColor: C.felt),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Label('Players (2–8)'),
                Row(children: [
                  IconButton.outlined(
                    onPressed: seats.length > 2 ? () => setState(() => seats.removeLast()) : null,
                    icon: const Icon(Icons.remove),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text('${seats.length}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                  ),
                  IconButton.outlined(
                    onPressed: seats.length < 8
                        ? () => setState(() {
                              final keys = kPersonas.keys.toList();
                              final used = seats.map((x) => x.type).toSet();
                              final type = keys.firstWhere((k) => !used.contains(k),
                                  orElse: () => keys[seats.length % keys.length]);
                              seats.add(SeatDraft(personaName(type, seats.map((x) => x.name.text)), type));
                            })
                        : null,
                    icon: const Icon(Icons.add),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Take turns on this device, or play the computer',
                        style: TextStyle(color: C.inkSoft, fontSize: 13)),
                  ),
                ]),
                const SizedBox(height: 12),
                for (var i = 0; i < seats.length; i++)
                  Padding(
                    key: ObjectKey(seats[i]),
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      SizedBox(
                        width: 28,
                        child: Text('${i + 1}',
                            style: const TextStyle(color: C.saffron, fontWeight: FontWeight.w900, fontSize: 18)),
                      ),
                      Expanded(
                        child: TextField(
                          controller: seats[i].name,
                          maxLength: 16,
                          buildCounter: _noCounter,
                          // Computer characters keep their own names.
                          readOnly: seats[i].type != 'human',
                          enableInteractiveSelection: seats[i].type == 'human',
                          style: TextStyle(color: seats[i].type == 'human' ? C.ink : C.saffron, fontWeight: FontWeight.w700),
                          decoration: InputDecoration(
                            suffixIcon: seats[i].type == 'human'
                                ? null
                                : const Icon(Icons.lock_outline, size: 18, color: C.inkSoft),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 160,
                        child: DropdownButtonFormField<String>(
                          initialValue: seats[i].type,
                          items: [
                            const DropdownMenuItem(value: 'human', child: Text('Human')),
                            for (final e in kPersonas.entries)
                              DropdownMenuItem(value: e.key, child: Text(e.value.name)),
                          ],
                          onChanged: (v) => setState(() {
                            final type = v ?? 'human';
                            final wasCpu = seats[i].type != 'human';
                            seats[i].type = type;
                            final others = [for (var k = 0; k < seats.length; k++) if (k != i) seats[k].name.text];
                            if (type != 'human') {
                              seats[i].name.text = personaName(type, others);
                            } else if (wasCpu) {
                              seats[i].name.text = 'Player ${i + 1}';
                            }
                          }),
                        ),
                      ),
                    ]),
                    if (kPersonas[seats[i].type] != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 28, top: 4),
                        child: Text(
                          '${kPersonas[seats[i].type]!.title}: ${kPersonas[seats[i].type]!.blurb}',
                          style: const TextStyle(color: C.inkSoft, fontSize: 12),
                        ),
                      ),
                    ]),
                  ),
              ]),
            ),
            const SizedBox(height: 16),
            Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Label('Points to win'),
                TargetPicker(value: target, onChanged: (t) => setState(() => target = t)),
                const SizedBox(height: 16),
                const Label('Cards'),
                DeckModePicker(value: deckMode, onChanged: (m) => setState(() => deckMode = m)),
                const SizedBox(height: 16),
                const Label('Computer speed'),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Normal')),
                    ButtonSegment(value: true, label: Text('Fast')),
                  ],
                  selected: {fast},
                  onSelectionChanged: (v) => setState(() => fast = v.first),
                ),
                const SizedBox(height: 20),
                SizedBox(width: double.infinity, child: FilledButton(onPressed: _start, child: const Text('Start game'))),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

Widget? _noCounter(BuildContext context,
        {required int currentLength, required bool isFocused, required int? maxLength}) =>
    null;
