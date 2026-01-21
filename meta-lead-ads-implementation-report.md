# Meta Lead Ads 実装完了レポート

**作成日**: 2026-01-19
**ステータス**: ✅ 実装完了
**対象仕様書**: `/meta遷移.md`

---

## 概要

Meta Lead Ads（Instant Form）で取得したリードを、n8n等を介さずCRMバックエンドがWebhookで直接受信し、Graph APIで詳細取得してDBへ保存する機能を実装完了。

---

## 実装完了項目

### 1. APIエンドポイント ✅

| エンドポイント | ファイル | ステータス |
|---------------|---------|-----------|
| `GET /api/webhook/meta` | `src/routes/metaWebhook.ts` | ✅ 完了 |
| `POST /api/webhook/meta` | `src/routes/metaWebhook.ts` | ✅ 完了 |

**GET /api/webhook/meta**
- Meta検証用エンドポイント
- `hub.verify_token` が `META_WEBHOOK_VERIFY_TOKEN` と一致 → `hub.challenge` を200で返却
- 不一致 → 403

**POST /api/webhook/meta**
- raw body を使って `X-Hub-Signature-256` を HMAC SHA256 で検証
- `payload.entry[].changes[]` から `field=="leadgen"` を抽出
- `leadgen_id` を取り出し、冪等性チェック
- `webhook_inbox` に保存（pending）
- Graph API で leadgen_id の詳細を取得
- `field_data` から email/full_name/phone を抽出
- `leads` を email で upsert（email は lower/trim）
- `lead_attribution` を meta_lead_id unique で insert
- `webhook_inbox` を processed に更新
- **常に 200 を返す**（Meta再送を避けるため）

---

### 2. 署名検証 ✅

**ファイル**: `src/middleware/metaSignatureVerify.ts`

```typescript
// 実装内容
- expected = "sha256=" + HMAC_SHA256(META_APP_SECRET, raw_body)
- crypto.timingSafeEqual() によるタイミング攻撃対策
- raw body 保持ミドルウェア（express.json の verify オプション使用）
- DISABLE_META_SIGNATURE_VERIFY=true で開発時バイパス可能
```

---

### 3. Graph API クライアント ✅

**ファイル**: `src/services/metaGraphApiClient.ts`

```typescript
// 実装機能
- GET https://graph.facebook.com/{version}/{leadgen_id}?fields=created_time,form_id,field_data
- 429/5xx 時の簡易リトライ（1回 + 指数バックオフ）
- 失敗時は inbox.failed にして終了（HTTP は 200 返却）
- extractLeadFormData() で email/fullName/phone を抽出
```

---

### 4. データベーススキーマ ✅

**ファイル**: `supabase/migrations/20260117_add_meta_lead_tables.sql`

| テーブル | 説明 | ステータス |
|---------|------|-----------|
| `leads` | リード情報（既存テーブルを活用） | ✅ |
| `lead_attribution` | アトリビューション情報 | ✅ 新規作成 |
| `webhook_inbox` | Webhook受信ログ（冪等性管理） | ✅ 新規作成 |

**lead_attribution スキーマ**
```sql
- id: uuid (PK)
- lead_id: uuid (FK → leads)
- meta_lead_id: text (UNIQUE)
- meta_form_id: text
- meta_campaign_id: text (nullable)
- meta_adset_id: text (nullable)
- meta_ad_id: text (nullable)
- utm_campaign: text (default "P1_static")
- utm_content: text
- received_at: timestamptz
```

**webhook_inbox スキーマ**
```sql
- id: uuid (PK)
- provider: text ("meta")
- event_type: text ("leadgen")
- external_id: text (leadgen_id, UNIQUE per provider)
- payload: jsonb
- status: text (pending/processed/failed)
- retry_count: int (default 0)
- created_at, updated_at: timestamptz
```

---

### 5. 再処理スクリプト ✅

**ファイル**: `scripts/retry_meta_inbox.ts`

```bash
# 使用例
npx ts-node scripts/retry_meta_inbox.ts              # 全 failed/pending を再処理
npx ts-node scripts/retry_meta_inbox.ts --id <uuid>  # 単体再処理
npx ts-node scripts/retry_meta_inbox.ts --status failed  # failed のみ
npx ts-node scripts/retry_meta_inbox.ts --dry-run    # ドライラン
npx ts-node scripts/retry_meta_inbox.ts --limit 10   # 最大10件
```

---

### 6. ログ出力 ✅

**ファイル**: `src/services/loggerService.ts` （構造化ロガー使用）

出力内容:
- Webhook受信ログ
- 署名検証 OK/NG
- leadgen_id 処理状況
- DB upsert/insert 成否
- Graph API 失敗理由
- **PII（email/phone）はマスク処理**

---

### 7. 擬似UTM ✅

**ファイル**: `src/services/metaLeadService.ts`

```typescript
// 実装ロジック
utm_campaign: "P1_static"  // 固定値
utm_content: ad_name || meta_lead_id  // ad_name が取れない場合は meta_lead_id
```

---

### 8. 環境変数 ✅

**ファイル**: `.env.example`

```env
# Meta for Developers > アプリ設定 > ベーシック から取得
META_APP_SECRET=your_meta_app_secret

# Webhook設定時に入力する任意の検証トークン
META_WEBHOOK_VERIFY_TOKEN=your_meta_webhook_verify_token

# ページアクセストークン（長期トークン推奨）
META_ACCESS_TOKEN=your_meta_page_access_token

# Graph API バージョン
META_GRAPH_API_VERSION=v19.0

# デフォルトプロジェクトID
DEFAULT_PROJECT_ID=your_default_project_uuid

# 開発環境で署名検証をスキップ（本番では設定しないこと）
# DISABLE_META_SIGNATURE_VERIFY=true
```

---

### 9. ドキュメント ✅

**ファイル**: `README.md`（Meta Lead Ads セクション追加）

含まれる内容:
- 環境変数の説明
- Meta側設定手順（Callback URL / Verify Token / leadgen subscribe）
- curl による動作確認例（GET/POST）
- 署名生成の Node.js スクリプト例
- 再処理スクリプトの使用方法

---

## ファイル構成

```
crm-backend/
├── src/
│   ├── routes/
│   │   └── metaWebhook.ts          # Webhook エンドポイント
│   ├── middleware/
│   │   └── metaSignatureVerify.ts  # 署名検証ミドルウェア
│   ├── services/
│   │   ├── metaGraphApiClient.ts   # Graph API クライアント
│   │   ├── metaLeadService.ts      # リード処理ロジック
│   │   └── loggerService.ts        # 構造化ロガー
│   └── index.ts                    # Express アプリ（ルート登録）
├── scripts/
│   └── retry_meta_inbox.ts         # 再処理CLI
├── supabase/
│   └── migrations/
│       └── 20260117_add_meta_lead_tables.sql
├── .env.example
└── README.md
```

---

## 動作確認コマンド

### GET 検証テスト
```bash
curl "http://localhost:3001/api/webhook/meta?hub.mode=subscribe&hub.verify_token=YOUR_TOKEN&hub.challenge=test123"
# 成功時: test123
```

### POST 受信テスト（署名付き）
```javascript
// 署名生成スクリプト
const crypto = require('crypto');
const APP_SECRET = 'YOUR_META_APP_SECRET';
const payload = JSON.stringify({
  object: 'page',
  entry: [{
    id: '123456789',
    time: Date.now(),
    changes: [{
      field: 'leadgen',
      value: { leadgen_id: '999888777666' }
    }]
  }]
});

const signature = 'sha256=' + crypto
  .createHmac('sha256', APP_SECRET)
  .update(payload)
  .digest('hex');

console.log('Signature:', signature);
```

```bash
curl -X POST http://localhost:3001/api/webhook/meta \
  -H "Content-Type: application/json" \
  -H "X-Hub-Signature-256: sha256=COMPUTED_SIGNATURE" \
  -d '{"object":"page","entry":[...]}'
```

---

## Meta側設定手順

1. **Meta for Developers** (https://developers.facebook.com/) でアプリを作成
2. **Webhooks** プロダクトを追加
3. **Page** オブジェクトを選択し、以下を設定:
   - **Callback URL**: `https://crm-backend-production-b5b4.up.railway.app/api/webhook/meta`
   - **Verify Token**: `META_WEBHOOK_VERIFY_TOKEN` に設定した値
4. **leadgen** フィールドをサブスクライブ
5. ページの **Subscribed Apps** でアプリを有効化

---

## Railway デプロイ状況

| 項目 | ステータス |
|------|-----------|
| ドメインプロビジョニング | ✅ 完了 |
| `GET /` ヘルスチェック | ✅ 200 OK |
| `GET /api/webhook/meta` | ⏳ 環境変数設定待ち |
| `POST /api/webhook/meta` | ⏳ 環境変数設定待ち |

**必要なRailway環境変数**:
- `META_WEBHOOK_VERIFY_TOKEN`
- `META_APP_SECRET`
- `META_ACCESS_TOKEN`
- `META_GRAPH_API_VERSION`
- `DEFAULT_PROJECT_ID`

---

## 仕様書との対応表

| 仕様要件 | ステータス | 備考 |
|---------|-----------|------|
| GET /meta/webhook 検証 | ✅ | `/api/webhook/meta` で実装 |
| POST /meta/webhook 受信 | ✅ | 署名検証・冪等性チェック含む |
| HMAC SHA256 署名検証 | ✅ | timing safe compare 実装 |
| raw body 保持 | ✅ | express.json verify オプション使用 |
| Graph API クライアント | ✅ | リトライ・バックオフ実装 |
| leads upsert | ✅ | email で lower/trim 正規化 |
| lead_attribution insert | ✅ | meta_lead_id unique |
| webhook_inbox 冪等性 | ✅ | external_id + provider unique |
| 再処理スクリプト | ✅ | CLI で単体/一括再処理可能 |
| 擬似UTM | ✅ | utm_campaign=P1_static, utm_content=ad_name or meta_lead_id |
| ログ出力 | ✅ | PII マスク対応 |
| .env.example | ✅ | 全環境変数記載 |
| README 動作確認例 | ✅ | curl例・署名生成例含む |

---

## 今後の拡張予定

- [ ] Meta Campaign/Adset/Ad ID の取得（Marketing API 連携）
- [ ] リアルタイム通知（Slack/メール）
- [ ] ダッシュボードでの Meta リード可視化
- [ ] A/B テスト用の UTM パラメータ拡張
