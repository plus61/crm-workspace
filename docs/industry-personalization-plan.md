# 業界別メールパーソナライゼーション実装計画書

## 概要

LPフォームに業界選択項目を追加し、knowledge_seed RAGデータを活用して即時返信メールおよびステップメールに業界特化コンテンツを挿入する機能を実装する。

---

## 現状分析

### 現在のアーキテクチャ

```
[LP Form] → [API Route] → [crm-backend] → [SendGrid]
     ↓
  email, name, targetType, hasGroupCompanies
```

### 関連ファイル

| ファイル | 役割 |
|---------|------|
| `v0-modern-lp-design/components/contact-form.tsx` | LPフォームUI |
| `v0-modern-lp-design/app/api/leads/route.ts` | LP → Backend中継API |
| `crm-backend/src/services/emailService.ts` | メール送信・変数置換 |
| `crm-backend/src/services/emailStepDeliveryService.ts` | ステップメール配信 |
| `crm-backend/knowledge_seed/` | RAGナレッジベース（~287ファイル） |

### knowledge_seedの業界一覧（15業界）

- aesthetic（美容）
- b2b（BtoB）
- clinic（クリニック）
- construction（建設）
- ec（EC）
- edu（教育）
- hotel（ホテル）
- local（地域ビジネス）
- manufacturing（製造）
- profession（士業）
- real_estate（不動産）
- recruiting（人材）
- retail（小売）
- service（サービス）
- travel（旅行）

### コンテンツカテゴリ

- case_study（導入事例）
- faq（よくある質問）
- objection_handling（反論対応）
- roi（ROI試算）
- operation（運用方法）

---

## 実装タスク

### Task 1: LPフォームに業界選択追加

**難易度**: ★☆☆☆☆（簡単）
**作業時間目安**: 30分〜1時間

#### 変更ファイル
`v0-modern-lp-design/components/contact-form.tsx`

#### 実装内容

```tsx
// 業界選択肢の定義
const INDUSTRY_OPTIONS = [
  { value: "aesthetic", label: "美容・エステ" },
  { value: "b2b", label: "BtoB・法人向けサービス" },
  { value: "clinic", label: "クリニック・医療" },
  { value: "construction", label: "建設・土木" },
  { value: "ec", label: "EC・通販" },
  { value: "edu", label: "教育・スクール" },
  { value: "hotel", label: "ホテル・宿泊" },
  { value: "local", label: "地域密着ビジネス" },
  { value: "manufacturing", label: "製造業" },
  { value: "profession", label: "士業（税理士・弁護士等）" },
  { value: "real_estate", label: "不動産" },
  { value: "recruiting", label: "人材・採用" },
  { value: "retail", label: "小売・店舗" },
  { value: "service", label: "サービス業" },
  { value: "travel", label: "旅行・観光" },
  { value: "other", label: "その他" },
];

// フォームStateに追加
const [industry, setIndustry] = useState("");

// UI追加（Select/Dropdown）
<select
  value={industry}
  onChange={(e) => setIndustry(e.target.value)}
  required
>
  <option value="">業界を選択してください</option>
  {INDUSTRY_OPTIONS.map((opt) => (
    <option key={opt.value} value={opt.value}>{opt.label}</option>
  ))}
</select>
```

---

### Task 2: API経由でindustryを送信

**難易度**: ★☆☆☆☆（簡単）
**作業時間目安**: 15分

#### 変更ファイル
`v0-modern-lp-design/app/api/leads/route.ts`

#### 実装内容

```typescript
// リクエストボディから取得
const { email, name, targetType, groupCompanies, requestType, industry } = body

// payloadに追加
const payload: Record<string, unknown> = {
  email,
  name,
  projectKey: "dragon-keiei",
  targetType: targetType || "executive",
  sourceLp: "v0-dragon-keiei.vercel.app",
  channel: "exec_mail",
  hasGroupCompanies: groupCompaniesValue,
  industry: industry || null,  // ← 追加
}
```

---

### Task 3: 即時返信メールの業界パーソナライゼーション

**難易度**: ★★★☆☆（中程度）
**作業時間目安**: 2〜3時間

#### 処理フロー

```
[Lead登録]
    ↓
[industry取得] → manufacturing
    ↓
[knowledge_seedから取得]
  ├─ manufacturing_case_study_001.md → 事例コンテンツ
  └─ manufacturing_roi_001.md → ROI試算
    ↓
[テンプレート変数置換]
  {{industry_case_study}} → 製造業の事例文
  {{industry_roi_example}} → 製造業のROI例
    ↓
[パーソナライズされたメール送信]
```

#### 実装ファイル

**新規作成**: `crm-backend/src/services/knowledgeSeedService.ts`

```typescript
import fs from 'fs';
import path from 'path';
import matter from 'gray-matter';

const KNOWLEDGE_SEED_PATH = path.join(__dirname, '../../knowledge_seed');

interface KnowledgeContent {
  title: string;
  content: string;
  category: string;
  industry: string;
}

/**
 * 業界・カテゴリでナレッジを取得
 */
export async function getKnowledgeByIndustry(
  industry: string,
  category: 'case_study' | 'faq' | 'objection_handling' | 'roi' | 'operation'
): Promise<KnowledgeContent | null> {
  const pattern = `${industry}_${category}_`;
  const files = fs.readdirSync(KNOWLEDGE_SEED_PATH);

  const matchingFile = files.find(f => f.startsWith(pattern) && f.endsWith('.md'));
  if (!matchingFile) return null;

  const filePath = path.join(KNOWLEDGE_SEED_PATH, matchingFile);
  const fileContent = fs.readFileSync(filePath, 'utf-8');
  const { data, content } = matter(fileContent);

  return {
    title: data.title || '',
    content: content.trim(),
    category: data.category,
    industry: data.industry,
  };
}

/**
 * 即時返信用の変数セットを生成
 */
export async function getImmediateReplyVariables(
  industry: string
): Promise<Record<string, string>> {
  const variables: Record<string, string> = {};

  // 事例を取得
  const caseStudy = await getKnowledgeByIndustry(industry, 'case_study');
  if (caseStudy) {
    variables.industry_case_study = caseStudy.content;
    variables.industry_case_title = caseStudy.title;
  }

  // ROI例を取得
  const roi = await getKnowledgeByIndustry(industry, 'roi');
  if (roi) {
    variables.industry_roi_example = roi.content;
  }

  return variables;
}
```

#### 変更ファイル
`crm-backend/src/services/emailService.ts`

```typescript
import { getImmediateReplyVariables } from './knowledgeSeedService';

// sendEmail関数内で業界変数を追加
export async function sendEmail(options: EmailOptions): Promise<SendEmailResult> {
  // ... 既存コード ...

  // 業界パーソナライゼーション変数を取得
  let industryVariables: Record<string, string> = {};
  if (options.industry && options.industry !== 'other') {
    industryVariables = await getImmediateReplyVariables(options.industry);
  }

  // 変数をマージして置換
  const allVariables = {
    ...options.variables,
    ...industryVariables,
    name: options.recipientName || '',
  };

  const personalizedBody = replaceTemplateVariables(options.body, allVariables);
  // ...
}
```

#### テンプレート例

```
{{name}}様

お問い合わせありがとうございます。

{{#if industry_case_study}}
【{{industry_case_title}}】
{{industry_case_study}}
{{/if}}

{{#if industry_roi_example}}
【期待できる効果】
{{industry_roi_example}}
{{/if}}

詳しいご説明をさせていただければと存じます。
```

---

### Task 4: ステップメールの業界パーソナライゼーション

**難易度**: ★★★☆☆（中程度）
**作業時間目安**: 2〜3時間

#### 処理フロー

```
[ステップメール配信トリガー]
    ↓
[Lead情報取得] → industry: manufacturing
    ↓
[email_step_templatesから取得]
  subject: "{{industry_name}}における課題解決のご提案"
  body: "... {{industry_faq}} ..."
    ↓
[knowledge_seedから取得]
  manufacturing_faq_001.md → FAQ内容
    ↓
[変数置換 & 送信]
```

#### 変更ファイル
`crm-backend/src/services/emailStepDeliveryService.ts`

```typescript
import { getStepEmailVariables } from './knowledgeSeedService';

// executeEmailStepDelivery関数内

// リード情報にindustryを含める
const { data: leads, error: leadsError } = await supabase
  .from('leads')
  .select('id, project_id, email, display_name, initial_segment, status, email_opt_in, created_at, industry')  // ← industry追加
  .eq('project_id', projectId)
  .eq('status', 'active')
  .eq('email_opt_in', true)
  .not('email', 'is', null);

// 送信時に業界変数を取得
const industryVariables = lead.industry
  ? await getStepEmailVariables(lead.industry, nextStep)
  : {};

const allVariables = {
  name: lead.display_name || '',
  ...industryVariables,
};

const personalizedSubject = replaceTemplateVariables(
  selectedTemplate.subject,
  allVariables
);
const personalizedBody = replaceTemplateVariables(
  selectedTemplate.body,
  allVariables
);
```

#### knowledgeSeedService.tsに追加

```typescript
/**
 * ステップメール用の変数セットを生成
 * ステップ番号に応じて異なるカテゴリのコンテンツを使用
 */
export async function getStepEmailVariables(
  industry: string,
  stepNumber: number
): Promise<Record<string, string>> {
  const variables: Record<string, string> = {};

  // ステップ番号に応じたカテゴリマッピング
  const categoryByStep: Record<number, string> = {
    1: 'case_study',      // Step1: 事例紹介
    2: 'roi',             // Step2: ROI・効果
    3: 'faq',             // Step3: よくある質問
    4: 'objection_handling', // Step4: 懸念点解消
    5: 'operation',       // Step5: 導入・運用方法
  };

  const category = categoryByStep[stepNumber] || 'case_study';
  const content = await getKnowledgeByIndustry(industry, category as any);

  if (content) {
    variables[`industry_${category}`] = content.content;
    variables[`industry_${category}_title`] = content.title;
  }

  // 業界名（日本語）
  variables.industry_name = INDUSTRY_LABELS[industry] || industry;

  return variables;
}

const INDUSTRY_LABELS: Record<string, string> = {
  aesthetic: '美容・エステ業界',
  b2b: 'BtoB業界',
  clinic: 'クリニック・医療業界',
  construction: '建設業界',
  ec: 'EC・通販業界',
  edu: '教育業界',
  hotel: 'ホテル・宿泊業界',
  local: '地域ビジネス',
  manufacturing: '製造業界',
  profession: '士業',
  real_estate: '不動産業界',
  recruiting: '人材業界',
  retail: '小売業界',
  service: 'サービス業界',
  travel: '旅行・観光業界',
};
```

---

## データベース変更

### leadsテーブルにindustryカラム追加

```sql
-- Migration: add_industry_to_leads
ALTER TABLE leads
ADD COLUMN industry VARCHAR(50) DEFAULT NULL;

-- インデックス追加（検索用）
CREATE INDEX idx_leads_industry ON leads(industry);

COMMENT ON COLUMN leads.industry IS '業界コード（knowledge_seedと対応）';
```

---

## 実装順序

```
Phase 1: フロントエンド（Task 1, 2）
├─ contact-form.tsx に業界選択追加
├─ api/leads/route.ts でindustry送信
└─ 動作確認

Phase 2: バックエンド基盤（新規サービス）
├─ knowledgeSeedService.ts 作成
├─ gray-matter パッケージ追加
└─ 単体テスト

Phase 3: DBマイグレーション
├─ leads.industry カラム追加
└─ 既存データ対応（NULL許容）

Phase 4: 即時返信メール（Task 3）
├─ emailService.ts 改修
├─ テンプレート変数追加
└─ E2Eテスト

Phase 5: ステップメール（Task 4）
├─ emailStepDeliveryService.ts 改修
├─ email_step_templates 更新
└─ 配信テスト
```

---

## テスト計画

### 単体テスト

- [ ] knowledgeSeedService: 業界・カテゴリ別取得
- [ ] replaceTemplateVariables: 新変数の置換
- [ ] getStepEmailVariables: ステップ別カテゴリマッピング

### 統合テスト

- [ ] LP → Backend → DB保存フロー
- [ ] 即時返信メールの変数置換
- [ ] ステップメール配信の変数置換

### E2Eテスト

- [ ] フォーム送信〜メール受信の完全フロー
- [ ] 各業界でのコンテンツ出し分け確認
- [ ] 「その他」選択時のフォールバック

---

## 注意事項

1. **knowledge_seedの充実度確認**: 全15業界×5カテゴリのコンテンツが揃っているか事前確認
2. **フォールバック処理**: 該当コンテンツがない場合は汎用テキストを使用
3. **パフォーマンス**: ファイル読み込みのキャッシュ検討（頻繁アクセス時）
4. **テンプレート管理**: 変数名の命名規則を統一

---

## 見積もり総括

| タスク | 難易度 | 工数目安 |
|--------|--------|----------|
| Task 1: フォームUI | ★☆☆☆☆ | 30分〜1時間 |
| Task 2: API追加 | ★☆☆☆☆ | 15分 |
| Task 3: 即時返信 | ★★★☆☆ | 2〜3時間 |
| Task 4: ステップメール | ★★★☆☆ | 2〜3時間 |
| DB Migration | ★☆☆☆☆ | 15分 |
| テスト・検証 | ★★☆☆☆ | 1〜2時間 |
| **合計** | | **6〜10時間** |

---

*作成日: 2025年1月*
*対象プロジェクト: crm-workspace*
