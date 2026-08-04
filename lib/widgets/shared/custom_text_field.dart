// lib/widgets/custom_text_field.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // للأمان والاهتزاز اللمسي
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
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  bool _obscureText = true;
  bool _isFocused = false;
  String? _errorText;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // تسمية الحقل (Label) بشكل أنيق
        Padding(
          padding: const EdgeInsets.only(right: 4, bottom: 8),
          child: Text(
            widget.label,
            style: TextStyle(
              fontFamily: AppFonts.arabic,
              fontWeight: FontWeight.bold,
              color: _errorText != null
                  ? AppColors.error
                  : (_isFocused ? AppColors.primary : AppColors.textSecondary),
              fontSize: 13,
            ),
          ),
        ),

        // حاوية الحقل مع تأثيرات بصرية متقدمة
        Focus(
          onFocusChange: (hasFocus) {
            setState(() => _isFocused = hasFocus);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _errorText != null
                    ? AppColors.error
                    : (_isFocused ? AppColors.primary : AppColors.gray200),
                width: _isFocused ? 1.5 : 1.0,
              ),
              boxShadow: _isFocused
                  ? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
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
              onTap: widget.onTap,
              onChanged: (val) {
                if (widget.validator != null) {
                  setState(() => _errorText = widget.validator!(val));
                }
                if (widget.onChanged != null) widget.onChanged!(val);
              },
              // إعدادات الأمان
              enableSuggestions: !widget.isPassword,
              autocorrect: !widget.isPassword,
              obscuringCharacter: '●', // شكل عصري لإخفاء كلمة المرور

              style: TextStyle(
                fontFamily: AppFonts.arabic,
                fontSize: 15,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),

              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: TextStyle(
                  fontFamily: AppFonts.arabic,
                  color: AppColors.textSecondary.withOpacity(0.5),
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
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      _obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      key: ValueKey(_obscureText),
                      color: AppColors.gray500,
                      size: 22,
                    ),
                  ),
                  onPressed: () {
                    HapticFeedback.selectionClick(); // اهتزاز خفيف عند التبديل
                    setState(() => _obscureText = !_obscureText);
                  },
                )
                    : null,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
          ),
        ),

        // عرض رسالة الخطأ بأسلوب أنيميشن بسيط
        if (_errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 8),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: _errorText != null ? 1.0 : 0.0,
              child: Row(
                children: [
                  const Icon(Icons.error_outline, size: 14, color: AppColors.error),
                  const SizedBox(width: 4),
                  Text(
                    _errorText!,
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
    );
  }
}