# Business guide

For anyone using these reports to make a decision. No SQL needed.

## 1. Business question and value

**The question:** how many deals does Sales move through each deal stage of the funnel, month by month?

Pipedrive holds this as a log of field changes, which nobody can read directly. Deals and calls sit in separate tables, and the export has problems that can quietly distort a count. These reports turn that log into one monthly view and show what was left out and why. If the data fails its quality checks, the reports keep their last good version. If a finished report doesn't match the final recount, the failure is flagged, but the new version is already in place.

## 2. The reports

| Report | What it shows |
|---|---|
| `rep_sales_funnel_monthly` | Deals entering each deal stage each month |
| `rep_deal_stage_distribution_monthly` | Estimated open deals in each deal stage at month end |
| `rep_deal_last_owner` | Who last owned each deal |
| `rep_data_quality_checks` | Which checks passed, and which months have data |
| `rep_records_for_review` | Which records were excluded, and why |

## 3. Use Cases

Read these like a medicine label.

### `rep_sales_funnel_monthly`

**Use for:** monthly volume per deal stage, and trends.

**Don't use for:**
- Open deals at month end. Use `rep_deal_stage_distribution_monthly`
- Conversion between deal stages. Deals skip deal stages, and each month holds different deals
- Reading a sales call as part of the deal stage around it. Calls and deal stages are counted on their own

### `rep_deal_stage_distribution_monthly`

**Use for:** open pipeline by deal stage.

**Don't use for:** deals entering a deal stage, or calls. It's an estimate: a deal counts as open until it gets a lost reason, because the data has no deal status.

### `rep_deal_last_owner`

**Use for:** finding a deal's last owner, and the deals that changed owner.

**Don't use for:** sales performance by owner, or who owned a deal at an earlier date. Every deal in this data has a lost reason, so status reads lost throughout.

### `rep_data_quality_checks`

**Use for:** deciding whether to trust a month.

**Don't use for:** business figures.

### `rep_records_for_review`

**Use for:** fixing issues at the source.

**Don't use for:** business figures.

## 4. KPIs

A deal counts once per deal stage per month.

| Deal stage or sales call | How it's counted | Date used |
|---|---|---|
| Lead Generation | Deals entering it | Date it entered the deal stage |
| Qualified Lead | Deals entering it, or passing it on the way to a later deal stage | Same |
| Sales Call 1 | Deals with a completed Sales Call 1 | Due date |
| Needs Assessment | As Qualified Lead | Date it entered the deal stage |
| Sales Call 2 | Deals with a completed Sales Call 2 | Due date |
| Proposal/Quote Preparation | As Qualified Lead | Date it entered the deal stage |
| Negotiation | As Qualified Lead | Same |
| Closing | As Qualified Lead | Same |
| Implementation/Onboarding | As Qualified Lead | Same |
| Follow-up/Customer Success | As Qualified Lead | Same |
| Renewal/Expansion | Deals entering it | Same |

**A `0`** means nothing was recorded that month. `rep_data_quality_checks` shows which months have data: call records stop earlier than deal stage records, so later months show `0` for calls.

## 5. Movement against position

The main report and the month-end report answer different questions.

- **Movement:** how many deals entered this deal stage this month? A deal parked for three months counts once, when it entered.
- **Position:** where were the open deals at month end? The same parked deal counts at each of the three month ends.

**Example:** a deal enters Lead Generation in May, Needs Assessment in June, Proposal/Quote Preparation and Closing in July and Implementation/Onboarding in August, and is lost in August.

| | May | Jun | Jul | Aug |
|---|---|---|---|---|
| `rep_sales_funnel_monthly` | Lead Generation | Qualified Lead, Needs Assessment | Proposal/Quote Preparation, Negotiation, Closing | Implementation/Onboarding |
| `rep_deal_stage_distribution_monthly` | Lead Generation | Needs Assessment | Closing | None |

## 6. What this data can't answer

We give no substitute figures for these.

- **Win rate or revenue.** There's no deal status, won date or deal value
- **Conversion between deal stages.** Deals skip deal stages, and each month holds different deals
- **The true causes of lost deals.** The data records lost reasons, but can't prove them
- **Whether calls work.** Too few deal IDs match between calls and deal stages to rely on
- **When calls were held.** Only the due date is available

## 7. Fit with the business

Enpal is a full-service energy company: solar, heat pumps, storage and wallboxes, installed by our own teams and trained in our own academy. Our mission is to make renewable energy accessible to everyone.

Each signed deal commits installers and supply, so a trusted monthly view of the funnel could help plan capacity as well as measure Sales. A report that shows its own gaps also suits many teams relying on the same numbers.

## 8. Product roadmap

| Priority | Initiative | Status |
|---:|---|---|
| 1 | Win/loss status and analysis | In consideration |
| 2 | Deal conversion rates | In consideration |
| 3 | Lost deal reasons analysis | Proposed |

Win/loss needs deal status, won date and value in the export; conversion needs a view by deal creation month.

AI tools full disclosure: Codex and Claude Code were used.
