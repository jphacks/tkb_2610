import 'package:flutter/material.dart';
import '../core/controller.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../widgets/character_view.dart';
import '../widgets/common.dart';

String? validateName(String? value) {
  final name = value?.trim() ?? '';
  if (name.isEmpty) return '名前を入力してください';
  if (name.length > 20) return '名前は20文字以内で入力してください';
  if (RegExp(r'[\x00-\x1F\x7F]').hasMatch(name)) {
    return '使用できない文字が含まれています';
  }
  return null;
}

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key, required this.controller});
  final GameController controller;
  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController();
  String? error;
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() => error = null);
    try {
      await widget.controller.register(name.text.trim());
    } catch (e) {
      if (mounted) setState(() => error = GameController.message(e));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  const SizedBox(height: 52),
                  const Text(
                    'よいのこ',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text('善いことを、この子と。'),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.only(top: 32),
                    child: CharacterView(
                      character: Companion(
                        id: 'preview',
                        generation: 1,
                        bornAt: DateTime.now(),
                      ),
                      size: 128,
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    color: floor,
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
                    child: Panel(
                      child: Form(
                        key: form,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Center(
                              child: Text(
                                'はじめまして',
                                style: TextStyle(
                                  fontSize: 23,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text('プレイヤー名'),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: name,
                              validator: validateName,
                              maxLength: 20,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) =>
                                  widget.controller.busy ? null : submit(),
                              decoration: const InputDecoration(
                                hintText: '名前を入力',
                                counterText: '',
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '名前はあとから変更できます',
                              style: TextStyle(fontSize: 12, color: muted),
                            ),
                            if (error != null) ErrorNotice(error!),
                            const SizedBox(height: 24),
                            PrimaryButton(
                              label: 'はじめる',
                              onPressed: submit,
                              busy: widget.controller.busy,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
