import 'package:flutter/material.dart';
import '../core/controller.dart';
import '../core/theme.dart';
import '../widgets/character_view.dart';
import '../widgets/common.dart';
import 'registration.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.controller,
    required this.isDemo,
  });
  final GameController controller;
  final bool isDemo;
  Future<void> changeName(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _NameDialog(controller: controller),
    );
  }

  Future<void> removeAccount(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DeleteDialog(controller: controller),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => Stack(
      children: [
        if (box.maxHeight >= 700 &&
            MediaQuery.textScalerOf(context).scale(14) <= 19) ...[
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 130,
            child: Container(
              decoration: const BoxDecoration(
                color: floor,
                border: Border(top: BorderSide(color: line)),
              ),
            ),
          ),
          Positioned(
            bottom: 90,
            left: 0,
            right: 0,
            child: Center(
              child: CharacterView(
                character: controller.snapshot!.current,
                size: 140,
              ),
            ),
          ),
        ],
        PageBody(
          title: '設定',
          children: [
            Row(
              children: [
                CharacterView(
                  character: controller.snapshot!.current,
                  size: 62,
                  animate: false,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        controller.snapshot!.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text('ゲストで利用中', style: TextStyle(color: muted)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Panel(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    title: const Text('プレイヤー名を変更'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => changeName(context),
                  ),
                  const Divider(height: 1, color: line),
                  const ListTile(
                    title: Text('引き継ぎ設定', style: TextStyle(color: muted)),
                    trailing: Text(
                      '準備中',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text(
                '現在はゲストで利用しています。アプリの削除や端末変更で、データにアクセスできなくなる場合があります。',
                style: TextStyle(fontSize: 12, color: muted),
              ),
            ),
            Panel(
              padding: EdgeInsets.zero,
              child: ListTile(
                title: const Text(
                  '退会する',
                  style: TextStyle(color: Color(0xFFB74444)),
                ),
                subtitle: const Text(
                  'アカウントと育成記録を削除します',
                  style: TextStyle(fontSize: 11, color: muted),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => removeAccount(context),
              ),
            ),
            if (isDemo)
              const Padding(
                padding: EdgeInsets.only(top: 32),
                child: Text(
                  'デモモード\nこの端末だけに保存されます。分類と褒め言葉はデモ用です。',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: muted),
                ),
              ),
          ],
        ),
      ],
    ),
  );
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.controller});
  final GameController controller;
  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final text = TextEditingController(
    text: widget.controller.snapshot!.name,
  );
  final form = GlobalKey<FormState>();
  String? error;
  bool busy = false;
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.controller.rename(text.text.trim());
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = GameController.message(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      title: const Text('プレイヤー名を変更'),
      content: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: text,
              enabled: !busy,
              validator: validateName,
              maxLength: 20,
              decoration: const InputDecoration(labelText: 'プレイヤー名'),
            ),
            if (error != null) ErrorNotice(error!),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: busy ? null : save,
          child: Text(busy ? '保存中…' : '保存する'),
        ),
      ],
    ),
  );
}

class _DeleteDialog extends StatefulWidget {
  const _DeleteDialog({required this.controller});
  final GameController controller;
  @override
  State<_DeleteDialog> createState() => _DeleteDialogState();
}

class _DeleteDialogState extends State<_DeleteDialog> {
  bool checked = false, busy = false;
  String? error;
  Future<void> remove() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.controller.deleteAccount();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = GameController.message(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      title: const Text('退会しますか？'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('すべてのキャラクターと善行の記録が削除され、元に戻せません。'),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: checked,
              onChanged: busy ? null : (v) => setState(() => checked = v!),
              title: const Text(
                '記録が削除されることを確認しました',
                style: TextStyle(fontSize: 12),
              ),
            ),
            if (error != null) ErrorNotice(error!),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        TextButton(
          onPressed: checked && !busy ? remove : null,
          child: Text(
            busy ? '削除中…' : '退会する',
            style: const TextStyle(color: Color(0xFFB74444)),
          ),
        ),
      ],
    ),
  );
}
