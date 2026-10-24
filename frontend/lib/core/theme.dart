import 'package:flutter/material.dart';

const ink = Color(0xFF25324A);
const muted = Color(0xFF788296);
const wall = Color(0xFFE8F5FD);
const floor = Color(0xFFEDEAE6);
const peach = Color(0xFFFFBE96);
const orange = Color(0xFFE88A46);
const line = Color(0xFFCDD2DA);
const categoryColors = [
  Color(0xFFEF8798),
  Color(0xFF8ABF78),
  Color(0xFFBA91D9),
  Color(0xFFF2A35F),
  Color(0xFF80AFE3),
  Color(0xFFA88E79),
  Color(0xFFA694D5),
];
const categoryIcons = [
  Icons.favorite_outline_rounded,
  Icons.eco_outlined,
  Icons.local_florist_outlined,
  Icons.local_fire_department_outlined,
  Icons.water_drop_outlined,
  Icons.diamond_outlined,
  Icons.nightlight_outlined,
];
ThemeData yoinokoTheme() => ThemeData(
  useMaterial3: true,
  fontFamily: 'Rounded',
  scaffoldBackgroundColor: wall,
  colorScheme: ColorScheme.fromSeed(
    seedColor: peach,
    primary: ink,
    surface: Colors.white,
    error: const Color(0xFFB74444),
  ),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(fontSize: 14, height: 1.5, color: ink),
    bodyLarge: TextStyle(fontSize: 16, color: ink),
    titleLarge: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: ink,
    ),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: wall,
    foregroundColor: ink,
    surfaceTintColor: Colors.transparent,
    centerTitle: false,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFFFAFBFC),
    contentPadding: const EdgeInsets.all(16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: line),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: peach,
      foregroundColor: ink,
      minimumSize: const Size(48, 50),
      textStyle: const TextStyle(
        fontFamily: 'Rounded',
        fontWeight: FontWeight.w700,
        fontSize: 16,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: ink,
      minimumSize: const Size(48, 48),
      side: const BorderSide(color: line),
    ),
  ),
);
