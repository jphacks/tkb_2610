import 'package:flutter/material.dart';
import 'app.dart';
import 'core/api_client.dart';
import 'core/config.dart';
import 'core/controller.dart';
import 'core/theme.dart';
import 'data/api_repository.dart';
import 'data/repository.dart';
import 'features/android_pet_overlay.dart';

@pragma('vm:entry-point')
void petOverlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AndroidPetOverlay());
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    AppConfig.validate();
    final GameRepository repository = AppConfig.isDemo
        ? DemoRepository(LocalSnapshotStore())
        : ApiRepository(
            ApiClient(
              baseUrl: AppConfig.baseUrl,
              sessions: SecureSessionStore(AppConfig.baseUrl),
            ),
          );
    final controller = GameController(repository);
    runApp(YoinokoApp(controller: controller, isDemo: AppConfig.isDemo));
    controller.initialize();
  } catch (e) {
    runApp(
      MaterialApp(
        theme: yoinokoTheme(),
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(GameController.message(e)),
            ),
          ),
        ),
      ),
    );
  }
}
