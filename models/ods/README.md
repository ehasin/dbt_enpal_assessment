# ods

Cleans each source table, one view per table, with the same grain after removing exact duplicate rows.

**Reads from:** the `pipedrive` source. **Read by:** core, and the quality checks.

**Rules:** types, names and exact-row dedup only. No business rules, no filters. Because of the dedup, appending a load twice can't change a report.

| Model | Grain | Why it exists |
|---|---|---|
| `ods_pipedrive__deal_changes` | One row per recorded field change | Typed log behind every deal fact |
| `ods_pipedrive__activity` | One row per distinct activity row | Typed activities. IDs can still repeat across differing rows |
| `ods_pipedrive__users` | One row per user | Typed users. Emails stop here |
| `ods_pipedrive__stages` | One row per stage | Typed stages, in the source's spelling |
| `ods_pipedrive__activity_types` | One row per type | The source's link between `meeting` and Sales Call 1 |
| `ods_pipedrive__fields` | One row per field | Source of lost reason labels |

AI tools full disclosure: Codex and Claude Code were used.
