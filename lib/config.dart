// Online play settings. The anon key is a public key meant to ship inside
// apps; it only allows what the project's settings allow.
//
// They can also be passed at build time:
//   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
const String kSupabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://zegfvsebcmyynpxlrteg.supabase.co');
const String kSupabaseAnonKey =
    String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'sb_publishable_5EACvdIKQI5_iSZf6uSEiQ_W8X9MDb9');

/// Where the web version is hosted; used to build the invite link.
const String kWebUrl = String.fromEnvironment('WEB_URL', defaultValue: 'https://m3nb.github.io/1more/');

bool get onlineConfigured => kSupabaseUrl.isNotEmpty && kSupabaseAnonKey.isNotEmpty;
