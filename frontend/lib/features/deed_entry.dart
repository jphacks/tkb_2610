import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/controller.dart';
import '../widgets/common.dart';

String newRequestId() {
  final r = Random.secure();
  final b = List.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 15) | 64;
  b[8] = (b[8] & 63) | 128;
  final h = b.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

Future<void> openDeedEntry(
  BuildContext context,
  GameController controller,
) async {
  controller.dismissResult();
  final submitted = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: .35),
    enableDrag: false,
    isDismissible: false,
    builder: (_) => DeedEntry(controller: controller),
  );
  if (submitted == true && context.mounted) context.go('/home');
}

class DeedEntry extends StatefulWidget {
  const DeedEntry({super.key, required this.controller});
  final GameController controller;
  @override
  State<DeedEntry> createState() => _DeedEntryState();
}

class _DeedEntryState extends State<DeedEntry> {
  final text = TextEditingController();
  final form = GlobalKey<FormState>();
  String? error, requestId, sentText;
  bool sending = false;
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (sending || !form.currentState!.validate()) return;
    final content = text.text.trim();
    if (sentText != content) {
      requestId = newRequestId();
      sentText = content;
    }
    setState(() {
      sending = true;
      error = null;
    });
    try {
      await widget.controller.post(content, requestId!);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          error = GameController.message(e);
          sending = false;
        });
      }
    }
  }

  Future<void> close() async {
    if (sending) return;
    if (text.text.trim().isNotEmpty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('入力をやめますか？'),
          content: const Text('入力中の内容は保存されません。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('続ける'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('閉じる'),
            ),
          ],
        ),
      );
      if (discard != true) return;
    }
    if (mounted) Navigator.pop(context, false);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) close();
    },
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        24,
        16,
        MediaQuery.viewInsetsOf(context).bottom +
            MediaQuery.paddingOf(context).bottom +
            90,
      ),
      child: SingleChildScrollView(
        child: Panel(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '善行を記録',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '閉じる',
                      onPressed: sending ? null : close,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text('今日の善行'),
                const SizedBox(height: 8),
                TextFormField(
                  key: const ValueKey('deed-content'),
                  controller: text,
                  enabled: !sending,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: 500,
                  validator: (v) => v == null || v.trim().isEmpty
                      ? '今日の善行を入力してください'
                      : v.characters.length > 500
                      ? '500文字以内で入力してください'
                      : null,
                  decoration: const InputDecoration(hintText: '例：電車で席をゆずりました。'),
                ),
                if (error != null) ErrorNotice(error!),
                const SizedBox(height: 8),
                PrimaryButton(
                  label: error == null ? '送る' : 'もう一度送る',
                  onPressed: submit,
                  busy: sending,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
