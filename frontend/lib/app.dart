import 'package:flutter/material.dart';
import 'core/controller.dart';
import 'core/theme.dart';
import 'features/home.dart';
import 'features/registration.dart';
import 'widgets/common.dart';

class YoinokoApp extends StatelessWidget {
  const YoinokoApp({super.key, required this.controller});
  final GameController controller;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'よいのこ',
    debugShowCheckedModeBanner: false,
    theme: yoinokoTheme(),
    home: AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (controller.loading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (controller.error != null) {
          return Scaffold(
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ErrorNotice(controller.error!),
                      PrimaryButton(
                        label: '再読み込み',
                        onPressed: controller.initialize,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        if (controller.snapshot == null) {
          return RegistrationPage(controller: controller);
        }
        return Scaffold(
          body: SafeArea(child: HomePage(controller: controller)),
        );
      },
    ),
  );
}
