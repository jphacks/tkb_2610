# 一日一善 backend

Node.js 24 / TypeScript / Express / Supabase / Gemini で動作するREST API。
APIの入出力は [API設計書](./API設計書.md) にまとめています。

## セットアップ

このフォルダで実行します。

```sh
npm ci
cp .env.example .env
```

`.env` に設定します。既存の `.env` がある場合はコピーで上書きせず、必要な項目だけ追加してください。

| 変数 | 内容 |
|---|---|
| PORT | APIポート。既定値3000 |
| SUPABASE_URL | プロジェクトURL |
| SUPABASE_SECRET_KEY | サーバー専用のSecret Keyまたはservice_roleキー |
| GEMINI_API_KEY | Google AI Studioで発行したキー |
| GEMINI_MODEL | モデル名。省略時はgemini-3.5-flash-lite |

管理用キーと `.env` はGitへ登録しません。Flutterにも含めません。

Supabase SQL Editorで `sql/` の001〜016を番号順に実行します。
001〜014を適用済みの環境には、次の2本を追加します。

1. `sql/015_complete_game_api.sql`
2. `sql/016_get_current_streak_function.sql`

015・016はこの開発環境では実行成功を確認済みです。SQLは対象プロジェクトを確認してから適用してください。

## 起動

```sh
npm run dev
```

`http://localhost:3000/api/health` で `{"status":"ok"}` が返ります。

通常起動：

```sh
npm run build
npm start
```

`src/` は編集するTypeScript、`dist/` はビルドで作られたJavaScriptです。
`dist/` は直接編集せず、`src/` を修正して再ビルドします。

## 主なファイルと処理の順番

```text
routes → controllers → services → repositories → Supabase RPC / テーブル
                         ↓
                       Gemini
```

| 場所 | 役割 |
|---|---|
| src/app.ts | URL登録、JSON解析、問い合わせID、共通エラー |
| src/server.ts | 環境変数の読み込み、HTTPサーバー起動 |
| src/middleware/require-auth.ts | Bearerトークン照合 |
| src/lib/gemini.ts | 善行の有効性・カテゴリ・褒め言葉を取得 |
| src/services/deeds.service.ts | 受付予約→AI判定→報酬確定 |
| sql/014_... | 未投稿日のHP減算と死亡確定 |
| sql/015_... | 報酬・進化・世代交代・重複防止・退会 |
| sql/016_... | 善行継続日数 |

AI通信中はDBのロックを保持せず、確定時にユーザー行をロックして報酬等をまとめて保存します。

## 動作確認

```sh
npm run test:integration
```

実際のSupabaseを使用する16件の結合テストです。AIはテスト用の固定応答へ差し替えるため、Geminiの課金・判定揺れには依存しません。
実行のたび専用ゲストを作成し、そのユーザーだけの日時・HP等をテスト用に変更します。
終了処理で作成したユーザーと関連データを削除し、残件0を確認します。
プロセスを強制終了すると終了処理が動かない可能性があるため、開発用DBで実行してください。

確認内容：認証、名前変更、履歴、同時投稿、XP上限後の属性0、編集再判定、二段階進化、未投稿死亡、世代交代、重複要求、AI障害時の再試行、処理中の退会、関連データ削除。

実際のAI接続を確認する場合：

```sh
npm run check:ai
```

確認用の善行1件をGeminiへ送ります。DBに善行は登録しません。通常のAPI利用と同様にAI利用枠を消費します。
モデルを一時的に指定する場合：

```sh
GEMINI_MODEL=gemini-2.5-flash npm run check:ai
```

現在のキーではgemini-2.5-flashが404（新規利用者向け提供終了）を返しました。
モデル名が一覧に表示されても、生成APIで利用可能とは限りません。
本番起動前に対象キー・モデルで `check:ai` が成功することを確認してください。
モデルの応答仕様は [Google公式のThinking設定](https://ai.google.dev/gemini-api/docs/generate-content/thinking) を参照しています。

## 現行ルールと残る設定項目

- XPは1件+10、ユーザー単位でJST当日50まで。
- XP0なら属性ポイントも0。HP回復・褒め言葉・記録は継続。
- 無効判定422の投稿は、同じrequestIdで本文を上書きして再判定可能。
- 第1進化100XP、第2進化300XP、50XPごとにレベル+1は暫定。
- 第2進化属性は第1進化した投稿の次からのポイントで判定。
- 数値はSupabaseの `game_config` 1行で管理。過去の報酬の再計算は行わない。
- 画像IDは `base_01`・`stage1_<属性>`・`stage2_<第1属性>_<第2属性>` の仮命名。画像素材は別途用意する。
- ゲストセッションは90日。トークン更新・端末間引き継ぎは未実装。

iOSとの接続確認、本番デプロイ、画像素材の対応付けは別工程です。
