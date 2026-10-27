# 第一進化7体のアニメーション

承認済みの「第一進化・シンプル塗り案」から独立した透過パーツを画像生成し、Riveで各パーツの関節を動かします。脚を一枚絵のメッシュで変形させる方式は廃止しました。表情はハイライトのない目・口の図形で切り替え、頭に追従させます。ナミルカは全状態で口なしです。素材の構成は [PARTS.md](PARTS.md) を参照してください。

| 形態 | 種族名 | 歩行・移動 | タッチ時のポーズ |
| --- | --- | --- | --- |
| stage1_kindness | ルミクラ | 呼吸、独立した5本の触手の時間差の揺れ | 笑顔で弾み、触手を揺らす |
| stage1_environment | メブシカ | 4本の脚の交互の踏み出し、葉のしっぽ | 首を傾け、前脚を上げる |
| stage1_gratitude | フワラム | 小さな足運び、耳と角の揺れ | 首を傾けて笑う |
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

`build_models.py` が動作の編集元、`part_layouts.py` が部品の接合位置、`character_specs.py` と `face_geometry.py` が顔の位置と表情、`rig_writer.py` がRMLの共通出力処理です。`scene.rml` は生成物として除外しています。画像はすべて `.riv` に埋め込み、追加の画像サーバーや実行時の画像生成は不要です。

`source/blank_faces_*.png` は旧方式で使用した参照素材です。現在は `source/parts_*.png` を `prepare_parts.py` で切り出した `parts/` を使います。切り出しにはPillowとnumpyが必要で、ユーザーが許可した切り抜き・透過整理のみ行います。描き足しや顔の消去は画像生成ツールで行いました。

`rig_manifest.json` は独立した部品の一覧と初期位置の検証用データです。テストでは実際のRiveファイルを読み、全7体の全6状態で、画像と関節の拡大率が固定されること、まばたき、各関節が別々に動くこと、ミケルナの歩行姿への切り替えを確認します。
