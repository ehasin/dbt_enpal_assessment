"""Export the five reports and their documentation for the offline catalog.

Run after a successful `dbt build`. Uses the project's local dev profile by default;
PGHOST, PGPORT, PGDATABASE, PGUSER and PGPASSWORD override it. The database
connection is read-only, and all exports share one repeatable-read transaction.
"""
from __future__ import annotations

import argparse
import csv
import datetime as dt
import decimal
import hashlib
import io
import json
import os
import re
from pathlib import Path

import psycopg2
from psycopg2 import sql
import yaml

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
PORTS = (
    "rep_sales_funnel_monthly",
    "rep_deal_stage_distribution_monthly",
    "rep_data_quality_checks",
    "rep_records_for_review",
    "rep_deal_last_owner",
)
DOCS = {
    "methodology": "docs/methodology_and_assumptions.md",
    "business": "docs/business_guide.md",
    "technical": "docs/technical_documentation.md",
}


def serial(value):
    if isinstance(value, (dt.datetime, dt.date)):
        return value.isoformat()
    if isinstance(value, decimal.Decimal):
        return float(value)
    raise TypeError(type(value).__name__)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--schema", default="public_pipedrive_analytics")
    args = parser.parse_args()
    profile = yaml.safe_load((ROOT / "profiles.yml").read_text(encoding="utf-8"))
    dev = profile["enpal_assessment_project"]["outputs"]["dev"]
    connection = {k: os.environ.get(env, dev[key]) for k, env, key in (
        ("host", "PGHOST", "host"), ("port", "PGPORT", "port"),
        ("dbname", "PGDATABASE", "dbname"), ("user", "PGUSER", "user"),
        ("password", "PGPASSWORD", "pass"),
    )}
    definitions = yaml.safe_load(
        (ROOT / "models/reporting/_reporting__models.yml").read_text(encoding="utf-8")
    )["models"]
    definitions = {m["name"]: m for m in definitions}
    steps = list(csv.DictReader(io.StringIO((ROOT / "seeds/funnel_steps.csv").read_text(encoding="utf-8"))))
    payload = {
        "generated_at": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"),
        "schema": args.schema,
        "mode": "static export; no live database connection in the browser",
        "steps": steps,
        "ports": {},
        "documents": {key: {"path": path, "markdown": (ROOT / path).read_text(encoding="utf-8")}
                      for key, path in DOCS.items()},
    }
    with psycopg2.connect(**connection, connect_timeout=10) as conn:
        conn.set_session(readonly=True, isolation_level="REPEATABLE READ")
        with conn.cursor() as cur:
            for name in PORTS:
                cur.execute(sql.SQL("select * from {}.{}").format(
                    sql.Identifier(args.schema), sql.Identifier(name)))
                columns = [c.name for c in cur.description]
                rows = [dict(zip(columns, row)) for row in cur.fetchall()]
                if name in PORTS[:2]:
                    order = {s["funnel_step"]: int(s["step_order"]) for s in steps}
                    rows.sort(key=lambda r: (r["month"], order[r["funnel_step"]]))
                elif name == "rep_data_quality_checks":
                    rows.sort(key=lambda r: (r["month"] or dt.date.min, r["check_name"]))
                elif name == "rep_deal_last_owner":
                    rows.sort(key=lambda r: r["deal_id"])
                else:
                    rows.sort(key=lambda r: (r["source_table"], r["dq_reason"], r["record_key"]))
                meta = definitions[name]
                payload["ports"][name] = {
                    "columns": [{"name": c["name"], "type": c.get("data_type", ""),
                                 "description": c.get("description", "")}
                                for c in meta.get("columns", [])],
                    "rows": rows,
                    "meta": meta.get("meta", {}),
                    "description": meta.get("description", ""),
                }
            cur.execute("select version()")
            payload["database_version"] = cur.fetchone()[0].split(" on ")[0]
            raw = {}
            for table in ("deal_changes", "activity", "users", "stages", "activity_types", "fields"):
                cur.execute(sql.SQL("select count(*) from public.{}").format(sql.Identifier(table)))
                raw[table] = cur.fetchone()[0]
            payload["source_rows"] = raw

    # Keep the provenance with the export.
    tracked = []
    for folder in ("models", "macros", "tests", "seeds", "raw_data", "docs"):
        tracked += [p for p in (ROOT / folder).rglob("*") if p.is_file() and p.suffix in (".sql", ".yml", ".csv", ".md", ".sh")]
    tracked += [ROOT / p for p in ("dbt_project.yml", "requirements.txt", "init.sql")]
    provenance = {p.relative_to(ROOT).as_posix(): digest(p) for p in sorted(tracked)}
    lineage = {}
    for path in (ROOT / "models").rglob("*.sql"):
        content = path.read_text(encoding="utf-8")
        lineage[path.stem] = {
            "path": path.relative_to(ROOT).as_posix(),
            "refs": sorted(set(re.findall(r"ref\(['\"]([^'\"]+)['\"]\)", content))),
            "sources": re.findall(r"source\(['\"]([^'\"]+)['\"],\s*['\"]([^'\"]+)['\"]\)", content),
            "sql": content,
        }
    manifest_path = ROOT / "target/manifest.json"
    if not manifest_path.exists():
        raise SystemExit("target/manifest.json is missing. Run dbt build before exporting the catalog.")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    for node in manifest.get("nodes", {}).values():
        name = node.get("name")
        if node.get("resource_type") != "model" or name not in lineage:
            continue
        if node.get("raw_code", "").replace("\r\n", "\n").strip() != lineage[name]["sql"].strip():
            raise SystemExit(f"Manifest is out of date for {name}. Run dbt build before exporting.")
        deps = node.get("depends_on", {}).get("nodes", [])
        lineage[name]["refs"] = sorted({manifest["nodes"][d]["name"] for d in deps
                                        if d in manifest.get("nodes", {})})
        lineage[name]["sources"] = sorted({
            (manifest["sources"][d]["source_name"], manifest["sources"][d]["name"])
            for d in deps if d in manifest.get("sources", {})
        })
        lineage[name]["dependency_origin"] = "dbt manifest (includes macro and dynamic references)"
    payload["lineage"] = lineage
    payload["provenance"] = {
        "input_sha256": provenance,
        "project_fingerprint": hashlib.sha256(json.dumps(provenance, sort_keys=True).encode()).hexdigest(),
        "note": "Export after dbt build. Input hashes identify the packaged source; they do not certify a build or freshness SLA.",
    }
    normalized = json.loads(json.dumps(payload, default=serial))
    destination = HERE / "data"
    destination.mkdir(exist_ok=True)
    for name, port in normalized["ports"].items():
        out = io.StringIO(newline="")
        writer = csv.DictWriter(out, fieldnames=[c["name"] for c in port["columns"]], lineterminator="\n")
        writer.writeheader()
        for row in port["rows"]:
            writer.writerow({k: json.dumps(v, ensure_ascii=False, sort_keys=True) if isinstance(v, (dict, list)) else v
                             for k, v in row.items()})
        (destination / f"{name}.csv").write_text(out.getvalue(), encoding="utf-8", newline="")
    encoded = json.dumps(normalized, ensure_ascii=False, separators=(",", ":"))
    # Classic script makes local file:// opening work without fetch/CORS or a server.
    (HERE / "snapshot.js").write_text("window.CATALOG_SNAPSHOT = " + encoded.replace("<", "\\u003c") + ";\n", encoding="utf-8")
    (destination / "provenance.json").write_text(json.dumps({
        "generated_at": normalized["generated_at"], "schema": args.schema,
        **payload["provenance"],
        "exports": {f"{name}.csv": digest(destination / f"{name}.csv") for name in PORTS},
    }, indent=2) + "\n", encoding="utf-8")
    print("Catalog snapshot exported (read-only). " + ", ".join(f"{name}: {len(port['rows'])} rows" for name, port in normalized["ports"].items()))


if __name__ == "__main__":
    main()
