# Meta Lead Ads → Railway CRM Webhook 連携 完全手順書

## 目的
Meta Lead広告（Instant Form）から送信されたリード情報を、
Railway 上の CRM バックエンドで **Webhook 受信・検証・保存** する。

---

## 全体構成図（論理）

Meta Lead Form  
→ Meta Webhook（leadgen）  
→ Railway `/api/webhook/meta`  
→ CRM Backend  
→ DB / メール / 後続オートメーション

---

## 事前準備チェックリスト

- Meta（Facebook）個人アカウント
- Facebookページ（広告出稿元）
- Meta for Developers アカウント
- Railway プロジェクト
- 公開 HTTPS ドメイン（Railway）

---

## Step 1. Meta for Developers：アプリ作成

1. https://developers.facebook.com/
2. 「マイアプリ」→「アプリを作成」
3. アプリタイプ：**ビジネス**
4. アプリ名：任意（例：CRM Lead Webhook）
5. 作成後、**App ID / App Secret** を控える

---

## Step 2. Webhooks プロダクト追加

1. アプリダッシュボード →「製品を追加」
2. **Webhooks** を追加
3. Webhooks → **Page** を選択

---

## Step 3. Page Webhook 設定

### サブスクリプション追加

- コールバックURL
  ```
  https://crm-backend-production-b5b4.up.railway.app/api/webhook/meta
  ```

- 検証トークン
  任意の文字列（例：meta_verify_token_2026）

※この値は Railway 環境変数 `META_WEBHOOK_VERIFY_TOKEN` と一致させる

---

## Step 4. Subscribe フィールド設定

Page → Subscriptions で以下を有効化：

- `leadgen`

---

## Step 5. Page Access Token 取得

1. Graph API Explorer
2. 対象ページ選択
3. 権限：
   - pages_show_list
   - pages_read_engagement
   - leads_retrieval
4. **永続トークンを生成**
5. 値を保存

---

## Step 6. Railway 環境変数設定

Railway → Variables に以下を設定：

```
META_WEBHOOK_VERIFY_TOKEN=xxxxx
META_APP_SECRET=xxxxx
META_ACCESS_TOKEN=xxxxx
META_GRAPH_API_VERSION=v19.0
DEFAULT_PROJECT_ID=xxxxx
PORT=3000
```

---

## Step 7. Webhook 実装要件（バックエンド）

### GET /api/webhook/meta

- hub.verify_token 検証
- hub.challenge をそのまま返却

### POST /api/webhook/meta

- X-Hub-Signature-256 検証
- 常に 200 を返す
- object=page / entry 処理

---

## Step 8. Railway デプロイ後確認

### 1. ルート確認

```bash
curl https://crm-backend-production-b5b4.up.railway.app/
```

期待：
```json
{"status":"ok","service":"crm-backend","timestamp":"..."}
```

**検証結果**: ✅ 2026-01-19 確認済み

---

### 2. Webhook Verify テスト

```bash
curl "https://crm-backend-production-b5b4.up.railway.app/api/webhook/meta?hub.mode=subscribe&hub.verify_token=YOUR_TOKEN&hub.challenge=123"
```

期待：
```
123
```

**現状**: ⏳ Railway環境変数 `META_WEBHOOK_VERIFY_TOKEN` 設定後に動作

---

### 3. POST テスト

```bash
curl -X POST https://crm-backend-production-b5b4.up.railway.app/api/webhook/meta \
-H "Content-Type: application/json" \
-d '{"object":"page","entry":[]}'
```

期待：
```
EVENT_RECEIVED
```

---

## 完了条件

- Meta 側 Webhook ステータス：Active
- Railway ログに POST 受信が出る
- リード送信で CRM 側にデータ保存される

---

## 補足（よくある詰まり）

- Meta 個人アカウントの **セキュリティ制限**
  → 数日ログイン継続が必要
- Verify Token 不一致
- HTTPS でない URL
- App が「開発中」のまま

---

## 次の拡張

- leadgen_id → Graph API で詳細取得
- CRM 正規化
- ステップメール自動起動
- ROI シミュレーター連携
