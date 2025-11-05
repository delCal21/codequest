import 'package:flutter/material.dart';

class AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;
  final IconData? prefixIcon;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final bool hasError;
  final bool showUnderline;

  const AuthTextField({
    super.key,
    required this.controller,
    required this.labelText,
    this.hintText,
    this.obscureText = false,
    this.keyboardType,
    this.suffixIcon,
    this.prefixIcon,
    this.validator,
    this.onChanged,
    this.hasError = false,
    this.showUnderline = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      onChanged: onChanged,
      validator: validator,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon:
            prefixIcon != null ? Icon(prefixIcon, color: Colors.grey) : null,
        suffixIcon: suffixIcon,
        enabledBorder: showUnderline
            ? UnderlineInputBorder(
                borderSide: BorderSide(
                  color: hasError
                      ? Theme.of(context).colorScheme.error
                      : Colors.grey.shade400,
                ),
              )
            : OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    BorderSide(color: Theme.of(context).colorScheme.outline),
              ),
        focusedBorder: showUnderline
            ? UnderlineInputBorder(
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                ),
              )
            : OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                ),
              ),
        errorBorder: showUnderline
            ? UnderlineInputBorder(
                borderSide:
                    BorderSide(color: Theme.of(context).colorScheme.error),
              )
            : OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    BorderSide(color: Theme.of(context).colorScheme.error),
              ),
        focusedErrorBorder: showUnderline
            ? UnderlineInputBorder(
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.error,
                  width: 2,
                ),
              )
            : OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.error,
                  width: 2,
                ),
              ),
        filled: true,
        fillColor: Colors.transparent,
        contentPadding: showUnderline
            ? const EdgeInsets.symmetric(vertical: 8.0, horizontal: 0.0)
            : const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
      ),
    );
  }
}
