import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';

class CustomTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? prefixIcon;
  final bool isPassword;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final int maxLines;
  final bool readOnly;
  final VoidCallback? onTap;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final String? errorText;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.prefixIcon,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.maxLines = 1,
    this.readOnly = false,
    this.onTap,
    this.textInputAction,
    this.onChanged,
    this.enabled = true,
    this.errorText,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  bool _obscureText = true;
  bool _isFocused = false;
  String? _internalErrorText;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveErrorText = widget.errorText ?? _internalErrorText;

    return Semantics(
      label: widget.label,
      textField: true,
      enabled: widget.enabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label
          Padding(
            padding: const EdgeInsets.only(right: 4, bottom: 8),
            child: Text(
              widget.label,
              style: TextStyle(
                fontFamily: AppFonts.arabic,
                fontWeight: FontWeight.bold,
                color: effectiveErrorText != null
                    ? AppColors.error
                    : (_isFocused ? AppColors.primary : (isDark ? AppColors.gray400 : AppColors.textSecondary)),
                fontSize: 13,
              ),
            ),
          ),

          // Field container
          Focus(
            onFocusChange: (hasFocus) {
              setState(() => _isFocused = hasFocus);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              decoration: BoxDecoration(
                color: isDark ? AppColors.webCardBackground : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: effectiveErrorText != null
                      ? AppColors.error
                      : (_isFocused ? AppColors.primary : (isDark ? AppColors.webBorder : AppColors.gray300)),
                  width: _isFocused ? 1.5 : 1.0,
                ),
                boxShadow: _isFocused
                    ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  )
                ]
                    : [],
              ),
              child: TextFormField(
                controller: widget.controller,
                obscureText: widget.isPassword ? _obscureText : false,
                keyboardType: widget.keyboardType,
                textInputAction: widget.textInputAction,
                maxLines: widget.maxLines,
                readOnly: widget.readOnly,
                enabled: widget.enabled,
                onTap: widget.onTap,
                onChanged: (val) {
                  if (widget.validator != null) {
                    setState(() => _internalErrorText = widget.validator!(val));
                  }
                  if (widget.onChanged != null) widget.onChanged!(val);
                },
                enableSuggestions: !widget.isPassword,
                autocorrect: !widget.isPassword,
                obscuringCharacter: '●',
                style: TextStyle(
                  fontFamily: AppFonts.arabic,
                  fontSize: 15,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: widget.hint,
                  hintStyle: TextStyle(
                    fontFamily: AppFonts.arabic,
                    color: isDark ? AppColors.gray500 : AppColors.textSecondary.withOpacity(0.6),
                    fontSize: 13,
                  ),
                  prefixIcon: widget.prefixIcon != null
                      ? Icon(
                    widget.prefixIcon,
                    color: _isFocused ? AppColors.primary : AppColors.gray500,
                    size: 22,
                  )
                      : null,
                  suffixIcon: widget.isPassword
                      ? IconButton(
                    icon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: Icon(
                        _obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        key: ValueKey(_obscureText),
                        color: AppColors.gray500,
                        size: 22,
                      ),
                    ),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      setState(() => _obscureText = !_obscureText);
                    },
                  )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                ),
              ),
            ),
          ),

          // Error message
          if (effectiveErrorText != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 8),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: effectiveErrorText != null ? 1.0 : 0.0,
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, size: 14, color: AppColors.error),
                    const SizedBox(width: 4),
                    Text(
                      effectiveErrorText,
                      style: const TextStyle(
                        fontFamily: AppFonts.arabic,
                        color: AppColors.error,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}