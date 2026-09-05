import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

class AppThemeNotifier extends ValueNotifier<ThemeMode> {
  AppThemeNotifier() : super(ThemeMode.dark) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final hasTheme = prefs.containsKey('theme_is_dark');
    final isDark = hasTheme ? (prefs.getBool('theme_is_dark') ?? true) : true;
    value = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> toggle() async {
    final nextMode = value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    value = nextMode;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('theme_is_dark', nextMode == ThemeMode.dark);
  }

  bool get isDark => value == ThemeMode.dark;
}

final appThemeNotifier = AppThemeNotifier();

/// Paleta de marca Portal Pilot — identidad única.
///
/// Colores firmados para Portal Pilot (inspirado en el "habitat" del piloto):
/// magenta/ciruela profundo como ancla primaria, con acento violeta eléctrico,
/// esmeralda, ámbar y cian para estados. La identidad se diferencia de cualquier
/// otro ERP por su gama "nave/piloto" y la fusión entre deep neutral (grafito)
/// y los acentos neón de baja saturación.
class ThemePalette {
  final bool isDark;

  ThemePalette({required this.isDark});

  // ─── Superficies ──────────────────────────────────────────────────────────
  Color get bgPrimary =>
      isDark ? const Color(0xFF070510) : const Color(0xFFF6F4FB);
  Color get bgSecondary =>
      isDark ? const Color(0xFF0E0B1A) : const Color(0xFFECE8F7);
  Color get bgTertiary =>
      isDark ? const Color(0xFF17132A) : const Color(0xFFDDD6F0);
  Color get cardColor => isDark ? const Color(0xFF12101F) : const Color(0xFFFFFFFF);
  Color get cardElevated => isDark ? const Color(0xFF1B1830) : const Color(0xFFFFFFFF);
  Color get borderLight =>
      isDark ? const Color(0x2A9B8FF2) : const Color(0x1A1A1633);
  Color get appBarColor =>
      isDark ? const Color(0xFF0A0814) : const Color(0xFFFFFFFF);
  Color get sidebarColor =>
      isDark ? const Color(0xFF0C0A18) : const Color(0xFFFDFCFF);
  Color get overlayScrim => isDark ? const Color(0xCC000000) : const Color(0x33000000);

  // ─── Marca / Primario ─────────────────────────────────────────────────────
  /// "Magenta Portal" — ancla principal de la marca.
  Color get brand => const Color(0xFFB94DDC);
  Color get brandBright => const Color(0xFFD16BF0);
  Color get brandDim => const Color(0xFF8B2FB0);
  Color get brandDeep => const Color(0xFF5C1A7E);

  /// Violeta eléctrico de acento.
  Color get accentPurple => const Color(0xFF8B5CF6);
  Color get accentPurpleDark => const Color(0xFF6D28D9);
  Color get accentPurpleLight => const Color(0xFFA78BFA);
  Color get accentPurpleDeep => const Color(0xFF5B21B6);

  /// Gradiente de marca (para cabeceras, botones primarios, sidebar).
  List<Color> get brandGradient =>
      isDark ? const [Color(0xFFB94DDC), Color(0xFF6D28D9)] : const [Color(0xFFB94DDC), Color(0xFF6D28D9)];
  List<Color> get brandGradientSoft =>
      isDark ? const [Color(0xFF2A1850), Color(0xFF1A1E3C)] : const [Color(0xFFF3E8FD), Color(0xFFE0E7FB)];

  /// Gradiente de fondo "aurora" para pantallas principales.
  List<Color> get aurora =>
      isDark ? const [Color(0xFF070510), Color(0xFF1A0F2E), Color(0xFF101426)] : const [Color(0xFFF6F4FB), Color(0xFFF1E8FD), Color(0xFFE3E9FB)];

  // ─── Texto ────────────────────────────────────────────────────────────────
  Color get textPrimary => isDark ? const Color(0xFFF5F2FF) : const Color(0xFF1E1B2A);
  Color get textMuted => isDark ? const Color(0xFF9C95B5) : const Color(0xFF675F7D);
  Color get textDim => isDark ? const Color(0xFF5D5672) : const Color(0xFF9289A8);
  Color get textDark => isDark ? const Color(0xFF4A4460) : const Color(0xFF4A4460);
  Color get textOnBrand => Colors.white;

  // ─── Estados ──────────────────────────────────────────────────────────────
  Color get successGreen => const Color(0xFF34C99B);
  Color get successGreenDeep => const Color(0xFF0E8A65);
  Color get warningAmber => const Color(0xFFF5B544);
  Color get warningAmberDeep => const Color(0xFFB97216);
  Color get infoBlue => const Color(0xFF4DA6FF);
  Color get infoBlueDeep => const Color(0xFF1E6FD6);
  Color get errorRed => const Color(0xFFF0506E);
  Color get errorRedDeep => const Color(0xFFBF2D4A);

  // ─── Skeleton / shimmer ──────────────────────────────────────────────────
  Color get skeletonBase =>
      isDark ? const Color(0xFF1A1828) : const Color(0xFFE6E1F2);
  Color get skeletonHighlight =>
      isDark ? const Color(0xFF262238) : const Color(0xFFF2EEFB);

  // ─── Utilidades ───────────────────────────────────────────────────────────
  Color colorWithAlpha(Color color, double alpha) => color.withValues(alpha: alpha);

  /// Sombra de marca para tarjetas/bloques.
  List<BoxShadow> glowShadow(Color color, {double blur = 20, double spread = 0}) => [
        BoxShadow(
          color: color.withValues(alpha: 0.18),
          blurRadius: blur,
          spreadRadius: spread,
          offset: const Offset(0, 6),
        ),
      ];

  static ThemeData buildTheme({required bool isDark}) {
    final base = ThemeData(
      brightness: isDark ? Brightness.dark : Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFB94DDC),
        brightness: isDark ? Brightness.dark : Brightness.light,
        primary: const Color(0xFFB94DDC),
      ),
    );
    return base.copyWith(
      scaffoldBackgroundColor: isDark ? const Color(0xFF070510) : const Color(0xFFF6F4FB),
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? const Color(0xFF0A0814) : Colors.white,
        foregroundColor: isDark ? const Color(0xFFF5F2FF) : const Color(0xFF1E1B2A),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: isDark ? const Color(0xFF12101F) : Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? const Color(0x299B8FF2) : const Color(0x1A1A1633),
        thickness: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? const Color(0xFF17132A) : const Color(0xFFECE8F7),
        side: BorderSide(color: isDark ? const Color(0x299B8FF2) : const Color(0x1A1A1633)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF12101F) : Colors.white,
        hintStyle: GoogleFonts.dmSans(
          fontSize: 13,
          color: isDark ? const Color(0xFF5D5672) : const Color(0xFF9289A8),
        ),
        labelStyle: GoogleFonts.dmSans(
          fontSize: 13,
          color: isDark ? const Color(0xFF9C95B5) : const Color(0xFF675F7D),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? const Color(0x299B8FF2) : const Color(0x1A1A1633)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? const Color(0x299B8FF2) : const Color(0x1A1A1633)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFB94DDC), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFF0506E)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFF0506E), width: 1.5),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: const Color(0xFFB94DDC),
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? const Color(0xFF12101F) : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? const Color(0xFF12101F) : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? const Color(0xFF1B1830) : const Color(0xFF1E1B2A),
        contentTextStyle: GoogleFonts.dmSans(color: Colors.white, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? const Color(0xFF0C0A18) : Colors.white,
        indicatorColor: const Color(0xFFB94DDC).withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.all(
          GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: const Color(0xFFB94DDC),
        linearTrackColor: isDark ? const Color(0xFF1A1828) : const Color(0xFFE6E1F2),
      ),
    );
  }
}
