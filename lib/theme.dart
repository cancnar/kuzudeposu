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
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Renk.cizgi),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Renk.cizgi),
      ),
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
