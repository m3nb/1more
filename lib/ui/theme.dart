import 'package:flutter/material.dart';

class C {
  static const felt = Color(0xFF0E2B2C);
  static const felt2 = Color(0xFF143A3B);
  static const line = Color(0xFF24524F);
  static const ink = Color(0xFFEEF3EA);
  static const inkSoft = Color(0xFFA9C1BB);
  static const stock = Color(0xFFF6EFE0);
  static const stockInk = Color(0xFF1D2423);
  static const saffron = Color(0xFFF2B134);
  static const coral = Color(0xFFFF6F5E);
  static const ice = Color(0xFF86D6F2);
  static const mint = Color(0xFF73DBA0);
  static const plum = Color(0xFFE46BB0);
  static const violet = Color(0xFFB39BFF);
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: C.saffron,
      brightness: Brightness.dark,
      primary: C.saffron,
      onPrimary: C.stockInk,
      surface: C.felt2,
      onSurface: C.ink,
    ),
    scaffoldBackgroundColor: C.felt,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: C.ink, displayColor: C.ink),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: C.saffron,
        foregroundColor: C.stockInk,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: C.ink,
        side: const BorderSide(color: C.line),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: C.felt,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: C.line)),
      enabledBorder:
          OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: C.line)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    ),
    dialogTheme: const DialogThemeData(backgroundColor: C.felt2),
  );
}

/// Panel used for grouped sections.
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? border;
  final Color? fill;
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.border, this.fill});

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: fill ?? Colors.black.withValues(alpha: 0.16),
          border: Border.all(color: border ?? C.line, width: border == null ? 1 : 2),
          borderRadius: BorderRadius.circular(14),
        ),
        child: child,
      );
}

class Label extends StatelessWidget {
  final String text;
  const Label(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text.toUpperCase(),
            style: const TextStyle(
                color: C.inkSoft, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.1)),
      );
}

const titleStyle = TextStyle(color: C.saffron, fontSize: 44, fontWeight: FontWeight.w900, height: 1);

/// One colour per seat, so a player is recognisable everywhere on the table.
const playerColors = [
  Color(0xFF86D6F2),
  Color(0xFF73DBA0),
  Color(0xFFE46BB0),
  Color(0xFFB39BFF),
  Color(0xFFFFA94D),
  Color(0xFFC5E063),
  Color(0xFF6FA8FF),
  Color(0xFFFF8FA3),
];

Color playerColor(int seat) => playerColors[seat % playerColors.length];
