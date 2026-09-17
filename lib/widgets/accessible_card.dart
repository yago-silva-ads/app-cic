import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// ═══════════════════════════════════════════════════════════════════════
/// Card Acessível do App CIC
/// • Semantics descritivo para leitores de tela
/// • Bordas visíveis e espaçamento generoso
/// • Variantes semânticas: sucesso, aviso, erro, info, neutro
/// ═══════════════════════════════════════════════════════════════════════

enum CardVariant { neutral, success, warning, error, info }

class AccessibleCard extends StatelessWidget {
  final Widget child;
  final String? semanticsLabel;
  final CardVariant variant;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool hasBorder;

  const AccessibleCard({
    super.key,
    required this.child,
    this.semanticsLabel,
    this.variant = CardVariant.neutral,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.hasBorder = true,
  });

  Color get _backgroundColor {
    switch (variant) {
      case CardVariant.success:  return AppColors.successLight;
      case CardVariant.warning:  return AppColors.warningLight;
      case CardVariant.error:    return AppColors.errorLight;
      case CardVariant.info:     return AppColors.infoLight;
      case CardVariant.neutral:  return AppColors.surface;
    }
  }

  Color get _borderColor {
    switch (variant) {
      case CardVariant.success:  return AppColors.successBorder;
      case CardVariant.warning:  return AppColors.warningBorder;
      case CardVariant.error:    return AppColors.errorBorder;
      case CardVariant.info:     return AppColors.borderFocus;
      case CardVariant.neutral:  return AppColors.divider;
    }
  }



  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: hasBorder
          ? Border.all(color: _borderColor, width: 1.5)
          : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );

    final Widget wrappedCard = onTap != null
      ? InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: card,
        )
      : card;

    if (semanticsLabel != null) {
      return Semantics(
        label: semanticsLabel,
        container: true,
        child: wrappedCard,
      );
    }

    return wrappedCard;
  }

  /// Helper para criar um card de alerta com ícone + mensagem
  static Widget alert({
    required String message,
    required CardVariant variant,
    String? semanticsLabel,
  }) {
    final iconData = variant == CardVariant.success
      ? Icons.check_circle_outline
      : variant == CardVariant.warning
        ? Icons.warning_amber_rounded
        : variant == CardVariant.error
          ? Icons.error_outline
          : Icons.info_outline;

    final iconColor = variant == CardVariant.success
      ? AppColors.success
      : variant == CardVariant.warning
        ? AppColors.warning
        : variant == CardVariant.error
          ? AppColors.error
          : AppColors.info;

    final textColor = variant == CardVariant.success
      ? AppColors.success
      : variant == CardVariant.warning
        ? AppColors.warning
        : variant == CardVariant.error
          ? AppColors.error
          : AppColors.info;

    return AccessibleCard(
      variant: variant,
      semanticsLabel: semanticsLabel ?? message,
      child: Row(
        children: [
          Icon(iconData, color: iconColor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w600,
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
