# フロントエンド・バックエンド共有定義

このドキュメントは、フロントエンド (crm-admin) とバックエンド (crm-backend) で同期が必要な定義を管理します。

## テンプレート変数

**変更時は必ず両方を更新すること！**

| 変数キー | 説明 | Frontend | Backend |
|---------|------|----------|---------|
| `{{name}}` | リードの氏名 | `src/types/index.ts` | `src/services/emailService.ts` |
| `{{firstName}}` | リードの名 | ✅ | ✅ |
| `{{lastName}}` | リードの姓 | ✅ | ✅ |
| `{{email}}` | メールアドレス | ✅ | ✅ |
| `{{phone}}` | 電話番号 | ✅ | ✅ |
| `{{company}}` | 会社名 | ✅ | ✅ |
| `{{assignee}}` | 担当者名 | ✅ | ✅ |
| `{{assigneeEmail}}` | 担当者メール | ✅ | ✅ |
| `{{assigneePhone}}` | 担当者電話 | ✅ | ✅ |
| `{{date}}` | 現在日付 | ✅ | ✅ |
| `{{unsubscribeUrl}}` | 配信停止URL | ✅ | ✅ |
| `{{unsubscribeLink}}` | 配信停止HTMLリンク | ✅ | ✅ |

### 更新手順

1. **Frontend**: `crm-admin/src/types/index.ts` の `TEMPLATE_VARIABLES` を更新
2. **Backend**: `crm-backend/src/services/emailService.ts` の `getLeadVariables()` を更新
3. 両方をコミット＆プッシュ

### 関連ファイル

**Frontend (crm-admin)**:
- `src/types/index.ts` - TEMPLATE_VARIABLES 定義
- `src/components/email/EmailStepEditorDialog.tsx` - 変数ヒント表示
- `src/components/scenarios/StepEditDialog.tsx` - 変数ヒント表示
- `src/app/(dashboard)/email/auto-reply/page.tsx` - 変数ヒント表示

**Backend (crm-backend)**:
- `src/services/emailService.ts` - getLeadVariables(), replaceTemplateVariables()

---

## その他の共有定義

### セグメント定義

| セグメント | 説明 |
|-----------|------|
| `Hot` | 高温度リード |
| `Warm` / `Middle` | 中温度リード |
| `Cold` | 低温度リード |

### チャネル定義

| チャネル | 説明 |
|---------|------|
| `line` | LINE |
| `email` | メール |
| `web` | Web |

---

*最終更新: 2026-01-13*
