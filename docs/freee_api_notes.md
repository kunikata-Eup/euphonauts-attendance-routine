# freee API 調査メモ（勤怠コンプライアンスチェック用）

このファイルが存在する場合、次回実行時はエンドポイント調査をスキップしてよい
（この内容をそのまま使う）。

## 調査日
2026-07-04（初回実行時。認証切れで途中停止し、再認証後に再開して検証完了）

## 結論：全社一括で取得できる勤怠CSV/レポートAPIは存在しない

`freee_api_list_paths` で freee人事労務API (`https://api.freee.co.jp/hr`) の
全エンドポイントを確認したが、全従業員分をまとめて返す「一括勤怠出力」
「勤怠レポート」「CSV一括ダウンロード」に相当するエンドポイントは存在しない。
（freee会計側には `/api/1/reports/*` があるが、これは会計帳票用で勤怠とは無関係）

→ 個別従業員ごとに取得する方式（フェーズ1のステップ2〜4）を使うしかない。

## 使用するエンドポイント（確定版）

| 用途 | メソッド・パス | 備考 |
|---|---|---|
| 従業員一覧（全社まとめて1回で取得可） | `GET /api/v1/companies/{company_id}/employees` | 在職中(`retire_date: null`)で絞り込み、除外対象4名をここでフィルタ |
| 月次サマリー＋日次明細（1回で両方取得） | `GET /api/v1/employees/{employee_id}/work_record_summaries/{year}/{month}?company_id={company_id}&work_records=true` | 下記の注意点を必ず守ること |

`time_clocks` や単日の `work_records/{date}` は不要（下記「不要と判明」参照）。

## 【最重要・注意点1】`company_id` はクエリパラメータに必須

`company_id` をクエリに付けないと `403 forbidden` になる（事業所コンテキストの自動解決に
失敗するため）。必ず `query: { company_id: 10700252, ... }` を明示すること。
（前回実行時の403エラーの原因はこれだった。401 expired_access_tokenは別問題＝トークン失効で、
再認証により解消済み。）

## 【最重要・注意点2】`{month}` パラメータは「暦月+1」を指定する

`{month}` は実労働月ではなく、支給月（`closing_day=31`, `month_of_pay_day=next_month` の設定に
対応する値）。検証の結果、**暦月Mの実労働データを取得するには `{month}=M+1` を指定する**。

例：2026年7月の実労働データが欲しい場合 → `.../work_record_summaries/2026/8` をリクエストする。
`.../2026/7` をリクエストすると2026年6月分が返ってくる。

全従業員が同じ `closing_day: 31` / `month_of_pay_day: next_month` 設定（`/employees` 一覧で確認済み）
なので、このオフセットは全従業員共通と考えてよい。

## 【最重要・注意点3】`work_records=true` で日次明細＋月次サマリーが1回で取れる

`work_records=true` を付けると、レスポンスに月次サマリー(`total_work_mins`,
`total_excess_statutory_work_mins`, `num_paid_holidays`, `num_paid_holidays_left` 等)と、
その月全日分の日次明細配列 `work_records[]`（各日の `clock_in_at`/`clock_out_at`/
`break_records`/`day_pattern`/`note` 等）が **両方** 含まれる。

→ 日次データ取得と月次サマリー取得を別々のAPIコールにする必要はない。常に
`work_records=true` を付けて1回呼べば両方まかなえる。これによりフェーズ1の想定コール数
（1人あたり最大3回）は実質「前月分1回＋当月分1回＝2回」に削減できる
（前月分が不要な週＝実行日が月の8日目以降の週は当月分1回のみでよい）。

未来日（まだ到来していない日）は `clock_in_at`/`clock_out_at` が `null` のまま所定パターンで
返ってくる（＝欠勤ではなく単に「まだ勤務していない」）。打刻漏れ判定では実行日より前の日付のみを
対象にすること。

## 不要と判明したエンドポイント
- `GET /api/v1/employees/{id}/time_clocks` → 従業員によっては「タイムレコーダー機能がオフに
  なっています」(400)で使えない。`work_record_summaries?work_records=true` で日次の打刻時刻は
  取得できるため、このエンドポイントは使わない。
- `GET /api/v1/employees/{id}/work_records/{date}`（単日）→ 上記の月次まとめ取得で代替できるため
  使わない。

## 対象外従業員（管理者・専任担当者として除外）
- 國方翔冴（employee_id: 1928011）
- 飯村拓也（employee_id: 2351330）
- 関口雄大（employee_id: 2028494）
- 川上貴大（employee_id: 1986285）

## テスト対象5名（在職中・上記除外後の先頭5件、`/employees` のAPI返却順）
1. 小川陽暉（1943218）
2. 田中大地（1943221）
3. 野口智哉（1943222）
4. 髙野悠星（1986176）
5. 紺野将人（1986181）
