import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Slate & Mist colour palette
class AppColors {
  static const background = Color(0xFF202A35);
  static const surface = Color(0xFF2C3845);
  static const field = Color(0xFF273340);
  static const navigation = Color(0xFF1B242E);

  static const accent = Color(0xFFA8C4D9);
  static const accentSoft = Color(0xFF354C5D);

  static const text = Color(0xFFF2F5F7);
  static const muted = Color(0xFFB5C0CC);
  static const border = Color(0xFF4A5D6E);

  static const error = Color(0xFFFFB4AB);

  // Compatibility with earlier code.
  static const gold = accent;
  static const coffee = surface;
  static const olive = background;
  static const beige = muted;
}

class RoadColors {
  static const background = AppColors.background;
  static const surface = AppColors.surface;
  static const field = AppColors.field;
  static const border = AppColors.border;
  static const brown = AppColors.accent;
  static const text = AppColors.text;
  static const muted = AppColors.muted;
}

const appSystemStyle = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
  systemNavigationBarColor: AppColors.navigation,
  systemNavigationBarIconBrightness: Brightness.light,
);

class AutoCareTheme {
  static OutlineInputBorder _inputBorder(Color color, [double width = 1]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  static ThemeData get theme {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.accent,
          brightness: Brightness.dark,
        ).copyWith(
          primary: AppColors.accent,
          onPrimary: AppColors.navigation,
          secondary: AppColors.accent,
          onSecondary: AppColors.navigation,
          surface: AppColors.surface,
          onSurface: AppColors.text,
          outline: AppColors.border,
          error: AppColors.error,
          onError: AppColors.navigation,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      dividerColor: AppColors.border,

      // App bars
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: appSystemStyle,
        titleTextStyle: TextStyle(
          color: AppColors.text,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),

      // Cards
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: AppColors.border, width: 0.7),
        ),
      ),

      // Forms and search fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.field,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 19,
        ),
        labelStyle: const TextStyle(color: AppColors.muted),
        floatingLabelStyle: const TextStyle(color: AppColors.accent),
        hintStyle: const TextStyle(color: AppColors.muted),
        prefixIconColor: AppColors.muted,
        suffixIconColor: AppColors.muted,
        border: _inputBorder(AppColors.border),
        enabledBorder: _inputBorder(AppColors.border),
        disabledBorder: _inputBorder(AppColors.border),
        focusedBorder: _inputBorder(AppColors.accent, 1.8),
        errorBorder: _inputBorder(AppColors.error),
        focusedErrorBorder: _inputBorder(AppColors.error, 1.8),
      ),

      // Main buttons
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.navigation,
          disabledBackgroundColor: AppColors.accentSoft,
          disabledForegroundColor: AppColors.muted,
          minimumSize: const Size(0, 54),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),

      // Secondary buttons
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accent,
          side: const BorderSide(color: AppColors.border),
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.accent),
      ),

      // Add Customer / Add Vehicle / Add Part buttons
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.navigation,
        elevation: 2,
      ),

      // Bottom navigation
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.navigation,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.accentSoft,
        elevation: 0,
        height: 72,
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
          final selected = states.contains(WidgetState.selected);

          return TextStyle(
            color: selected ? AppColors.accent : AppColors.muted,
            fontSize: 10,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
          final selected = states.contains(WidgetState.selected);

          return IconThemeData(
            color: selected ? AppColors.accent : AppColors.muted,
            size: 24,
          );
        }),
      ),

      // Filters
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.field,
        selectedColor: AppColors.accentSoft,
        checkmarkColor: AppColors.accent,
        labelStyle: const TextStyle(color: AppColors.text),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      // Loading indicators
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accent,
      ),

      // Text selection
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.accent,
        selectionColor: Color(0x55A8C4D9),
        selectionHandleColor: AppColors.accent,
      ),

      // Messages
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surface,
        contentTextStyle: const TextStyle(color: AppColors.text),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border),
        ),
      ),

      // Dialogs
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: const TextStyle(
          color: AppColors.text,
          fontSize: 21,
          fontWeight: FontWeight.w800,
        ),
        contentTextStyle: const TextStyle(
          color: AppColors.muted,
          fontSize: 14,
          height: 1.5,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }
}
