import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Palette et typographie communes à toute l'app — vert forêt (confiance,
/// argent) + or chaud (accent/actions) + fond crème (chaleur), à la place
/// de l'indigo/violet et du gris froid par défaut. Importer avec
/// `import '../theme/app_theme.dart';` depuis lib/pages/, ou
/// `import 'theme/app_theme.dart';` depuis home_screen.dart.
class AppColors {
  static const bg = Color(0xFFFAF7F0);
  static const surface = Color(0xFFF1EDE1); // surfaces imbriquées : chips, inputs neutres
  static const forestDark = Color(0xFF0B3D2E);
  static const forestDarker = Color(0xFF072A20);
  static const ink = Color(0xFF1A2E22);
  static const inkMuted = Color(0xFF6B7D72);
  static const inkFaint = Color(0xFFAAB3A9); // icônes/labels inactifs
  static const gold = Color(0xFFC9A227);
  static const goldLight = Color(0xFFE8C766);
  static const terracotta = Color(0xFF8A6B3A);
  static const clay = Color(0xFFB9583F);
  static const cardLine = Color(0xFFEBE5D8);
  static const success = Color(0xFF1E7A52);
  static const successDark = Color(0xFF145C3D);
  static const pending = Color(0xFFB9583F);
  static const error = Color(0xFFC1443A);
  static const errorDark = Color(0xFF8F2E26);
}

/// Fraunces (serif) pour les titres et montants qui doivent porter de la
/// personnalité ; Inter (sans) pour le reste — deux familles nettement
/// distinctes plutôt qu'une seule police système sans hiérarchie affirmée.
class AppText {
  static TextStyle serif({
    double size = 24,
    FontWeight weight = FontWeight.w600,
    Color? color,
    double? letterSpacing,
    double? height,
  }) {
    return GoogleFonts.fraunces(
      fontSize: size,
      fontWeight: weight,
      color: color ?? AppColors.ink,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  static TextStyle sans({
    double size = 14,
    FontWeight weight = FontWeight.w500,
    Color? color,
    double? letterSpacing,
    double? height,
  }) {
    return GoogleFonts.inter(
      fontSize: size,
      fontWeight: weight,
      color: color ?? AppColors.ink,
      letterSpacing: letterSpacing,
      height: height,
    );
  }
}