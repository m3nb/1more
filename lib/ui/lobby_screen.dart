import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config.dart';
import '../net/session.dart';
import 'game_screen.dart';
import 'setup_screen.dart';
import 'theme.dart';

String inviteLink(String code) {
  if (kWebUrl.isEmpty) return '';
  final base = kWebUrl.endsWith('/') ? kWebUrl : '$kWebUrl/';
  return '$base?room=$code';
}

String inviteText(String code) {
  final link = inviteLink(code);
  return link.isEmpty
      ? 'Join my 1More game! Room code: $code'
      : 'Join my 1More game! Open $link or enter room code $code in the app.';
}

class LobbyScreen extends StatefulWidget {
  final OnlineSession session;
  const LobbyScreen({super.key, required this.session});
  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  OnlineSession get s => widget.session;
  bool _inGame = false;

  @override
  void initState() {
    super.initState();
    s.addListener(_onChange);
  }

  @override
  void dispose() {
    s.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (!mounted) return;
    if (s.controller != null && !_inGame) {
      _inGame = true;
      final ctl = s.controller!;
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => GameScreen(controller: ctl, myClientId: s.myId)))
          .then((_) async {
        await s.close();
        ctl.dispose();
        if (mounted) Navigator.of(context).pop();
      });
    }
    setState(() {});
  }

  Future<void> _leave() async {
    await s.close();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: inviteText(s.code)));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Invite copied. Paste it in WhatsApp or any chat.')));
    }
  }

  String _seatType(LobbySeat x) {
    if (x.type == 'human') return 'Host';
    if (x.type == 'remote') return 'Online';
    return cpuTypes[x.type] ?? x.type;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: C.felt,
          title: Text(s.isHost ? 'Your room' : 'Room ${s.code}'),
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _leave),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(padding: const EdgeInsets.all(16), children: [
              if (s.fatal != null)
                Panel(
                  border: C.coral,
                  child: Text(s.fatal!, style: const TextStyle(color: C.coral, fontWeight: FontWeight.w700)),
                ),
              if (s.fatal != null) const SizedBox(height: 16),
              Panel(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Label('Room code'),
                  SelectableText(s.code,
                      style: const TextStyle(
                          fontSize: 44, fontWeight: FontWeight.w900, letterSpacing: 6, color: C.saffron)),
                  if (s.isHost) ...[
                    const SizedBox(height: 8),
                    if (inviteLink(s.code).isNotEmpty)
                      SelectableText(inviteLink(s.code), style: const TextStyle(color: C.inkSoft, fontSize: 13)),
                    const SizedBox(height: 12),
                    FilledButton.icon(onPressed: _copy, icon: const Icon(Icons.copy), label: const Text('Copy invite')),
                  ],
                  if (s.note != null) ...[
                    const SizedBox(height: 10),
                    Text(s.note!, style: const TextStyle(color: C.inkSoft)),
                  ],
                ]),
              ),
              const SizedBox(height: 16),
              Panel(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Label('Players (${s.seats.length}/8)'),
                  if (s.seats.isEmpty) const Text('Connecting…', style: TextStyle(color: C.inkSoft)),
                  for (var i = 0; i < s.seats.length; i++)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: C.felt2,
                        child: Text('${i + 1}', style: const TextStyle(color: C.saffron, fontWeight: FontWeight.w900)),
                      ),
                      title: Text(s.seats[i].name + (s.seats[i].cid == s.myId ? ' (you)' : '')),
                      subtitle: Text(_seatType(s.seats[i]), style: const TextStyle(color: C.inkSoft)),
                      trailing: s.isHost && i > 0
                          ? IconButton(
                              icon: const Icon(Icons.close),
                              tooltip: 'Remove',
                              onPressed: () => s.removeSeat(i),
                            )
                          : null,
                    ),
                  if (s.isHost) ...[
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final e in cpuTypes.entries)
                        OutlinedButton.icon(
                          onPressed: s.seats.length < 8 ? () => s.addCpu(e.key) : null,
                          icon: const Icon(Icons.smart_toy_outlined, size: 18),
                          label: Text('Add ${e.value}'),
                        ),
                    ]),
                  ],
                ]),
              ),
              const SizedBox(height: 16),
              Panel(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Label('Points to win'),
                  if (s.isHost)
                    TargetPicker(value: s.target, onChanged: s.setTarget)
                  else
                    Text('${s.target}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 20),
                  if (s.isHost)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: s.seats.length >= 2 ? s.startGame : null,
                        child: Text(s.seats.length >= 2 ? 'Start game' : 'Waiting for players…'),
                      ),
                    )
                  else
                    Text(
                      s.amInLobby ? 'You\'re in. Waiting for the host to start…' : 'Joining…',
                      style: const TextStyle(color: C.inkSoft),
                    ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
