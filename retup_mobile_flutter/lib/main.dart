import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart'; // ← AGREGAR ESTE IMPORT
import 'providers/auth_provider.dart';
import 'providers/reto_provider.dart';
import 'providers/pildora_provider.dart';
import 'providers/racha_provider.dart';
import 'providers/notification_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/social_screen.dart';
import 'screens/rachas_screen.dart';
import 'screens/practicalo_screen.dart';
import 'utils/colors.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<void> main() async {
  // Inicializar Supabase con credenciales directas
  await Supabase.initialize(
    url: 'https://ebysbekfijndklgkpk.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVieXNic2Vma2Zqam5ka2xna3BrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg3ODk1ODEsImV4cCI6MjEwNDM2NTU4MX0.WL5wGCnAA9v8QIwX7drFxhHVaKaIEfHj7-48vupu8xI',
  );

  // ← AGREGAR ESTAS DOS LÍNEAS
  await initializeDateFormatting('es_ES', null);
  await initializeDateFormatting('es', null);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => RetoProvider()),
        ChangeNotifierProvider(create: (_) => PildoraProvider()),
        ChangeNotifierProvider(create: (_) => RachaProvider()),
        ChangeNotifierProvider(
          create: (context) => NotificationProvider(),
        ),
      ],
      child: MaterialApp(
        title: 'RetUp',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6366F1),
            brightness: Brightness.light,
          ),
        ),
        routes: {
          '/': (context) => Consumer<AuthProvider>(
                builder: (context, authProvider, _) {
                  if (!authProvider.isAuthenticated) {
                    return const LoginScreen();
                  }
                  return const HomeScreen();
                },
              ),
          '/profile': (context) => const ProfileScreen(),
          '/social': (context) => const SocialScreen(),
          '/rachas': (context) => const RachasScreen(),
          '/practicalo': (context) => const PracticaloScreen(),
        },
      ),
    );
  }
}
