import 'package:flutter/material.dart';
import 'app.dart';
import 'core/controller.dart';
import 'data/repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = GameController(DemoRepository(LocalSnapshotStore()));
  runApp(YoinokoApp(controller: controller));
  controller.initialize();
}
