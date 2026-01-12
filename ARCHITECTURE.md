# CRM Workspace アーキテクチャ

## プロジェクト構成

```
crm-workspace/
├── crm-backend/          # バックエンドAPI（Express + TypeScript）
├── crm-admin/            # 管理ダッシュボード（Next.js）
├── v0-modern-lp-design/  # ランディングページ（Next.js）
└── web-booking/          # 予約システム（Next.js）
```

## 各プロジェクトの責務

### crm-backend
- **リポジトリ**: https://github.com/plus61/crm-backend.git
- **デプロイ**: https://backend-ivory-iota-92.vercel.app
- **フレームワーク**: Express.js + TypeScript
- **役割**:
  - リード管理API (`/api/web/lead/init`)
  - メール送信サービス
  - シナリオ管理・配信
  - プロジェクト設定管理
  - 予約スロット管理API
  - AI会話サービス
  - メッセージ分類・オーケストレーション
  - ステップメール配信スケジュール管理

### crm-admin
- **リポジトリ**: https://github.com/plus61/crm-admin.git
- **デプロイ**: Vercel
- **フレームワーク**: Next.js 14 + TypeScript + Supabase
- **役割**:
  - 管理ダッシュボード
  - リード管理・詳細表示
  - チャット機能（AI自動応答 + 手動対応）
  - セグメント昇格/降格システム
  - ステップメール配信管理
  - 設定管理（テンプレート、自動応答、ナレッジベース等）
  - Cron ジョブ（シミュレータータイムアウト処理）
- **主要 API Routes**:
  - `POST /api/leads/[id]/promote` - セグメント昇格
  - `GET /api/leads/[id]/segment-history` - セグメント履歴
  - `POST /api/cron/simulator-timeout` - 自動降格処理
  - `GET/POST /api/step-templates` - ステップテンプレート管理
  - `POST /api/settings/auto-response` - 自動応答設定

### v0-modern-lp-design
- **リポジトリ**: https://github.com/plus61/v0-modern-lp-design.git
- **デプロイ**: https://v0-dragon-keiei.vercel.app
- **フレームワーク**: Next.js + TypeScript
- **役割**:
  - ランディングページ表示
  - 無料相談フォーム
  - ROIシミュレーター
  - フォーム送信 → crm-backend API呼び出し
- **API Routes**:
  - `POST /api/leads` - リード作成
  - `POST /api/submit-roi-result` - ROI結果送信
  - `POST /api/verify-access-code` - アクセスコード検証

### web-booking
- **リポジトリ**: https://github.com/plus61/web-booking.git
- **デプロイ**: https://web-booking-psi.vercel.app
- **フレームワーク**: Next.js + TypeScript
- **役割**:
  - 予約カレンダー表示
  - 予約確定処理
  - 既存予約の確認・キャンセル
- **URL パターン**: `/{projectKey}?lineUserId=xxx&leadId=xxx`

## セグメント管理システム

### Entry Point セグメント

リードの温度感を3段階で管理：

| セグメント | 説明 | ステップメール開始位置 |
|-----------|------|----------------------|
| **Hot** | 予約済み・高関心 | Step 1 |
| **Warm** | シミュレーター利用済み | Step 3 |
| **Cold** | 初期状態・低関心 | Step 5 |

### 昇格トリガー（Promotion）

| トリガー | 説明 | 昇格先 |
|---------|------|--------|
| `booking` | 予約完了 | Hot |
| `simulator_usage` | ROIシミュレーター利用 | Warm |
| `document_download` | 資料ダウンロード | Warm |
| `lp_form_submit` | LPフォーム送信 | Warm |
| `admin_manual` | 管理者による手動変更 | 任意 |

### 降格トリガー（Demotion）

| トリガー | 説明 | 降格先 |
|---------|------|--------|
| `simulator_timeout` | 72時間シミュレーター未使用 | Cold |

### 自動降格処理（Cron Job）

- **エンドポイント**: `POST /api/cron/simulator-timeout`
- **実行頻度**: 毎日（Vercel Cron）
- **処理内容**:
  - Warm セグメントのリードを検索
  - シミュレーターアクセスから72時間経過したリードを Cold に降格
  - 降格時は Step 5 からステップメール再開

## データフロー

### 無料相談申込フロー

```
[v0-modern-lp-design]          [crm-backend]                [web-booking]
      |                              |                            |
 フォーム送信 ────────────────> /api/web/lead/init              |
      |                              |                            |
      |                        リード作成                         |
      |                              |                            |
      |                   welcomeMessageService                   |
      |                    メール送信（予約URL付き）              |
      |                              |                            |
      |                    bookingUrl から URL生成                |
      |                 {bookingUrl}/{projectKey}?leadId={id}     |
      |                              |                            |
      └──────────────────────────────┼────────────────────────────┘
                                     |
                               [ユーザー]
                                     |
                             メール内リンクをクリック
                                     |
                                     v
                              /{projectKey}?leadId={id}
                                     |
                         スロット選択 → 予約確定
```

### 管理者運用フロー

```
[crm-admin]                        [crm-backend]              [Supabase]
    |                                   |                          |
リード一覧表示 ←── GET /leads ──────────|                          |
    |                                   |                          |
リード詳細表示 ←── GET /leads/[id] ─────|                          |
    |                                   |                          |
チャット送受信 ←→ POST /chat/send ──────|                          |
    |                                   |                          |
セグメント昇格 ──→ POST /api/leads/[id]/promote ──────────────────→|
    |                                   |                          |
セグメント履歴 ←── GET /api/leads/[id]/segment-history ←──────────|
    |                                   |                          |
Cron 自動降格 ──→ POST /api/cron/simulator-timeout ───────────────→|
```

### ROIシミュレーターフロー

```
[v0-modern-lp-design]          [crm-backend]              [crm-admin]
      |                              |                          |
 メール内URL ─────────────────> アクセスコード検証              |
      |                              |                          |
 シミュレーター表示                  |                          |
      |                              |                          |
 ROI計算結果送信 ─────────────> /api/submit-roi-result          |
      |                              |                          |
      |                        セグメント昇格                    |
      |                        (Cold → Warm)                     |
      |                              |                          |
      |                              └──────────────────────────→|
      |                                                  履歴記録|
```

## 重要な設定

### プロジェクト設定 (projectService.ts)

```typescript
{
  key: 'dragon-keiei',
  name: 'DRAGON AI 経営者向け',
  bookingUrl: 'https://web-booking-psi.vercel.app', // 予約システムURL
  lpUrl: 'https://v0-dragon-keiei.vercel.app',      // LPのURL
  // ... 他の設定
}
```

### URL生成パターン

| 用途 | パターン | 例 |
|------|----------|-----|
| 予約ページ | `{bookingUrl}/{projectKey}?leadId={leadId}` | `https://web-booking-psi.vercel.app/dragon-keiei?leadId=xxx` |
| シミュレーター | `{lpUrl}/simulator?code={accessCode}` | `https://v0-dragon-keiei.vercel.app/simulator?code=ABC123` |

### 環境変数

各プロジェクトで必要な主要環境変数：

| プロジェクト | 環境変数 | 用途 |
|-------------|---------|------|
| crm-admin | `NEXT_PUBLIC_SUPABASE_URL` | Supabase接続 |
| crm-admin | `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Supabase認証 |
| crm-admin | `CRON_SECRET` | Cron ジョブ認証 |
| crm-backend | `SUPABASE_URL` | Supabase接続 |
| crm-backend | `RESEND_API_KEY` | メール送信 |

## 開発時の注意点

### 新機能追加前のチェックリスト

1. **既存機能の確認**
   - 類似機能がすでに別プロジェクトに存在しないか確認
   - 各プロジェクトの役割分担を確認

2. **URL・エンドポイントの確認**
   - ハードコードされたURLがないか確認
   - プロジェクト設定から動的に取得すべきか検討

3. **データフローの確認**
   - どのプロジェクトがどのデータを管理するか確認
   - API呼び出しの方向性を確認

4. **セグメント影響の確認**
   - 機能がセグメント昇格/降格に影響するか確認
   - 適切なトリガータイプを使用しているか確認

### 機能の配置ルール

| 機能カテゴリ | 配置先 |
|-------------|--------|
| 管理ダッシュボード | crm-admin |
| リード管理・チャット | crm-admin |
| セグメント昇格/降格 | crm-admin |
| Cron ジョブ | crm-admin |
| フォーム（LP用） | v0-modern-lp-design |
| ROIシミュレーター | v0-modern-lp-design |
| 予約機能 | web-booking |
| API・バックエンド処理 | crm-backend |
| メール送信 | crm-backend |
| シナリオ管理 | crm-backend |
| AI会話処理 | crm-backend |

## 関連ドキュメント

- 各プロジェクトのREADME.md
- crm-backend/src/services/ 内のサービスコメント
- crm-admin/src/lib/services/ 内のサービスコメント
