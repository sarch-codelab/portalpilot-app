import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';

/// Campo de formulario Portal Pilot con teclado virtual optimizado (móvil).
///
/// Aplica automáticamente [TextInputAction] adecuado al tipo de texto,
/// `autofillHints`, y fluye el foco con [FocusTraversalGroup] para que
/// "próximo" funcione en formularios largos.
class PPFormField extends StatelessWidget {
  final TextEditingController? controller;
  final String label;
  final String? hint;
  final IconData? icon;
  final TextInputType keyboardType;
  final bool obscureText;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;
  final VoidCallback? onSubmitted;
  final int? maxLines;
  final bool enabled;

  const PPFormField({
    super.key,
    this.controller,
    required this.label,
    this.hint,
    this.icon,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.validator,
    this.onChanged,
    this.textInputAction,
    this.focusNode,
    this.onSubmitted,
    this.maxLines = 1,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ThemePalette(isDark: appThemeNotifier.isDark);
    final action = textInputAction ?? _actionFor(keyboardType);

    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      onChanged: onChanged,
      enabled: enabled,
      maxLines: obscureText ? 1 : maxLines,
      textInputAction: action,
      onFieldSubmitted: onSubmitted != null ? (_) => onSubmitted!() : null,
      autofillHints: _hintsFor(keyboardType),
      style: GoogleFonts.dmSans(fontSize: 14, color: palette.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: GoogleFonts.dmSans(fontSize: 13, color: palette.textDim),
        labelStyle: GoogleFonts.dmSans(fontSize: 13, color: palette.textMuted),
        prefixIcon: icon != null
            ? Icon(icon, size: 18, color: palette.brand)
            : null,
        alignLabelWithHint: maxLines != null && maxLines! > 1,
        filled: true,
        fillColor: palette.cardColor,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 14,
          vertical: maxLines != null && maxLines! > 1 ? 16 : 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFB94DDC), width: 1.5),
        ),
      ),
    );
  }

  static TextInputAction _actionFor(TextInputType type) {
    return switch (type) {
      TextInputType.emailAddress => TextInputAction.next,
      TextInputType.phone => TextInputAction.next,
      TextInputType.datetime => TextInputAction.next,
      TextInputType.multiline => TextInputAction.newline,
      TextInputType.number => TextInputAction.done,
      _ => TextInputAction.next,
    };
  }

  static List<String>? _hintsFor(TextInputType type) {
    return switch (type) {
      TextInputType.emailAddress => const [AutofillHints.email],
      TextInputType.phone => const [AutofillHints.telephoneNumber],
      TextInputType.name => const [AutofillHints.name],
      _ => null,
    };
  }
}

/// Sección de formulario agrupada en una tarjeta Portal Pilot.
class PPFormSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<Widget> children;

  const PPFormSection({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ThemePalette(isDark: appThemeNotifier.isDark);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: GoogleFonts.syne(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: palette.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FocusTraversalGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _withSpacing(children),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _withSpacing(List<Widget> children) {
    return [
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) const SizedBox(height: 14),
        children[i],
      ],
    ];
  }
}