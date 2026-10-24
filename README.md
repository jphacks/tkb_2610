# 一日一善

Flutter製のiOS・Androidアプリと、Node.js / TypeScript製のREST APIをまとめたリポジトリです。

## 必要なツール

- Flutter SDK（Dartを含む）
- Android StudioとAndroid SDK（Android開発用）
- XcodeとCocoaPods（iOS開発用、Macのみ）
- Node.js 24 LTS、npm、Git

Android SDKライセンスの確認が必要な場合は、ターミナルで `flutter doctor --android-licenses` を実行し、表示内容を確認して承認します。

## ディレクトリ

```text
frontend/   Flutterアプリ
backend/    Express / TypeScript API
supabase/   ローカルDB設定と共有migration
```

## バックエンドを起動

```bash
cd backend
cp .env.example .env
npm run dev
```

起動したら `http://localhost:3000/api/health` を開き、`{"status":"ok"}` が返ることを確認します。現時点ではヘルスチェックのみのAPIひな形です。

SupabaseのURL・サーバー用キーとOpenAI APIキーは `backend/.env` に設定してください。`.env` はGitに登録しないでください。これらの値をFlutterアプリに含めてはいけません。

## Flutterアプリを起動

```bash
cd frontend
flutter run
```

FlutterのAPI接続先は、実行する端末ごとに異なります。AndroidエミュレーターからMac上のAPIへ接続する場合は通常 `http://10.0.2.2:3000`、iOSシミュレーターは `http://localhost:3000` を使います。実機ではMacのLAN内IPアドレスを指定してください。リリース環境ではHTTPSを使います。

## ローカルSupabaseを起動

Docker Desktopを起動してから、リポジトリのルートで実行します。

```bash
./backend/node_modules/.bin/supabase start -x studio,logflare,edge-runtime,vector,analytics,mailpit,gotrue,realtime,storage-api,imgproxy
```

この構成ではローカルPostgreSQLとREST APIを使い、未使用の管理画面などを起動しません。初回はDockerイメージのダウンロードに時間がかかります。接続先やローカル用キーを確認するには次を実行します。

```bash
./backend/node_modules/.bin/supabase status
```

2人で開発する場合、ローカルDBのデータは各自のMacに保存されます。テーブル定義は `supabase/migrations/` に追加してGitで共有します。

## 共同開発

- `frontend/pubspec.lock` と `backend/package-lock.json` をコミットし、依存関係を揃えます。
- `.env`、APIキー、Supabaseの秘密鍵をコミットしません。
- 機能ごとにブランチを作り、Pull Requestで `main` に統合します。
- DBスキーマ変更は、実装開始後にSupabase migrationとして管理します。

## 仕様上の確認事項

基本設計はゲスト認証をBearerトークン方式としていますが、API資料の一部にCookie認証の記載があります。APIを実装する前に、Bearerトークン方式へ統一してください。
