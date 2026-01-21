# メール配信フロー可視化ドキュメント

このドキュメントは、CRMシステムにおけるメール配信の全体像を可視化したものです。

## 配信システム概要

本システムには **3つの独立した配信メカニズム** が存在します。

| システム | 管理サービス | 用途 | トリガー |
|---------|-------------|------|----------|
| シナリオベース配信 | `scenarioService.ts` | A/B/Cシナリオ（温度感別ナーチャリング） | 時間経過 + 相談日基準 |
| セグメントベース配信 | `emailStepDeliveryService.ts` | Hot/Middle/Cold別ステップメール | 開封条件 + 時間経過 |
| 予約確認メール | `booking.ts` | 予約完了時の即座確認 | 予約完了イベント |

---

## 1. シナリオベース配信フロー

### 1.1 シナリオ遷移全体図

```mermaid
flowchart TB
    subgraph Entry["リード入口"]
        ML[メーリングリスト登録]
        ROI[ROIシミュレーション]
        CONSULT[無料相談申込]
        BOOKING[Web予約完了]
    end

    subgraph ScenarioC["シナリオC (Cold) - メルマガ登録者"]
        direction TB
        C1["C1: 登録直後<br/>共感・信頼構築"]
        C2["C2: 翌日<br/>失敗する理由"]
        C3["C3: 3日後<br/>他の選択肢の限界"]
        C4["C4: 5日後<br/>三位一体サポート"]
        C5["C5: 7日後<br/>オファー詳細"]
        C6["C6: 10日後<br/>導入事例"]
        C7["C7: 14日後<br/>理想の未来"]
        C8["C8: 21日後<br/>行動喚起"]
        C1 --> C2 --> C3 --> C4 --> C5 --> C6 --> C7 --> C8
    end

    subgraph ScenarioB["シナリオB (Warm) - ROIシミュレーション申込者"]
        direction TB
        B1["B1: 申込直後<br/>結果送付"]
        B2["B2: 翌日<br/>共感"]
        B3["B3: 3日後<br/>他の選択肢の限界"]
        B4["B4: 5日後<br/>三位一体"]
        B5["B5: 7日後<br/>オファー"]
        B1 --> B2 --> B3 --> B4 --> B5
    end

    subgraph ScenarioA["シナリオA (Hot) - 無料相談申込者"]
        direction TB
        A1["A1: 申込直後<br/>確認&準備"]
        A2["A2: 相談前日<br/>リマインド"]
        A3["A3: 相談当日朝<br/>最終リマインド"]
        A4["A4: 相談翌日<br/>フォローアップ"]
        A1 --> A2 --> A3 --> A4
    end

    ML --> C1
    ROI --> B1
    CONSULT --> A1
    BOOKING --> A1

    ScenarioC -.->|"ROIシミュレーター<br/>クリック"| B1
    ScenarioB -.->|"無料相談申込"| A1
    ScenarioC -.->|"無料相談申込"| A1

    style Entry fill:#e1f5fe
    style ScenarioC fill:#e3f2fd
    style ScenarioB fill:#fff3e0
    style ScenarioA fill:#ffebee
```

### 1.2 シナリオ詳細

#### シナリオA: 無料相談申込者向け（Hot）

| 通数 | タイミング | テーマ | 目的 |
|------|-----------|--------|------|
| A1 | 申込直後 | 確認&準備 | 商談のNo Show防止 |
| A2 | 相談前日 18:00 | リマインド&共感 | 期待値設定 |
| A3 | 相談当日 9:00 | 最終リマインド | 出席確認 |
| A4 | 相談翌日 10:00 | フォローアップ | 成約率UP |

**特徴**: 相談日基準で配信（`getLeadsForConsultationDelivery` で処理）

#### シナリオB: ROIシミュレーション申込者向け（Warm）

| 通数 | タイミング | テーマ | 目的 |
|------|-----------|--------|------|
| B1 | 申込直後 | 結果送付 | ROI結果の活用促進 |
| B2 | 24時間後 | 共感 | 数字→感情への橋渡し |
| B3 | 72時間後 | 他の選択肢の限界 | 差別化 |
| B4 | 120時間後 | 三位一体 | ソリューション説明 |
| B5 | 168時間後 | オファー | 相談への誘導 |

**特徴**: 申込からの経過時間で配信

#### シナリオC: メーリングリスト登録者向け（Cold）

| 通数 | タイミング | テーマ | 目的 |
|------|-----------|--------|------|
| C1 | 登録直後 | 共感・信頼構築 | ウェルカム |
| C2 | 24時間後 | 失敗する理由 | 問題提起 |
| C3 | 72時間後 | 他の選択肢の限界 | 差別化 |
| C4 | 120時間後 | 三位一体 | ソリューション説明 |
| C5 | 168時間後 | オファー詳細 | 具体的提案 |
| C6 | 240時間後 | 導入事例 | 社会的証明 |
| C7 | 336時間後 | 理想の未来 | ビジョン共有 |
| C8 | 504時間後 | 行動喚起 | CTA |

**特徴**: 最も長いシナリオ（教育が必要なため）

---

## 2. シナリオ遷移ルール

```mermaid
stateDiagram-v2
    [*] --> ScenarioC : メルマガ登録
    [*] --> ScenarioB : ROI試算申込
    [*] --> ScenarioA : 無料相談申込

    ScenarioC --> ScenarioB : ROIシミュレーター\nクリック
    ScenarioB --> ScenarioA : 無料相談申込
    ScenarioC --> ScenarioA : 無料相談申込

    ScenarioA --> Unsubscribed : 配信停止
    ScenarioB --> Unsubscribed : 配信停止
    ScenarioC --> Unsubscribed : 配信停止

    ScenarioA --> Completed : シナリオ完了
    ScenarioB --> Completed : シナリオ完了
    ScenarioC --> Completed : シナリオ完了

    note right of ScenarioA : 4通（相談日基準）
    note right of ScenarioB : 5通（時間経過）
    note right of ScenarioC : 8通（時間経過）
```

### 遷移時の処理

| イベント | 遷移元 | 遷移先 | 除外される配信 |
|---------|--------|--------|--------------|
| ROIシミュレータークリック | C | B | シナリオCから除外 |
| 無料相談申込 | B, C | A | シナリオB,Cから除外 |
| 配信停止 | A, B, C | null | 全シナリオから除外 |

---

## 3. セグメントベース配信フロー

シナリオベースとは別に、リードのセグメント（Hot/Middle/Cold）に基づく配信も存在します。

```mermaid
flowchart LR
    subgraph Cold["Cold セグメント"]
        CS1[Step 1] --> CS2[Step 2] --> CS3[Step 3]
    end

    subgraph Middle["Middle セグメント"]
        MS1[Step 1] --> MS2[Step 2]
        MS2 -->|開封した| MS2A[Step 2A<br/>エンゲージ高]
        MS2 -->|開封しない| MS2B[Step 2B<br/>再アプローチ]
    end

    subgraph Hot["Hot セグメント"]
        HS1[Step 1] --> HS2[Step 2] --> HS3[Step 3]
    end

    Cold -.->|昇格| Middle
    Middle -.->|昇格| Hot

    style Cold fill:#e3f2fd
    style Middle fill:#fff3e0
    style Hot fill:#ffebee
```

### セグメントベースの特徴

- **開封条件分岐**: 前のステップの開封有無で配信内容を変更
- **リード作成日基準**: `delay_days` で配信タイミングを制御
- **テンプレート管理**: `email_step_templates` テーブルで管理

---

## 4. 予約確認メール

予約完了時に即座に送信されるトランザクションメール。

```mermaid
sequenceDiagram
    participant User as ユーザー
    participant LP as LP/Web
    participant Backend as crm-backend
    participant Email as メールサービス

    User->>LP: 予約フォーム送信
    LP->>Backend: POST /api/booking
    Backend->>Backend: 予約データ保存
    Backend->>Backend: bookingEmailTemplate 生成
    Backend->>Email: 予約確認メール送信
    Email->>User: 予約確認メール到着
    Backend->>Backend: scenarioService.initializeLeadScenario(A)
    Note over Backend: シナリオAに登録され<br/>ステップメール配信開始
```

---

## 5. システム間の関係図

```mermaid
flowchart TB
    subgraph DataLayer["データベース層"]
        leads[(leads)]
        scenario_states[(lead_scenario_states)]
        step_templates[(email_step_templates)]
        delivery_logs[(scenario_delivery_logs)]
        email_steps[(lead_email_steps)]
    end

    subgraph ServiceLayer["サービス層"]
        scenarioSvc[scenarioService.ts]
        stepDeliverySvc[emailStepDeliveryService.ts]
        bookingSvc[booking.ts]
    end

    subgraph TriggerLayer["トリガー"]
        cron[定時バッチ]
        webhook[Webhook/API]
    end

    cron --> scenarioSvc
    cron --> stepDeliverySvc
    webhook --> bookingSvc

    scenarioSvc --> scenario_states
    scenarioSvc --> delivery_logs
    scenarioSvc --> leads

    stepDeliverySvc --> step_templates
    stepDeliverySvc --> email_steps
    stepDeliverySvc --> leads

    bookingSvc --> leads
    bookingSvc --> scenarioSvc

    style DataLayer fill:#f5f5f5
    style ServiceLayer fill:#e8f5e9
    style TriggerLayer fill:#fff8e1
```

---

## 6. 重要ファイル一覧

| ファイル | 役割 |
|---------|------|
| `crm-backend/src/services/scenarioService.ts` | シナリオ状態管理 |
| `crm-backend/src/services/scenarioDeliveryService.ts` | シナリオ配信実行 |
| `crm-backend/src/services/emailStepDeliveryService.ts` | セグメントベース配信 |
| `crm-backend/src/types/scenario.ts` | シナリオ定義 |
| `crm-backend/src/routes/booking.ts` | 予約処理 |
| `crm-backend/supabase/migrations/20260103_add_scenario_tables.sql` | DBスキーマ |

---

## 7. 運用上の注意点

### シナリオとセグメントの二重管理について

現在、以下の2つのシステムが並存しています：

1. **シナリオベース（A/B/C）**: 申込窓口に応じた温度感別のナーチャリング
2. **セグメントベース（Hot/Middle/Cold）**: エンゲージメントに基づく配信

**推奨**: 新規リードはシナリオベースで管理し、セグメントベースは既存リードの補完的配信に使用

### 配信停止時の挙動

- シナリオからの配信停止: `transitionScenario(leadId, 'unsubscribe')`
- 全メール配信停止: リードの `email_opt_in = false` に更新

---

*最終更新: 2026-01-11*
