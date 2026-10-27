# 元絵と同じ座標で作る独立パーツ

## 現状の制約

これは簡易アニメーションの途中版。頭と胴体は一体の画像で、耳・脚・尾などは切り抜いた画像を小さく回転・移動させる。肩・肘・腰・膝の変形、足の接地を保つIK、体重移動、角度を変えるための描き分けは実装していない。元絵との一致や接続テストが通っても、自然な歩行や完成した育成ゲーム品質を保証しない。次の品質改善では、単体で動作を設計して見本を確認してから他のキャラクターへ適用する。

メブシカ、フワラム、ヒノレオ、ナミルカ、コハガメ、ミケルナは、完成した500pxの元絵を同じ座標で切り分ける。別々に生成した頭・胴体・脚の寸法を合わせて組み立てる方式は廃止した。頭と胴体の輪郭は共通の本体画像で保ち、耳・脚・尾・ひれなどを独立させる。ルミクラは既存の傘と触手5本の構成を継続する。

`registered_cuts.py` が部品の切り抜き範囲、付け根に残す重なり、関節位置を定義する。`prepare_registered.py` はプログラムによる切り抜き・透過処理のみを行い、絵を描き足さない。各部品は原寸のまま保存し、Riveでも拡大率1で配置する。隠れる付け根にだけ透過のぼかしを設け、動作中の切り口を目立ちにくくする。

元画像は内部にも透明度254などの値を持つ。これを輪郭の半透明画素と同じ扱いにすると、付け根の重なりが削られてしまうため、250以上のほぼ不透明な塗りだけ255に整える。本当の輪郭の半透明は維持する。正規化した完成絵を `masters/` に保存し、部品を静止状態で重ねた画像が、この完成絵と全画素一致することを生成時に検証する。

ミケルナの歩行用だけは、承認済みの四足姿の完成絵から目と口を画像生成で除去した。鼻・ひげ・模様は維持し、その一枚から全パーツを切り出す。通常の座り姿と歩行姿を切り替え、目・口の位置もそれぞれの完成絵に合わせる。目にハイライトは加えない。ナミルカには全状態で口を作らない。

## 編集・検証

1. Pillowとnumpyが使えるPythonで `prepare_registered.py` を実行する。
2. `python3 build_models.py` でRMLを作成する。
3. `rive . --verify`、`rive inspect . --summary` で検証し、各状態を描画して確認する。
4. `rive . --once` で生成したファイルをアプリの `assets/animations/first_evolutions.riv` にコピーする。
5. Flutterのテストとブラウザの実表示を確認する。

`first_evolution_contacts_test.dart` は実ファイルの変換行列とパーツPNGの透明度を使い、全状態で付け根が本体と重なるかを確認する。形や自然さを保証するテストではないため、元絵との一致と動作中の目視確認も行う。

## 使用した画像生成

内蔵の画像生成ツールを使用。入力は承認済みの四足姿、生成原本は `source/cat_standing_blank.png`、アプリ用の全身絵は `masters/cat_standing.png`。生成した部品単位の修正案は採用していない。

最終プロンプト:

> EDIT the supplied transparent standing lavender moon cat. Remove ONLY the two dark oval eyes and the little black W-shaped mouth below the nose, replacing them with uninterrupted matching face paint. Keep the small dark triangular nose and its tiny vertical nose line, blush, whiskers, crescent, outline, ears, tail, four legs, body shape, shading, standing pose, orientation, proportions and exact placement unchanged. Output ONE complete assembled cat, NOT separated parts, NOT an atlas. Maintain transparency, no ground or shadow, no new objects or text. All animation parts will be cut from this single exact assembled artwork, so preserve its anatomy.
