import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';

/// ═══════════════════════════════════════════════════════════════════════
/// Botão Acessível do App CIC
/// • Mínimo 56dp de altura (WCAG 2.5.5)
/// • Feedback tátil (haptic) ao tocar
/// • Semantics completo para leitores de tela
/// • Ícone + texto obrigatório (redundância visual)
/// ═══════════════════════════════════════════════════════════════════════
class AccessibleButton extends StatelessWidget {
  final String label;
  final String? semanticsLabel;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double minHeight;
  final bool isDestructive;

  const AccessibleButton({
    super.key,
    required this.label,
    this.semanticsLabel,
    this.icon,
    this.onPressed,
    this.isLoading = false,
    this.backgroundColor,
    this.foregroundColor,
    this.minHeight = 56,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? 
      (isDestructive ? AppColors.error : AppColors.primary);
    final fgColor = foregroundColor ?? AppColors.onPrimary;

    return Semantics(
      label: semanticsLabel ?? label,
      button: true,
      enabled: onPressed != null && !isLoading,
      child: SizedBox(
        height: minHeight,
        child: ElevatedButton.icon(
          onPressed: (onPressed != null && !isLoading)
            ? () {
                HapticFeedback.mediumImpact();
                onPressed!();
              }
            : null,
          icon: isLoading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: fgColor,
                  strokeWidth: 2.5,
                ),
              )
            : (icon != null
                ? Icon(icon, color: fgColor, size: 24)
                : const SizedBox.shrink()),
          label: Text(
            isLoading ? 'Aguarde...' : label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: fgColor,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: bgColor,
            foregroundColor: fgColor,
            disabledBackgroundColor: bgColor.withValues(alpha: 0.5),
            minimumSize: Size(double.infinity, minHeight),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 2,
          ),
        ),
      ),
    );
  }
}

/// Variante secundária (outlined)
class AccessibleOutlinedButton extends StatelessWidget {
  final String label;
  final String? semanticsLabel;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color? borderColor;

  const AccessibleOutlinedButton({
    super.key,
    required this.label,
    this.semanticsLabel,
    this.icon,
    this.onPressed,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel ?? label,
      button: true,
      enabled: onPressed != null,
      child: SizedBox(
        height: 56,
        child: OutlinedButton.icon(
          onPressed: onPressed != null
            ? () {
                HapticFeedback.lightImpact();
                onPressed!();
              }
            : null,
          icon: icon != null
            ? Icon(icon, size: 22)
            : const SizedBox.shrink(),
          label: Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: borderColor ?? AppColors.primary,
            minimumSize: const Size(double.infinity, 56),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            side: BorderSide(
              color: borderColor ?? AppColors.primary,
              width: 2,
            ),
          ),
        ),
      ),
    );
  }
}
