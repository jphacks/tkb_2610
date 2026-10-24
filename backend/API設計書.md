# 一日一善 API設計書

バージョン：3.0 / 更新日：2026-10-24

対象：iOS・Flutter / Node.js・Express・TypeScript / Supabase / Gemini

## 1. 設計の前提

基本設計書3.0を優先し、元のAPI一覧のURLを引き継ぐ。会話で確定した変更は次のとおり。

- AIは設定済みのGeminiを使用する。現行の既定モデルは実接続成功済みの `gemini-3.5-flash-lite`。`GEMINI_MODEL` で変更可能。
- 1日のXP上限到達後は、属性ポイントも付与しない。記録・HP回復・褒め言葉は継続する。
- AIが善行ではないと判定した投稿は、同じ `requestId` のまま本文を上書きして再判定できる。
- 退会を含む以下の13本を実装済み。

## 2. エンドポイント一覧

ベースパスは `/api`。現在のURLにはバージョン番号 `/v1` を付けない。

| メソッド | パス | Bearer認証 | 機能 |
|---|---|---|---|
| POST | `/api/guests` | 不要 | ゲスト・初期キャラクター・セッション作成 |
| GET | `/api/users/me` | 必須 | プロフィール・最長生存日数 |
| PUT | `/api/users/me` | 必須 | 名前変更 |
| DELETE | `/api/users/me` | 必須 | 退会・関連データ削除 |
| GET | `/api/characters/me` | 必須 | 現在のキャラクター・今日の状況・継続日数 |
| POST | `/api/characters` | 必須 | 次世代作成 |
| GET | `/api/characters/me/evolution` | 必須 | 進化状況 |
| GET | `/api/characters/history` | 必須 | 現在・過去のキャラクター一覧 |
| POST | `/api/deeds` | 必須 | AI判定・善行保存・報酬・進化 |
| GET | `/api/deeds` | 必須 | 善行履歴・キャラクター別絞り込み |
| GET | `/api/deeds/today` | 必須 | 今日の投稿・獲得XP |
| GET | `/api/categories` | 不要 | 7カテゴリ |
| GET | `/api/health` | 不要 | プロセス稼働確認 |

## 3. 共通仕様

### 3.1 通信・認証

- 本番はHTTPS。JSON本文には `Content-Type: application/json` を付ける。
- 保護対象APIには `Authorization: Bearer <sessionToken>` を付ける。
- トークンは32バイトの暗号学的乱数をbase64urlにした値。DBにはSHA-256ハッシュだけを保存する。
- 現行の有効期限は発行後90日。更新・再発行・引き継ぎAPIは未提供。
- Flutterは `flutter_secure_storage` に保存する。Supabaseの管理用キーやGeminiキーをFlutterへ渡さない。
- `userId` はセッションから決定する。本文で他人のIDやHP・XPを指定できない。
- JSONキーはcamelCase。IDはUUID文字列。日時はISO 8601。`Z`・`+00:00` 等の表記、小数秒の桁数の違いを許容する。
- ゲーム内の日付はすべて `Asia/Tokyo`、日付文字列は `YYYY-MM-DD`。
- 未設定値は `null`、空の一覧は `[]`。204には本文がない。
- JSON本文の上限は16KB。以下の文字数制限はJavaScriptのUTF-16コード単位。
- ゲスト登録・名前変更・善行投稿の本文、履歴のクエリは定義済み項目のみ受け付ける。

### 3.2 エラー形式

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "入力内容を確認してください。",
    "requestId": "00000000-0000-4000-8000-000000000099"
  }
}
```

エラー内の `requestId` は問い合わせ用のサーバー生成ID。善行投稿本文の `requestId` とは別物。保存済み結果を再送した場合は、保存された問い合わせ用IDを返す場合がある。

| HTTP | code | 意味・クライアントの対応 |
|---|---|---|
| 400 | `VALIDATION_ERROR` | 型・値・余分な項目・JSON構文を修正 |
| 401 | `UNAUTHENTICATED` | トークンなし・不正・期限切れ・失効 |
| 404 | `USER_NOT_FOUND` | 認証後の退会等でユーザーが見つからない |
| 404 | `CHARACTER_NOT_FOUND` | 対象なし、または他人のキャラクター |
| 404 | `NOT_FOUND` | URLが未定義 |
| 409 | `IDEMPOTENCY_CONFLICT` | 使用中・確定済みの投稿IDに異なる本文を指定 |
| 409 | `REQUEST_IN_PROGRESS` | 処理中。同じ投稿ID・同じ内容で時間を空けて再試行 |
| 409 | `REQUEST_NOT_FOUND` | 投稿受付状態を確認できない |
| 409 | `CHARACTER_NOT_ACTIVE` | 投稿先が死亡・育成終了・世代交代済み |
| 409 | `GENERATION_NOT_AVAILABLE` | 次世代を作れる日付より前 |
| 409 | `ACTIVE_CHARACTER_EXISTS` | 育成中のキャラクターが存在 |
| 413 | `PAYLOAD_TOO_LARGE` | JSON本文が16KBを超過 |
| 422 | `DEED_NOT_VALID` | 未登録。本文を編集し同じ投稿IDで再判定可能 |
| 503 | `AI_UNAVAILABLE` | AI障害・30秒タイムアウト・不正な応答。同じ投稿IDで再試行 |
| 500 | `INTERNAL_ERROR` | DB障害等。本文を変えず同じ投稿IDで再試行 |

### 3.3 一覧のページ分割

| クエリ | 既定値 | 制約 |
|---|---:|---|
| `limit` | 20 | 整数1〜50 |
| `offset` | 0 | 整数0〜2147483647 |

数字の文字列として指定する。負数、小数、同じキーの複数指定は拒否する。

```json
{"items": [], "totalCount": 0, "limit": 20, "offset": 0, "hasMore": false}
```

続きは `offset + items.length`。更新中の一覧では先頭を再取得し、アプリ側でIDの重複を除く。

## 4. 共通のレスポンス要素

### 4.1 Character

ゲスト登録以外のキャラクター取得・履歴・次世代作成・善行保存で使用する。

```json
{
  "id": "00000000-0000-4000-8000-000000000002",
  "generation": 1,
  "imageId": "base_01",
  "hp": 100,
  "maxHp": 100,
  "totalXp": 0,
  "level": 1,
  "evolutionStage": 0,
  "firstEvolutionCategory": null,
  "secondEvolutionCategory": null,
  "secondEvolutionDate": null,
  "categoryPoints": {
    "kindness": 0, "environment": 0, "gratitude": 0, "courage": 0,
    "cooperation": 0, "honesty": 0, "selfCare": 0
  },
  "status": "alive",
  "createdAt": "2026-10-24T03:00:00+00:00",
  "diedAt": null,
  "endedAt": null,
  "endReason": null,
  "lifespanDays": 1,
  "deedCount": 0
}
```

| 項目 | 意味 |
|---|---|
| `generation` | 1から始まる世代番号 |
| `evolutionStage` | 0：初期、1：第1進化、2：最終進化 |
| `categoryPoints` | そのキャラクターの生涯累計。キーのみ `selfCare` とする |
| `firstEvolutionCategory` / `secondEvolutionCategory` | カテゴリIDまたはnull。セルフケアは `self_care` |
| `status` | `alive` / `dead` / `retired` |
| `diedAt` | 実際にHPが0になった日の末尾。死亡以外はnull |
| `endedAt` | 死亡日時、または最終進化翌日のJST 0:00。育成中はnull |
| `endReason` | null / `death` / `second_evolution` |
| `lifespanDays` | 作成日を1日目として実際の最終育成日まで数える |
| `deedCount` | このキャラクターに保存した有効な善行の総数。XP0を含む |

### 4.2 Today

```json
{
  "date": "2026-10-24",
  "deedCount": 2,
  "earnedXp": 20,
  "xpLimit": 50,
  "remainingXp": 30,
  "goalAchieved": true
}
```

ユーザー単位のJST当日分。`goalAchieved` は有効な善行が1件以上あるか。

### 4.3 Deed

```json
{
  "id": "00000000-0000-4000-8000-000000000003",
  "characterId": "00000000-0000-4000-8000-000000000002",
  "content": "公園のごみを拾った。",
  "category": "environment",
  "praise": "公園をきれいにして、みんなが気持ちよく過ごせますね。",
  "earnedXp": 10,
  "earnedCategoryPoints": 1,
  "recoveredHp": 20,
  "createdAt": "2026-10-24T03:10:00+00:00"
}
```

`recoveredHp` は実際の回復量。HP100なら0、HP95なら5。AIの褒め言葉は例であり固定ではない。

## 5. 各API

### 5.1 ゲスト登録

`POST /api/guests` → **201**

```json
{"displayName": "たろう"}
```

名前は前後の空白除去後1〜20文字、制御文字不可。ユーザー・第1世代・セッションを同じDBトランザクションで作成する。

```json
{
  "user": {
    "id": "00000000-0000-4000-8000-000000000001",
    "displayName": "たろう",
    "createdAt": "2026-10-24T03:00:00+00:00"
  },
  "currentCharacter": {
    "id": "00000000-0000-4000-8000-000000000002",
    "generation": 1, "imageId": "base_01", "hp": 100, "maxHp": 100,
    "totalXp": 0, "level": 1, "evolutionStage": 0,
    "status": "alive", "createdAt": "2026-10-24T03:00:00+00:00"
  },
  "sessionToken": "<発行されたトークン>"
}
```

登録時の `currentCharacter` はこの簡易形式。詳しい値は登録後の `GET /api/characters/me` で取得する。

呼び出すたび新規ユーザーを作る。登録APIは同じ本文でも再送を保証しない。`Idempotency-Key` は不要。受け取ったトークンは直ちに保存する。

### 5.2 プロフィール取得

`GET /api/users/me` → **200**

```json
{
  "user": {
    "id": "00000000-0000-4000-8000-000000000001",
    "displayName": "たろう",
    "createdAt": "2026-10-24T03:00:00+00:00",
    "isGuest": true,
    "longestSurvivalDays": 1
  }
}
```

未投稿ペナルティ等を確定してから、現在・過去の全世代の最長生存日数を計算する。

### 5.3 名前変更

`PUT /api/users/me` → **200**

本文は登録と同じ名前の入力制約。

```json
{"displayName": "新しい名前"}
```

応答：

```json
{"user": {"id": "00000000-0000-4000-8000-000000000001", "displayName": "新しい名前"}}
```

保存済みの褒め言葉を書き換えることはない。以後のAI判定には変更後の名前を使用する。

### 5.4 退会

`DELETE /api/users/me` → **204**、本文なし。

ユーザー・全キャラクター・善行・投稿受付状態・ゲスト登録要求・セッションを削除する。以後、同じトークンは401。Flutterは退会前に利用者へ削除確認を表示し、成功後に端末のトークンを削除する。

### 5.5 ホーム情報

`GET /api/characters/me` → **200**

応答は次の構造。`Character` と `Today` の全項目は4章参照。

```text
{
  currentCharacter: Character,
  today: Today,
  currentStreakDays: number,
  canCreateNextCharacter: boolean,
  nextCharacterAvailableOn: "YYYY-MM-DD" | null
}
```

- 未投稿ペナルティ・死亡・最終進化翌日の育成終了を確定して返す。
- 現在のキャラクターは最新世代。死亡・育成終了後も、次世代作成までは同じ個体を返す。
- `currentStreakDays` はユーザー単位の連続投稿日数。今日投稿済みなら今日から、今日未投稿なら昨日から遡る。空白日で途切れ、同日複数件は1日、XP0の有効投稿も数える。世代交代でリセットしない。
- `nextCharacterAvailableOn` は死亡日または最終進化達成日の翌日。終了条件未達成ならnull。

### 5.6 次世代作成

`POST /api/characters` → **201**

本文なし、または空の `{}`。応答は `{ "currentCharacter": Character }`。

死亡日の翌日以降、または第2進化日の翌日以降に作成可能。HP100・XP0・レベル1・属性0・進化段階0・`base_01`、世代番号+1。ユーザーID・名前と過去の履歴を維持する。

育成中なら `ACTIVE_CHARACTER_EXISTS`、死亡当日等は `GENERATION_NOT_AVAILABLE`。同時に2件届いても作成は1体のみ。成功応答を失った場合はホーム情報を取得して作成済みか確認する。

### 5.7 進化状況

`GET /api/characters/me/evolution` → **200**

```json
{
  "characterId": "00000000-0000-4000-8000-000000000002",
  "evolutionStage": 1,
  "firstEvolutionCategory": "kindness",
  "secondEvolutionCategory": null,
  "imageId": "stage1_kindness",
  "totalXp": 110,
  "nextEvolutionXp": 300,
  "remainingXp": 190,
  "categoryPoints": {
    "kindness": 1, "environment": 0, "gratitude": 0, "courage": 0,
    "cooperation": 0, "honesty": 0, "selfCare": 0
  }
}
```

第1進化後の `categoryPoints` は、第2進化判定に使う「第1進化後に獲得したポイント」。ホームや履歴の生涯累計とは集計範囲が異なる。段階0・2では生涯累計を返す。段階2の `nextEvolutionXp`・`remainingXp` はnull。

### 5.8 キャラクター履歴

`GET /api/characters/history?limit=20&offset=0` → **200**

3.3の一覧形式で、`items` は `Character[]`。現在の育成中キャラクターも含め、世代番号の降順。返却前に最新世代の未処理日付を確定する。個別画面はこの情報とキャラクター別善行履歴を組み合わせる。

### 5.9 善行投稿

`POST /api/deeds` → **201**（有効な場合）

```json
{
  "requestId": "00000000-0000-4000-8000-000000000010",
  "content": "公園のごみを拾った。"
}
```

- `requestId` はFlutterが投稿ごとに生成するUUID。
- `content` は前後の空白除去後1〜500文字。改行・タブは許可、その他の制御文字は拒否する。
- AIは有効性・7カテゴリのいずれか1つ・日本語の褒め言葉を返す。HP・XPはサーバー側の固定ルールで計算する。
- 登録先キャラクターを受付時に固定する。AI判定中に世代交代しても新世代に付け替えない。
- 善行・HP・XP・属性ポイント・進化・確定応答を同じDBトランザクションで保存する。

成功応答の構造：

```text
{
  deed: Deed,
  xpLimitReached: boolean,
  evolution: { changed: boolean, previousStage: 0 | 1 | 2, currentStage: 0 | 1 | 2 },
  currentCharacter: Character
}
```

#### 再送・再判定

| 受付状態 | 同じID・同じ内容 | 同じID・異なる内容 |
|---|---|---|
| 成功済み201 | 保存済み201と同じ本文。AI・報酬は再実行しない | 409 `IDEMPOTENCY_CONFLICT` |
| 判定中 | 409 `REQUEST_IN_PROGRESS` | 409 `IDEMPOTENCY_CONFLICT` |
| 無効判定422 | AIで再判定 | 旧内容を上書きしてAIで再判定 |
| AI障害503 | AIで再試行 | 409 `IDEMPOTENCY_CONFLICT` |
| 世代競合で確定した409 | 保存済み409 | 409 `IDEMPOTENCY_CONFLICT` |

無効な文章は善行履歴へ保存せず、報酬も付与しない。再判定用の投稿受付テーブルには直近の内容を保持する。

Flutter側の流れ：

1. UUIDを生成して投稿する。
2. 422なら入力欄に戻し、同じUUIDで修正文を送る。
3. 通信切断・503・処理中409は、同じUUIDと同じ本文で再送する。
4. 201を受け取ったら確定済みとして扱い、新しい投稿には新しいUUIDを使う。
5. `CHARACTER_NOT_ACTIVE` ならホーム情報を再取得し、世代交代へ進む。

処理予約は90秒。AI呼び出しは30秒でタイムアウトし、失敗時に予約を再試行可能にする。プロセス停止で予約が残った場合も期限後に再試行でき、古い処理が後から報酬を重複付与することはない。

### 5.10 善行履歴

`GET /api/deeds?limit=20&offset=0&characterId=<UUID>` → **200**

3.3の一覧形式で `items` は `Deed[]`。`characterId` は省略可能。省略時は自分の全世代の善行を返す。指定時はその個体のみ。作成日時の降順、同時刻ならID降順。他人・存在しないキャラクターは404。422の無効投稿は含まない。

### 5.11 今日の状況

`GET /api/deeds/today` → **200**、本文は4.2の `Today` そのもの。

XP上限は世代単位ではなくユーザー単位。日付境界はJST 0:00。世代交代しても当日の獲得XPを合算する。

### 5.12 カテゴリ

`GET /api/categories` → **200**

```json
{
  "categories": [
    {"id": "kindness", "name": "思いやり"},
    {"id": "environment", "name": "環境保護"},
    {"id": "gratitude", "name": "感謝"},
    {"id": "courage", "name": "勇気"},
    {"id": "cooperation", "name": "協力"},
    {"id": "honesty", "name": "誠実"},
    {"id": "self_care", "name": "セルフケア"}
  ]
}
```

### 5.13 稼働確認

`GET /api/health` → **200**

```json
{"status": "ok"}
```

APIプロセスの応答確認。DB・Geminiへの接続成功までは意味しない。

## 6. ゲームルールと暫定設定

| 項目 | 現行値 | 保存先・備考 |
|---|---:|---|
| 初期HP・最大HP | 100 | charactersの初期値 |
| 初期XP・レベル・進化段階 | 0・1・0 | charactersの初期値 |
| 善行1件のXP | 10 | game_config.xp_per_deed |
| 1日の獲得XP上限 | 50 | game_config.daily_xp_limit |
| HP回復量 | 最大20 | game_config.hp_recovery |
| 未投稿日HP減少 | 20 | game_config.hp_loss_per_day |
| 属性ポイント | XP獲得時+1、XP0なら0 | 投稿先カテゴリに付与 |
| 第1進化 | 累計100XP | game_config.first_evolution_xp、暫定 |
| 第2進化 | 累計300XP | game_config.second_evolution_xp、暫定 |
| レベル | 1 + floor(累計XP / 50) | game_config.level_xp_step、暫定 |

- 当日の残りXPが10未満なら残量だけ付与。1以上獲得すれば属性ポイント+1。
- 第1進化の属性は生涯累計、第2進化の属性は第1進化した投稿の次からのポイントで決める（暫定）。
- 属性同点時は該当カテゴリの最後の善行日時が新しい方。同時刻ならカテゴリ一覧の順で決定する。
- 画像IDは `base_01`、`stage1_<属性ID>`、`stage2_<第1属性ID>_<第2属性ID>`。57形態の仮命名であり画像ファイルは別途用意する。
- 第2進化当日はaliveで投稿・報酬・HP回復を継続。翌日からretiredとなり、前キャラクターへの新規投稿は不可。
- 作成当日・進行中の当日はペナルティ対象外。終了済みの未投稿日だけ1日ずつ減算し、二重適用しない。
- HP0の実際の対象日の23:59:59.999 JSTを死亡日時として記録する。第2進化日より後のペナルティは適用しない。
- 状態確定はプロフィール取得・ホーム・進化状況・キャラクター履歴・次世代作成・新規善行受付/確定時に行う。常駐バッチは不要。
- game_configは管理者用設定。変更は以後の計算に使われ、過去の善行報酬を再計算しない。リリース前に進化条件・レベル式を確定する。

## 7. DBと整合性

SQLは `sql/001_...` から `016_...` の順で適用する。既存環境で001〜014適用済みなら015・016のみ追加する。

| テーブル | 役割 |
|---|---|
| users | プレイヤー |
| characters | 各世代の状態・累計ポイント・第1進化後ポイント |
| guest_sessions | トークンハッシュ・有効期限・失効日時 |
| guest_registration_requests | 登録トランザクション用の内部管理 |
| deeds | 有効な善行と確定報酬 |
| deed_requests | AI処理予約・再送結果・無効投稿の編集再判定 |
| game_config | サーバー共通のゲーム設定1行 |

同一ユーザーのゲーム更新は最初にユーザー行をロックして直列化する。AI通信中はDBトランザクションを維持しない。ユーザー単位のXP上限、キャラクター同時育成1体、投稿IDの一意制約を併用する。退会と判定確定も同じロック順とし、削除したユーザー・善行を復活させない。

RLSを有効にし、ゲーム更新RPCはservice_roleのみ実行できる。FlutterからDBを直接更新しない。

## 8. 確認方法と現在の範囲

- `npm run build`：TypeScriptをdistへ変換。
- `npm run test:integration`：実Supabaseと確認用ユーザーによる16件の結合テスト。AIは固定応答へ差し替え、同時投稿・進化・死亡・世代交代・再判定・退会・予約競合を確認する。終了時に今回作成した確認用ユーザーと関連データを削除する。
- `npm run check:ai`：実際のGeminiへ確認用の善行を1件送信。DBへの善行登録はしない。

Supabaseの001〜016は適用済み。APIの結合テスト16件は成功し、確認用データの削除を確認済み。Geminiの実判定も `gemini-3.5-flash-lite` で成功済み。`gemini-2.5-flash` は対象キーで404を返すため使用できていない。iOSアプリとの接続・実機確認・本番公開は別工程。

起動・環境変数は同じフォルダのREADMEを参照する。
