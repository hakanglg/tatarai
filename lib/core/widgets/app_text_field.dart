import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';
import '../theme/color_scheme.dart';

/// Uygulama genelinde kullanılacak standart metin giriş bileşeni
class AppTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? labelText;
  final String? hintText;
  final String? errorText;
  final bool obscureText;
  final bool autofocus;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onEditingComplete;
  final ValueChanged<String>? onSubmitted;
  final IconData? prefixIcon;
  final Widget? suffix;
  final int? maxLines;
  final int? maxLength;
  final bool enabled;

  const AppTextField({
    super.key,
    this.controller,
    this.labelText,
    this.hintText,
    this.errorText,
    this.obscureText = false,
    this.autofocus = false,
    this.focusNode,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onEditingComplete,
    this.onSubmitted,
    this.prefixIcon,
    this.suffix,
    this.maxLines = 1,
    this.maxLength,
    this.enabled = true,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late FocusNode _focusNode;
  bool _focused = false;
  bool _obscureText = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
    _obscureText = widget.obscureText;
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    _focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _focused = _focusNode.hasFocus;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool hasError =
        widget.errorText != null && widget.errorText!.isNotEmpty;
    final Color borderColor =
        hasError
            ? AppColors.error
            : _focused
            ? AppColors.primary
            : AppColors.border;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.labelText != null) ...[
          Text(
            widget.labelText!,
            style: AppTextStyles.labelMedium.copyWith(
              color: hasError ? AppColors.error : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Container(
          decoration: BoxDecoration(
            color:
                widget.enabled ? AppColors.surface : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor, width: 1.0),
          ),
          child: CupertinoTextField(
            controller: widget.controller,
            focusNode: _focusNode,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            placeholder: widget.hintText,
            placeholderStyle: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textTertiary,
            ),
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textPrimary,
            ),
            prefix:
                widget.prefixIcon != null
                    ? Padding(
                      padding: const EdgeInsets.only(left: 12.0),
                      child: Icon(
                        widget.prefixIcon,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                    )
                    : null,
            suffix: widget.obscureText ? _buildPasswordToggle() : widget.suffix,
            obscureText: _obscureText,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            autofocus: widget.autofocus,
            onChanged: widget.onChanged,
            onEditingComplete: widget.onEditingComplete,
            onSubmitted: widget.onSubmitted,
            maxLines: widget.maxLines,
            maxLength: widget.maxLength,
            enabled: widget.enabled,
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 4),
          Text(
            widget.errorText!,
            style: AppTextStyles.labelSmall.copyWith(color: AppColors.error),
          ),
        ],
      ],
    );
  }

  Widget _buildPasswordToggle() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _obscureText = !_obscureText;
        });
      },
      child: Padding(
        padding: const EdgeInsets.only(right: 12.0),
        child: Icon(
          _obscureText ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
          color: AppColors.textSecondary,
          size: 20,
        ),
      ),
    );
  }
}
