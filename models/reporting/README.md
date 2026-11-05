# reporting

The five reports, in the schema `public_pipedrive_analytics`. Tables with enforced contracts.

**Reads from:** core and the seed. `rep_data_quality_checks` also reads the sources and `ods_`, because it has to see every layer. **Read by:** consumers.

**Rules:** no business rules of their own. A failed check in `rep_data_quality_checks` stops all three output ports, which keep their last good version.

| Model | Grain | Why it exists |
|---|---|---|
| `rep_sales_funnel_monthly` | One row per month and step | The required report: the one place stages and calls meet |
| `rep_deal_stage_distribution_monthly` | One row per month and stage step | The month-end report: estimated open deals by stage |
| `rep_deal_last_owner` | One row per accepted deal | The last owner report: who last owned each deal |
| `rep_data_quality_checks` | One row per check and month | All check results, and the publish gate |
| `rep_records_for_review` | One row per flagged record | Every excluded record, with its reason |

AI tools full disclosure: Codex and Claude Code were used.
