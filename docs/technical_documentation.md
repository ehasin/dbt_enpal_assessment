# Technical documentation

> Documentation note: the documentation in this repository was written with AI assistance.

For engineers. Every number here comes from a saved query in `analyses/`. `docs/methodology_and_assumptions.md` explains the decisions.

## 1. Architecture and lineage

```
raw (public)                 source tables, loaded unchanged
  |
ods_pipedrive__*             views: types, names, exact-row dedup
  |
core                         tables
  dim_user, dim_stage, dim_activity_type, dim_month
  fct_deal_change, fct_activity             <- every row, with dq_reason
  dim_deal_owner, dim_deal, fct_deal_stage_entry,
  fct_deal_stage_month_end                  <- accepted rows
  |
rep_records_for_review       flagged rows, one shape
rep_data_quality_checks      all check results
  | gate: any failed check, the next three don't build
rep_sales_funnel_monthly             the required report, stages and calls meet here
rep_deal_stage_distribution_monthly  the month-end report
rep_deal_last_owner                  the last owner report
  | output comparison: every month and funnel step against an independent recount,
  | and every deal and column of the last owner report against the change log
```

`dbt docs generate && dbt docs serve` shows the full lineage.

## 2. Layers

| Layer | Folder | Schema | Stored as | Reads | Does | Never does |
|---|---|---|---|---|---|---|
| raw | `raw_data/`, `init.sql` | `public` | Tables | | Holds data as loaded | Changes |
| `ods_` | `models/ods/pipedrive/` | `public_pipedrive_ods` | Views | Sources | Casts, renames, drops exact duplicate rows | Business rules, filters |
| core | `models/core/` | `public_pipedrive_core` | Tables | `ods_`, seed, core | Business entities and events at a declared grain | Report logic |
| `rep_` | `models/reporting/` | `public_pipedrive_analytics` | Tables | Core, seed | Serves consumers | Holds rules |

`rep_data_quality_checks` is the one exception on what it reads, because it has to see every layer. The failing rows of the gate and the output comparison are kept in `public_pipedrive_audit`.

**Names:** `ods_pipedrive__<table>`, `dim_<entity>`, `fct_<event>`, `rep_<purpose>`.

## 3. Models

| Model | Grain | Key | Why it exists |
|---|---|---|---|
| `ods_pipedrive__deal_changes` | One row per recorded field change | All four columns | Typed log behind every deal fact |
| `ods_pipedrive__activity` | One row per distinct activity row | All six columns | Typed activities |
| `ods_pipedrive__users` | One row per user | `user_id` | Typed users. Emails stop here |
| `ods_pipedrive__stages` | One row per stage | `stage_id` | Typed stages |
| `ods_pipedrive__activity_types` | One row per type | `activity_type_id` | The source's link between `meeting` and Sales Call 1 |
| `ods_pipedrive__fields` | One row per field | `field_id` | Source of lost reason labels |
| `dim_deal` | One row per accepted deal | `deal_id` | Pivots the key/value log into the business view of a deal |
| `dim_deal_owner` | One row per accepted deal and ownership period | `deal_id`, `valid_from` | The history of who owned a deal |
| `dim_user` | One row per user | `user_id` | Users without emails |
| `dim_stage` | One row per stage | `stage_id` | Stages with the required labels |
| `dim_activity_type` | One row per type | `activity_type` | Marks the two sales calls |
| `dim_month` | One row per month | `month` | Reporting months, independent of accepted data |
| `fct_deal_change` | One row per field change, all rows | `deal_id`, `changed_field`, `changed_at`, `new_value` | Flags broken deal identity in one place |
| `fct_activity` | One row per activity row, all rows | None: flagged IDs repeat | Flags repeated activity IDs in one place |
| `fct_deal_stage_entry` | One row per deal, stage and entry | `deal_id`, `stage_id`, `entered_at` | The movement logic |
| `fct_deal_stage_month_end` | One row per open deal and month end | `deal_id`, `month` | The position logic |
| `rep_sales_funnel_monthly` | One row per month and funnel step | `month`, `funnel_step` | The required report |
| `rep_deal_stage_distribution_monthly` | One row per month and deal stage | `month`, `funnel_step` | The month-end report |
| `rep_deal_last_owner` | One row per accepted deal | `deal_id` | The last owner report |
| `rep_data_quality_checks` | One row per check and month | `check_name`, `month` | All check results, and the publish gate |
| `rep_records_for_review` | One row per flagged record | `record_key` | Every excluded record, with its reason |

The seed `funnel_steps` lists the 11 funnel steps in the required order and wording. A deal stage carries its `stage_id`. A sales call matches its name in `activity_types`, so `meeting` as Sales Call 1 comes from the source's own table.

## 4. Facts and dimensions

| Fact | Type | Notes |
|---|---|---|
| `fct_deal_change` | Transaction | All rows, with `dq_reason`. Two values of a field can share a timestamp, so `new_value` is part of the key |
| `fct_activity` | Transaction | All rows, with `dq_reason`. `has_deal_history` is information only |
| `fct_deal_stage_entry` | Transaction | Accepted rows. `is_skipped_stage` marks stages a deal passed |
| `fct_deal_stage_month_end` | Periodic snapshot | Accepted rows. Open deals only |

**How skipped stages work.** A forward move from stage `p` to `s` creates an entry for every stage from `p + 1` to `s`, at the time of the move. Entries below `s` carry `is_skipped_stage = true`.

**Edge cases,** each with a unit test:

| Case | Rule |
|---|---|
| First stage row of a deal | An entry for that stage only |
| Move to a lower stage | An entry for that stage only. Earlier entries stand |
| Same stage again | A new entry for that stage |
| Stage rows on one timestamp | Ordered by stage, lowest first. An assumed sequence, not an observed one. The same order sets `current_stage_id` and the month-end position. This data has no such ties |

**How month-end position works.** A deal sits in the last stage recorded by month end, until it gets a lost reason. Skipped stages are passed, never held. The time of the earliest lost reason stands in for the loss time. Every month, including the last, is read at its calendar month end.

`deal_status` in `dim_deal` is derived: `lost` with a lost reason, otherwise `open`.

**How owner history works.** `dim_deal_owner` is a type 2 history: one row per deal and period of ownership. It reads the change log, which keeps every owner, so it needs no dbt snapshot. A period includes `valid_from` and excludes `valid_to`, which is empty for the current owner. To find the owner at a point in time, join on `event_at >= valid_from and (event_at < valid_to or valid_to is null)`.

- Repeated rows for one owner stay one period, and an owner who returns starts a new one.
- Owner rows on one timestamp leave the highest ID. This data has no such ties.
- A deal has no recorded owner before its first owner row.
- `dim_deal.owner_user_id` reads the current row, so the rule has one home.
- Changes to a user's own details aren't tracked: `users` holds one version per user, so that history can only start when a snapshot does.

**On this data:** 1,494 deals have one owner, 496 have two, and none has more. No owner change falls after a deal's first stage, so the last owner also held every stage. Saved query: `analyses/sql/owner_history.sql`.

## 5. Report construction

`rep_sales_funnel_monthly`, step by step:

1. **Stage counts:** distinct deals per month and stage from `fct_deal_stage_entry`, labelled through `dim_stage`.
2. **Call counts:** distinct deal IDs per due month from accepted, done rows of `fct_activity`, for activity types marked as sales calls. There's no join to deals.
3. **Union** the two, on the funnel step name.
4. **Grid:** `dim_month` crossed with the seed, so every month and funnel step has a row, and an empty cell shows `0`.

`rep_deal_stage_distribution_monthly` counts `fct_deal_stage_month_end` on the same grid, for deal stages only.

Each tricky part has one home:

| Tricky part | Where |
|---|---|
| Key/value change log | `dim_deal`, `fct_deal_stage_entry` |
| Skipped stages | `fct_deal_stage_entry` |
| Month-end position | `fct_deal_stage_month_end` |
| Who owned a deal, and when | `dim_deal_owner` |
| Broken deal identity and activity IDs | `fct_deal_change`, `fct_activity` |
| Stages and calls meeting in one report | `rep_sales_funnel_monthly` |
| Empty months and funnel steps | `dim_month` crossed with the seed |
| Protecting the published reports | Section 6 |

## 6. Data quality

### Flags

`ods_` collapses exact duplicate rows first. Then a row leaves accepted data only for a broken key. It stays in core with its `dq_reason`, and `rep_records_for_review` lists it with a hash of the whole row as `record_key`, because `activity_id` repeats there and `deal_changes` has no ID.

| `dq_reason` | Rule | On this data |
|---|---|---|
| `multiple_deal_creations` | All rows of a deal with more than one `add_time` row | 5 deals, 80 rows |
| `duplicate_activity_id` | All rows of an activity ID still appearing more than once | 11 IDs, 22 rows, 5 of them done sales calls |

### Known oddities

Kept in, each with a `severity: warn` test tagged `extract_specific` where shown. These are facts about this data, kept apart from reusable rules.

| Oddity | On this data | Test |
|---|---|---|
| Stages skipped | 4,143 filled entries | `warn_deals_skip_stages` |
| Lost reason after entering Implementation | 1,076 deals | `warn_lost_reason_after_entering_implementation` |
| Sales Call 2 with no earlier Sales Call 1 | 1,115 of 1,115 rows | `warn_sales_call_2_without_earlier_sales_call_1` |
| Stage name differs from the required label | 1 stage | `warn_stage_label_differs_from_required` |
| Users sharing an email | 8 users | `warn_users_share_an_email` |
| Calls with few matching deal IDs | 8 of 4,572 deal IDs, against about 10 for shuffled IDs | None: `has_deal_history` shows it |
| Stage 1 later than deal creation | 1,990 deals, a median 35 days | None: `stage_timing.sql` shows it |

### Gates

| Gate | Where | Stops | Catches |
|---|---|---|---|
| Load | `load_data.sh` and the run command | The load, and dbt | Copy errors, partial loads. All tables are replaced in one transaction |
| Source tests | `dbt build` | Dependent models | Empty tables, missing IDs, unknown stages or activity types |
| Unit tests | `dbt build` | That model | Wrong logic, including rules this data never triggers |
| Contracts | Core and `rep_` | That model | Wrong columns or types, including a fifth column |
| Publish gate | `assert_no_failed_quality_checks` | All three output reports | Any `fail` row in `rep_data_quality_checks` |
| Output comparison | `assert_sales_funnel_matches_recount`, `assert_stage_distribution_matches_recount`, `assert_last_owner_matches_change_log` | The build, visibly. The report is already replaced | A wrong filter, aggregation, seed join or mapping in a report |

**How the publish gate works.** All three output reports declare `-- depends_on: {{ ref('rep_data_quality_checks') }}`, so a failed test on that table makes `dbt build` skip them, and the last published tables stay in place.

**Limits.** Core rebuilds before the gate, so the gate protects the three reports, not core. When its dependencies succeed, `rep_data_quality_checks` records the failure. Earlier source or model failures show in the dbt logs and run results, and the stored table may be from the last successful build. The output comparison runs after a report builds, so it flags a wrong report but can't hold it back: unit tests and contracts are what stop one before it builds.

### Checks in `rep_data_quality_checks`

Expected values come from `ods_` or fixed lists, never from accepted data alone.

| Check | Compares | Failing means |
|---|---|---|
| `raw_tables_loaded` | Each source has rows | Fail |
| `exact_duplicates_in_raw` | Raw rows against `ods_` rows | Warn: the reports stay correct |
| `stage_row_acceptance_rate` | Accepted share of stage rows, at least 0.95 | Fail |
| `sales_call_acceptance_rate` | Accepted share of sales call rows, at least 0.95 | Fail |
| `accepted_plus_review_balances` | Accepted plus flagged rows against `ods_` rows | Fail |
| `accepted_data_in_every_month` | Each month with source rows has accepted rows, per source | Fail |
| `funnel_steps_complete` | The seed against a fixed list of the required funnel steps | Fail |
| `stage_steps_reconcile` | Core counts against a recount from `ods_`, per month and stage | Fail |
| `call_steps_reconcile` | Core counts against a recount from `ods_`, per month and call | Fail |
| `unmapped_stage` | Stage values with no funnel step | Fail |
| `unmapped_activity_type` | Unknown activity types, and sales calls with no activity type | Fail |
| `stage_coverage` | Rows and the last observed date, per month | Warn |
| `activity_coverage` | Same | Warn |

The thresholds are in `dbt_project.yml`. With no rows to measure, a rate fails. A month with no observed calls passes `accepted_data_in_every_month`, and a month that lost them all fails.

**Coverage on this data:** observed activity records end on 13 September 2024, and observed stage records on 24 February 2025. Later months may be incomplete, so the checks warn from those months on. The data doesn't show a cutoff, so no month is claimed as complete.

### The recounts

The macros in `macros/recount_funnel.sql` read `ods_` only, with no core model or seed. They use a different method from core: a self-join on row order and a range join on the stage list, not `lag` and `generate_series`, and `distinct on` per month end, not a `lead` window. Labels come from the source tables, compared in lower case, so a seed fault shows up too.

`assert_last_owner_matches_change_log` does the same for the last owner report: it rebuilds every column of every deal from `ods_`, and a deal missing from either side counts as a difference.

## 7. Tests and crash test results

`dbt build`: 181 passed, 5 warnings for the known oddities, 0 errors, of 186.

| Type | Count | Where |
|---|---:|---|
| Unit tests | 39 | `models/core/_core__unit_tests.yml`, `models/reporting/_reporting__unit_tests.yml`, `models/reporting/_rep_data_quality_checks__unit_tests.yml` |
| Data tests | 125 | Sources, `ods_`, core, `rep_`, `tests/` |

The quality check unit tests start from one clean fixture, then swap in one corrupted input per test, to prove each check fails on what it's meant to catch.

**Crash tests.** Each one breaks something on purpose, checks the outcome, reloads, and confirms that both reports are back, cell for cell. They ran by hand, and all passed. CT5 and CT7 ran again after `rep_deal_last_owner` was added: both stopped it too, and it came back identical. Its comparison failed on each of ten deliberate faults: a missing deal, an extra deal, a wrong value in each column, one owner lost, and every row wrong.

| Test | What was broken | Expected | Result |
|---|---|---|---|
| CT1 | Fresh start, build, repeat `docker compose up -d`, build | Report identical, row counts unchanged | Passed |
| CT2 | `deal_changes` and `activity` appended a second time, doubling them | Report identical, `exact_duplicates_in_raw` warns | Passed |
| CT3 | Every deal given a second creation row, so all stage rows are flagged. Then every sales call ID repeated with different data | Build errors, last reports kept | Passed, twice: `stage_row_acceptance_rate`, then `sales_call_acceptance_rate`, each with `accepted_data_in_every_month` |
| CT4 | An unknown stage value in raw | Stops at source tests, last reports kept | Passed: `stage_rows_use_a_known_stage` |
| CT5 | A mapped activity type removed | Gate blocks, last reports kept | Passed: `unmapped_activity_type` |
| CT6 | The loader fails on a file midway, after three tables loaded | Failure visible, previous data kept, dbt doesn't run | Passed: exit code 3, all row counts unchanged |
| CT7 | `deal_changes` and `activity` emptied | Stops at source tests, last reports kept | Passed: `not_empty` on both tables, 131 resources skipped |
| CT8 | Each report's aggregation broken on purpose | Unit tests stop it. Without them, the comparison fails and names the month and funnel step | Passed for both reports. For example: 2024-01 Step 1, report 31, recount 30 |

After each one, a reload and build brought both reports back, identical to before.

**Independent recount, outside dbt.** The main and month-end reports were recounted once from the CSV files in plain Python: all 280 cells matched.

## 8. Scalability and measured performance

- Each rule has one home, so a new rule touches one model.
- Core is stored as tables, so reports don't recompute source logic.
- A new funnel step on an existing mapping is a seed row. A new stage is a seed row and one value in the source test. Either also needs the fixed list in `funnel_steps_complete`, its unit test and the KPI definitions: that check rejects a step it doesn't know, on purpose. A new kind of activity needs logic. A new source adds `ods_` models and a fact.
- `fct_deal_stage_entry` keeps its grain, so an incremental build can follow at higher volumes. It isn't built here: this data is too small to justify it.

**Measured.** One real plan on this data, with `explain (analyze, buffers)`, on PostgreSQL 18.6 in Docker with default settings. Over three runs each, the main report's query took 18 to 22 ms with current table statistics, and 462 to 602 ms straight after a fresh build, because Postgres chose to compile the query (JIT), which took 415 to 564 ms of that. With JIT off, the fresh database took 21 to 30 ms. Times vary with the machine and the database state. The query scans each core table once, including all 13,003 rows of `fct_deal_stage_entry`, and reads no source table. The data is small, so the plan's shape says more than the time. Saved query: `analyses/sql/query_performance.sql`.

## 9. Results

### `rep_sales_funnel_monthly`

154 rows: 14 months, January 2024 to February 2025, by 11 funnel steps. Saved query: `analyses/sql/monthly_volumes.sql` for the sources, and the report itself.

| Month | 1 | 2 | 2.1 | 3 | 3.1 | 4 | 5 | 6 | 7 | 8 | 9 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 2024-01 | 30 | 6 | 76 | 1 | 66 | 1 | 0 | 0 | 0 | 0 | 0 |
| 2024-02 | 194 | 92 | 64 | 49 | 59 | 31 | 20 | 11 | 3 | 2 | 2 |
| 2024-03 | 199 | 232 | 54 | 198 | 75 | 133 | 88 | 55 | 36 | 19 | 7 |
| 2024-04 | 229 | 208 | 70 | 196 | 57 | 185 | 163 | 128 | 83 | 52 | 23 |
| 2024-05 | 247 | 237 | 61 | 225 | 65 | 213 | 185 | 153 | 108 | 78 | 25 |
| 2024-06 | 244 | 244 | 64 | 246 | 66 | 238 | 205 | 180 | 138 | 98 | 42 |
| 2024-07 | 264 | 254 | 88 | 240 | 65 | 221 | 213 | 192 | 151 | 85 | 48 |
| 2024-08 | 238 | 254 | 57 | 255 | 71 | 244 | 212 | 179 | 136 | 105 | 37 |
| 2024-09 | 208 | 221 | 32 | 209 | 33 | 221 | 222 | 155 | 123 | 77 | 43 |
| 2024-10 | 119 | 173 | 0 | 207 | 0 | 207 | 185 | 166 | 127 | 78 | 34 |
| 2024-11 | 18 | 60 | 0 | 100 | 0 | 118 | 125 | 115 | 97 | 73 | 31 |
| 2024-12 | 0 | 4 | 0 | 18 | 0 | 40 | 57 | 63 | 54 | 34 | 19 |
| 2025-01 | 0 | 0 | 0 | 2 | 0 | 5 | 13 | 19 | 17 | 16 | 10 |
| 2025-02 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 3 | 3 | 3 | 1 |

`0` means nothing was recorded. Call records end in September 2024, so those call zeros don't show that no calls took place.

### `rep_deal_last_owner`

1,990 rows, one per accepted deal, all with an owner. Every deal has a lost reason, so `deal_status` is `lost` throughout. 1,197 users are last owners, so most hold one or two deals: too few to compare them.

### Readings compared

The same monthly cells under each reading, added up across all months only to compare the readings. Saved query: `analyses/sql/reading_comparison.sql`.

| Stage | Movement (main report) | Recorded stage changes only | Last stage each month | Month-end distribution |
|---|---:|---:|---:|---:|
| Lead Generation | 1,990 | 1,990 | 995 | 992 |
| Qualified Lead | 1,985 | 1,474 | 776 | 759 |
| Needs Assessment | 1,946 | 1,300 | 713 | 669 |
| Proposal/Quote Preparation | 1,857 | 1,082 | 662 | 593 |
| Negotiation | 1,688 | 892 | 590 | 456 |
| Closing | 1,419 | 738 | 551 | 370 |
| Implementation/Onboarding | 1,076 | 586 | 468 | 297 |
| Follow-up/Customer Success | 720 | 476 | 440 | 245 |
| Renewal/Expansion | 322 | 322 | 322 | 158 |
| **All stages** | **13,003** | **8,860** | **5,517** | **4,539** |

Movement and position are two different measures, so the gap between them is neither an error nor an uplift.

### Sensitivity table

How much each funnel assumption changes the numbers, by its number in `docs/methodology_and_assumptions.md`. Each row comes from `analyses/sql/assumption_sensitivity.sql`. Sums add up the report's own cells to measure the difference only: they aren't reported KPIs. The unit is monthly distinct deals, except for the last two columns, which count report cells.

| # | Chosen | Alternative not chosen | Cells compared | Sum, chosen / alternative | Cells changed | Largest cell change |
|---|---|---|---|---:|---:|---:|
| Key | Calls counted on their own | Only calls linked to a deal | Sales calls | 1,123 / 2 | 18 | 88 |
| 1 | Every stage reached | Only recorded stage changes | Deal stages | 13,003 / 8,860 | 87 | 118 |
| 1 | Every stage reached | Only a deal's last stage each month | Deal stages | 13,003 / 5,517 | 99 | 161 |
| 1 | Every stage reached | Month-end deal / stage distribution, a different measure | Deal stages | 13,003 / 4,539 | 110 | 173 |
| 2 | Completed calls | All scheduled calls | Sales calls | 1,123 / 2,255 | 18 | 77 |
| 3 | Broken IDs excluded | Keeping everything | All funnel steps | 14,126 / 14,198 | 44 | 4 |
| 3 | Broken IDs excluded | Keeping one of the conflicting records: a deal's latest creation, an activity's earliest due date | All funnel steps | 14,126 / 14,180 | 34 | 3 |
| 3 | Unusual records kept | Removing them: deals lost after Implementation, and Sales Call 2 with no earlier Sales Call 1 | All funnel steps | 14,126 / 4,995 | 122 | 155 |
| 4 | Open until a lost reason | Guessing won deals: one guess, that a deal reaching Implementation was won | Month-end report | 4,539 / 3,839 | 38 | 50 |
| 5 | First to last month with data | Fixed dates: calendar 2024 | All funnel steps | 14,126 / 14,034 | 11 | 19 |
| 5 | First to last month with data | Running to the last lost reason: adds one month of 11 zero cells | All funnel steps | 14,126 / 14,126 | 0 | 0 |
| 5 | Empty cells show `0` | Leaving out empty cells: 23 fewer rows | All funnel steps | 14,126 / 14,126 | 0 | 0 |
| 5 | `0` and a separate report | A coverage column: breaks the four required columns | All funnel steps | No change | 0 | 0 |
| 6 | Deal Created not a deal stage | Showing it as a deal stage: adds a 12th funnel step | All funnel steps | 14,126 / 16,116 | 9 | 262 |
| 6 | Dated by stage 1 | Dating Lead Generation by deal creation | Lead Generation | 1,990 / 1,990 | 11 | 217 |
| 6 | Gap not reported as a position | Treating the gap as real: a No stage yet row at month end | Month-end report | 4,539 / 6,813 | 10 | 301 |

Assumption 7 isn't in the table, because it changes no funnel count: 496 deals changed owner, none after their first stage. Saved query: `analyses/sql/owner_history.sql`.

### Source profile

Saved query: `analyses/sql/source_profile.sql`.

| Raw table | Rows | Notes |
|---|---:|---|
| `deal_changes` | 15,406 | 1,995 deals. Stage rows from 8 January 2024 to 24 February 2025, lost reasons to 11 March 2025 |
| `activity` | 4,579 | Due dates from 1 January to 13 September 2024. 4,568 distinct IDs |
| `users` | 1,787 | Holds personal data |
| `stages` | 9 | |
| `activity_types` | 4 | |
| `fields` | 4 | |

Other saved queries: `call_deal_link_test.sql` and `call_user_link_test.sql` test the link from calls to deals, `stage_data_quality.sql` measures skips and lost reasons, `stage_timing.sql` measures creation to stage entry, `exclusion_impact.sql` measures what each exclusion removes, and `owner_history.sql` measures owner changes.

To run one: `dbt compile --select <name>`, then run the SQL it writes to `target/compiled/`.

## 10. How to run and reload

See the README. In short:

```bash
pip install -r requirements.txt
docker compose run --rm data_loader && dbt build
```

- The loader replaces all six tables in one transaction. Any error rolls back, keeps the previous data and exits non-zero, so `&&` keeps dbt from running.
- The database health check runs over TCP, because during first-time setup the server listens only on its local socket.
- `dbt run` runs no tests, so use `dbt build`.
- `dbt-core` and `dbt-postgres` are pinned in `requirements.txt`, and the Postgres image in `docker-compose.yml`.
- `raw_data/load_data.sh` must keep LF line endings, which `.gitattributes` enforces.

AI tools full disclosure: Codex and Claude Code were used.
