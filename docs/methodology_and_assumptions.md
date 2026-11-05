# Methodology and assumptions

What I built, what I assumed, and why.

## 1. The goal

Turn a Pipedrive export into a dbt project that ends in one monthly report, `rep_sales_funnel_monthly`. It shows how many deals reached each deal stage and sales call, in exactly four columns: `month`, `kpi_name`, `funnel_step` and `deals_count`.

The requirements don't say when a deal counts, how calls fit with stages, or which dates to use. Those decisions are in section 5.

## 2. What I'm delivering

- A working dbt and Postgres project, with tests and exploratory analysis
- The required report, `rep_deal_stage_distribution_monthly`, `rep_deal_last_owner` and two data quality reports
- Technical documentation, and business-friendly documentation for self-service
- A pull request to my fork, and a zip of the same version

## 3. The reports

| Report | What it shows | Good for | Not for |
|---|---|---|---|
| `rep_sales_funnel_monthly` | Deals entering each deal stage each month | Monthly volume per deal stage, trends | Open deals at month end |
| `rep_deal_stage_distribution_monthly` | Estimated open deals in each stage at month end | Open pipeline by stage | Deals entering a stage, calls |
| `rep_deal_last_owner` | Who last owned each deal | Finding a deal's last owner, and deals that changed owner | Sales performance by owner, earlier owners |
| `rep_data_quality_checks` | Which checks passed, and which months have data | Deciding whether to trust a month | Business figures |
| `rep_records_for_review` | Which records were excluded, and why | Fixing issues at the source | Business figures |

## 4. What the numbers mean

**The main report, `rep_sales_funnel_monthly`, counts movement:** how many deals entered each stage this month? A deal that jumps from stage 2 to 5 counts in 3, 4 and 5, because it got past them.

**The month-end report, `rep_deal_stage_distribution_monthly`, counts position:** where were the open deals at month end? Calls aren't included, because a call is a one-off event with no month-end state, and too few deal IDs match between calls and stages to rely on.

**Example:** a deal enters stage 1 in May, stage 3 in June, stages 4 and 6 in July and stage 7 in August, and is lost in August.

| | May | Jun | Jul | Aug |
|---|---|---|---|---|
| `rep_sales_funnel_monthly` | 1 | 2, 3 | 4, 5, 6 | 7 |
| `rep_deal_stage_distribution_monthly` | 1 | 3 | 6 | None |

A deal counts once per deal stage per month.

| Deal stage or sales call | Counts | Date used |
|---|---|---|
| Deal stages (1 to 9) | Deals entering that stage | Date it entered the stage |
| 2.1 Sales Call 1 | Deals with a completed `meeting` activity | Due date |
| 3.1 Sales Call 2 | Deals with a completed `sc_2` activity | Due date |

The data can't show win rate, revenue, conversion between deal stages, the true causes of lost deals, or whether calls work, so I don't report them.

## 5. Assumptions

**Key assumption: sales calls are part of a deal's progress.** The stages in `deal_changes` don't show everything: two more come from call activity. I assume this order: Qualified Lead -> Sales Call 1 -> [optional: Needs Assessment -> Sales Call 2] -> Proposal/Quote Preparation. Normally a Deal ID would link calls to deals and confirm this, but in this data too few IDs match to rely on. I assume a working link exists in production, and I don't use it here. So this order is unverified and adds no rules to the counts: each is counted on its own, call counts can't be tied to stage counts, and a call step can be lower than the stage after it.
*Not chosen:* counting only calls linked to a deal (almost none would be left).

**1. A deal counts in every stage it reached that month, even ones it skipped.** [Pipedrive's Deal Progress report](https://support.pipedrive.com/en/article/insights-reports-deal-progress) counts skipped stages the same way.
*Not chosen:* only recorded stage changes (misses skipped stages); only a deal's last stage each month (misses stages it passed through); month-end deal / stage distribution (a different question, so it has its own report).

**2. A call counts only if it was completed, in the month it was due.** A call that didn't happen shouldn't count, and the data doesn't show when calls were held.
*Not chosen:* all scheduled calls (many may never have happened).

**3. Records with a broken ID are excluded from the counts and listed.** Exact duplicate rows are collapsed first. If different records still conflict on one ID, none can be trusted, so all of them move to `rep_records_for_review`. Unusual records stay in. See the appendix.
*Not chosen:* keeping everything (miscounts deals); keeping one of the conflicting records (nothing shows which is right); removing unusual records (they may be valid).

**4. In `rep_deal_stage_distribution_monthly`, a deal is open until it gets a lost reason.** The data has no deal status, only lost reasons, so the report is an estimate. The time of the lost reason stands in for the loss time, and won, reopened or deleted deals can't be seen.
*Not chosen:* guessing won deals from how far they got (nothing supports it).

**5. The report runs from the first to the last month with a stage change or activity, and `0` means nothing was recorded.** The requirements give no dates. `rep_data_quality_checks` shows which months have data.
*Not chosen:* fixed dates (no basis); running to the last lost reason (adds empty months); leaving out empty months (leaves gaps); a coverage column (the columns are fixed).

**6. Lead Generation is dated by the recorded entry into stage 1.** Pipedrive requires every deal to have a stage, so I assume a production deal has one from the moment it's created. This data doesn't capture that first assignment: it shows stage 1 later than creation. I use the recorded dates and don't fill in an unknown first stage.
*Not chosen:* showing Deal Created as a deal stage (not required); dating Lead Generation by deal creation (that assumes which stage came first); treating the gap as real (a Pipedrive deal always has a stage).

**7. A deal's owners are the ones recorded in its change log.** Each owner holds the deal from the recorded change until the next one, and a deal has no recorded owner before its first one. `dim_deal_owner` keeps the whole history, and `rep_deal_last_owner` shows the latest. This doesn't touch the funnel counts.
*Not chosen:* keeping only the last owner (credits them with stages an earlier owner handled); dating the first owner from deal creation (assumes who held it); a dbt snapshot (the change log already holds the history); putting the history on `dim_deal` (breaks one row per deal).

`docs/technical_documentation.md` has a table showing how much assumptions 1 to 6 change the numbers. `analyses/sql/owner_history.sql` shows why assumption 7 changes none.

## 6. How it's built

```
raw tables -> ods_ -> core (dim_, fct_) -> rep_
```

| Layer | What it does | Stored as |
|---|---|---|
| `ods_` | Cleans each source table: data types, names, exact duplicates. No business rules | Views |
| core | Holds the business data, ready for analysis | Tables |
| `rep_` | The five reports | Tables |

- **`dim_` tables describe things:** deals, deal owners, users, stages, activity types and months.
- **`fct_` tables record events:** deal changes, activities, stage entries and month-end positions.
- **The seed** `funnel_steps` lists the deal stages and sales calls with their labels.

`dbt build` runs the models and tests with one command. Loading twice changes nothing, and a failed load keeps the previous data.

## 7. Quality checks

| Check | Catches | If it fails |
|---|---|---|
| Load | Copy errors, partial loads | The load stops |
| Source tests | Empty tables, missing IDs, unknown stages | Dependent models are skipped |
| Unit tests | Wrong logic | That model doesn't build |
| Contracts | Wrong columns or types | That model doesn't build |
| Publish gate | Any failed data quality check upstream of the reports | Reports keep their last good version |
| Output comparison | Any number that differs from a separate recount, for every month, deal stage and sales call, and every deal in the last owner report | The build fails, but the reports are already updated |

## Appendix: data problems

| Problem | What happens |
|---|---|
| Deal with more than one creation record | Excluded and listed, because nothing shows which records are right |
| Different activities with the same ID | All excluded and listed, for the same reason |
| Two users sharing an email | Kept and flagged |
| Calls with no usable link to deals | Kept, see the key assumption |
| Stage 1 recorded later than deal creation | Kept, see assumption 6 |
| Deal skips stages | Kept, and counts in the skipped stages (assumption 1) |
| Deal moves backward or repeats a stage | Kept, as a new entry. A deal counts at most once per stage in a month, and a later month can count it again |
| Lost reason added after a deal entered Implementation | Kept, with a warning |
| Sales Call 2 with no earlier Sales Call 1 | Kept, with a warning |

AI tools full disclosure: Codex and Claude Code were used.
