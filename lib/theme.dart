import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Çayır paleti
class Renk {
  static const yesil = Color(0xFF2F5D3A);
  static const krem = Color(0xFFFBF6E9);
  static const kiremit = Color(0xFFB2432C);
  static const murekkep = Color(0xFF3A3220);
  static const cizgi = Color(0xFFE3DCC3);
  static const soluk = Color(0xFF6A5E48);
}

ThemeData kuzuTema() {
  final govde = GoogleFonts.nunitoTextTheme().apply(
    bodyColor: Renk.murekkep,
    displayColor: Renk.murekkep,
  );
  final baslik = GoogleFonts.fraunces(
    fontWeight: FontWeight.w700,
    color: Renk.murekkep,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Renk.yesil,
      primary: Renk.yesil,
      secondary: Renk.kiremit,
      surface: Renk.krem,
    ),
    scaffoldBackgroundColor: Renk.krem,
    appBarTheme: AppBarTheme(
      backgroundColor: Renk.krem,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: Renk.yesil,
      titleTextStyle: baslik.copyWith(fontSize: 22),
    ),
    textTheme: govde.copyWith(
      headlineMedium: baslik.copyWith(fontSize: 28),
      titleLarge: baslik.copyWith(fontSize: 22),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      hoverColor: Colors.white,
      focusColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Renk.cizgi),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Renk.cizgi),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Renk.yesil, width: 1.6),
      ),
      labelStyle: const TextStyle(color: Renk.soluk),
    ),
    dividerColor: Renk.cizgi,
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: Renk.yesil),
    textSelectionTheme: const TextSelectionThemeData(cursorColor: Renk.yesil, selectionHandleColor: Renk.yesil),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Renk.krem,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: Renk.murekkep,
      contentTextStyle: GoogleFonts.nunito(color: Renk.krem, fontWeight: FontWeight.w700),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : Renk.soluk),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Renk.yesil : Renk.cizgi),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Renk.yesil : Colors.transparent),
      checkColor: WidgetStateProperty.all(Colors.white),
      side: const BorderSide(color: Renk.soluk, width: 1.6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Renk.yesil : Colors.white),
        foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : Renk.murekkep),
        side: WidgetStateProperty.all(const BorderSide(color: Renk.cizgi)),
        textStyle: WidgetStateProperty.all(GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 14)),
        shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Renk.yesil,
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: Renk.yesil, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 16),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: Renk.yesil, textStyle: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 15)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Renk.yesil,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 16),
      ),
    ),
  );
}
