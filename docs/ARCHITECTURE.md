# CRM-WORKSPACE アーキテクチャドキュメント

## 目次

1. [システム概要](#1-システム概要)
2. [プロジェクト構成](#2-プロジェクト構成)
3. [crm-backend（APIサーバー）](#3-crm-backendapiサーバー)
4. [crm-admin（管理画面）](#4-crm-admin管理画面)
5. [web-booking（予約システム）](#5-web-booking予約システム)
6. [v0-modern-lp-design（ランディングページ）](#6-v0-modern-lp-designランディングページ)
7. [プロジェクト間連携](#7-プロジェクト間連携)
8. [データフロー](#8-データフロー)
9. [外部サービス連携](#9-外部サービス連携)
10. [デプロイメント構成](#10-デプロイメント構成)

---

## 1. システム概要

### 1.1 概要

CRM-WORKSPACEは、LINE連携型のマルチプロジェクト対応CRMシステムです。AI（Claude）を活用したリード管理、自動ステップ配信、商談管理を実現する統合プラットフォームです。

### 1.2 主要機能

- **リード獲得**: LINE友だち追加 / Webフォーム / メール経由
- **AI分類・スコアリング**: Claude APIによる自動分類（Hot/Middle/Cold）
- **自動ステップ配信**: LINE / Emailでのシーケンス配信
- **予約管理**: カレンダー連携の予約システム
- **商談管理**: クローザーリクエスト・営業データ管理
- **RAGナレッジベース**: 業界別知識を活用したAI応答

### 1.3 システム構成図

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           CRM-WORKSPACE                                  │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐                │
│  │   crm-admin  │   │ web-booking  │   │v0-modern-lp │                │
│  │  (管理画面)   │   │  (予約画面)   │   │    (LP)     │                │
│  │   Next.js    │   │   Next.js    │   │   Next.js   │                │
│  │   Vercel     │   │   Vercel     │   │   Vercel    │                │
│  └──────┬───────┘   └──────┬───────┘   └──────┬──────┘                │
│         │                  │                   │                        │
│         │    REST API      │                   │                        │
│         └─────────┬────────┴───────────────────┘                        │
│                   │                                                      │
│         ┌────────▼────────┐                                             │
│         │   crm-backend   │◄──── LINE Webhook                          │
│         │  (APIサーバー)   │◄──── CRON Jobs                             │
│         │   Express.js    │                                             │
│         │    Railway      │                                             │
│         └────────┬────────┘                                             │
│                  │                                                       │
└──────────────────┼───────────────────────────────────────────────────────┘
                   │
     ┌─────────────┼─────────────┐
     │             │             │
┌────▼────┐  ┌────▼────┐  ┌────▼────┐
│Supabase │  │ Claude  │  │  LINE   │
│  (DB)   │  │  API    │  │Messaging│
└─────────┘  └─────────┘  └─────────┘
```

---

## 2. プロジェクト構成

### 2.1 ディレクトリ構造

```
crm-workspace/
├── crm-backend/          # バックエンドAPIサーバー
├── crm-admin/            # 管理画面フロントエンド
├── web-booking/          # 予約システム
├── v0-modern-lp-design/  # ランディングページ
├── docs/                 # ドキュメント
├── docker-compose.yml    # ローカル開発環境
├── .env.example          # 環境変数テンプレート
└── README.md             # プロジェクト概要
```

### 2.2 プロジェクト一覧

| プロジェクト | 役割 | 技術スタック | デプロイ先 | ポート |
|-------------|------|-------------|-----------|--------|
| crm-backend | REST API | Express.js + TypeScript | Railway | 3000 |
| crm-admin | 管理画面 | Next.js 14 + shadcn/ui | Vercel | 3001 |
| web-booking | 予約システム | Next.js 14 | Vercel | 3002 |
| v0-modern-lp-design | LP | Next.js 14 + Radix UI | Vercel | - |

---

## 3. crm-backend（APIサーバー）

### 3.1 概要

Express.js + TypeScriptで構築されたRESTful APIサーバー。LINE Webhook受信、AI処理、データベース操作、CRON実行を担当。

### 3.2 ディレクトリ構成

```
crm-backend/
├── src/
│   ├── index.ts                    # エントリーポイント
│   ├── routes/                     # APIルーター（21ファイル）
│   │   ├── lineWebhook.ts         # LINE Webhook処理
│   │   ├── webLead.ts             # Web経由リード初期化
│   │   ├── chat.ts                # AIチャット
│   │   ├── messageClassification.ts # メッセージ分類
│   │   ├── initialAnswers.ts      # スコアリング
│   │   ├── stepDelivery.ts        # LINEステップ配信
│   │   ├── stepTemplates.ts       # テンプレート管理
│   │   ├── scenarioDelivery.ts    # シナリオ配信
│   │   ├── sales.ts               # 商談管理
│   │   ├── booking.ts             # 予約スロット管理
│   │   ├── closerRequests.ts      # クローザーリクエスト
│   │   ├── projects.ts            # プロジェクト管理
│   │   ├── leads.ts               # リード管理
│   │   ├── email.ts               # メール配信停止
│   │   ├── emailStepDelivery.ts   # メールステップ配信
│   │   ├── report.ts              # レポート生成
│   │   ├── metrics.ts             # Prometheusメトリクス
│   │   ├── jobs.ts                # ジョブ管理
│   │   ├── canary.ts              # Canary Bot設定
│   │   ├── alertWebhook.ts        # アラート通知
│   │   └── systemTest.ts          # システムテスト
│   ├── services/                   # ビジネスロジック（39+ファイル）
│   │   ├── supabaseService.ts     # DB接続
│   │   ├── aiClientWrapper.ts     # Claude APIラッパー
│   │   ├── projectService.ts      # プロジェクト管理
│   │   ├── messageOrchestrationService.ts # メッセージ処理
│   │   ├── scoringService.ts      # スコアリング
│   │   ├── escalationService.ts   # エスカレーション
│   │   ├── welcomeMessageService.ts # Welcome Message
│   │   ├── scarcityService.ts     # Stage 2処理
│   │   ├── nurtureScarcityService.ts # Stage 1処理
│   │   ├── conversationStateService.ts # 会話状態
│   │   ├── emailService.ts        # メール送信
│   │   ├── knowledgeService.ts    # RAG検索
│   │   ├── closerRequestService.ts # クローザー管理
│   │   ├── healthCheckService.ts  # ヘルスチェック
│   │   ├── cronScheduler.ts       # CRONスケジューラ
│   │   ├── loggerService.ts       # 構造化ログ
│   │   └── [他サービス]
│   ├── middleware/
│   │   └── lineSignatureVerify.ts # LINE署名検証
│   ├── types/                      # TypeScript型定義
│   └── utils/                      # ユーティリティ
├── scripts/
│   └── migrations/                 # DBマイグレーション
├── tests/                          # テストファイル
├── load-tests/                     # Artillery負荷テスト
└── docs/                           # Backend固有ドキュメント
```

### 3.3 主要APIエンドポイント

#### LINE連携
| メソッド | パス | 説明 |
|---------|------|------|
| POST | `/api/webhook/line/:projectKey` | LINE Webhook受信 |

#### リード管理
| メソッド | パス | 説明 |
|---------|------|------|
| POST | `/api/web/lead/init` | Web経由リード初期化 |
| POST | `/api/web/lead/account-setup` | アカウント設定 |
| GET | `/api/leads` | リード一覧 |
| GET | `/api/leads/:leadId` | リード詳細 |
| PUT | `/api/leads/:leadId` | リード更新 |

#### AI機能
| メソッド | パス | 説明 |
|---------|------|------|
| POST | `/api/chat` | AIチャット処理 |
| POST | `/api/messages/classify` | メッセージ分類 |
| POST | `/api/messages/classify-and-escalate` | 分類+エスカレーション |
| POST | `/api/leads/:leadId/initial-answers/score` | スコアリング |

#### ステップ配信
| メソッド | パス | 説明 |
|---------|------|------|
| POST | `/api/step-delivery` | LINE配信実行（CRON） |
| POST | `/api/step-delivery/send` | LINE送信実行 |
| GET | `/api/step-templates` | テンプレート取得 |
| PUT | `/api/step-templates/:segment/:step` | テンプレート更新 |
| POST | `/api/scenario-delivery/execute` | シナリオ配信（CRON） |

#### メール配信
| メソッド | パス | 説明 |
|---------|------|------|
| POST | `/api/email-step-delivery/preview` | 配信プレビュー |
| POST | `/api/email-step-delivery/execute` | 配信実行（CRON） |
| GET | `/api/email-step-delivery/templates` | テンプレート一覧 |
| POST | `/api/email/unsubscribe` | 配信停止 |
| POST | `/api/email/resubscribe` | 再購読 |

#### 予約管理
| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/api/booking/:projectKey/slots` | スロット一覧 |
| POST | `/api/booking/:projectKey/book` | 予約作成 + 確定メール送信 |
| DELETE | `/api/booking/:projectKey/bookings/:bookingId` | 予約キャンセル + キャンセル確認メール送信 |
| GET | `/api/booking/:projectKey/users/:lineUserId` | ユーザーの予約一覧 |

#### 商談・クローザー管理
| メソッド | パス | 説明 |
|---------|------|------|
| POST | `/api/sales/close` | 商談結果登録 |
| GET | `/api/sales` | 営業データ一覧 |
| GET | `/api/report/prepare/:leadId` | 商談準備レポート |
| GET | `/api/closer-requests` | クローザーリクエスト一覧 |
| POST | `/api/closer-requests` | リクエスト作成 |
| PUT | `/api/closer-requests/:id/status` | ステータス更新 |
| GET | `/api/closer-requests/capacity` | 週間キャパシティ |

#### プロジェクト管理
| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/api/projects` | プロジェクト一覧 |
| POST | `/api/projects` | プロジェクト作成 |
| PUT | `/api/projects/:id/settings` | 設定更新 |

#### 監視・ヘルスチェック
| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/health` | 基本ヘルスチェック |
| GET | `/healthz` | Kubernetes Liveness Probe |
| GET | `/readyz` | Kubernetes Readiness Probe |
| GET | `/health/detailed` | 詳細ヘルスチェック |
| GET | `/api/metrics` | Prometheusメトリクス |

### 3.4 主要サービス

#### messageOrchestrationService
メッセージ受信時の統合処理フロー：
```
1. Stage 1 (ナーチャリング) 応答チェック
2. AI分類 (Claude claude-sonnet-4-20250514)
3. Stage 2 (スカーシティ) 応答処理
4. Stage 2 フロー発動判定
5. Stage 1 フロー発動判定
6. フォールバック処理
```

#### scoringService
リードスコアリングロジック：
```
Rule-Based Scoring (70%)
├── employeeCount: 0-30点
├── budget: 0-25点
├── timeline: 0-25点
└── role: 0-20点

AI Adjustment (30%)
└── Claude APIによる -15〜+15点調整

最終スコア: 0-100点
├── 80-100: Hot
├── 50-79: Middle
└── 0-49: Cold
```

#### AI分類カテゴリ
| カテゴリ | 説明 | アクション |
|---------|------|-----------|
| `inquiry` | 質問・問い合わせ | RAG検索で回答 |
| `intent_mtg` | 商談・相談希望 | エスカレーション |
| `objection` | 反論・懸念 | 説得応答 |
| `casual` | 雑談 | カジュアル応答 |
| `booking_yes/no` | 予約承諾/拒否 | 予約処理 |
| `waitlist_yes/no` | キャンセル待ち承諾/拒否 | ウェイトリスト処理 |
| `nurture_yes/no` | ナーチャリング承諾/拒否 | Stage 1処理 |

---

## 4. crm-admin（管理画面）

### 4.1 概要

Next.js 14 (App Router) + shadcn/ui で構築された管理画面。リード管理、チャット対応、予約管理、テンプレート設定などを提供。

### 4.2 ディレクトリ構成

```
crm-admin/
├── src/
│   ├── app/
│   │   ├── (auth)/              # 認証ページ
│   │   │   └── login/page.tsx
│   │   ├── (dashboard)/         # ダッシュボード（認証必須）
│   │   │   ├── page.tsx                 # ダッシュボードトップ
│   │   │   ├── leads/page.tsx           # リード一覧
│   │   │   ├── messages/page.tsx        # メッセージ管理
│   │   │   ├── bookings/
│   │   │   │   ├── page.tsx             # 予約一覧
│   │   │   │   ├── calendar/page.tsx    # カレンダー表示
│   │   │   │   └── closers/page.tsx     # クローザー管理
│   │   │   ├── line/
│   │   │   │   ├── page.tsx             # LINE概要
│   │   │   │   ├── history/page.tsx     # 配信履歴
│   │   │   │   ├── stats/page.tsx       # 統計
│   │   │   │   └── step-settings/page.tsx # ステップ設定
│   │   │   ├── email/
│   │   │   │   ├── page.tsx             # メール概要
│   │   │   │   ├── templates/page.tsx   # テンプレート
│   │   │   │   ├── campaigns/page.tsx   # キャンペーン
│   │   │   │   ├── segments/page.tsx    # セグメント
│   │   │   │   ├── analytics/page.tsx   # 分析
│   │   │   │   ├── stats/page.tsx       # 統計
│   │   │   │   ├── auto-reply/page.tsx  # 自動返信
│   │   │   │   ├── step-settings/page.tsx # ステップ設定
│   │   │   │   └── unsubscribes/page.tsx  # 配信停止
│   │   │   ├── scenarios/
│   │   │   │   ├── page.tsx             # シナリオ一覧
│   │   │   │   ├── history/page.tsx     # 配信履歴
│   │   │   │   ├── stats/page.tsx       # 統計
│   │   │   │   ├── a/page.tsx           # シナリオA
│   │   │   │   ├── b/page.tsx           # シナリオB
│   │   │   │   └── c/page.tsx           # シナリオC
│   │   │   ├── reports/
│   │   │   │   ├── page.tsx             # レポート概要
│   │   │   │   ├── leads/page.tsx       # リードレポート
│   │   │   │   └── funnel/page.tsx      # ファネル分析
│   │   │   ├── settings/
│   │   │   │   ├── page.tsx             # 設定概要
│   │   │   │   ├── project/page.tsx     # プロジェクト設定
│   │   │   │   ├── knowledge/page.tsx   # ナレッジ管理
│   │   │   │   ├── auto-response/page.tsx # 自動応答設定
│   │   │   │   └── users/page.tsx       # ユーザー管理
│   │   │   └── step-delivery/
│   │   │       └── templates/page.tsx   # 配信テンプレート
│   │   └── layout.tsx
│   ├── components/
│   │   ├── ui/                  # shadcn/ui コンポーネント
│   │   ├── leads/               # リード関連
│   │   ├── chat/                # チャット関連
│   │   ├── bookings/            # 予約関連
│   │   └── knowledge/           # ナレッジ関連
│   ├── hooks/
│   │   ├── useLeads.ts
│   │   ├── useChat.ts
│   │   └── [他データフェッチング]
│   ├── lib/
│   │   └── api-client.ts        # Axios設定
│   ├── types/
│   └── middleware.ts            # 認証ミドルウェア
└── public/
```

### 4.3 機能詳細

#### ダッシュボード
- リード数サマリー（Hot/Middle/Cold）
- 最近のリード一覧
- 予約件数・商談件数
- KPIグラフ（Recharts）

#### リード管理 (`/leads`)
- リード一覧表示（テーブル形式）
- フィルタリング（ステータス、セグメント、チャネル）
- リード詳細表示
- スコア・ステータス更新
- 会話履歴表示

#### LINE管理 (`/line`)
- ステップ配信設定
- 配信履歴確認
- 送信統計表示

#### メール管理 (`/email`)
- テンプレート管理（WYSIWYG エディタ）
- セグメント別配信設定
- 開封率・クリック率統計
- 配信停止者管理

#### シナリオ管理 (`/scenarios`)
- シナリオA/B/C設定
- 配信履歴
- 効果測定統計

#### 予約管理 (`/bookings`)
- カレンダー表示（FullCalendar）
- 予約一覧
- クローザー割り当て
- キャパシティ管理

#### レポート (`/reports`)
- リード獲得推移
- ファネル分析
- 商談成約率

#### 設定 (`/settings`)
- プロジェクト設定
- Welcome Message設定
- ナレッジベース管理
- 自動応答ルール設定
- **メールテンプレート設定** (`/settings/email-template`)
  - 予約確定メールテンプレート
  - **キャンセル確認メールテンプレート** - 予約キャンセル時の自動返信設定
  - URL: https://crm-admin-five-gamma.vercel.app/settings/email-template

### 4.4 技術スタック

| 技術 | 用途 |
|------|------|
| Next.js 14 | フレームワーク（App Router） |
| TypeScript | 型安全性 |
| shadcn/ui | UIコンポーネント |
| Tailwind CSS | スタイリング |
| TanStack Query | データフェッチング・キャッシュ |
| Zustand | 状態管理 |
| Recharts | グラフ描画 |
| FullCalendar | カレンダー |
| Zod | フォームバリデーション |
| React Hook Form | フォーム管理 |
| Supabase Auth | 認証 |

---

## 5. web-booking（予約システム）

### 5.1 概要

リード向けの予約ページ。LINE経由またはURLリンクからアクセスし、空きスロットを選択して予約を確定する。

### 5.2 ディレクトリ構成

```
web-booking/
├── src/
│   ├── app/
│   │   ├── page.tsx                    # ルートページ（リダイレクト）
│   │   ├── [projectKey]/
│   │   │   ├── page.tsx               # 予約メインページ
│   │   │   ├── success/page.tsx       # 予約完了ページ
│   │   │   └── error/page.tsx         # エラーページ
│   │   └── layout.tsx
│   ├── components/
│   │   ├── BookingCalendar.tsx        # カレンダーコンポーネント
│   │   ├── SlotSelector.tsx           # スロット選択
│   │   ├── BookingForm.tsx            # 予約フォーム
│   │   └── ScarcityIndicator.tsx      # 希少性表示
│   ├── hooks/
│   │   └── useBooking.ts              # 予約データフェッチ
│   ├── lib/
│   │   └── api.ts                     # API クライアント
│   └── types/
└── public/
```

### 5.3 機能詳細

#### メインページ (`/[projectKey]`)
- URLパラメータ: `?leadId={leadId}` または `?lineUserId={lineUserId}`
- 空きスロット表示（カレンダー形式）
- スロット選択
- 希少性インジケーター（残り枠数）
- 予約確定ボタン
- **既存予約モーダル** - 既存予約がある場合の変更・キャンセル機能

#### 予約フロー
```
1. URL アクセス: /{projectKey}?leadId={leadId} または ?lineUserId={lineUserId}
2. GET /api/booking/{projectKey}/slots → 空きスロット取得
3. スロット選択
4. POST /api/booking/{projectKey}/book → 予約作成
5. 成功: /success ページ表示 + 予約確定メール自動送信
6. 失敗: /error ページ表示
```

#### キャンセルフロー
```
1. 既存予約がある場合、既存予約モーダル表示
2. キャンセル理由選択（日程調整困難/別の予定/検討中止/その他）
3. DELETE /api/booking/{projectKey}/bookings/{bookingId} → キャンセル実行
4. キャンセル完了画面表示 + キャンセル確認メール自動送信
5. 再予約ボタンから新規予約可能
```

#### 自動返信メール
| トリガー | メール種別 | 設定場所 |
|---------|-----------|---------|
| 予約確定時 | 予約確定メール | crm-admin `/settings/email-template` |
| 予約キャンセル時 | キャンセル確認メール | crm-admin `/settings/email-template` |

**crm-admin メールテンプレート設定URL**: https://crm-admin-five-gamma.vercel.app/settings/email-template

**web-booking 予約画面URL**: https://web-booking-crm.vercel.app/{projectKey}?leadId={leadId}

#### 希少性表示機能
- 残りスロット数をリアルタイム表示
- 「残り3枠」などの緊急感を演出
- 予約後のスロット数自動更新

### 5.4 デザイン特徴

- ダークテーマ + ゴールドアクセント
- モバイル最適化（レスポンシブ）
- ミニマルなUI
- スムーズなアニメーション

---

## 6. v0-modern-lp-design（ランディングページ）

### 6.1 概要

DRAGON AI サービスのランディングページ。v0.app で生成・管理され、無料相談フォームからリードを獲得する。

### 6.2 ディレクトリ構成

```
v0-modern-lp-design/
├── app/
│   ├── layout.tsx                # レイアウト
│   ├── page.tsx                  # メインLP
│   └── simulator/page.tsx        # ROIシミュレーター
├── components/
│   ├── header.tsx                # ヘッダー
│   ├── hero-section.tsx          # ヒーローセクション
│   ├── problem-section.tsx       # 課題提起
│   ├── empathy-section.tsx       # 共感セクション
│   ├── solution-section.tsx      # ソリューション
│   ├── features-section.tsx      # 機能紹介
│   ├── movie-scene-section.tsx   # 映画風演出
│   ├── failure-risk-section.tsx  # 失敗リスク
│   ├── case-studies-section.tsx  # 導入事例
│   ├── testimonials-section.tsx  # お客様の声
│   ├── roi-section.tsx           # ROI説明
│   ├── roi-simulator.tsx         # ROIシミュレーター
│   ├── pricing-section.tsx       # 料金
│   ├── faq-section.tsx           # FAQ
│   ├── cta-section.tsx           # CTA
│   ├── footer.tsx                # フッター
│   ├── theme-provider.tsx        # テーマ設定
│   └── ui/                       # 基本UIコンポーネント
│       ├── accordion.tsx
│       ├── button.tsx
│       ├── card.tsx
│       ├── input.tsx
│       ├── label.tsx
│       ├── select.tsx
│       ├── slider.tsx
│       └── textarea.tsx
├── lib/
│   └── utils.ts
└── public/
```

### 6.3 機能詳細

#### ページ構成
1. **ヒーローセクション**: キャッチコピー + CTAボタン
2. **課題提起**: ターゲットの悩みを明示
3. **共感セクション**: 「あなたもこうではありませんか？」
4. **ソリューション**: DRAGON AI の解決策
5. **機能紹介**: 主要機能の説明
6. **映画風演出**: ビジュアル訴求
7. **失敗リスク**: 導入しない場合のリスク
8. **導入事例**: 成功事例紹介
9. **お客様の声**: テスティモニアル
10. **ROI説明**: 投資対効果
11. **ROIシミュレーター**: インタラクティブ計算
12. **料金**: プラン説明
13. **FAQ**: よくある質問
14. **CTA**: 無料相談フォーム
15. **フッター**: 会社情報・リンク

#### 無料相談フォーム
```
フォーム項目:
├── 会社名
├── 担当者名
├── メールアドレス
├── 電話番号（任意）
├── 従業員数
├── 相談内容
└── プライバシーポリシー同意

送信先: POST /api/web/lead/init (crm-backend)
```

#### ROIシミュレーター (`/simulator`)
- 現在の営業人数入力
- 月間リード数入力
- 商談化率入力
- AI導入後の効果予測表示
- グラフ表示

### 6.4 技術スタック

| 技術 | 用途 |
|------|------|
| Next.js 14 | フレームワーク |
| TypeScript | 型安全性 |
| Radix UI | アクセシブルなUIプリミティブ |
| Tailwind CSS | スタイリング |
| Framer Motion | アニメーション |
| React Hook Form | フォーム管理 |
| Zod | バリデーション |

---

## 7. プロジェクト間連携

### 7.1 連携図

```
┌──────────────────────────────────────────────────────────────────────────┐
│                          プロジェクト間連携                                │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│   ┌─────────────┐                                                        │
│   │   LINE App  │                                                        │
│   └──────┬──────┘                                                        │
│          │ Webhook                                                        │
│          ▼                                                                │
│   ┌──────────────────────────────────────────────────────────────────┐  │
│   │                      crm-backend                                  │  │
│   │  ┌──────────────────────────────────────────────────────────┐   │  │
│   │  │  /api/webhook/line/:projectKey  ←── LINE Webhook         │   │  │
│   │  │  /api/web/lead/init             ←── LP フォーム送信      │   │  │
│   │  │  /api/booking/:projectKey/*     ←── 予約操作             │   │  │
│   │  │  /api/leads/*                   ←── 管理画面からの操作   │   │  │
│   │  │  /api/step-delivery/*           ←── CRON 配信実行        │   │  │
│   │  └──────────────────────────────────────────────────────────┘   │  │
│   └───────────┬─────────────────┬─────────────────┬──────────────────┘  │
│               │                 │                 │                      │
│               ▼                 ▼                 ▼                      │
│   ┌───────────────┐  ┌─────────────────┐  ┌─────────────────┐          │
│   │   crm-admin   │  │   web-booking   │  │ v0-modern-lp    │          │
│   │               │  │                 │  │                 │          │
│   │ ・リード管理   │  │ ・予約画面表示  │  │ ・LP表示        │          │
│   │ ・チャット     │  │ ・スロット選択  │  │ ・フォーム送信  │          │
│   │ ・予約確認     │  │ ・予約確定      │  │ ・ROIシミュレータ│         │
│   │ ・レポート     │  │ ・完了表示      │  │                 │          │
│   └───────────────┘  └─────────────────┘  └─────────────────┘          │
│                                                                           │
└──────────────────────────────────────────────────────────────────────────┘
```

### 7.2 連携パターン

#### パターン1: LP → Backend → LINE通知
```
1. ユーザーがLPでフォーム送信
2. POST /api/web/lead/init → crm-backend
3. leads テーブルにINSERT
4. Welcome Message を LINE送信
5. 初回質問をスケジュール
```

#### パターン2: LINE → Backend → 予約案内
```
1. ユーザーがLINEでメッセージ送信
2. LINE Platform → Webhook → crm-backend
3. AI分類で「intent_mtg」判定
4. 予約URLをLINE送信
5. ユーザーがweb-bookingにアクセス
6. 予約完了 → crm-backend → LINE通知
```

#### パターン3: 管理画面 → Backend → LINE送信
```
1. 管理者がcrm-adminで手動メッセージ作成
2. POST /api/chat → crm-backend
3. LINE Push API で送信
4. lead_messages に記録
```

#### パターン4: CRON → Backend → ステップ配信
```
1. 毎時0分にCRONトリガー
2. POST /api/step-delivery (x-cron-key)
3. 配信対象リード抽出
4. テンプレート取得
5. LINE Push API で一斉送信
```

### 7.3 API認証パターン

| 呼び出し元 | 認証方式 | 説明 |
|-----------|---------|------|
| LINE Platform | x-line-signature | HMAC-SHA256署名検証 |
| crm-admin | Supabase JWT | ユーザー認証 |
| web-booking | なし（リード限定） | leadId パラメータで特定 |
| v0-modern-lp | なし（公開API） | リード作成のみ |
| CRON Jobs | x-cron-key | 環境変数で検証 |

---

## 8. データフロー

### 8.1 リード獲得フロー

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          リード獲得フロー                                 │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  【チャネル1: LINE友だち追加】                                            │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐         │
│  │ LINE追加 │───▶│ Webhook  │───▶│leads作成 │───▶│ Welcome  │         │
│  │  (follow) │    │  受信    │    │(channel: │    │ Message  │         │
│  └──────────┘    └──────────┘    │  line)   │    │  送信    │         │
│                                   └──────────┘    └──────────┘         │
│                                                                          │
│  【チャネル2: LPフォーム】                                                │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐         │
│  │ フォーム │───▶│  /init   │───▶│leads作成 │───▶│ Welcome  │         │
│  │  送信    │    │  API     │    │(channel: │    │ Email    │         │
│  └──────────┘    └──────────┘    │exec_mail)│    │  送信    │         │
│                                   └──────────┘    └──────────┘         │
│                                                                          │
│  【チャネル3: Web+LINE】                                                  │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐         │
│  │LIFF経由  │───▶│  /init   │───▶│leads作成 │───▶│ LINE     │         │
│  │フォーム  │    │  API     │    │(channel: │    │ Welcome  │         │
│  └──────────┘    └──────────┘    │line_web) │    │  送信    │         │
│                                   └──────────┘    └──────────┘         │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 8.2 メッセージ処理フロー

```
┌─────────────────────────────────────────────────────────────────────────┐
│                       メッセージ処理フロー                                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌──────────┐                                                           │
│  │ユーザー  │                                                           │
│  │メッセージ│                                                           │
│  └────┬─────┘                                                           │
│       │                                                                  │
│       ▼                                                                  │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │              messageOrchestrationService.orchestrate()            │  │
│  ├──────────────────────────────────────────────────────────────────┤  │
│  │                                                                   │  │
│  │  Step 1: Nurture Response Check                                  │  │
│  │  ├── conversation_states テーブル確認                             │  │
│  │  └── nurture_yes/no → Stage 1 処理                               │  │
│  │                                                                   │  │
│  │  Step 2: AI Classification (Claude API)                          │  │
│  │  ├── メッセージ内容を分析                                         │  │
│  │  └── カテゴリ判定: inquiry/intent_mtg/objection/casual/...       │  │
│  │                                                                   │  │
│  │  Step 3: Scarcity Response Check                                 │  │
│  │  ├── booking_yes/no → 予約処理                                   │  │
│  │  └── waitlist_yes/no → ウェイトリスト処理                         │  │
│  │                                                                   │  │
│  │  Step 4: Stage 2 Trigger (Hot + intent_mtg)                      │  │
│  │  ├── 条件: scoring_segment = 'Hot' AND category = 'intent_mtg'   │  │
│  │  └── アクション: 予約URL送信 + closer_request作成                 │  │
│  │                                                                   │  │
│  │  Step 5: Stage 1 Trigger (Middle + ABC conditions)               │  │
│  │  ├── 条件: セグメント・回答内容に基づく判定                       │  │
│  │  └── アクション: ナーチャリングメッセージ送信                     │  │
│  │                                                                   │  │
│  │  Step 6: Fallback                                                │  │
│  │  └── カテゴリ別定型応答                                          │  │
│  │                                                                   │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 8.3 予約フロー

```
┌─────────────────────────────────────────────────────────────────────────┐
│                            予約フロー                                    │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐         │
│  │ 予約URL  │───▶│web-booking│───▶│ スロット │───▶│ 予約確定 │         │
│  │  クリック │    │  表示    │    │  選択   │    │  ボタン  │         │
│  └──────────┘    └──────────┘    └──────────┘    └────┬─────┘         │
│                                                        │                │
│                                                        ▼                │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                     crm-backend                                  │   │
│  │  POST /api/booking/:projectKey/book                             │   │
│  │  ├── booking_slots テーブル更新                                  │   │
│  │  ├── leads.booking_context = 'booking' 更新                     │   │
│  │  ├── closer_requests 作成 (type: 'booking')                     │   │
│  │  └── LINE 確認メッセージ送信                                     │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                          │
│  【キャパシティ超過時】                                                   │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐                         │
│  │ 予約不可 │───▶│ウェイト │───▶│closer_   │                         │
│  │  判定    │    │リスト案内│    │requests  │                         │
│  └──────────┘    └──────────┘    │(waitlist)│                         │
│                                   └──────────┘                         │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 8.4 ステップ配信フロー

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        ステップ配信フロー                                 │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  【LINE ステップ配信】                                                    │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐         │
│  │  CRON    │───▶│対象リード│───▶│テンプレー│───▶│ LINE     │         │
│  │ (毎時0分)│    │  抽出    │    │ト取得    │    │ Push送信 │         │
│  └──────────┘    └──────────┘    └──────────┘    └──────────┘         │
│                                                                          │
│  対象条件:                                                               │
│  - status = 'active'                                                    │
│  - current_step + 1 のテンプレートが存在                                 │
│  - 前回配信から delay_hours 経過                                        │
│                                                                          │
│  【Email ステップ配信】                                                   │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐         │
│  │  CRON    │───▶│対象リード│───▶│条件分岐  │───▶│ Email    │         │
│  │          │    │  抽出    │    │          │    │  送信    │         │
│  └──────────┘    └──────────┘    └──────────┘    └──────────┘         │
│                                                                          │
│  条件分岐 (condition_type):                                             │
│  - 'all': 全員に配信                                                    │
│  - 'opened': 前ステップを開封した人のみ                                  │
│  - 'not_opened': 前ステップを開封していない人のみ                        │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 9. 外部サービス連携

### 9.1 Supabase

| 用途 | 説明 |
|------|------|
| PostgreSQL | メインデータベース |
| Auth | crm-admin の認証 |
| pgvector | RAG用ベクトル検索 |
| RLS | Row Level Security |

**環境変数**:
```
SUPABASE_URL=https://xxx.supabase.co
SUPABASE_ANON_KEY=xxx
SUPABASE_SERVICE_ROLE_KEY=xxx
```

### 9.2 Claude API

| 用途 | モデル |
|------|--------|
| メッセージ分類 | claude-sonnet-4-20250514 |
| スコアリング調整 | claude-sonnet-4-20250514 |
| チャット応答 | claude-sonnet-4-20250514 |

**環境変数**:
```
ANTHROPIC_API_KEY=sk-ant-xxx
```

### 9.3 LINE Messaging API

| 用途 | 説明 |
|------|------|
| Webhook受信 | メッセージ・イベント受信 |
| Push API | メッセージ送信 |
| Reply API | 応答メッセージ |

**環境変数**:
```
LINE_CHANNEL_ID=xxx
LINE_CHANNEL_SECRET=xxx
LINE_CHANNEL_ACCESS_TOKEN=xxx
LINE_PUSH_ENDPOINT=https://api.line.me/v2/bot/message/push
```

### 9.4 SendGrid / SMTP

| 用途 | 説明 |
|------|------|
| メール送信 | ステップ配信・通知 |
| 開封トラッキング | 開封率計測 |

**環境変数**:
```
EMAIL_PROVIDER=sendgrid
SENDGRID_API_KEY=SG.xxx
SENDGRID_FROM_EMAIL=noreply@example.com
SENDGRID_FROM_NAME=Company Name

# SMTP（バックアップ）
SMTP_HOST=xxx
SMTP_PORT=587
SMTP_USER=xxx
SMTP_PASS=xxx
```

### 9.5 OpenAI

| 用途 | 説明 |
|------|------|
| Embedding | RAGナレッジのベクトル化 |

**環境変数**:
```
OPENAI_API_KEY=sk-xxx
```

---

## 10. デプロイメント構成

### 10.1 本番環境

| サービス | デプロイ先 | URL |
|---------|-----------|-----|
| crm-backend | Railway | https://crm-backend-production-b5b4.up.railway.app |
| crm-admin | Vercel | https://crm-admin.vercel.app |
| web-booking | Vercel | https://web-booking.vercel.app |
| v0-modern-lp-design | Vercel | https://v0-dragon-keiei.vercel.app |

### 10.2 ローカル開発環境

```yaml
# docker-compose.yml
services:
  backend:
    port: 3000
    build: ./crm-backend

  admin:
    port: 3001
    build: ./crm-admin

  booking:
    port: 3002
    build: ./web-booking

  redis:  # オプション
    port: 6379
```

**起動コマンド**:
```bash
# 全サービス起動
docker-compose up -d

# 個別起動
docker-compose up -d backend
docker-compose up -d admin

# ログ確認
docker-compose logs -f backend

# 停止
docker-compose down
```

### 10.3 環境変数設定

各プロジェクトの `.env` ファイル:

**crm-backend/.env**:
```env
PORT=3000
NODE_ENV=production
SUPABASE_URL=xxx
SUPABASE_ANON_KEY=xxx
SUPABASE_SERVICE_ROLE_KEY=xxx
ANTHROPIC_API_KEY=xxx
LINE_CHANNEL_ID=xxx
LINE_CHANNEL_SECRET=xxx
LINE_CHANNEL_ACCESS_TOKEN=xxx
CRON_SECRET_KEY=xxx
ENABLE_CRON_SCHEDULER=true
```

**crm-admin/.env**:
```env
NEXT_PUBLIC_API_URL=http://localhost:3000/api
NEXT_PUBLIC_SUPABASE_URL=xxx
NEXT_PUBLIC_SUPABASE_ANON_KEY=xxx
```

**web-booking/.env**:
```env
NEXT_PUBLIC_API_BASE_URL=http://localhost:3000/api
NEXT_PUBLIC_LIFF_ID=xxx
```

---

## 付録

### A. データベーステーブル一覧

| テーブル | 説明 |
|---------|------|
| projects | プロジェクト設定 |
| leads | リード情報 |
| lead_messages | 会話履歴 |
| sales_data | 商談データ |
| closer_requests | クローザーリクエスト |
| step_templates | LINEステップテンプレート |
| email_step_templates | メールステップテンプレート |
| email_unsubscribes | 配信停止 |
| conversation_states | 会話状態 |
| knowledge_items | RAGナレッジ |
| booking_slots | 予約スロット |

### B. CRON ジョブ一覧

| ジョブ | スケジュール | エンドポイント |
|--------|-------------|---------------|
| シナリオ配信 | 毎時0分 | POST /api/scenario-delivery/execute |
| ステップ配信 | 毎時0分 | POST /api/step-delivery |
| メール配信 | 毎日9:00 | POST /api/email-step-delivery/execute |

### C. 監視エンドポイント

| エンドポイント | 用途 |
|---------------|------|
| GET /health | 基本ヘルスチェック |
| GET /healthz | Kubernetes Liveness Probe |
| GET /readyz | Kubernetes Readiness Probe |
| GET /api/metrics | Prometheusメトリクス |

---

*最終更新: 2026年1月18日*
