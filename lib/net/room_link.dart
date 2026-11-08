import 'dart:async';

import 'package:supabase/supabase.dart';

import '../config.dart';

SupabaseClient? _client;
SupabaseClient get supabase => _client ??= SupabaseClient(kSupabaseUrl, kSupabaseAnonKey);

/// One realtime channel per room. Every message is {k: kind, from: id, ...}.
class RoomLink {
  final String code;
  final String myId;
  RealtimeChannel? _ch;

  void Function(Map<String, dynamic> msg)? onMessage;
  void Function(bool connected, String? note)? onStatus;

  RoomLink(this.code, this.myId);

  static Map<String, dynamic>? _extract(Map<String, dynamic> full) {
    dynamic node = full;
    for (var depth = 0; depth < 3 && node is Map; depth++) {
      if (node['d'] is Map) return Map<String, dynamic>.from(node['d'] as Map);
      node = node['payload'];
    }
    return null;
  }

  Future<void> connect() {
    final done = Completer<void>();
    final ch = supabase.channel('onemore-$code');
    ch.onBroadcast(
      event: 'msg',
      callback: (full) {
        final m = _extract(full);
        if (m == null || m['from'] == myId) return;
        onMessage?.call(m);
      },
    );
    ch.subscribe((status, error) {
      switch (status) {
        case RealtimeSubscribeStatus.subscribed:
          onStatus?.call(true, null);
          if (!done.isCompleted) done.complete();
          break;
        case RealtimeSubscribeStatus.channelError:
        case RealtimeSubscribeStatus.timedOut:
          onStatus?.call(false, 'Connection problem, retrying…');
          if (!done.isCompleted) done.completeError(error ?? 'Could not connect');
          break;
        case RealtimeSubscribeStatus.closed:
          onStatus?.call(false, 'Disconnected');
          break;
      }
    });
    _ch = ch;
    return done.future.timeout(const Duration(seconds: 15));
  }

  Future<void> send(String kind, [Map<String, dynamic> data = const {}]) async {
    final ch = _ch;
    if (ch == null) return;
    await ch.sendBroadcastMessage(event: 'msg', payload: {
      'd': {...data, 'k': kind, 'from': myId},
    });
  }

  Future<void> close() async {
    final ch = _ch;
    _ch = null;
    if (ch != null) await supabase.removeChannel(ch);
  }
}
