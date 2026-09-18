import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// ═══════════════════════════════════════════════════════════════════════
/// CustomTextField — Campo de texto padronizado v2.0
///
/// Encapsula TextFormField com styling consistente e validação.
/// ═══════════════════════════════════════════════════════════════════════
class CustomTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final bool readOnly;
  final int? maxLines;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String)? onFieldSubmitted;
  final void Function()? onTap;

  const CustomTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.readOnly = false,
    this.maxLines = 1,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      readOnly: readOnly,
      maxLines: maxLines,
      validator: validator,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
        suffixIcon: suffixIcon,
      ),
    );
  }
}

/// Badge de categoria colorido (Alimentos, Bebidas, etc.)
class CategoryBadge extends StatelessWidget {
  final String label;
  final Color? color;
  final double fontSize;

  const CategoryBadge({
    super.key,
    required this.label,
    this.color,
    this.fontSize = 11,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final badgeColor = color ?? AppColors.gold;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: isDark ? 0.2 : 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: badgeColor.withValues(alpha: isDark ? 0.4 : 0.3),
          width: 0.5,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: badgeColor,
        ),
      ),
    );
  }
}

/// Badge da Curva ABC (Classe A, B, C)
class AbcClassBadge extends StatelessWidget {
  final String classe; // 'A', 'B', 'C'
  final double fontSize;

  const AbcClassBadge({
    super.key,
    required this.classe,
    this.fontSize = 11,
  });

  Color get _color {
    switch (classe.toUpperCase()) {
      case 'A':
        return AppColors.classeA;
      case 'B':
        return AppColors.classeB;
      case 'C':
        return AppColors.classeC;
      default:
        return AppColors.darkTextSecondary;
    }
  }

  String get _label {
    switch (classe.toUpperCase()) {
      case 'A':
        return 'Classe A';
      case 'B':
        return 'Classe B';
      case 'C':
        return 'Classe C';
      default:
        return classe;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: isDark ? 0.2 : 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: _color.withValues(alpha: isDark ? 0.5 : 0.35),
          width: 0.5,
        ),
      ),
      child: Text(
        _label,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: _color,
        ),
      ),
    );
  }
}
