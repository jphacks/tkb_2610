# 第一進化7体のアニメーション

完成した元絵を同じ座標で切り分け、Riveで耳・脚・尾などを動かします。6種は原寸で配置し、元絵の頭身と頭・胴体のつながりを保ちます。ルミクラは既存の傘と触手5本の構成です。表情はハイライトのない目・口の図形で切り替え、ナミルカは全状態で口なしです。現在の編集方法は [REGISTERED_PARTS.md](REGISTERED_PARTS.md) を参照してください。

| 形態 | 種族名 | 歩行・移動 | タッチ時のポーズ |
| --- | --- | --- | --- |
| stage1_kindness | ルミクラ | 呼吸、独立した5本の触手の時間差の揺れ | 笑顔で弾み、触手を揺らす |
| stage1_environment | メブシカ | 4本の脚の交互の踏み出し、葉のしっぽ | 首を傾け、前脚を上げる |
| stage1_gratitude | フワラム | 小さな足運び、耳の揺れ | 笑顔で弾む |
| stage1_courage | ヒノレオ | 4本の脚の踏み出し、炎のしっぽ | 前脚を上げて挨拶する |
| stage1_cooperation | ナミルカ | 尾とひれをずらして泳ぐ | ひれを振る |
| stage1_honesty | コハガメ | ゆっくりした足運び、小さな首振り | 首を傾けて挨拶する |
| stage1_self_care | ミケルナ | 専用の四足で立つ姿と脚4本、耳と尻尾の揺れ | 座り姿で首をかしげ、前足を上げる |

全7体に待機中の呼吸・まばたき、投稿後の喜び、元気の少ない表情、おやすみを用意しています。向きは左右の切り替えと頭・体の傾きで表現します。正面・背面の別アングルの絵は含みません。

## 実行時の接続

`assets/animations/first_evolutions.riv` のartboard名は上表の形態ID。全artboardが `CompanionState` の同じ契約を使います。

| mode | 動き |
| --- | --- |
| 0 | Idle |
| 1 | Walk |
| 2 | Tap |
| 3 | Happy |
| 4 | Low energy |
| 5 | Sleep |

`lookX` は目線の横位置。口は絵に残した鼻からずれないように固定しています。部屋の上下・左右・斜めの移動、名前と吹き出しの追従は `RoomCharacter`、モデルの再生と表情は `CharacterRiveView` が担当します。1つのファイルを共有し、各表示の再生状態は独立させます。図鑑・動きを減らす設定・おやすみでは停止します。

## 再生成

Rive CLI 1.8.0で作成。Rive用の生成処理はPython 3標準ライブラリだけで動きます。

```sh
cd frontend/animation/first_evolutions
python3 build_models.py
rive . --verify
rive inspect . --summary
rive . --once
cp build/first_evolutions.riv ../../assets/animations/first_evolutions.riv
```

`registered_cuts.py` が切り抜き範囲と関節位置、`registered_rig.py` が6種の動作、`character_specs.py` と `face_geometry.py` が顔の位置と表情、`rig_writer.py` がRMLの共通出力処理です。`build_models.py` が全体を組み立てます。画像はすべて `.riv` に埋め込みます。

6種は `textures/` と歩行用ミケルナの完成絵を `prepare_registered.py` で切り分けた `registered/` を使用します。ルミクラは既存の `parts/` を使用します。切り出しにはPillowとnumpyが必要です。目・口の除去は画像生成ツール、切り抜き・透過整理はユーザーが許可したプログラム処理で行います。

`rig_manifest.json` は独立した部品の一覧と初期位置の検証用データです。テストでは実際のRiveファイルを読み、全7体の全6状態で、画像と関節の拡大率が固定されること、まばたき、各関節が別々に動くこと、ミケルナの歩行姿への切り替えを確認します。
