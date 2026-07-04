# freee API 調査メモ（勤怠コンプライアンスチェック用）

このファイルが存在する場合、次回実行時はエンドポイント調査をスキップしてよい
（この内容をそのまま使う）。

## 調査日
2026-07-04（初回実行時）

## 結論：全社一括で取得できる勤怠CSV/レポートAPIは存在しない

`freee_api_list_paths` で freee人事労務API (`https://api.freee.co.jp/hr`) の
全エンドポイントを確認したが、全従業員分をまとめて返す「一括勤怠出力」
「勤怠レポート」「CSV一括ダウンロード」に相当するエンドポイントは存在しない。
（freee会計側には `/api/1/reports/*` があるが、これは会計帳票用で勤怠とは無関係）

→ 個別従業員ごとに取得する方式（フェーズ1のステップ2〜4）を使うしかない。

## 使用するエンドポイント

| 用途 | メソッド・パス | 備考 |
|---|---|---|
| 従業員一覧（全社まとめて1回で取得可） | `GET /api/v1/companies/{company_id}/employees` | 在職中(`retire_date: null`)で絞り込み、除外対象4名をここでフィルタ |
| 月次サマリー＋当月日次明細 | `GET /api/v1/employees/{employee_id}/work_record_summaries/{year}/{month}` | `work_records=true` クエリを付けると当該月の日次内訳込みで1回のリクエストで取得できる想定（要・再検証。下記「未検証事項」参照） |
| 個別日の打刻詳細 | `GET /api/v1/employees/{employee_id}/work_records/{date}` | この1エンドポイントのみ `company_id` をクエリパラメータで明示要求された（他は事業所コンテキストから自動解決される中で例外的挙動。要再検証） |
| 打刻一覧（time_clocks） | `GET /api/v1/employees/{employee_id}/time_clocks` | 出退勤の打刻ログ。日付範囲パラメータの有無は未検証 |

## 未検証事項（認証エラーのため確認できず。次回実行時に要検証）

2026-07-04の実行では、従業員一覧取得（`/employees`）は成功したが、その直後に
以下の個別従業員エンドポイントを呼んだところ、一貫して **認証エラー** が発生し、
挙動を確認できなかった:

- `GET /api/v1/employees/{id}/work_record_summaries/{year}/{month}`（`work_records=true`有無どちらも） → 403 forbidden
- `GET /api/v1/employees/{id}/time_clocks/available_types` → 403 forbidden（自分自身の従業員IDでも同様）
- `GET /api/v1/employees/{id}/work_records/{date}` → 400（`company_id` 未指定エラー。再試行時は company_id をクエリに追加すること）
- `GET /api/v1/groups` → **401 expired_access_token**（`freee_auth_status` は「有効」と表示されていたにもかかわらず、実際のAPI呼び出しはトークン期限切れで拒否された）

途中から401 expired_access_tokenが再現するようになったため、これは個別エンドポイントの
権限不足ではなく、**freee連携のアクセストークンが実行中に期限切れになった**ことが原因の
可能性が高い。次回実行時、再認証後にあらためて上記エンドポイントの挙動（特に
`work_records=true`で日次明細が本当に含まれるか、`time_clocks`の日付範囲パラメータ名）
を確認し、このメモを更新すること。

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
