import 'package:flutter/cupertino.dart';
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

  /// Kart yüzeyi (sıcak beyaz)
  static const kart = Color(0xFFFFFDF8);

  /// Dolgulu ikincil buton, sekme zemini
  static const zemin2 = Color(0xFFEDE6CF);

  /// Küpe / güven rozeti
  static const kupe = Color(0xFFF4E3AE);

  /// Olumlu durum zemini ve yazısı
  static const okZemin = Color(0xFFE3ECDA);
  static const okYazi = Color(0xFF24492D);

  /// İnce ayraç
  static const ayrac = Color(0x143A3220);
}

/// Hareket kuralları: sık yapılan işte animasyon yok, girip çıkan her şey güçlü ease-out.
class Hareket {
  static const cikis = Cubic(0.23, 1, 0.32, 1);
  static const yerinde = Cubic(0.77, 0, 0.175, 1);
  static const cekmece = Cubic(0.32, 0.72, 0, 1);
  static const basma = Duration(milliseconds: 160);
  static const renk = Duration(milliseconds: 180);
  static const gosterge = Duration(milliseconds: 240);

  /// Alt sayfalar: açılış 320 ms çekmece eğrisi, kapanış daha hızlı.
  static AnimationStyle get altSayfa => AnimationStyle(
        duration: const Duration(milliseconds: 320),
        reverseDuration: const Duration(milliseconds: 200),
        curve: cekmece,
        reverseCurve: Curves.easeOutCubic,
      );
}

/// Kenarlık yerine katmanlı, yarı saydam gölge.
class Golge {
  static const kart = [
    BoxShadow(color: Color(0x0F3A3220), blurRadius: 0, spreadRadius: 1),
    BoxShadow(color: Color(0x0F3A3220), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x293A3220), blurRadius: 20, spreadRadius: -10, offset: Offset(0, 8)),
  ];
  static const hafif = [
    BoxShadow(color: Color(0x0F3A3220), blurRadius: 0, spreadRadius: 1),
    BoxShadow(color: Color(0x0D3A3220), blurRadius: 2, offset: Offset(0, 1)),
  ];
  static const yuzen = [
    BoxShadow(color: Color(0x263A3220), blurRadius: 8, offset: Offset(0, 2)),
  ];
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
  const cupertino = CupertinoPageTransitionsBuilder();
  final ince = OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: Color(0x1F3A3220)),
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
    // Dalga efekti yerine basma küçülmesi (Basma bileşeni) ve hafif vurgu.
    splashFactory: NoSplash.splashFactory,
    highlightColor: const Color(0x0F3A3220),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.iOS: cupertino,
      TargetPlatform.android: cupertino,
      TargetPlatform.macOS: cupertino,
      TargetPlatform.linux: cupertino,
      TargetPlatform.windows: cupertino,
      TargetPlatform.fuchsia: cupertino,
    }),
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
      fillColor: Renk.kart,
      hoverColor: Renk.kart,
      focusColor: Renk.kart,
      border: ince,
      enabledBorder: ince,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Renk.yesil, width: 1.6),
      ),
      labelStyle: const TextStyle(color: Renk.soluk),
      hintStyle: const TextStyle(color: Renk.soluk),
      prefixIconColor: Renk.soluk,
    ),
    dividerColor: Renk.ayrac,
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: Renk.yesil),
    textSelectionTheme: const TextSelectionThemeData(cursorColor: Renk.yesil, selectionHandleColor: Renk.yesil),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Renk.krem,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: Color(0x383A3220),
      dragHandleSize: Size(40, 5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: Renk.murekkep,
      contentTextStyle: GoogleFonts.nunito(color: Renk.krem, fontWeight: FontWeight.w700),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
        backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Renk.yesil : Renk.kart),
        foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : Renk.murekkep),
        side: WidgetStateProperty.all(const BorderSide(color: Color(0x1F3A3220))),
        textStyle: WidgetStateProperty.all(GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 14)),
        shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      ),
    ),
    // İkincil buton: çizgili değil, dolgulu ve sakin.
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Renk.yesil,
        backgroundColor: Renk.zemin2,
        minimumSize: const Size.fromHeight(52),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 16),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Renk.yesil,
        minimumSize: const Size(44, 44),
        textStyle: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 15),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Renk.yesil,
        foregroundColor: Renk.krem,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 16),
      ),
    ),
  );
}
