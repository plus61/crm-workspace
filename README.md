# CRM Platform Workspace

CRM プラットフォームの統合ワークスペースです。以下の4つのリポジトリを一元管理します。

## リポジトリ構成

| リポジトリ | 説明 | 技術スタック | デプロイ先 |
|-----------|------|-------------|-----------|
| [crm-backend](https://github.com/plus61/crm-backend) | REST API サーバー | Express.js + TypeScript | Railway |
| [crm-admin](https://github.com/plus61/crm-admin) | 管理画面フロントエンド | Next.js + TypeScript | Vercel |
| [web-booking](https://github.com/plus61/web-booking) | 予約フロントエンド | Next.js + TypeScript | Vercel |
| [v0-modern-lp-design](https://github.com/plus61/v0-modern-lp-design) | DRAGON AI LP | Next.js + TypeScript | Vercel |

## クイックスタート

### 1. 全リポジトリを一括クローン

```bash
git clone https://github.com/plus61/crm-workspace.git
cd crm-workspace
./clone-all.sh
```

### 2. 環境変数の設定

```bash
cp .env.example .env
# .env ファイルを編集して必要な値を設定
```

### 3. 開発サーバーの起動

**Docker を使用する場合:**
```bash
docker-compose up -d
```

**個別に起動する場合:**
```bash
# Backend (Port 3000)
cd crm-backend && npm install && npm run dev

# Admin (Port 3001)
cd crm-admin && npm install && npm run dev

# Web Booking (Port 3002)
cd web-booking && npm install && npm run dev
```

## ディレクトリ構造

```
crm-workspace/
├── README.md
├── clone-all.sh          # 一括クローンスクリプト
├── docker-compose.yml    # ローカル開発環境
├── .env.example          # 環境変数テンプレート
│
├── crm-backend/          # Backend API (git clone)
├── crm-admin/            # Admin Frontend (git clone)
├── web-booking/          # Booking Frontend (git clone)
└── v0-modern-lp-design/  # DRAGON AI LP (git clone)
```

## 開発ワークフロー

### ブランチ戦略

各リポジトリは独立したブランチ戦略を持ちます：

- `main` - 本番環境
- `develop` - 開発環境
- `feature/*` - 機能開発

### コミット規約

```
feat: 新機能追加
fix: バグ修正
docs: ドキュメント更新
refactor: リファクタリング
test: テスト追加・修正
chore: その他の変更
```

## 本番環境

| サービス | URL |
|---------|-----|
| Backend API | https://crm-backend-production-b5b4.up.railway.app |
| Admin Panel | https://crm-admin.vercel.app |
| Web Booking | https://web-booking.vercel.app |
| DRAGON AI LP | https://v0-dragon-keiei.vercel.app |

## ライセンス

Private
