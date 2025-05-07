import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tatarai/core/theme/dimensions.dart';
import 'package:tatarai/core/theme/text_theme.dart';
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
  final IconData? suffixIcon;
  final VoidCallback? onSuffixIconTap;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final bool expands;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final AutovalidateMode? autovalidateMode;
  final String? Function(String?)? validator;
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
    this.suffixIcon,
    this.onSuffixIconTap,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.expands = false,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.autovalidateMode,
    this.validator,
    this.enabled = true,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late FocusNode _focusNode;
  bool _focused = false;
  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
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
    final Color borderColor = hasError
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
            style: AppTextTheme.bodyLarge.copyWith(
              color: hasError ? AppColors.error : AppColors.textSecondary,
            ),
          ),
          SizedBox(height: context.dimensions.spaceXS),
        ],
        Container(
          decoration: BoxDecoration(
            color:
                widget.enabled ? AppColors.surface : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(context.dimensions.radiusS),
            border: Border.all(color: borderColor, width: 1.0),
          ),
          child: CupertinoTextField(
            controller: widget.controller,
            focusNode: _focusNode,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(context.dimensions.radiusS),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: context.dimensions.paddingM,
              vertical: context.dimensions.paddingM,
            ),
            placeholder: widget.hintText,
            placeholderStyle: AppTextTheme.bodyMedium.copyWith(
              color: AppColors.textTertiary,
            ),
            style: AppTextTheme.bodyMedium.copyWith(
              color: AppColors.textPrimary,
            ),
            prefix: widget.prefixIcon != null
                ? Padding(
                    padding: EdgeInsets.only(left: context.dimensions.paddingM),
                    child: Icon(
                      widget.prefixIcon,
                      color: AppColors.textSecondary,
                      size: context.dimensions.iconSizeM,
                    ),
                  )
                : null,
            suffix: widget.obscureText
                ? GestureDetector(
                    onTap: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });

                      if (widget.onSuffixIconTap != null) {
                        widget.onSuffixIconTap!();
                      }
                    },
                    child: Padding(
                      padding:
                          EdgeInsets.only(right: context.dimensions.paddingM),
                      child: Icon(
                        _isPasswordVisible
                            ? CupertinoIcons.eye_slash
                            : CupertinoIcons.eye,
                        color: AppColors.textSecondary,
                        size: context.dimensions.iconSizeM,
                      ),
                    ),
                  )
                : widget.suffixIcon != null
                    ? GestureDetector(
                        onTap: widget.onSuffixIconTap,
                        child: Padding(
                          padding: EdgeInsets.only(
                              right: context.dimensions.paddingM),
                          child: Icon(
                            widget.suffixIcon,
                            color: AppColors.textSecondary,
                            size: context.dimensions.iconSizeM,
                          ),
                        ),
                      )
                    : null,
            obscureText: widget.obscureText && !_isPasswordVisible,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            autofocus: widget.autofocus,
            onChanged: widget.onChanged,
            onEditingComplete: widget.onEditingComplete,
            onSubmitted: widget.onSubmitted,
            maxLines: widget.obscureText ? 1 : widget.maxLines,
            minLines: widget.minLines,
            maxLength: widget.maxLength,
            expands: widget.expands,
            textCapitalization: widget.textCapitalization,
            inputFormatters: widget.inputFormatters,
            enabled: widget.enabled,
          ),
        ),
        if (hasError) ...[
          SizedBox(height: context.dimensions.spaceXXS),
          Text(
            widget.errorText!,
            style: AppTextTheme.bodyLarge.copyWith(color: AppColors.error),
          ),
        ],
      ],
    );
  }
}
