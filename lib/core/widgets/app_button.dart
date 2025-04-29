import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:sprung/sprung.dart';
import 'package:tatarai/core/theme/text_theme.dart';
import '../theme/color_scheme.dart';

/// Buton tipleri - Apple HIG'e uygun olarak düzenlenmiştir
enum AppButtonType {
  /// Ana buton - Prominent action
  primary,

  /// İkincil buton - Default action
  secondary,

  /// Tehlikeli işlem butonu - Destructive action
  destructive,

  /// Text buton - Plain button
  text,
}

/// Apple Human Interface Guidelines'a uygun olarak tasarlanmış buton bileşeni.
/// Cupertino tasarım dilini ve spring animasyonlarını kullanır.
class AppButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final AppButtonType type;
  final bool isLoading;
  final bool isFullWidth;
  final IconData? icon;
  final double height;
  final EdgeInsets? padding;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.type = AppButtonType.primary,
    this.isLoading = false,
    this.isFullWidth = true,
    this.icon,
    this.height = 48.0,
    this.padding,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _pressController,
      curve: Sprung.custom(
        mass: 1.0,
        stiffness: 400.0,
        damping: 15.0,
      ),
    ));
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _handlePress() {
    if (!widget.isLoading && widget.onPressed != null) {
      widget.onPressed!();
    }
  }

  void _handleTapDown() {
    if (!widget.isLoading && widget.onPressed != null) {
      setState(() => _isPressed = true);
      _pressController.forward();
    }
  }

  void _handleTapUp() {
    if (!widget.isLoading && widget.onPressed != null) {
      setState(() => _isPressed = false);
      _pressController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final buttonContent = ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        height: widget.height,
        padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: _getBackgroundColor(),
          borderRadius: BorderRadius.circular(10),
          border: widget.type == AppButtonType.secondary
              ? Border.all(color: AppColors.primary.withOpacity(0.3), width: 1)
              : null,
          boxShadow: widget.type != AppButtonType.text
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: _buildContent(),
      ),
    );

    final buttonChild = CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: widget.isLoading ? null : widget.onPressed,
      child: buttonContent,
    );

    return GestureDetector(
      onTapDown: (_) => _handleTapDown(),
      onTapUp: (_) => _handleTapUp(),
      onTapCancel: () => _handleTapUp(),
      child: widget.isFullWidth
          ? SizedBox(
              width: double.infinity,
              height: widget.height,
              child: buttonChild,
            )
          : SizedBox(height: widget.height, child: buttonChild),
    );
  }

  Widget _buildContent() {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: widget.isLoading || widget.onPressed == null ? 0.5 : 1.0,
      child: Center(
        child: widget.isLoading
            ? CupertinoActivityIndicator(color: _getTextColor())
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, color: _getTextColor(), size: 18),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    widget.text,
                    style: AppTextTheme.labelLarge.copyWith(
                      color: _getTextColor(),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Color _getBackgroundColor() {
    final baseColor = switch (widget.type) {
      AppButtonType.primary => AppColors.primary,
      AppButtonType.secondary => AppColors.surface,
      AppButtonType.destructive => AppColors.error,
      AppButtonType.text => Colors.transparent,
    };

    if (_isPressed && widget.onPressed != null && !widget.isLoading) {
      return baseColor.withOpacity(0.8);
    }

    return baseColor;
  }

  Color _getTextColor() {
    return switch (widget.type) {
      AppButtonType.primary => AppColors.onPrimary,
      AppButtonType.secondary => AppColors.primary,
      AppButtonType.destructive => AppColors.onPrimary,
      AppButtonType.text => AppColors.primary,
    };
  }
}

/* 
// Örnek Kullanım:
Row(
  children: [
    // Primary Buton
    AppButton(
      text: 'Primary',
      onPressed: () {},
      type: AppButtonType.primary,
      isFullWidth: false,
    ),
    
    const SizedBox(width: 8),
    
    // Secondary Buton
    AppButton(
      text: 'Secondary',
      onPressed: () {},
      type: AppButtonType.secondary,
      isFullWidth: false,
    ),
    
    const SizedBox(width: 8),
    
    // Destructive Buton
    AppButton(
      text: 'Destructive',
      onPressed: () {},
      type: AppButtonType.destructive,
      isFullWidth: false,
    ),
    
    const SizedBox(width: 8),
    
    // Text Buton
    AppButton(
      text: 'Text',
      onPressed: () {},
      type: AppButtonType.text,
      isFullWidth: false,
    ),
  ],
)
*/
