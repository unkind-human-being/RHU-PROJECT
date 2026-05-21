import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'features/auth/auth_provider.dart';
import 'features/medicine/medicine_provider.dart';
import 'features/splash/splash_screen.dart';
import 'routes/app_routes.dart';
import 'features/sync/sync_provider.dart';
import 'features/public/public_provider.dart';

class RHUApp extends StatelessWidget {
  const RHUApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
            providers: <ChangeNotifierProvider>[
                ChangeNotifierProvider<AuthProvider>(
                  create: (_) => AuthProvider(),
                ),
                ChangeNotifierProvider<MedicineProvider>(
                  create: (_) => MedicineProvider(),
                ),
                ChangeNotifierProvider<SyncProvider>(
                  create: (_) => SyncProvider(),
                ),
                ChangeNotifierProvider<PublicProvider>(
                  create: (_) => PublicProvider(),
                ),
              ],
      child: MaterialApp(
        title: 'Tawi-Tawi RHU Mobile Portal',
        debugShowCheckedModeBanner: false,
        theme: _RHUTheme.light,
        initialRoute: AppRoutes.splash,
        routes: AppRoutes.routes,
        onUnknownRoute: (_) {
          return MaterialPageRoute<void>(
            builder: (_) => const SplashScreen(),
          );
        },
      ),
    );
  }
}

class _RHUTheme {
  static const Color primary = Color(0xFF0F766E);
  static const Color accent = Color(0xFF14B8A6);
  static const Color background = Color(0xFFF7FAF9);
  static const Color surface = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color danger = Color(0xFFDC2626);

  static ThemeData get light {
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      primary: primary,
      secondary: accent,
      surface: surface,
      error: danger,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textDark,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(
            color: Color(0xFFE5E7EB),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: const TextStyle(
          color: textMuted,
          fontSize: 14,
        ),
        labelStyle: const TextStyle(
          color: textMuted,
          fontSize: 14,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: Color(0xFFE5E7EB),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: Color(0xFFE5E7EB),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: primary,
            width: 1.6,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: danger,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(double.infinity, 54),
          side: const BorderSide(
            color: Color(0xFFD1D5DB),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: textDark,
          fontSize: 30,
          height: 1.15,
          fontWeight: FontWeight.w800,
        ),
        headlineMedium: TextStyle(
          color: textDark,
          fontSize: 24,
          height: 1.2,
          fontWeight: FontWeight.w800,
        ),
        titleLarge: TextStyle(
          color: textDark,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
        titleMedium: TextStyle(
          color: textDark,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: TextStyle(
          color: textDark,
          fontSize: 16,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          color: textMuted,
          fontSize: 14,
          height: 1.45,
        ),
      ),
    );
  }
}