# 素材

- `characters/initial.png`：よいのこの初期形態の暫定透過画像。ユーザーのキャラクター資料・合意した画面案を参考にImage Genで生成。
- `characters/turtle.png`：おやすみ画面の確認用の暫定進化形態。Image Genで生成。最終Riveモデルへの置き換え対象。
- `characters/dome.png`：2Dアニメ塗りのガラスケースと木の台座。Image Genで生成。名札の文字はアプリ側で表示。
- `fonts/MPLUSRounded1c-*.ttf`：Google FontsのM PLUS Rounded 1c、Regular/Bold。SIL OFL 1.1。著作権表示と本文は `fonts/LICENSE.txt`。配布元: https://github.com/google/fonts/tree/main/ofl/mplusrounded1c
- `icons/uchinoko.png`：ユーザーの最初の手描き案を参照し、Image Gen（組み込みツール）で生成した専用の輪郭アイコン。透過線画をアプリ側でグレー／オレンジに着色。生成条件は `icons/prompt.txt`。
- 他の操作アイコン：Flutter同梱のMaterial Icons。

リヴリーアイランドやことだま日記等の素材を転載していません。アプリアイコンはユーザー提供の `app_icon/yoinoko.png` を各プラットフォーム向けに縮小して使用しています。再生成は Pillow を導入した Python で `tool/update_app_icons.py` を実行してください。起動画面はFlutter標準です。

## 進化素材（2026-10-24）

`characters/evolution/` に初期1種・第一進化7種・第二進化49種の透過PNGを配置。ユーザー提供の8枚の一覧画像を、許可を得てプログラムで切り抜き・透過した素材です。文字と隣接キャラクターの断片を除外し、512×512の共通キャンバスに統一しました。切り抜き元・座標は `characters/evolution/manifest.json`、再現用の処理は `tool/extract_character_assets.py`。元画像は変更しません。

草系の月の鹿（`stage2_environment_self_care`）だけ、顔の崩れを修正するため組み込みImage Genで生成し直しています。原デザインの角・ポーズ・模様・配色を維持し、短い丸い鼻先とやさしい目・小さな笑顔へ修正。編集元の透過画像は `characters/overrides/` に保存し、生成条件は同フォルダの `prompt.txt`。アプリは正規化したevolution内の素材を使います。

対応は光＝思いやり（クラゲ）、草＝環境保全（シカ）、風＝感謝（ヒツジ）、炎＝勇気（ライオン）、水＝協力（クジラ）、鉱石＝誠実（カメ）、月＝セルフケア（ネコ）。第二進化では第一属性が種族、第二属性が最終的な見た目の属性です。

透過の再確認後、ユーザー選択により風シカ（ソヨノカ）と風ライオン（ソヨレオ）のみ新しい切り抜きを採用。羽・前脚の先まで切り抜き範囲を広げ、輪郭の小さな隙間から体まで透明になることを防いでいます。他55体は前版のPNGをバイト単位で維持。比較画像は `docs/transparency/wind-before-after.png`。再現用スクリプトの `REVIEWED_BOUNDS` はこの2体だけに適用します。

## 進化の効果音

`audio/evolution_charge.wav`（1.8秒）と `audio/evolution_reveal.wav`（2.3秒）は、`tool/create_evolution_sounds.py` で合成したオリジナルのチャイムです。外部の録音・ゲーム音源は使用していません。アプリ内の再生音量は45%、ON/OFFは端末へ保存します。
