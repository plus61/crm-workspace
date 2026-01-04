# CRM Workspace アーキテクチャ

## プロジェクト構成

```
crm-workspace/
├── crm-backend/          # バックエンドAPI（Express + TypeScript）
├── v0-modern-lp-design/  # ランディングページ（Next.js）
├── web-booking/          # 予約システム（Next.js）
└── (その他のプロジェクト)
```

## 各プロジェクトの責務

### crm-backend
- **リポジトリ**: https://github.com/plus61/crm-backend.git
- **デプロイ**: https://backend-ivory-iota-92.vercel.app
- **役割**:
  - リード管理API (`/api/web/lead/init`)
  - メール送信サービス
  - シナリオ管理
  - プロジェクト設定管理
  - 予約スロット管理API

### v0-modern-lp-design
- **リポジトリ**: https://github.com/plus61/v0-modern-lp-design.git
- **デプロイ**: https://v0-dragon-keiei.vercel.app
- **役割**:
  - ランディングページ表示
  - 無料相談フォーム
  - ROIシミュレーター
  - フォーム送信 → crm-backend API呼び出し

### web-booking
- **リポジトリ**: https://github.com/plus61/web-booking.git
- **デプロイ**: https://web-booking-psi.vercel.app
- **役割**:
  - 予約カレンダー表示
  - 予約確定処理
  - 既存予約の確認・キャンセル
- **URL パターン**: `/{projectKey}?lineUserId=xxx&leadId=xxx`

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

## 重要な設定

### プロジェクト設定 (projectService.ts)

```typescript
{
  key: 'dragon-keiei',
  name: 'DRAGON AI 経営者向け',
  bookingUrl: 'https://web-booking-psi.vercel.app', // 予約システムURL
  // ... 他の設定
}
```

### URL生成パターン

| 用途 | パターン | 例 |
|------|----------|-----|
| 予約ページ | `{bookingUrl}/{projectKey}?leadId={leadId}` | `https://web-booking-psi.vercel.app/dragon-keiei?leadId=xxx` |
| シミュレーター | `{lpUrl}/simulator?code={accessCode}` | `https://v0-dragon-keiei.vercel.app/simulator?code=ABC123` |

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

### 機能の配置ルール

| 機能カテゴリ | 配置先 |
|-------------|--------|
| フォーム（LP用） | v0-modern-lp-design |
| 予約機能 | web-booking |
| API・バックエンド処理 | crm-backend |
| メール送信 | crm-backend |
| シナリオ管理 | crm-backend |

## 関連ドキュメント

- 各プロジェクトのREADME.md
- crm-backend/src/services/ 内のサービスコメント
