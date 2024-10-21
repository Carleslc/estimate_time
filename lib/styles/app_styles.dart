import 'package:flutter/material.dart';

abstract final class AppStyles {
  static Color _seedColor = Colors.lightGreen;

  static ColorScheme colorScheme = ColorScheme.fromSeed(seedColor: _seedColor);

  static ThemeData theme(BuildContext context) {
    // ThemeData defaultTheme = Theme.of(context);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.primary, // colorScheme.inversePrimary
        foregroundColor:
            colorScheme.onPrimary, // colorScheme.onPrimaryContainer
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colorScheme.primary, // colorScheme.primaryContainer
        selectedItemColor: colorScheme.onPrimary, // colorScheme.primary
        unselectedItemColor: colorScheme
            .inversePrimary, // colorScheme.secondary.withOpacity(0.6)
        selectedIconTheme: const IconThemeData(size: 28),
        unselectedIconTheme: const IconThemeData(size: 24),
        selectedLabelStyle: const TextStyle(fontSize: 14),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colorScheme.inverseSurface,
        actionTextColor: colorScheme.inversePrimary,
        contentTextStyle: TextStyle(color: colorScheme.onInverseSurface),
        behavior: SnackBarBehavior.fixed,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.zero),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary, // colorScheme.primaryContainer
        foregroundColor: colorScheme.onPrimary, // colorScheme.primary
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        sizeConstraints: BoxConstraints.tight(Size.fromRadius(32)),
        iconSize: 32,
      ),
      tooltipTheme: TooltipThemeData(
        preferBelow: false,
        margin: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: colorScheme.inverseSurface,
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      dialogTheme: DialogTheme(
        titleTextStyle: TextStyle(
          fontSize: 22,
          color: colorScheme.secondary,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.secondary,
      ),
      listTileTheme: ListTileThemeData(
        selectedColor: colorScheme.primary,
      ),
      dividerTheme: DividerThemeData(color: colorScheme.outlineVariant),
    );
  }
}
