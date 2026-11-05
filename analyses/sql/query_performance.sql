-- Question: how much work does the main report take on this design?
-- Backs: section 8 of docs/technical_documentation.md.
-- Result on this extract: 18 to 22 ms with current table statistics, 462 to 602 ms straight after a fresh build (JIT).
-- Each core table is scanned once, and no source table is read.
-- To repeat it, run `explain (analyze, buffers)` on the report's SQL in target/compiled, then compare the rows below.
select 'fct_deal_stage_entry rows' as metric, count(*)::text as value from {{ ref('fct_deal_stage_entry') }}
union all select 'fct_activity rows', count(*)::text from {{ ref('fct_activity') }}
union all select 'report rows', count(*)::text from {{ ref('rep_sales_funnel_monthly') }}
