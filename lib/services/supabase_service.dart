import 'package:supabase_flutter/supabase_flutter.dart';

/// Inicializa Supabase utilizando variables de entorno.
///
/// Para desarrollo local, usa `--dart-define-from-file=.env`:
///   flutter run --dart-define-from-file=.env -d chrome
///
/// Para Vercel, configura las variables SUPABASE_URL y SUPABASE_ANON_KEY
/// en el panel de Environment Variables del proyecto. El build command debe ser:
///   flutter build web --dart-define=SUPABASE_URL=$SUPABASE_URL --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
Future<void> initializeSupabase() async {
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    throw Exception(
      'Las variables de entorno SUPABASE_URL y SUPABASE_ANON_KEY no están configuradas.\n'
      'Para desarrollo local, ejecuta: flutter run --dart-define-from-file=.env -d chrome\n'
      'Para producción (Vercel), configura las variables en el panel del proyecto.',
    );
  }

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );
}
