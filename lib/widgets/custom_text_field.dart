// lib/widgets/custom_text_field.dart
import 'package:flutter/material.dart';

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

  const CustomTextField({
    Key? key,
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
  }) : super(key: key);

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  bool _obscureText = true;
  bool _isFocused = false;

  static const Color _logoBlue = Color(0xFF1E70B8);
  static const Color _logoTeal = Color(0xFF17A5A3);
  static const Color _baseBg = Color(0xFFF1F5F9);

  @override
  Widget build(BuildContext context) {
    return FocusScope(
      child: Focus(
        onFocusChange: (hasFocus) {
          setState(() {
            _isFocused = hasFocus;
          });
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 4, bottom: 8),
              child: Text(
                widget.label,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  color: _logoBlue,
                  fontSize: 13,
                ),
              ),
            ),
            // حاوية التأثير النيومورفي للحقل
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: _baseBg,
                borderRadius: BorderRadius.circular(16),
                boxShadow: _isFocused
                    ? [
                  // تأثير الغوران للداخل عند الضغط
                  BoxShadow(color: const Color(0xFFCBD5E1).withOpacity(0.8), blurRadius: 4, offset: const Offset(2, 2)),
                  const BoxShadow(color: Colors.white, blurRadius: 4, offset: Offset(-2, -2)),
                ]
                    : [
                  // تأثير البروز الناعم في الحالة العادية
                  BoxShadow(color: const Color(0xFFCBD5E1).withOpacity(0.5), blurRadius: 8, offset: const Offset(4, 4)),
                  const BoxShadow(color: Colors.white, blurRadius: 8, offset: Offset(-4, -4)),
                ],
              ),
              child: TextFormField(
                controller: widget.controller,
                obscureText: widget.isPassword ? _obscureText : false,
                keyboardType: widget.keyboardType,
                validator: widget.validator,
                maxLines: widget.maxLines,
                readOnly: widget.readOnly,
                onTap: widget.onTap,
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, color: Colors.black87),
                decoration: InputDecoration(
                  hintText: widget.hint,
                  hintStyle: TextStyle(fontFamily: 'Cairo', color: Colors.grey.shade500, fontSize: 12),
                  prefixIcon: widget.prefixIcon != null
                      ? Icon(widget.prefixIcon, color: _isFocused ? _logoTeal : _logoBlue.withOpacity(0.6), size: 20)
                      : null,
                  suffixIcon: widget.isPassword
                      ? IconButton(
                    icon: Icon(
                      _obscureText ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      color: _logoBlue.withOpacity(0.6),
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureText = !_obscureText;
                      });
                    },
                  )
                      : null,
                  filled: true,
                  fillColor: Colors.transparent, // الاعتماد على لون الحاوية الخارجية
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Colors.redAccent, width: 1),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}