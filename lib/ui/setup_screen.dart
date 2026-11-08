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

const cpuTypes = {
  'easy': 'CPU · Easy',
  'medium': 'CPU · Medium',
  'hard': 'CPU · Hard',
};

class LocalSetupScreen extends StatefulWidget {
  const LocalSetupScreen({super.key});
  @override
  State<LocalSetupScreen> createState() => _LocalSetupScreenState();
}

class _LocalSetupScreenState extends State<LocalSetupScreen> {
  final seats = <SeatDraft>[
    SeatDraft('You', 'human'),
    SeatDraft('CPU 1', 'medium'),
    SeatDraft('CPU 2', 'hard'),
  ];
  int target = 200;
  bool fast = false;

  void _start() {
    final players = [
      for (var i = 0; i < seats.length; i++)
        Player(
          name: seats[i].name.text.trim().isEmpty ? 'Player ${i + 1}' : seats[i].name.text.trim(),
          type: seats[i].type,
        )
    ];
    final ctl = EngineController(Engine.newGame(players, target), fast: fast);
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
                        ? () => setState(() => seats.add(SeatDraft('CPU ${seats.length}', 'medium')))
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
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      SizedBox(
                        width: 28,
                        child: Text('${i + 1}',
                            style: const TextStyle(color: C.saffron, fontWeight: FontWeight.w900, fontSize: 18)),
                      ),
                      Expanded(child: TextField(controller: seats[i].name, maxLength: 16, buildCounter: _noCounter)),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 160,
                        child: DropdownButtonFormField<String>(
                          initialValue: seats[i].type,
                          items: const [
                            DropdownMenuItem(value: 'human', child: Text('Human')),
                            DropdownMenuItem(value: 'easy', child: Text('CPU · Easy')),
                            DropdownMenuItem(value: 'medium', child: Text('CPU · Medium')),
                            DropdownMenuItem(value: 'hard', child: Text('CPU · Hard')),
                          ],
                          onChanged: (v) => setState(() => seats[i].type = v ?? 'human'),
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
