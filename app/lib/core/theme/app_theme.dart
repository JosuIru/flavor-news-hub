import 'package:flutter/material.dart';

/// Tema Material 3 sobrio, sin dependencia del idioma ni de la plataforma.
///
/// Usa un único `seedColor` del que Material 3 deriva toda la paleta.
/// El color base es el mismo azul del CSS de las plantillas web del
/// backend, para que la app y el fallback web compartan identidad.
class AppTheme {
  AppTheme._();

  static const Color _colorSemilla = Color(0xFF0B63CE);

  static ThemeData claro() => _construir(Brightness.light);

  static ThemeData oscuro() => _construir(Brightness.dark);

  static ThemeData _construir(Brightness brillo) {
    final esquemaColor = ColorScheme.fromSeed(
      seedColor: _colorSemilla,
      brightness: brillo,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: esquemaColor,
      scaffoldBackgroundColor: esquemaColor.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: esquemaColor.surface,
        foregroundColor: esquemaColor.onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: esquemaColor.onSurface,
        ),
      ),
      cardTheme: CardTheme(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: esquemaColor.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: esquemaColor.outlineVariant, width: 1),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: esquemaColor.surfaceContainerHighest,
        labelStyle: TextStyle(color: esquemaColor.onSurfaceVariant),
        side: BorderSide.none,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        backgroundColor: esquemaColor.surface,
        indicatorColor: esquemaColor.primaryContainer,
      ),
    );
  }
}
