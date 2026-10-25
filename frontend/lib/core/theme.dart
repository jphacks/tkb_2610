import 'package:flutter/material.dart';

const ink = Color(0xFF214E59);
const muted = Color(0xFF35515A);
const aqua = Color(0xFF58D9DE);
const teal = Color(0xFF126F7B);
const wall = aqua;
const floor = Color(0xFFE5F8F5);
const peach = Color(0xFFCEF1EF);
const orange = teal;
const line = Color(0xFFB9DFDF);
const categoryColors = [
  Color(0xFFC84F76),
  Color(0xFF477E48),
  Color(0xFF8C5CB3),
  Color(0xFFAE6420),
  Color(0xFF3977AF),
  Color(0xFF806048),
  Color(0xFF7560AB),
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
    seedColor: aqua,
    primary: teal,
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
    fillColor: const Color(0xFFF0FAF9),
    contentPadding: const EdgeInsets.all(16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: const BorderSide(color: line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: const BorderSide(color: line),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: const BorderSide(color: teal, width: 2),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: teal,
      foregroundColor: Colors.white,
      minimumSize: const Size(48, 50),
      textStyle: const TextStyle(
        fontFamily: 'Rounded',
        fontWeight: FontWeight.w700,
        fontSize: 16,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: ink,
      minimumSize: const Size(48, 48),
      side: const BorderSide(color: line),
    ),
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
  ),
);
