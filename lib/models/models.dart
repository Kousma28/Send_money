import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class Transaction {
  final String id;
  final String name;
  final double amount;
  final String date;
  final TransactionType type;
  final String country;
  final String flag;
  final String? avatar;

  Transaction({
    required this.id,
    required this.name,
    required this.amount,
    required this.date,
    required this.type,
    required this.country,
    required this.flag,
    this.avatar,
  });
}

enum TransactionType { sent, received }

class Country {
  final String name;
  final String code;
  final String flag;
  final String dialCode;
  final double rate;

  Country({
    required this.name,
    required this.code,
    required this.flag,
    required this.dialCode,
    required this.rate,
  });
}

class Contact {
  final String name;
  final String phone;
  final String country;
  final String flag;

  Contact({
    required this.name,
    required this.phone,
    required this.country,
    required this.flag,
  });
}

class AppColors {
  static const Color primary = Color(0xFF6366F1);
  static const Color secondary = Color(0xFF8B5CF6);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color background = Color(0xFFF8F9FA);
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color border = Color(0xFFE5E7EB);
}

class AppTextStyles {
  static const TextStyle headline1 = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );
  
  static const TextStyle headline2 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );
  
  static const TextStyle headline3 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );
  
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );
  
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );
  
  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );
  
  static const TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );
}

class AppShadows {
  static BoxShadow small = BoxShadow(
    color: Colors.black.withValues(alpha: 0.04),
    blurRadius: 10,
    offset: const Offset(0, 4),
  );
  
  static BoxShadow medium = BoxShadow(
    color: Colors.black.withValues(alpha: 0.1),
    blurRadius: 20,
    offset: const Offset(0, 10),
  );
  
  static BoxShadow large = BoxShadow(
    color: Colors.black.withValues(alpha: 0.15),
    blurRadius: 30,
    offset: const Offset(0, 15),
  );
  
  static BoxShadow colored(Color color) => BoxShadow(
    color: color.withValues(alpha: 0.3),
    blurRadius: 12,
    offset: const Offset(0, 6),
  );
}

class AppBorderRadius {
  static const double small = 8.0;
  static const double medium = 12.0;
  static const double large = 16.0;
  static const double extraLarge = 20.0;
  static const double round = 30.0;
}

class AppGradients {
  static const LinearGradient primary = LinearGradient(
    colors: [AppColors.primary, AppColors.secondary],
  );
  
  static const LinearGradient success = LinearGradient(
    colors: [AppColors.success, Color(0xFF059669)],
  );
  
  static const LinearGradient warning = LinearGradient(
    colors: [AppColors.warning, Color(0xFFD97706)],
  );
  
  static const LinearGradient error = LinearGradient(
    colors: [AppColors.error, Color(0xFFDC2626)],
  );
}

class AppAnimations {
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration medium = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration extraSlow = Duration(milliseconds: 1000);
  
  static const Curve easeIn = Curves.easeIn;
  static const Curve easeOut = Curves.easeOut;
  static const Curve easeInOut = Curves.easeInOut;
  static const Curve easeOutQuart = Curves.easeOutQuart;
  static const Curve easeOutCubic = Curves.easeOutCubic;
}
