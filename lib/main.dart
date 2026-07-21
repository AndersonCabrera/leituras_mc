import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'screens/auth/tela_login.dart';
import 'core/theme.dart'; // NOVO IMPORT!

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const LeiturasMCApp());
}

class LeiturasMCApp extends StatelessWidget {
  const LeiturasMCApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: temaNotifier,
      builder: (_, ThemeMode currentMode, __) {
        return MaterialApp(
          title: 'Leituras MC',
          debugShowCheckedModeBanner: false,

          // Tema Claro (Padrão Oficial da Marca)
          theme: ThemeData(
            brightness: Brightness.light,
            primaryColor: const Color(0xFF0D47A1),
            scaffoldBackgroundColor: const Color(0xFFF5F6FA),
            useMaterial3: true,
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF0D47A1),
              iconTheme: IconThemeData(color: Colors.white),
              titleTextStyle: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // Tema Escuro (Base inicial para evolução)
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primaryColor: Colors.blueGrey.shade900,
            scaffoldBackgroundColor: const Color(0xFF121212),
            useMaterial3: true,
            appBarTheme: AppBarTheme(
              backgroundColor: Colors.blueGrey.shade900,
              iconTheme: const IconThemeData(color: Colors.white),
              titleTextStyle: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          themeMode: currentMode,

          // Direciona sempre para a tela de Login limpa
          home: const EcraLogin(),
        );
      },
    );
  }
}
