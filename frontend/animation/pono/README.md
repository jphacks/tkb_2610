# ポノのRiveモデル

承認済みの「B・すっきりした塗り」に合わせたベクターモデルです。背景は透明。体、顔、目、口、ほっぺ、右上の玉を分け、玉の動きには体からの遅れを付けています。ほかの56形態の画像は変更しません。

## アプリとの接続

Artboard: `Pono` / State machine: `Pono motion` / View model: `PonoState`

| `mode` | 動作 |
| --- | --- |
| 0 | 呼吸、まばたき、見回し（8秒） |
| 1 | 歩行中のぷにっとした伸縮と揺れ（1.2秒） |
| 2 | タップで笑顔と小さなジャンプ（2秒） |
| 3 | 投稿後の笑顔と2回のジャンプ（2秒） |
| 4 | 元気が少ない時の半目とゆっくりした呼吸（6秒） |
| 5 | おやすみの閉じた目（アプリでは静止） |

`lookX` は顔の横向きのオフセット。歩行時にアプリが ±3 を渡します。部屋での上下・左右・斜め移動と、名前・吹き出しの追従は引き続き `RoomCharacter` が担当し、モデルのポーズと重ねがけしません。

## 編集・出力

Rive CLI 1.8.0で作成。Python 3標準ライブラリのみで元デザインとタイムラインを再生成できます。

```sh
cd frontend/animation/pono
python3 build_model.py
rive . --verify
rive inspect . --summary
rive . --once
cp build/pono.riv ../../assets/animations/pono.riv
```

`build_model.py` が編集元、`scene.rml` がRiveに読み込むソース、`assets/animations/pono.riv` がアプリに同梱するファイルです。スクリプトや外部画像は含めず、Riveアカウントへのログイン・署名・実行時の画像生成は不要です。ネイティブテストの初回は `dart run rive_native:setup --platform macos`（OSに合わせて変更）で公式ライブラリを準備します。

描画は既存の進化演出の色フィルターと共存するFlutterレンダラーを使用します。ファイルの読み込み中・失敗時は元のポノ画像を表示。図鑑や動きを減らす設定では再生を止め、各画面の再生状態は独立させます。
