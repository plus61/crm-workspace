# CRM Admin 機能検証レポート

**検証日時**: 2026年1月13日
**検証方法**: API直接呼び出し + コードベース解析
**対象環境**:
- Backend: https://crm-backend-production-b5b4.up.railway.app
- Frontend: crm-admin (localhost:3001 / Vercel)

---

## 検証結果サマリー

| カテゴリ | 状態 | 詳細 |
|---------|------|------|
| リード管理 | ✅ 正常 | API動作確認済み |
| メールステップ設定 | ✅ 正常 | 6テンプレート確認 |
| 予約スロット | ✅ 正常 | 156スロット確認 |
| KPIダッシュボード | ⚠️ 部分的 | シナリオパラメータ無視 |
| 予約一覧 | ❌ 要修正 | エンドポイント不一致 |
| キャンペーン | ❌ 未実装 | APIエンドポイント無し |

---

## 1. 正常動作確認済みAPI

### 1.1 リード管理 (`/api/leads`)
```
GET /api/leads?projectKey=dragon-keiei
✅ ステータス: 200 OK
✅ データ: 2件のリード取得成功
✅ セグメントフィルター: 動作確認済み
```

### 1.2 メールステップテンプレート (`/api/email/step-templates`)
```
GET /api/email/step-templates?projectKey=dragon-keiei
✅ ステータス: 200 OK
✅ データ: 6テンプレート（Hot:2, Warm:2, Cold:2）
✅ セグメント別取得: 動作確認済み
```

### 1.3 予約スロット (`/api/booking/:projectKey/slots`)
```
GET /api/booking/dragon-keiei/slots
✅ ステータス: 200 OK
✅ データ: 156スロット取得成功
```

### 1.4 プロジェクト設定 (`/api/projects`)
```
GET /api/projects?projectKey=dragon-keiei
✅ ステータス: 200 OK
✅ データ: プロジェクト情報取得成功
```

### 1.5 メッセージ (`/api/leads/:id/messages`)
```
GET /api/leads/{leadId}/messages?projectKey=dragon-keiei
✅ ステータス: 200 OK
✅ データ: メッセージ履歴取得成功
```

### 1.6 営業担当者設定 (`/api/booking/:projectKey/closer-settings`)
```
GET /api/booking/dragon-keiei/closer-settings
✅ ステータス: 200 OK
✅ データ: 0件（担当者未設定）
```

### 1.7 LINEステップテンプレート (`/api/step-templates`)
```
GET /api/step-templates?projectKey=dragon-keiei&channel=line
✅ ステータス: 200 OK
✅ データ: 0件（LINE未設定）
```

---

## 2. 発見された問題

### 2.1 [Critical] 予約一覧エンドポイント不一致

**問題**: フロントエンドとバックエンドでエンドポイントパスが異なる

| 項目 | フロントエンド | バックエンド |
|------|---------------|-------------|
| パス | `/api/bookings` | `/api/booking` |
| ファイル | `useBookings.ts:65` | `index.ts:193` |

**影響**: 予約一覧ページ (`/bookings`) でデータ取得失敗

**修正方法**:
```typescript
// Option A: バックエンドを修正
// src/index.ts
app.use('/api/bookings', bookingRouter);  // 's' を追加

// Option B: フロントエンドを修正
// useBookings.ts
const response = await api.get<BookingWithLead[]>(`/api/booking?${params.toString()}`);
```

### 2.2 [High] KPIシナリオパラメータ無視

**問題**: `/api/kpi/configs` がシナリオパラメータを無視し、常に同じデータを返す

**検証結果**:
```
GET /api/kpi/configs?projectKey=dragon-keiei&scenario=A → scenario: "C"
GET /api/kpi/configs?projectKey=dragon-keiei&scenario=B → scenario: "C"
GET /api/kpi/configs?projectKey=dragon-keiei&scenario=C → scenario: "C"
```

**影響**: KPIダッシュボードでシナリオ切り替えが機能しない

**修正箇所**: `crm-backend/src/routes/kpi.ts`

### 2.3 [Medium] キャンペーンAPI未実装

**問題**: `/api/email/campaigns` エンドポイントが存在しない

**検証結果**:
```
GET /api/email/campaigns?projectKey=dragon-keiei
❌ ステータス: 404 Not Found
```

**影響**: キャンペーン管理ページ (`/email/campaigns`) が機能しない

**必要な実装**:
- `GET /api/email/campaigns` - キャンペーン一覧取得
- `POST /api/email/campaigns` - キャンペーン作成
- `PUT /api/email/campaigns/:id` - キャンペーン更新
- `DELETE /api/email/campaigns/:id` - キャンペーン削除

### 2.4 [Low] セグメント名の大文字小文字不一致

**問題**: フロントエンドとバックエンドでセグメント名の形式が異なる

| フロントエンド | バックエンド |
|---------------|-------------|
| `hot` | `Hot` |
| `warm` | `Middle` |
| `cold` | `Cold` |

**影響**: セグメントフィルター時に不一致が発生する可能性

**推奨**: バックエンドで大文字小文字を無視する処理を追加

### 2.5 [Info] KPI Metricsデータなし

**問題**: ステップ別KPIメトリクスがすべてnull

**検証結果**:
```json
{
  "scenarioId": "uuid",
  "stepNumber": 1,
  "metricData": null
}
```

**原因**: データ集計処理が未実行、またはデータが存在しない

**推奨**: 手動集計ボタンの動作確認、または初期データ投入

---

## 3. 機能別検証ステータス

### 高優先度機能

| # | 機能 | API | 状態 |
|---|------|-----|------|
| 3.1-3.11 | リード一覧 | `/api/leads` | ✅ |
| 3.12-3.19 | リード詳細 | `/api/leads/:id` | ✅ |
| 5.10-5.20 | メールステップ設定 | `/api/email/step-templates` | ✅ |
| 6.1-6.10 | 予約管理 | `/api/booking` | ⚠️ エンドポイント不一致 |
| 5.38-5.44 | KPIダッシュボード | `/api/kpi/*` | ⚠️ シナリオ無視 |

### 中優先度機能

| # | 機能 | API | 状態 |
|---|------|-----|------|
| 5.21-5.27 | セグメント設定 | - | ⚠️ フロントエンドのみ |
| 5.28-5.37 | キャンペーン | `/api/email/campaigns` | ❌ 未実装 |
| 6.11-6.15 | 営業担当者管理 | `/api/booking/.../closer-settings` | ✅ |

### 低優先度機能

| # | 機能 | API | 状態 |
|---|------|-----|------|
| 7.1-7.6 | LINEステップ設定 | `/api/step-templates` | ✅ (データなし) |
| 8.1-8.9 | メッセージ | `/api/leads/:id/messages` | ✅ |
| 10.1-10.11 | 設定各種 | `/api/projects` | ✅ |

---

## 4. 推奨アクション

### 即時対応（Critical）

1. **予約エンドポイント修正**
   - バックエンド `app.use('/api/bookings', bookingRouter)` に変更
   - または一般的な予約一覧エンドポイントを追加

### 短期対応（High）

2. **KPIシナリオパラメータ修正**
   - `kpi.ts` でシナリオパラメータを正しく処理
   - クエリでシナリオ別フィルタリングを実装

### 中期対応（Medium）

3. **キャンペーンAPI実装**
   - CRUD エンドポイント一式を実装
   - データベーステーブル確認・作成

4. **セグメント名の正規化**
   - バックエンドでcase-insensitive処理を追加
   - または統一した命名規則を採用

---

## 5. 検証環境情報

```
Backend URL: https://crm-backend-production-b5b4.up.railway.app
Project Key: dragon-keiei
検証ツール: curl, jq
検証日: 2026-01-13
```

---

## 6. 次回検証項目

- [ ] 予約エンドポイント修正後の動作確認
- [ ] KPIシナリオ切り替えの動作確認
- [ ] キャンペーンAPI実装後の動作確認
- [ ] E2Eテストによるフルフロー確認
- [ ] ブラウザベースのUI動作確認
