# Data Product Catalog

Open **index.html** in a modern browser. Keep this entire folder inside the project: its model and document links are relative to the parent directory. No server, package installation, internet connection or database is needed to browse the included snapshot.

The catalog presents one Data Product, **Sales Funnel**, with five Reports. Each Report opens with its purpose and use cases, then its data, with definitions and technical detail on their own tabs.

**Request access** downloads or copies a Markdown draft with the selected Reports and intended use. Nothing is sent and no access is granted: there is no approval backend or provisioning integration. The basket and intended-use text stay in browser storage. Storage may be unavailable for local files in some browser configurations; browsing and downloads still work for that session.

## Refresh the snapshot

After a successful data load and `dbt build`, use the project's Python environment:

```bash
python catalog/export_catalog.py
```

The exporter uses the local dev settings in `profiles.yml`; `PGHOST`, `PGPORT`, `PGDATABASE`, `PGUSER` and `PGPASSWORD` override them. `--schema` overrides the reporting schema. It reads PostgreSQL in one **read-only, repeatable-read transaction**, then writes:

- `snapshot.js`: all five report datasets, dbt YAML descriptions and KPI metadata, public documents, model SQL and dbt dependencies. A classic script supports `file://` without fetch or CORS.
- `data/*.csv`: complete downloadable report outputs.
- `data/provenance.json`: export time, source-file fingerprints and CSV checksums.

No database credentials are included in these browser artifacts. Source hashes identify packaged inputs; they do not certify that a build succeeded or establish a freshness SLA. If model SQL differs from the manifest, the exporter asks you to rebuild before exporting.

The included reporting window is January 2024–February 2025. Source coverage differs: activity observations stop on 13 September 2024 and stage observations on 24 February 2025. Boundary periods may be incomplete. The export date is distinct from those data dates.

## Files and design

`index.html`, `styles.css`, `storefront.css` and `app.js` form a buildless, dependency-free application. Hash routes support Data Product, Report, documentation and basket deep links on disk. Data values, KPI metadata and documentation come from the exporter; editorial descriptions, use guidance, SQL examples and the roadmap controls are in `app.js` and should be reviewed when business rules change.

The styling uses navy (`#072543`), solar yellow (`#ffd233`) and Poppins. Poppins is bundled from [Google Fonts' source repository](https://github.com/google/fonts/tree/main/ofl/poppins), with its SIL Open Font License in `assets/Poppins-OFL.txt`. No remote assets, telemetry, backend or trackers are used.

AI tools full disclosure: Codex and Claude Code were used.
