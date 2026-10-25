import 'package:flutter/material.dart';
import '../core/controller.dart';
import '../core/android_pet.dart';
import '../core/theme.dart';
import '../core/evolution_preview.dart';
import '../core/evolution_sound.dart';
import 'evolution_scene.dart';
import '../widgets/character_view.dart';
import '../widgets/common.dart';
import 'registration.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.controller,
    required this.isDemo,
    this.evolutionSoundFactory,
    this.androidPet,
  });
  final GameController controller;
  final bool isDemo;
  final EvolutionSound Function()? evolutionSoundFactory;
  final AndroidPet? androidPet;
  static final _previewPicker = EvolutionPreviewPicker();
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

  Future<void> previewEvolution(BuildContext context, bool second) async {
    final event = _previewPicker.next(second: second);
    await Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        transitionDuration: Duration.zero,
        pageBuilder: (context, _, _) => EvolutionScene(
          event: event,
          sound: evolutionSoundFactory?.call(),
          onClose: () => Navigator.pop(context),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PageBody(
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
      if (androidPet?.supported == true)
        AnimatedBuilder(
          animation: androidPet!,
          builder: (context, _) => androidPet!.available
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: _AndroidPetSettings(pet: androidPet!),
                )
              : const SizedBox.shrink(),
        ),
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
          title: const Text('退会する', style: TextStyle(color: Color(0xFFB74444))),
          subtitle: const Text(
            'アカウントと育成記録を削除します',
            style: TextStyle(fontSize: 11, color: muted),
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => removeAccount(context),
        ),
      ),
      if (isDemo) ...[
        const SizedBox(height: 24),
        Panel(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                title: const Text('第一進化の演出をみる'),
                subtitle: const Text(
                  'ランダム7種・育成記録は変わりません',
                  style: TextStyle(fontSize: 11, color: muted),
                ),
                trailing: const Icon(Icons.play_circle_outline_rounded),
                onTap: () => previewEvolution(context, false),
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('第二進化の演出をみる'),
                subtitle: const Text(
                  'ランダム49種・育成記録は変わりません',
                  style: TextStyle(fontSize: 11, color: muted),
                ),
                trailing: const Icon(Icons.play_circle_outline_rounded),
                onTap: () => previewEvolution(context, true),
              ),
            ],
          ),
        ),
      ],
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
  );
}

class _AndroidPetSettings extends StatelessWidget {
  const _AndroidPetSettings({required this.pet});
  final AndroidPet pet;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: pet,
    builder: (context, _) => Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'よいのことおでかけ',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'ホーム画面や他のアプリの上で、うちのこが歩いておしゃべりします。'
            'タップでひとこと、ドラッグでお引っ越し。×でおうちに戻ります。',
            style: TextStyle(fontSize: 12, height: 1.7),
          ),
          const SizedBox(height: 12),
          if (!pet.allowed) ...[
            const Text(
              '最初に「他のアプリの上に表示」を許可してください。'
              '許可後、この画面に戻るとおでかけできます。',
              style: TextStyle(fontSize: 12, color: muted),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: pet.busy ? null : pet.requestPermission,
              icon: const Icon(Icons.settings_outlined),
              label: const Text('表示を許可する'),
            ),
          ] else ...[
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('おでかけする'),
              subtitle: Text(
                pet.running ? 'ホーム画面に戻ると、よいのこが現れます' : '今はおうちで待っています',
                style: const TextStyle(fontSize: 11),
              ),
              value: pet.running,
              onChanged: pet.busy
                  ? null
                  : (value) => value ? pet.start() : pet.stop(),
            ),
          ],
          const SizedBox(height: 8),
          const Text(
            'おしゃべりは文字で表示します。ロック中とアプリ内ではお休みします。'
            '終了後や端末の再起動後は、ここからまたおでかけできます。',
            style: TextStyle(fontSize: 11, color: muted, height: 1.6),
          ),
          if (pet.error != null) ErrorNotice(pet.error!),
        ],
      ),
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
