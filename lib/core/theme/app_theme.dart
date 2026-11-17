import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // Main palette
  static const Color alabasterGrey = Color(0xFFD8E2DC);
  static const Color softRose = Color(0xFFEAD9DE);
  static const Color pastelPink = Color(0xFFFFCAD4);
  static const Color cherryBlossom = Color(0xFFF4ACB7);
  static const Color dustyMauve = Color(0xFF9D8189);
  static const Color winePlum = Color(0xFF723D46);

  // Backward-compatible name for existing screen code
  static const Color powderPetal = softRose;

  static const Color primaryColor = winePlum;
  static const Color secondaryColor = cherryBlossom;
  static const Color backgroundColor = alabasterGrey;
  static const Color surfaceColor = softRose;
  static const Color textColor = winePlum;
  static const Color mutedTextColor = dustyMauve;
  static const Color accentColor = pastelPink;
  static const Color borderColor = cherryBlossom;
  static const Color errorColor = Color(0xFFB3261E);

  static const ColorScheme appColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: winePlum,
    onPrimary: Colors.white,
    secondary: cherryBlossom,
    onSecondary: winePlum,
    tertiary: pastelPink,
    onTertiary: winePlum,
    error: errorColor,
    onError: Colors.white,
    surface: alabasterGrey,
    onSurface: winePlum,
    outline: dustyMauve,
    outlineVariant: cherryBlossom,
    shadow: Colors.black12,
    scrim: Colors.black54,
    inverseSurface: winePlum,
    onInverseSurface: Colors.white,
    inversePrimary: cherryBlossom,
    surfaceTint: winePlum,
  );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: appColorScheme,
      scaffoldBackgroundColor: backgroundColor,

      appBarTheme: const AppBarTheme(
        backgroundColor: alabasterGrey,
        foregroundColor: winePlum,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: winePlum,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),

      textTheme: const TextTheme(
        displayLarge: TextStyle(color: winePlum, fontWeight: FontWeight.bold),
        displayMedium: TextStyle(color: winePlum, fontWeight: FontWeight.bold),
        displaySmall: TextStyle(color: winePlum, fontWeight: FontWeight.bold),
        headlineLarge: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.bold,
          color: winePlum,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: winePlum,
        ),
        headlineSmall: TextStyle(color: winePlum, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: winePlum,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: winePlum,
        ),
        titleSmall: TextStyle(color: winePlum, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(fontSize: 16, color: winePlum),
        bodyMedium: TextStyle(fontSize: 14, color: winePlum),
        bodySmall: TextStyle(fontSize: 12, color: dustyMauve),
        labelLarge: TextStyle(color: winePlum),
        labelMedium: TextStyle(color: winePlum),
        labelSmall: TextStyle(color: dustyMauve),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: winePlum,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          elevation: 2,
          shadowColor: winePlum.withValues(alpha: 0.20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: winePlum,
          backgroundColor: pastelPink,
          minimumSize: const Size(double.infinity, 50),
          side: const BorderSide(color: winePlum, width: 1.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: winePlum,
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: softRose,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        labelStyle: const TextStyle(color: winePlum),
        hintStyle: const TextStyle(color: dustyMauve),
        prefixIconColor: winePlum,
        suffixIconColor: winePlum,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: cherryBlossom),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: cherryBlossom),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: winePlum, width: 2),
        ),
      ),

      cardTheme: CardThemeData(
        color: softRose,
        elevation: 1,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: cherryBlossom, width: 0.8),
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: cherryBlossom,
        thickness: 0.8,
      ),

      iconTheme: const IconThemeData(color: winePlum),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: winePlum,
        linearTrackColor: pastelPink,
        circularTrackColor: pastelPink,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: softRose,
        indicatorColor: cherryBlossom,
        elevation: 1,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.bold
                : FontWeight.normal,
            color: winePlum,
          );
        }),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: winePlum,
        foregroundColor: Colors.white,
        elevation: 2,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: pastelPink,
        selectedColor: cherryBlossom,
        labelStyle: const TextStyle(color: winePlum),
        secondaryLabelStyle: const TextStyle(color: winePlum),
        side: const BorderSide(color: dustyMauve),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
