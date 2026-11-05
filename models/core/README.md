# core

The dimensional model: the business data, ready for analysis. Tables with enforced contracts.

**Reads from:** `ods_`, the seed and other core models. **Read by:** `rep_`.

**Rules:** one declared grain per model, and each rule in one place. No report logic, and no labels for a single report. A row leaves accepted data only for a broken key, and it stays here with its `dq_reason`.

| Model | Grain | Why it exists |
|---|---|---|
| `dim_deal` | One row per accepted deal | Pivots the key/value log into the business view of a deal |
| `dim_deal_owner` | One row per accepted deal and ownership period | The history of who owned a deal |
| `dim_user` | One row per user | Users without emails, with a shared email flag |
| `dim_stage` | One row per stage | Stages with the required labels |
| `dim_activity_type` | One row per type | Marks the two sales calls |
| `dim_month` | One row per month | Reporting months, independent of accepted data |
| `fct_deal_change` | One row per field change, all rows | Flags broken deal identity in one place |
| `fct_activity` | One row per activity row, all rows | Flags repeated activity IDs in one place |
| `fct_deal_stage_entry` | One row per deal, stage and entry | The movement logic: every stage entered, skipped stages filled |
| `fct_deal_stage_month_end` | One row per open deal and month end | The position logic: where open deals sit at month end |

AI tools full disclosure: Codex and Claude Code were used.
