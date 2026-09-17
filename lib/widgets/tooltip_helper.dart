import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// ═══════════════════════════════════════════════════════════════════════
/// Dica Contextual (Tooltip Helper)
/// Mostra um ícone ❓ que ao ser tocado exibe uma explicação
/// em linguagem simples para o microempreendedor.
/// ═══════════════════════════════════════════════════════════════════════
class TooltipHelper extends StatelessWidget {
  final String message;
  final double iconSize;
  final Color? iconColor;

  const TooltipHelper({
    super.key,
    required this.message,
    this.iconSize = 22,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Ajuda: $message',
      button: true,
      child: Tooltip(
        message: message,
        triggerMode: TooltipTriggerMode.tap,
        showDuration: const Duration(seconds: 6),
        preferBelow: true,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.textPrimary,
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          height: 1.4,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(
              Icons.help_outline_rounded,
              size: iconSize,
              color: iconColor ?? AppColors.textHint,
            ),
          ),
        ),
      ),
    );
  }
}

/// Banner de dica que aparece no topo de formulários
/// para guiar usuários com baixo letramento digital
class HintBanner extends StatefulWidget {
  final String message;
  final IconData icon;
  final bool dismissible;

  const HintBanner({
    super.key,
    required this.message,
    this.icon = Icons.lightbulb_outline,
    this.dismissible = true,
  });

  @override
  State<HintBanner> createState() => _HintBannerState();
}

class _HintBannerState extends State<HintBanner> {
  bool _visible = true;

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    return Semantics(
      label: 'Dica: ${widget.message}',
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.infoLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderFocus.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(widget.icon, color: AppColors.info, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.message,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.primary,
                  height: 1.4,
                ),
              ),
            ),
            if (widget.dismissible)
              InkWell(
                onTap: () => setState(() => _visible = false),
                borderRadius: BorderRadius.circular(20),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close, size: 18, color: AppColors.textHint),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
