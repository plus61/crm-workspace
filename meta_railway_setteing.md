# Claude Code投入用プロンプト（Meta Webhook / Railway 疎通トラブル対応版）

あなたは Claude Code です。以下の状況を前提に、**Railway上でMeta Webhook（Page/leadgen）の検証が通る最小実装**を完成させてください。質問で止まらず、MVPとして最も単純な選択で進めてください。

---

## 1. 現状（重要）

- Meta for Developers 側の設定を進めているが、Callback URL にアクセスすると **Railwayの 404 Not Found（The train has not arrived at the station）** が出る。
- つまり **Railwayドメインが未プロビジョニング** か、**Webhookエンドポイントが未デプロイ**、または **ルーティングが存在しない**。
- Meta Webhooks（Page subscription）の保存には、Callback URLに対して **GET検証（hub.challenge）** が必須。
- 目的は「Meta側でleadgenをSubscribeできる状態」＝ **Callback URLが必ず200を返す状態**を作ること。

---

## 2. 目標（Acceptance Criteria）

以下が満たされること：

1. `GET /api/webhook/meta` が外部から到達可能（Railwayの公開URLで）  
2. Meta検証形式に対応し、`hub.verify_token` が一致したら **200 + hub.challenge** を返す  
3. `POST /api/webhook/meta` が常に **200** を返す（Meta再送抑制）  
4. `POST` は raw body を保持し、署名検証（X-Hub-Signature-256）に備えた構造にする（実装はMVPで可）  
5. Railwayでドメインが有効化され、URLアクセスで404が出ない（＝プロビジョニング完了）  
6. `.env.example` と README に **Meta側設定手順（Callback/Verify token）** を記載

---

## 3. 前提技術（自由に採用してよい）

- Node.js 18+ / TypeScript
- Express か Next.js API Routes のどちらでも可（迷ったら Express）
- Railwayにデプロイしやすい構成（Start command / Port対応）

---

## 4. 実装要件（具体）

### 4.1 エンドポイント

#### A) GET /api/webhook/meta（Meta検証用）

- 入力：Query
  - `hub.mode`
  - `hub.verify_token`
  - `hub.challenge`

- 仕様：
  - `hub.verify_token` が `process.env.META_WEBHOOK_VERIFY_TOKEN` と一致し、かつ `hub.mode === "subscribe"` のとき  
    → `200` で `hub.challenge` を **本文そのまま返す**
  - 一致しない場合 → `403`

#### B) POST /api/webhook/meta（イベント受信）

- 仕様：
  - 常に `200` を返す（本文は `EVENT_RECEIVED` など）
  - request body はログに出すが、PII（email/phone）をそのままログに出しすぎない（マスク推奨）
  - raw body を保持できるように middleware を設定（署名検証のため）
  - 署名検証（X-Hub-Signature-256）の関数だけ用意（MVPで検証ON/OFF切替可）

---

## 5. Railway要件（最重要）

- `PORT` 環境変数に対応して listen する
- `GET /` にも 200 を返すヘルスチェックを追加（Railway疎通確認用）
- READMEに「Railwayで Domain が provisioned されているか確認する方法」を書く
- デプロイ後、以下URLが200になることを想定：
  - `https://<railway-domain>.up.railway.app/` → 200
  - `https://<railway-domain>.up.railway.app/api/webhook/meta?hub.mode=subscribe&hub.verify_token=XXX&hub.challenge=123` → 200で `123`

---

## 6. 生成すべき成果物

- `src/server.ts`（Expressの場合）または `app/api/webhook/meta/route.ts`（Nextの場合）
- `.env.example`
- `README.md`（下記含む）
  - ローカル起動手順
  - Railwayデプロイ手順
  - 動作確認（curl例）
  - Meta側Webhook設定手順（Callback URL / Verify Token / leadgenチェック）

---

## 7. 動作確認（READMEに必ず書く）

### 7.1 GET検証（ローカル/本番）
例：

```bash
curl -i "http://localhost:3000/api/webhook/meta?hub.mode=subscribe&hub.verify_token=TESTTOKEN&hub.challenge=123"

期待：
	•	200
	•	body: 123

7.2 POST受信
curl -i -X POST "http://localhost:3000/api/webhook/meta" \
  -H "Content-Type: application/json" \
  -d '{"object":"page","entry":[{"changes":[{"field":"leadgen","value":{"leadgen_id":"123"}}]}]}'

 期待：
	•	200
	•	body: EVENT_RECEIVED

⸻

8. 実装方針（必須）
	•	質問で止まらない
	•	最短で「Meta検証が通る」ことを最優先
	•	Not Found（Railway 404）を解消するため、GET / のヘルスチェックも必ず実装
	•	ルーティングが確実に当たるよう、Expressなら app.use("/api/webhook/meta", ...)、Nextなら route.ts を正しいディレクトリに置く

⸻

9. 最終出力

このプロンプトに従い、必要ファイルを作成し、READMEの手順で誰でも再現できる状態にして提示してください。

