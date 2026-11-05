/* Dependency-free data product catalog. All displayed rows are exports. */
(() => {
  "use strict";
  const S = window.CATALOG_SNAPSHOT;
  if (!S) {
    document.querySelector("#main").innerHTML =
      '<div class="page"><h1>The data snapshot is missing.</h1><p>Keep snapshot.js beside index.html or run the catalog exporter.</p></div>';
    return;
  }
  const $ = (s, root = document) => root.querySelector(s);
  const $$ = (s, root = document) => [...root.querySelectorAll(s)];
  const esc = (v) =>
    String(v ?? "").replace(
      /[&<>"']/g,
      (c) =>
        ({
          "&": "&amp;",
          "<": "&lt;",
          ">": "&gt;",
          '"': "&quot;",
          "'": "&#39;",
        })[c],
    );
  const fmt = (v) => Number(v).toLocaleString("en-GB");
  const month = (v, long = false) =>
    v
      ? new Date(v.slice(0, 7) + "-15T12:00:00Z").toLocaleDateString("en-GB", {
          month: long ? "long" : "short",
          year: "numeric",
          timeZone: "UTC",
        })
      : "Whole dataset";
  const day = (v) =>
    new Date(v.slice(0, 10) + "T12:00:00Z").toLocaleDateString("en-GB", {
      day: "numeric",
      month: "short",
      year: "numeric",
      timeZone: "UTC",
    });
  const exported = () =>
    new Date(S.generated_at).toLocaleDateString("en-GB", {
      day: "numeric",
      month: "short",
      year: "numeric",
      timeZone: "UTC",
    });
  const paths = {
    grid: '<rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><rect x="14" y="14" width="7" height="7" rx="1"/>',
    search: '<circle cx="10.5" cy="10.5" r="6.5"/><path d="m16 16 5 5"/>',
    arrow: '<path d="M4 12h16m-6-6 6 6-6 6"/>',
    external: '<path d="M14 4h6v6m0-6-11 11M10 4H4v16h16v-6"/>',
    chevron: '<path d="m9 5 7 7-7 7"/>',
    up: '<path d="m5 15 7-7 7 7"/>',
    down: '<path d="m5 9 7 7 7-7"/>',
    funnel: '<path d="M3 4h18l-7 8v7l-4 2v-9L3 4z"/>',
    chart: '<path d="M4 3v17h17M8 15l4-5 4 2 5-7"/>',
    layers:
      '<path d="m12 3 10 5-10 5L2 8l10-5zM2 12l10 5 10-5M2 16l10 5 10-5"/>',
    check: '<path d="m5 12 4 4L19 6"/>',
    shield: '<path d="m12 3 8 3v6c0 5-8 9-8 9s-8-4-8-9V6l8-3zM8 12l3 3 5-6"/>',
    review:
      '<rect x="5" y="4" width="14" height="17" rx="2"/><path d="M9 2h6v4H9zM9 11h6M9 15h4"/>',
    book: '<path d="M12 5C8 2 4 3 2 4v15c3-1 6-1 10 2m0-16c4-3 8-2 10-1v15c-3-1-6-1-10 2V5z"/>',
    info: '<circle cx="12" cy="12" r="9"/><path d="M12 11v6M12 7v.1"/>',
    warn: '<path d="M12 3 2 21h20L12 3zM12 9v5M12 17v.1"/>',
    x: '<path d="m6 6 12 12M6 18 18 6"/>',
    person:
      '<circle cx="12" cy="8" r="4"/><path d="M4 21c1-4 4-6 8-6s7 2 8 6"/>',
    copy: '<rect x="8" y="8" width="12" height="13" rx="2"/><path d="M15 8V3H3v13h5"/>',
    download: '<path d="M12 3v12m-5-5 5 5 5-5M4 16v5h16v-5"/>',
    code: '<path d="m7 6-6 6 6 6M17 6l6 6-6 6M14 3l-4 18"/>',
    bag: '<path d="M5 7h14l1 14H4L5 7zM8 8V6a4 4 0 0 1 8 0v2"/>',
  };
  const icon = (name) =>
    `<svg viewBox="0 0 24 24" aria-hidden="true">${paths[name] || paths.database}</svg>`;
  const FEATURED_MONTH = "2024-12-01";
  const ROADMAP = [
    {
      id: "win-loss",
      title: "Win/loss status and analysis",
      status: "In consideration",
    },
    {
      id: "conversion",
      title: "Deal conversion rates",
      status: "In consideration",
    },
    {
      id: "lost-reasons",
      title: "Lost deal reasons analysis",
      status: "Proposed",
    },
  ];
  const P = [
    {
      id: "monthly-funnel",
      model: "rep_sales_funnel_monthly",
      title: "Monthly sales funnel",
      kind: "Business Report",
      group: "business",
      icon: "chart",
      color: "yellow",
      question: "How many deals reached each deal stage this month?",
      description:
        "Counts the deals entering each deal stage, and the deals with a completed sales call, month by month.",
      use: [
        "Compare monthly deal volume at a deal stage.",
        "See how many deals reached a deal stage, including those that skipped it.",
        "Track completed sales calls.",
      ],
      avoid: [
        "Conversion rates between deal stages.",
        "Open deals at month end. Use Month-end pipeline.",
        "Revenue, win rate or the effect of calls on deals.",
      ],
      date: "Date a deal entered the deal stage; due date for sales calls",
      grain: "Month × deal stage or sales call",
      unit: "Distinct deals",
      caveat:
        "Deal stages and sales calls are counted separately, because calls can’t be reliably linked to deals. A call’s month comes from its due date.",
      keywords:
        "movement progress lead generation qualified needs assessment proposal quote negotiation closing implementation onboarding follow up customer success renewal expansion sales call calls meeting sc_2 pipeline stage funnel step skip monthly volume",
    },
    {
      id: "month-end-pipeline",
      model: "rep_deal_stage_distribution_monthly",
      title: "Month-end pipeline",
      kind: "Business Report",
      group: "business",
      icon: "layers",
      color: "blue",
      question: "Where were the open deals at month end?",
      description:
        "Estimates how many open deals sat in each of the nine deal stages at each month end.",
      use: [
        "Compare open deals across deal stages.",
        "Track a deal stage’s month-end position over time.",
      ],
      avoid: [
        "Deals entering a deal stage. Use Monthly sales funnel.",
        "An exact count: won, reopened and deleted deals can’t be identified.",
        "Sales calls, conversion rates, revenue or forecasts.",
      ],
      date: "Calendar month end",
      grain: "Month × deal stage",
      unit: "Estimated open deals",
      caveat:
        "“Open” is an estimate: a deal counts as open until it gets a lost reason.",
      keywords:
        "stock position stand standing snapshot estimated open inventory backlog end period state stages stage pipeline calendar month end capacity",
    },
    {
      id: "last-owner",
      model: "rep_deal_last_owner",
      title: "Last deal owner",
      kind: "Business Report",
      group: "business",
      icon: "person",
      color: "blue",
      question: "Who last owned each deal?",
      description:
        "Shows each deal’s last owner, when they took over, and the deal’s stage and status.",
      use: [
        "See who last owned a deal.",
        "Find the deals that changed owner.",
        "List a last owner’s deals.",
      ],
      avoid: [
        "Sales performance by owner.",
        "Who owned a deal at an earlier date. That history is in dim_deal_owner.",
      ],
      date: "Date the last owner was recorded",
      grain: "One row per deal",
      unit: "Deals",
      caveat:
        "Every deal in this data has a lost reason, so status reads lost throughout. Most owners hold one or two deals, too few to compare them.",
      keywords:
        "owner owners ownership owns owned user assigned assignee reassigned reassignment responsible last current latest history scd type 2 who sales rep name",
    },
    {
      id: "product-health",
      model: "rep_data_quality_checks",
      title: "Data Product Health",
      kind: "Data Quality Report",
      group: "quality",
      icon: "shield",
      color: "green",
      question: "Can I trust this month’s figures?",
      description: "Shows which checks passed, and how far each month’s data reaches.",
      use: [
        "See which months may be incomplete.",
        "Check that deal stage and sales call counts match a separate recount.",
      ],
      avoid: [
        "Sales performance figures.",
        "Proof that a month is complete.",
        "Proof that every data issue has been found.",
        "The final checks on finished Reports. Those are in the dbt run results.",
      ],
      date: "Reporting month or whole dataset",
      grain: "Check × month",
      unit: "Check results",
      caveat: "These are the results of the last export, not live monitoring.",
      keywords:
        "health freshness fresh trust quality audit gate tests pass fail warn warnings coverage acceptance missing incomplete source reconciliation zero availability",
    },
    {
      id: "records-for-review",
      model: "rep_records_for_review",
      title: "Records for review",
      kind: "Data Quality Report",
      group: "quality",
      icon: "review",
      color: "yellow",
      question: "Which records were left out, and why?",
      description:
        "Lists the records left out of the Reports because of conflicting IDs, so they can be fixed in Pipedrive.",
      use: [
        "Find activities and deals with conflicting records.",
        "See why each record was left out.",
        "Prepare a fix in Pipedrive.",
      ],
      avoid: [
        "Sales volumes.",
        "A list of every unusual record: valid ones stay in the Reports.",
      ],
      date: "Dates inside each source record",
      grain: "One row per record left out",
      unit: "Records left out",
      caveat:
        "One ID can have several records, so a record count isn’t a deal count.",
      keywords:
        "excluded left out quarantine exception review remediation broken identity duplicate conflicting source record multiple deal creations duplicate activity id",
    },
  ];
  const byId = (id) => P.find((p) => p.id === id);
  const portData = (p) => S.ports[p.model];
  const rows = (p) => portData(p).rows;
  const months = [
    ...new Set(S.ports.rep_sales_funnel_monthly.rows.map((r) => r.month)),
  ];
  const qualityRows = () => S.ports.rep_data_quality_checks.rows;
  const statCount = (status) =>
    qualityRows().filter((r) => r.status === status).length;
  const stepOrder = (label) =>
    Number(S.steps.find((s) => s.funnel_step === label)?.step_order || 0);
  function stored(key, fallback) {
    try {
      return (
        JSON.parse(localStorage.getItem("enpal.catalog." + key)) ?? fallback
      );
    } catch {
      return fallback;
    }
  }
  const state = {
    query: "",
    basket: stored("basket", []),
    purpose: stored("purpose", ""),
    votes: stored("votes", {}),
    preview: {},
    route: [],
  };
  function persist(key, val) {
    try {
      localStorage.setItem("enpal.catalog." + key, JSON.stringify(val));
    } catch {
      /* Browser storage can be unavailable for file URLs. */
    }
  }
  function toast(message) {
    const t = $("#toast");
    t.textContent = message;
    t.classList.add("visible");
    clearTimeout(toast.timer);
    toast.timer = setTimeout(() => t.classList.remove("visible"), 3200);
  }
  const reportHref = (p, tab = "overview") =>
    `#/reports/${p.id}${tab === "overview" ? "" : "/" + tab}`;
  const requestButton = (id, label = "Request access", small = false) =>
    `<button class="button primary ${small ? "small" : ""}" data-action="request" data-id="${id}">${icon("bag")}${label}</button>`;
  function footer() {
    return `<footer class="footer"><span>Enpal Data Product Catalog</span><span>Data exported ${exported()} · <a href="#/about">About this catalog</a></span></footer>`;
  }
  function breadcrumb(items) {
    return `<nav class="breadcrumb" aria-label="Breadcrumb"><a href="#/">Catalog</a>${items.map(([text, href]) => `${icon("chevron")}${href ? `<a href="${href}">${esc(text)}</a>` : `<span aria-current="page">${esc(text)}</span>`}`).join("")}</nav>`;
  }
  function productIcon(p) {
    return `<span class="product-icon ${p.color}">${icon(p.icon)}</span>`;
  }
  const DOCS = [
    ["business", "info", "Business guide"],
    ["methodology", "book", "Methodology & assumptions"],
    ["technical", "code", "Technical documentation"],
  ];
  function sideNav() {
    const route = state.route;
    const docLink = (id) => {
      const [, ic, title] = DOCS.find((d) => d[0] === id);
      return `<a class="nav-item sub ${route[1] === id ? "active" : ""}" href="#/docs/${id}">${icon(ic)}${title}</a>`;
    };
    $("#sidebar").innerHTML =
      `<div><a class="nav-item ${route.length === 0 ? "active" : ""}" href="#/">${icon("grid")}Catalog</a></div>
      <div><p class="nav-label">Data Product</p><a class="nav-item ${route[0] === "product" ? "active" : ""}" href="#/product/sales-funnel">${icon("funnel")}Sales Funnel</a><div class="nav-family">${docLink("business")}<p class="nav-sub-label">${icon("chart")}Reports</p><div class="nav-reports">${P.map((p) => `<a class="nav-item sub ${route[1] === p.id ? "active" : ""}" href="${reportHref(p)}">${icon(p.icon)}${p.title}</a>`).join("")}</div>${docLink("methodology")}${docLink("technical")}</div></div>
      <div class="sidebar-bottom"><a class="nav-item ${route[0] === "about" ? "active" : ""}" href="#/about">${icon("info")}About this catalog</a></div>`;
    $("#bag-count").textContent = state.basket.length;
    $(".request-bag").setAttribute(
      "aria-label",
      `Access request, ${state.basket.length} ${state.basket.length === 1 ? "Report" : "Reports"}`,
    );
  }
  function funnelChart(p, m) {
    const data = rows(p)
      .filter((r) => r.month === m)
      .sort((a, b) => stepOrder(a.funnel_step) - stepOrder(b.funnel_step));
    const max = Math.max(...data.map((r) => r.deals_count), 1);
    const legend =
      p.id === "monthly-funnel"
        ? `<div class="chart-legend"><span><i></i>Deal stages</span><span><i class="call"></i>Sales calls</span></div>`
        : "";
    return `${legend}<div class="bar-list" role="img" aria-label="${esc(p.title)}, ${month(m, true)}: ${data.map((r) => `${esc(r.kpi_name)} ${r.deals_count}`).join(", ")}">${data.map((r) => `<div class="bar-row"><span class="bar-label">${esc(r.kpi_name)}</span><div class="bar-track"><div class="bar-fill ${r.funnel_step.includes(".") ? "call" : ""}" style="width:${(r.deals_count / max) * 100}%"></div></div><span class="bar-value">${fmt(r.deals_count)}</span></div>`).join("")}</div>`;
  }
  function productCard() {
    return `<a class="product-card" href="#/product/sales-funnel"><div class="product-card-copy"><h3>Sales Funnel</h3><p>How deals move through our deal stages, where open deals stand, and how far the data can be trusted.</p><span class="text-link">Open Data Product ${icon("arrow")}</span></div><div class="product-card-chart"><h4>Monthly sales funnel · ${month(FEATURED_MONTH, true)}</h4>${coverageNote(P[0], FEATURED_MONTH)}${funnelChart(P[0], FEATURED_MONTH)}</div></a>`;
  }
  function reportCard(p) {
    return `<article class="report-card">${productIcon(p)}<h3><a href="${reportHref(p)}">${p.title}</a></h3><p>${p.question}</p></article>`;
  }
  function searchWords(q) {
    const stop = new Set([
      "which",
      "what",
      "where",
      "when",
      "how",
      "many",
      "the",
      "a",
      "an",
      "is",
      "are",
      "was",
      "were",
      "i",
      "my",
      "me",
      "we",
      "our",
      "this",
      "that",
      "can",
      "do",
      "does",
      "did",
      "for",
      "to",
      "of",
      "in",
      "at",
      "by",
      "and",
      "show",
      "find",
      "give",
      "need",
      "want",
      "dataset",
      "datasets",
      "data",
      "product",
      "products",
      "report",
      "reports",
      "please",
    ]);
    return q
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, " ")
      .trim()
      .split(/\s+/)
      .filter((w) => w && !stop.has(w));
  }
  function queryMatch(p, q) {
    const text = [
      p.title,
      p.model,
      p.kind,
      p.description,
      portData(p).description,
      p.question,
      p.use.join(" "),
      p.keywords,
      p.unit,
      p.grain,
      p.date,
      ...(portData(p).meta.kpis || []).map((k) =>
        [k.kpi_name, k.funnel_step, k.definition, k.aggregation].join(" "),
      ),
    ]
      .join(" ")
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, " ");
    return searchWords(q).every((word) => text.includes(word));
  }
  function updateResults() {
    const found = P.filter((p) => queryMatch(p, state.query));
    $("#result-count").textContent = state.query
      ? `${found.length} ${found.length === 1 ? "Report" : "Reports"} matching “${state.query}”`
      : "";
    $("#report-results").innerHTML = found.length
      ? found.map(reportCard).join("")
      : `<div class="empty">${icon("search")}<h3>No matching Reports</h3><p>${/revenue|win.?rate|conversion|forecast/i.test(state.query) ? "Our Reports don’t cover revenue, win rate, conversion or forecasts." : "Try “pipeline”, “calls”, “coverage” or a table name."}</p><button class="button small" data-action="clear-query">Clear search</button></div>`;
    const product = $("#product-discovery");
    if (product)
      product.hidden =
        !!state.query &&
        !found.length &&
        !searchWords(state.query).every((w) =>
          "sales funnel pipedrive monthly".includes(w),
        );
    const clear = $(".clear-search");
    if (clear) clear.hidden = !state.query;
  }
  function home() {
    return `<div class="page"><section class="sr-only"><h1>Data Product Catalog</h1></section>
      <div class="search-zone"><label class="searchbox" for="catalog-search">${icon("search")}<input id="catalog-search" type="search" autocomplete="off" placeholder="Search a question, KPI or table…" value="${esc(state.query)}" aria-label="Search Data Products and Reports"><button class="clear-search" data-action="clear-query" aria-label="Clear search" ${state.query ? "" : "hidden"}>Clear</button><kbd>/</kbd></label></div>
      <section id="product-discovery"><h2 class="section-title">Data Products</h2>${productCard()}</section>
      <section aria-labelledby="reports-heading"><h2 class="section-title" id="reports-heading">Reports</h2><div id="result-count" class="result-count" role="status" aria-live="polite"></div><div id="report-results" class="card-grid"></div></section>${footer()}</div>`;
  }
  function usePanels(use, avoid, noun) {
    return `<div class="two-col"><section class="use-panel"><h3>${icon("check")}Use this ${noun} for</h3><ul class="plain-list">${use.map((x) => `<li>${esc(x)}</li>`).join("")}</ul></section><section class="use-panel avoid"><h3>${icon("x")}Do not use this ${noun} for</h3><ul class="plain-list">${avoid.map((x) => `<li>${esc(x)}</li>`).join("")}</ul></section></div>`;
  }
  function callout(text, info = false) {
    return `<div class="callout ${info ? "info" : ""}">${icon(info ? "info" : "warn")}<div>${text}</div></div>`;
  }
  function voteControls(item) {
    const vote = state.votes[item.id] || 0;
    const button = (dir, label, path) =>
      `<button class="vote-button" data-action="vote" data-id="${item.id}" data-dir="${dir}" aria-label="Vote ${label}: ${esc(item.title)}" aria-pressed="${vote === dir}">${icon(path)}</button>`;
    return `<div class="vote" id="vote-${item.id}">${button(1, "up", "up")}<span class="vote-count">${vote}</span>${button(-1, "down", "down")}</div>`;
  }
  function roadmap(below) {
    return `<section id="roadmap"><div class="table-wrap"><table class="roadmap-table"><thead><tr><th class="num">Priority</th><th>Initiative</th><th>Status</th><th>Votes</th></tr></thead><tbody>${ROADMAP.map((item, i) => `<tr><td class="num">${i + 1}</td><td>${esc(item.title)}</td><td class="nowrap"><span class="roadmap-status ${item.status === "Proposed" ? "proposed" : ""}">${esc(item.status)}</span></td><td>${voteControls(item)}</td></tr>`).join("")}</tbody></table></div>${below}<p class="roadmap-note">Statuses: Proposed, In consideration, Not planned. Votes stay in this browser.</p><button class="button" data-action="suggest">Make a suggestion</button><dialog id="suggest-dialog" aria-labelledby="suggest-title"><h3 id="suggest-title">Make a suggestion</h3><p>This is a mockup button. It isn’t connected to a backend yet.</p><form method="dialog"><button class="button primary">OK</button></form></dialog></section>`;
  }
  function product() {
    const assumptions = [
      [
        "Skipped deal stages count as reached",
        "A deal that moves from Qualified Lead straight to Negotiation also counts in the deal stages between them, on the date of the move. A deal counts once per deal stage per month.",
      ],
      [
        "Sales calls use their due date",
        "Only completed calls count. The data has no completion time, so the due date sets the month.",
      ],
      [
        "Conflicting records are left out, and listed",
        "Activities that share an ID and deals with more than one creation record are left out of the Reports. You’ll find them in Records for review.",
      ],
      [
        "Open deals are an estimate",
        "A deal stays in its last recorded deal stage until it gets a lost reason. Won, reopened and deleted deals can’t be identified.",
      ],
      [
        "Zero means nothing was recorded",
        "It doesn’t prove nothing happened. Sales calls and new deals stop on 13 September 2024, and deal stage changes on 24 February 2025.",
      ],
      [
        "Owners are the owners recorded",
        "Each owner holds a deal from the recorded change until the next one. A deal has no recorded owner before its first one.",
      ],
      [
        "Lead Generation uses its recorded date",
        "A deal enters Lead Generation on the date recorded for that deal stage, not on the date the deal was created.",
      ],
      [
        "The order of sales calls is a working assumption",
        "We assume Qualified Lead, Sales Call 1, an optional Needs Assessment and Sales Call 2, then Proposal/Quote Preparation. The data links calls to deals too rarely to confirm this, so no Report depends on it.",
      ],
    ];
    return `<div class="page">${breadcrumb([["Sales Funnel"]])}<div class="page-heading"><div><div class="eyebrow">Data Product</div><h1>Sales Funnel<span class="heading-dot">.</span></h1></div><div class="actions">${requestButton("product")}</div></div><div class="single">
      <section class="detail-section"><h2>Purpose</h2><p>Our mission is to make renewable energy accessible to everyone, and every home we reach starts as a deal. This Data Product gives us one trusted monthly view of how deals move through our deal stages, where open deals stand, and which data needs a closer look.</p></section>
      <section class="detail-section"><h2>Use cases</h2>${usePanels(["Compare monthly deal volume at a deal stage.", "See how many open deals sit in each deal stage at month end.", "See who last owned a deal.", "See which months may be incomplete."], ["Revenue, win rate or forecasts.", "Conversion between deal stages.", "Following one group of deals through the funnel."], "Data Product")}</section>
      <section class="detail-section"><h2>Reports</h2><div class="card-grid">${P.map(reportCard).join("")}</div></section>
      <section class="detail-section"><h2>The funnel in ${month(FEATURED_MONTH, true)}</h2><div class="preview-panel plain">${coverageNote(P[0], FEATURED_MONTH)}${funnelChart(P[0], FEATURED_MONTH)}</div></section>
      <section class="detail-section"><h2>Assumptions</h2>${assumptions.map(([title, text]) => `<details class="accordion"><summary>${esc(title)}${icon("down")}</summary><div class="accordion-body"><p>${esc(text)}</p></div></details>`).join("")}</section>
      <section class="detail-section"><h2>Documentation</h2><div class="doc-links">${DOCS.map(([id, ic, title]) => `<a class="aside-link" href="#/docs/${id}">${title} ${icon("arrow")}</a>`).join("")}</div></section>
      <section class="detail-section"><h2>Technical details</h2><p>Source: Pipedrive CRM. Data covers ${month(months[0])} to ${month(months.at(-1))}. Data flows through Raw, ODS, Core and Reporting layers in dbt, on PostgreSQL.</p><div class="source-list">${Object.entries(
        S.source_rows,
      )
        .map(
          ([name, count]) =>
            `<div class="source-row"><code>${name}</code><span>${fmt(count)} rows</span></div>`,
        )
        .join("")}</div></section></div>${footer()}</div>`;
  }

  // REPORT VIEWS
  function report(p, tab) {
    const tabs = [
      ["overview", "Overview"],
      ["definitions", "Definitions"],
      ["technical", "Technical"],
    ];
    if (!tabs.some((t) => t[0] === tab)) tab = "overview";
    return `<div class="page">${breadcrumb([["Sales Funnel", "#/product/sales-funnel"], [p.title]])}<div class="page-heading"><div><div class="eyebrow">${p.kind}</div><h1>${p.title}<span class="heading-dot">.</span></h1></div><div class="actions">${requestButton(p.id)}</div></div>
      <nav class="tabs" aria-label="Report sections">${tabs.map(([key, label]) => `<a class="tab ${tab === key ? "active" : ""}" href="${reportHref(p, key)}" ${tab === key ? 'aria-current="page"' : ""}>${label}</a>`).join("")}</nav>
      <div class="single">${tab === "overview" ? overview(p) : tab === "definitions" ? definitions(p) : technical(p)}</div>${footer()}</div>`;
  }
  function overview(p) {
    return `<section class="detail-section"><h2>Purpose</h2><p><strong>${p.question}</strong> ${p.description}</p></section>
      <section class="detail-section"><h2>Use cases</h2>${usePanels(p.use, p.avoid, "Report")}${callout(esc(p.caveat))}</section>
      <section class="detail-section"><h2>The data</h2>${preview(p)}</section>`;
  }
  function previewState(p) {
    if (!state.preview[p.id])
      state.preview[p.id] = {
        mode: "stages",
        month: FEATURED_MONTH,
        step: "Step 2",
        status: "warn",
        qualityMonth: "all",
        reason: "all",
        owners: "all",
        query: "",
        page: 0,
      };
    return state.preview[p.id];
  }

  function selectOptions(values, selected) {
    return values
      .map(
        ([value, label]) =>
          `<option value="${esc(value)}" ${value === selected ? "selected" : ""}>${esc(label)}</option>`,
      )
      .join("");
  }
  function selectField(label, key, options, p) {
    return `<label class="field">${label}<select data-preview="${key}" data-id="${p.id}" aria-label="${label}">${selectOptions(options, previewState(p)[key])}</select></label>`;
  }
  function preview(p) {
    return `<div class="preview-panel" id="preview-${p.id}" data-report="${p.id}"><div class="preview-selects">${
      p.id === "last-owner"
        ? selectField(
            "Deals",
            "owners",
            [
              ["all", "All deals"],
              ["changed", "Changed owner"],
            ],
            p,
          )
        : p.group === "business"
          ? selectField(
              "View",
              "mode",
              [
                ["stages", "By deal stage"],
                ["trend", "Over time"],
              ],
              p,
            ) +
            selectField(
              "Month",
              "month",
              months.map((m) => [m, month(m)]),
              p,
            )
          : p.id === "product-health"
            ? selectField(
                "Status",
                "status",
                [
                  ["all", "All results"],
                  ["warn", "Warnings"],
                  ["pass", "Passed"],
                  ["fail", "Failed"],
                ],
                p,
              ) +
              selectField(
                "Month",
                "qualityMonth",
                [
                  ["all", "All periods"],
                  ["dataset", "Whole dataset"],
                  ...months.map((m) => [m, month(m)]),
                ],
                p,
              )
            : selectField(
                "Reason",
                "reason",
                [
                  ["all", "All reasons"],
                  ["duplicate_activity_id", "Conflicting activity ID"],
                  ["multiple_deal_creations", "Multiple deal creations"],
                ],
                p,
              )
    }</div><div class="preview-body" id="preview-body-${p.id}">${previewBody(p)}</div><div class="preview-note"><a href="data/${p.model}.csv" download class="text-link">Download all ${rows(p).length} rows as CSV ${icon("download")}</a></div></div>`;
  }
  function coverageNote(p, m) {
    const notes = {
      activity_coverage:
        "Sales calls and new deals stop on 13 September 2024, so sales calls and early deal stages are incomplete or 0 this month.",
      stage_coverage:
        "Deal stage changes stop on 24 February 2025, so this month is incomplete.",
    };
    const warns = qualityRows().filter(
      (r) =>
        r.month === m &&
        r.status !== "pass" &&
        (p.id === "monthly-funnel"
          ? r.check_name in notes
          : r.check_name === "stage_coverage"),
    );
    return warns.length
      ? `<div class="coverage-note">${icon("warn")}<div>${warns.map((w) => notes[w.check_name]).join("<br>")}</div></div>`
      : "";
  }
  function previewBody(p) {
    const v = previewState(p);
    if (p.id === "last-owner") return ownerPreview(p);
    if (p.group !== "business") return assurancePreview(p);
    const note = coverageNote(p, v.month);
    if (v.mode === "trend") {
      const series = rows(p).filter((r) => r.funnel_step === v.step),
        selected = series.find((r) => r.month === v.month);
      const stages = S.steps
        .filter((s) => p.id === "monthly-funnel" || s.stage_id)
        .map((s) => [s.funnel_step, s.kpi_name]);
      return `<div class="trend-select">${selectField(p.id === "monthly-funnel" ? "Deal stage or sales call" : "Deal stage", "step", stages, p)}</div>${note}<div class="trend-summary"><strong>${fmt(selected?.deals_count || 0)}</strong><span>${esc(selected?.kpi_name || "")} · ${month(v.month)}</span></div>${trendChart(series, v.month, p)}<details class="data-details"><summary>Show the numbers</summary>${businessTable(series)}</details>`;
    }
    return `${note}${funnelChart(p, v.month)}${callout(p.id === "monthly-funnel" ? "Don’t add bars together or read them as conversion rates." : "Each bar estimates the open deals in that deal stage at month end.", true)}`;
  }
  function trendChart(series, selected, p) {
    const W = 620,
      H = 230,
      L = 40,
      R = 14,
      T = 18,
      B = 42,
      plotW = W - L - R,
      plotH = H - T - B,
      max = Math.max(...series.map((r) => r.deals_count), 1),
      top = Math.ceil(max / 50) * 50;
    const x = (i) => L + (i * plotW) / (series.length - 1 || 1),
      y = (v) => T + plotH - (v / top) * plotH;
    const line = series.map((r, i) => `${x(i)},${y(r.deals_count)}`).join(" "),
      area = `M${L},${T + plotH} L${line.replace(/ /g, " L")} L${x(series.length - 1)},${T + plotH} Z`;
    return `<svg class="trend-chart" viewBox="0 0 ${W} ${H}" role="img" aria-label="Monthly ${esc(series[0]?.kpi_name || "")} trend. Open Show the numbers for exact values.">${[0, 0.5, 1].map((f) => `<path d="M${L} ${y(top * f)}H${W - R}" stroke="#e1e8ee" stroke-width="1"/><text x="${L - 9}" y="${y(top * f) + 3}" text-anchor="end" font-family="Poppins,sans-serif" font-size="9" fill="#8298aa">${fmt(top * f)}</text>`).join("")}<path d="${area}" fill="#eaf1f7"/><polyline points="${line}" fill="none" stroke="#285878" stroke-width="2.5" stroke-linejoin="round"/>${series.map((r, i) => `<circle cx="${x(i)}" cy="${y(r.deals_count)}" r="${r.month === selected ? 5.5 : 3}" fill="${r.month === selected ? "#ffd233" : "#426a89"}" stroke="white" stroke-width="1.5"><title>${month(r.month)}: ${r.deals_count}</title></circle>${[0, 3, 6, 9, series.length - 1].includes(i) ? `<text x="${x(i)}" y="${H - 14}" text-anchor="middle" fill="#7a91a5" font-family="Poppins,sans-serif" font-size="9">${month(r.month)}</text>` : ""}`).join("")}</svg>`;
  }
  function businessTable(data) {
    return `<div class="table-wrap"><table><caption class="sr-only">Monthly values</caption><thead><tr><th>Month</th><th class="num">Deals</th></tr></thead><tbody>${data.map((r) => `<tr><td class="nowrap">${month(r.month)}</td><td class="num">${fmt(r.deals_count)}</td></tr>`).join("")}</tbody></table></div>`;
  }
  function ownerPreview(p) {
    const v = previewState(p),
      all = rows(p),
      results = all.filter(
        (r) =>
          (v.owners === "all" || r.owner_count > 1) &&
          [r.deal_id, r.owner_user_id, r.owner_name]
            .join(" ")
            .toLowerCase()
            .includes(v.query.toLowerCase()),
      ),
      summary = [
        ["Deals", all.length],
        ["Changed owner", all.filter((r) => r.owner_count > 1).length],
      ];
    return `<div class="review-summary">${summary
      .map(
        ([label, count]) =>
          `<div class="review-summary-item"><span>${label}</span><strong>${fmt(count)}</strong></div>`,
      )
      .join(
        "",
      )}</div><label class="field" style="margin-top:18px">Find a deal<input class="data-filter" data-review-search="${p.id}" aria-label="Find a deal by ID or owner" value="${esc(v.query)}" placeholder="Deal ID or owner name…" type="search"></label>${pagedTable(
      p,
      results,
      5,
      (r) =>
        `<tr><td>${r.deal_id}</td><td>${esc(r.owner_name)}</td><td class="nowrap">${day(r.owner_since)}</td><td class="num">${r.owner_count}</td><td>${esc(r.current_stage)}</td><td>${esc(r.deal_status)}</td></tr>`,
      `<th>Deal</th><th>Last owner</th><th>Owner since</th><th class="num">Owners</th><th>Deal stage</th><th>Status</th>`,
    )}`;
  }
  function assurancePreview(p) {
    const v = previewState(p);
    if (p.id === "product-health") {
      let results = rows(p).filter(
        (r) =>
          (v.status === "all" || r.status === v.status) &&
          (v.qualityMonth === "all" ||
            (v.qualityMonth === "dataset" && !r.month) ||
            r.month === v.qualityMonth),
      );
      const table = pagedTable(
        p,
        results,
        8,
        (r) =>
          `<tr><td><code>${esc(r.check_name)}</code></td><td class="nowrap">${r.month ? month(r.month) : "Whole dataset"}</td><td><span class="status ${r.status}">${r.status}</span></td><td>${esc(r.detail)}</td></tr>`,
        `<th>Check</th><th>Period</th><th>Status</th><th>Detail</th>`,
      );
      return `${callout(`Data exported ${exported()}. Deal stage changes run to 24 February 2025. Sales calls and new deals run to 13 September 2024.`, true)}<div class="quality-stats">${[
        ["pass", "Passed"],
        ["warn", "Warnings"],
        ["fail", "Failed"],
      ]
        .map(
          ([s, label]) =>
            `<div class="quality-stat ${s}"><strong>${statCount(s)}</strong><span>${label}</span></div>`,
        )
        .join("")}</div>${table}`;
    }
    const review = rows(p),
      groups = {};
    review.forEach((r) => {
      if (!groups[r.dq_reason])
        groups[r.dq_reason] = { rows: 0, ids: new Set() };
      groups[r.dq_reason].rows++;
      groups[r.dq_reason].ids.add(r.record_id ?? r.deal_id);
    });
    const results = review.filter(
      (r) =>
        (v.reason === "all" || r.dq_reason === v.reason) &&
        [
          r.deal_id,
          r.record_id,
          r.record_key,
          r.dq_reason,
          JSON.stringify(r.source_record),
        ]
          .join(" ")
          .toLowerCase()
          .includes(v.query.toLowerCase()),
    );
    return `<div class="review-summary">${Object.entries(groups)
      .map(
        ([reason, g]) =>
          `<div class="review-summary-item"><span>${reason === "duplicate_activity_id" ? "Conflicting activity IDs" : "Repeated deal creations"}</span><strong>${g.ids.size} IDs <small>· ${g.rows} records</small></strong></div>`,
      )
      .join(
        "",
      )}</div><label class="field" style="margin-top:18px">Find a record<input class="data-filter" data-review-search="${p.id}" aria-label="Find a review record by ID or content" value="${esc(v.query)}" placeholder="Deal ID or activity ID…" type="search"></label>${pagedTable(p, results, 5, (r) => `<tr><td><code>${esc(r.source_table)}</code><br>${esc(r.record_id ?? "No row ID")}</td><td class="num">${esc(r.deal_id)}</td><td><code>${esc(r.dq_reason)}</code></td><td><details class="record-details"><summary>Inspect record</summary><div class="record-json"><span>record_key</span><code>${esc(r.record_key)}</code><pre>${esc(JSON.stringify(r.source_record, null, 2))}</pre></div></details></td></tr>`, '<th>Source / record ID</th><th class="num">Deal ID</th><th>Exclusion reason</th><th>Evidence</th>')}`;
  }
  function pagedTable(p, data, size, row, headers) {
    const v = previewState(p),
      pages = Math.max(1, Math.ceil(data.length / size));
    v.page = Math.min(v.page, pages - 1);
    const start = v.page * size;
    return `<div class="table-wrap"><table><thead><tr>${headers}</tr></thead><tbody>${
      data.length
        ? data
            .slice(start, start + size)
            .map(row)
            .join("")
        : `<tr><td colspan="8" class="empty-cell">No matching records.</td></tr>`
    }</tbody></table></div><div class="pagination" role="status"><span>${data.length ? `${start + 1}–${Math.min(start + size, data.length)} of ${data.length} matching rows` : "0 matching rows"}</span><div><button class="button small" data-action="page" data-id="${p.id}" data-dir="-1" ${v.page === 0 ? "disabled" : ""}>Previous</button><button class="button small" data-action="page" data-id="${p.id}" data-dir="1" ${v.page >= pages - 1 ? "disabled" : ""}>Next</button></div></div>`;
  }
  function refreshPreview(p) {
    const body = $(`#preview-body-${p.id}`);
    if (body) body.innerHTML = previewBody(p);
  }
  function schema(p) {
    return `<div class="table-wrap"><table class="schema-table"><thead><tr><th>Column</th><th>Type</th><th>Meaning</th></tr></thead><tbody>${portData(
      p,
    )
      .columns.map(
        (c) =>
          `<tr><td>${esc(c.name)}</td><td>${esc(c.type)}</td><td>${inline(c.description)}</td></tr>`,
      )
      .join("")}</tbody></table></div>`;
  }
  function highlightSQL(code) {
    return esc(code)
      .split("\n")
      .map((line) =>
        line.trim().startsWith("--")
          ? `<span class="sql-comment">${line}</span>`
          : line.replace(
              /\b(select|from|where|and|or|as|group by|order by|case|when|then|else|end|count|distinct|sum|filter|in|is not null|is null|true|false|desc|asc|with|join|on|limit|left join|inner join|date)\b/gi,
              '<span class="sql-key">$1</span>',
            ),
      )
      .join("\n");
  }
  const codeRegistry = new Map();
  function codeBlock(code, label = "PostgreSQL") {
    const id = "code-" + codeRegistry.size;
    codeRegistry.set(id, code);
    return `<div class="code-block"><div class="code-head"><span>${label}</span><button class="copy-button" data-action="copy" data-code="${id}" aria-label="Copy ${esc(label)}">${icon("copy")}${label === "Local terminal" ? "Copy command" : "Copy SQL"}</button></div><pre><code>${highlightSQL(code)}</code></pre></div>`;
  }
  function sqlExamples(p) {
    const relation = S.schema + "." + p.model;
    if (p.id === "monthly-funnel")
      return [
        [
          "Monthly Qualified Lead trend",
          "Each month holds different deals.",
          `select month, kpi_name, deals_count\nfrom ${relation}\nwhere funnel_step = 'Step 2'\norder by month;`,
        ],
        [
          "Completed first calls in July",
          "The month comes from the due date. Calls aren’t linked to deal stages.",
          `select month, kpi_name, deals_count\nfrom ${relation}\nwhere month = date '2024-07-01'\n  and funnel_step = 'Step 2.1';`,
        ],
        [
          "See every deal stage and sales call in order",
          "Use the seed’s step_order, not text sorting: Step 2.1 belongs between Step 2 and Step 3.",
          `select r.month, r.kpi_name, r.funnel_step, r.deals_count\nfrom ${relation} as r\njoin public_pipedrive_core.funnel_steps as s\n  on r.funnel_step = s.funnel_step\nwhere r.month = date '2024-07-01'\norder by s.step_order;`,
        ],
      ];
    if (p.id === "month-end-pipeline")
      return [
        [
          "Open deals by deal stage in July",
          "Each deal sits in at most one deal stage at month end. The total is an estimate.",
          `select r.kpi_name, r.deals_count\nfrom ${relation} as r\njoin public_pipedrive_core.funnel_steps as s\n  on r.funnel_step = s.funnel_step\nwhere r.month = date '2024-07-01'\norder by s.step_order;`,
        ],
        [
          "Open deals in Negotiation over time",
          "This is the position at each month end, not the deals entering Negotiation.",
          `select month, deals_count as estimated_open_in_negotiation\nfrom ${relation}\nwhere funnel_step = 'Step 5'\norder by month;`,
        ],
        [
          "Estimated open deals by month",
          "This Report can be added up across deal stages within a month, because a deal sits in only one.",
          `select month, sum(deals_count) as estimated_open_deals\nfrom ${relation}\ngroup by month\norder by month;`,
        ],
      ];
    if (p.id === "last-owner")
      return [
        [
          "List a last owner’s deals",
          "Names can repeat, so filter on the ID.",
          `select deal_id, owner_name, owner_since, current_stage, deal_status\nfrom ${relation}\nwhere owner_user_id = 13\norder by owner_since;`,
        ],
        [
          "Deals that changed owner",
          "",
          `select deal_id, owner_name, owner_since, owner_count\nfrom ${relation}\nwhere owner_count > 1\norder by owner_since;`,
        ],
        [
          "Who owned a deal on a given date",
          "Uses the full history in dim_deal_owner.",
          `select deal_id, owner_user_id, valid_from, valid_to\nfrom public_pipedrive_core.dim_deal_owner\nwhere timestamp '2024-06-01' >= valid_from\n  and (timestamp '2024-06-01' < valid_to or valid_to is null)\norder by deal_id;`,
        ],
      ];
    if (p.id === "product-health")
      return [
        [
          "Find warnings and failures",
          "",
          `select check_name, month, severity, status,\n       expected_value, actual_value, detail\nfrom ${relation}\nwhere status in ('warn', 'fail')\norder by month nulls first, check_name;`,
        ],
        [
          "Check coverage for a month",
          "A zero only means something if the data covers that month.",
          `select check_name, month, status, detail\nfrom ${relation}\nwhere month = date '2024-09-01'\n  and check_name in ('stage_coverage', 'activity_coverage')\norder by check_name;`,
        ],
      ];
    return [
      [
        "Summarize the records left out",
        "Records and IDs are counted separately. Neither is a sales figure.",
        `select source_table, dq_reason,\n       count(*) as excluded_records,\n       count(distinct coalesce(record_id, deal_id)) as source_ids\nfrom ${relation}\ngroup by source_table, dq_reason\norder by source_table, dq_reason;`,
      ],
      [
        "Inspect conflicting activity records",
        "All versions stay listed until the source is corrected.",
        `select record_key, record_id, deal_id, source_record\nfrom ${relation}\nwhere dq_reason = 'duplicate_activity_id'\norder by record_id, record_key\nlimit 20;`,
      ],
    ];
  }
  function definitions(p) {
    if (p.id === "monthly-funnel")
      return `<section class="detail-section"><h2>How it’s counted</h2><p>Each number counts the different deals in that deal stage and month. A deal can count in several deal stages in one month, and again in later months.</p>${callout("Don’t add deal stages into a total, or divide one by another to get a conversion rate. Deal stages and sales calls aren’t linked.")}</section><section class="detail-section"><h2>Deal stages and sales calls</h2><div class="table-wrap"><table><thead><tr><th>Name</th><th>What it counts</th><th>Date used</th></tr></thead><tbody>${portData(
        p,
      )
        .meta.kpis.map(
          (k) =>
            `<tr><td>${esc(k.kpi_name)}</td><td>${inline(k.definition.replace(/stage \d/, k.kpi_name))}</td><td>${k.date_field === "due_at" ? "Due date" : "Date it entered"}</td></tr>`,
        )
        .join(
          "",
        )}</tbody></table></div></section><section class="detail-section"><h2>Rules</h2><ul class="plain-list"><li>Skipped deal stages count as reached, on the date of the move.</li><li>Repeated and backward moves count as new entries.</li><li>When two moves share a timestamp, the earlier deal stage comes first.</li><li>Records with conflicting IDs are left out. See Records for review.</li></ul></section>`;
    if (p.id === "month-end-pipeline")
      return `<section class="detail-section"><h2>How it’s counted</h2><p>For each deal, we take the last deal stage recorded by the end of the month. The deal is left out if it has a lost reason before the next month begins.</p>${callout("This is an estimate. A lost reason is the only sign that a deal has closed, so won, reopened and deleted deals can’t be identified.")}</section><section class="detail-section"><h2>Rules</h2><ul class="plain-list"><li>A deal sits in at most one deal stage at each month end.</li><li>A deal with no recorded deal stage yet is left out.</li><li>Skipped deal stages are passed, not held.</li><li>When two moves share a timestamp, the earlier deal stage comes first.</li><li>The last month is read at calendar month end, even if the data stops earlier.</li></ul></section>`;
    if (p.id === "last-owner")
      return `<section class="detail-section"><h2>How it’s read</h2><p>Each row is one deal. The last owner is the most recent owner recorded for it in Pipedrive, and a deal has no recorded owner before its first one.</p></section><section class="detail-section"><h2>Terms</h2><div class="table-wrap"><table><thead><tr><th>Term</th><th>Meaning</th></tr></thead><tbody><tr><td>Owner since</td><td>The date the last owner was recorded.</td></tr><tr><td>Owners</td><td>How many owners the deal has had. A returning owner counts again.</td></tr><tr><td>Deal stage</td><td>The last deal stage the deal entered.</td></tr><tr><td>Status</td><td>Lost if the deal has a lost reason, otherwise open. An estimate, because the data has no deal status.</td></tr></tbody></table></div></section>`;
    if (p.id === "product-health") {
      const descriptions = {
        raw_tables_loaded: "All six source tables have rows.",
        exact_duplicates_in_raw: "Exact duplicate rows are removed.",
        stage_row_acceptance_rate:
          "At least 95% of deal stage rows are accepted.",
        sales_call_acceptance_rate:
          "At least 95% of sales call rows are accepted.",
        accepted_plus_review_balances:
          "Accepted and left-out records add up to the source.",
        accepted_data_in_every_month:
          "Every month with source data has accepted rows.",
        funnel_steps_complete: "All 11 deal stages and sales calls are set up.",
        stage_steps_reconcile: "Deal stage counts match a separate recount.",
        call_steps_reconcile: "Sales call counts match a separate recount.",
        unmapped_stage: "Every recorded deal stage is recognised.",
        unmapped_activity_type: "Every sales call type is recognised.",
        stage_coverage: "Deal stage data reaches the end of the month.",
        activity_coverage: "Sales call data reaches the end of the month.",
      };
      const distinct = [
        ...new Map(rows(p).map((r) => [r.check_name, r])).values(),
      ];
      return `<section class="detail-section"><h2>What a status means</h2><p>A warning means look into it before using the figure. A failure stops the business Reports from updating.</p></section><section class="detail-section"><h2>The checks</h2><div class="table-wrap"><table><thead><tr><th>Check</th><th>What it confirms</th></tr></thead><tbody>${distinct.map((r) => `<tr><td><code>${esc(r.check_name)}</code></td><td>${esc(descriptions[r.check_name] || r.detail)}</td></tr>`).join("")}</tbody></table></div></section>`;
    }
    return `<section class="detail-section"><h2>Why a record is left out</h2><div class="table-wrap"><table><thead><tr><th>Reason</th><th>Meaning</th></tr></thead><tbody><tr><td><code>multiple_deal_creations</code></td><td>A deal has more than one creation record. All its history rows are listed here, and none count in the Reports.</td></tr><tr><td><code>duplicate_activity_id</code></td><td>Different activities share one ID. All of them are listed here, and none count in the Reports.</td></tr></tbody></table></div></section>`;
  }
  function upstream(name, seen = new Set()) {
    if (seen.has(name)) return seen;
    seen.add(name);
    const n = S.lineage[name];
    if (n) n.refs.forEach((ref) => upstream(ref, seen));
    return seen;
  }
  function technical(p) {
    const direct = S.lineage[p.model]?.refs || [];
    const businessCore =
      p.id === "monthly-funnel"
        ? ["fct_deal_stage_entry", "fct_activity"]
        : p.id === "month-end-pipeline"
          ? ["fct_deal_stage_month_end"]
          : p.id === "last-owner"
            ? ["dim_deal_owner", "dim_deal", "dim_user", "dim_stage"]
            : p.id === "records-for-review"
              ? ["fct_deal_change", "fct_activity"]
              : ["fct_deal_change", "fct_activity", "fct_deal_stage_entry"];
    const mapping =
      p.id === "monthly-funnel"
        ? `<section class="detail-section"><h2>KPI mapping</h2><p><code>funnel_step</code> holds the reporting label for each deal stage or sales call.</p><div class="table-wrap"><table class="kpi-map"><thead><tr><th>funnel_step</th><th>kpi_name</th><th>Source</th><th>Rule</th><th>Date</th></tr></thead><tbody>${portData(
            p,
          )
            .meta.kpis.map(
              (k) =>
                `<tr><td class="nowrap">${esc(k.funnel_step)}</td><td>${esc(k.kpi_name)}</td><td><code>${esc(k.source_model)}</code></td><td><code>${esc(k.filter)}</code></td><td><code>${esc(k.date_field)}</code></td></tr>`,
            )
            .join("")}</tbody></table></div></section>`
        : "";
    const key =
      p.id === "records-for-review"
        ? `<p class="space-top"><code>record_key</code> is an MD5 hash of the source table and full source JSON. It tells rows apart when an ID repeats. It isn’t an anonymisation mechanism.</p>`
        : "";
    return `<section class="detail-section"><h2>Table</h2><div class="table-wrap"><table><tbody><tr><td>Table</td><td><code>${S.schema}.${p.model}</code></td></tr><tr><td>One row per</td><td>${p.grain}</td></tr><tr><td>Measure</td><td>${p.unit}</td></tr><tr><td>Date</td><td>${p.date}</td></tr><tr><td>Delivery</td><td>PostgreSQL table and CSV</td></tr></tbody></table></div></section>
      <section class="detail-section"><h2>Columns</h2>${schema(p)}${key}</section>${mapping}
      <section class="detail-section"><h2>Example SQL</h2>${sqlExamples(p)
        .map(
          ([title, desc, code]) =>
            `<div class="sql-example"><h3>${title}</h3>${desc ? `<p>${desc}</p>` : ""}${codeBlock(code)}</div>`,
        )
        .join("")}</section>
      <section class="detail-section"><h2>Lineage</h2><div class="lineage-flow"><div class="lineage-column"><div class="lineage-label">Source → ODS</div>${(p.id === "month-end-pipeline" ? ["deal_changes", "stages"] : p.id === "last-owner" ? ["deal_changes", "users", "stages"] : ["deal_changes", "activity"]).map((n) => `<div class="lineage-node"><code>pipedrive.${n}</code></div>`).join("")}</div><div class="lineage-arrow">${icon("arrow")}</div><div class="lineage-column"><div class="lineage-label">Core</div>${businessCore.map((n) => `<div class="lineage-node"><code>${n}</code></div>`).join("")}</div><div class="lineage-arrow">${icon("arrow")}</div><div class="lineage-column"><div class="lineage-label">Report</div><div class="lineage-node highlight"><code>${p.model}</code></div></div></div><div class="models-list">${direct.map((n) => `<div class="model-row"><code>${esc(n)}</code>${S.lineage[n] ? `<a href="../${S.lineage[n].path}" target="_blank" rel="noopener">View model SQL ${icon("external")}</a>` : n === "funnel_steps" ? '<a href="../seeds/funnel_steps.csv" download>Download seed ↓</a>' : ""}</div>`).join("")}</div></section>
      <section class="detail-section"><h2>Model SQL</h2><details class="data-details"><summary>Show the dbt model</summary>${codeBlock(S.lineage[p.model]?.sql || "-- Model source not included", "dbt model · " + p.model)}</details><p class="space-top"><a class="text-link" href="data/provenance.json" download>Download export metadata ${icon("download")}</a></p></section>`;
  }

  function safeLink(href) {
    const doc = Object.entries(S.documents).find(
      ([, d]) =>
        href === d.path || href.endsWith("/" + d.path.split("/").at(-1)),
    );
    if (doc) return "#/docs/" + doc[0];
    if (/^https?:\/\//i.test(href)) return href;
    if (/^[a-z][a-z\d+.-]*:/i.test(href) || href.startsWith("//"))
      return "#/about";
    if (href.startsWith("#")) return href;
    return "../" + href.replace(/^\.\.\//, "");
  }
  function inline(text) {
    const tokens = [];
    const token = (html) => {
      tokens.push(html);
      return "\u0000" + (tokens.length - 1) + "\u0000";
    };
    let value = String(text || "").replace(/`([^`]+)`/g, (_, code) =>
      token("<code>" + esc(code) + "</code>"),
    );
    value = value.replace(/\[([^\]]+)\]\(([^)]+)\)/g, (_, label, href) => {
      const url = safeLink(href),
        external = /^https?:/.test(url);
      return token(
        `<a href="${esc(url)}" ${external ? 'target="_blank" rel="noopener noreferrer"' : ""}>${esc(label)}</a>`,
      );
    });
    value = esc(value)
      .replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>")
      .replace(/\*([^*]+)\*/g, "<em>$1</em>");
    return value.replace(/\u0000(\d+)\u0000/g, (_, n) => tokens[Number(n)]);
  }
  function markdown(text) {
    const lines = String(text).replace(/\r/g, "").split("\n");
    let out = "",
      i = 0;
    const cells = (line) =>
      line
        .trim()
        .replace(/^\||\|$/g, "")
        .split("|")
        .map((x) => x.trim());
    const special = (line) =>
      /^(#{1,6} |```|> |[-*] |\d+\. |\|)/.test(line.trim());
    while (i < lines.length) {
      const line = lines[i].trim();
      if (!line) {
        i++;
        continue;
      }
      if (line.startsWith("```")) {
        const code = [];
        i++;
        while (i < lines.length && !lines[i].trim().startsWith("```"))
          code.push(lines[i++]);
        i++;
        out += "<pre><code>" + esc(code.join("\n")) + "</code></pre>";
        continue;
      }
      const head = line.match(/^(#{1,6}) (.+)/);
      if (head) {
        const level = Math.min(head[1].length, 4);
        out += `<h${level}>${inline(head[2])}</h${level}>`;
        i++;
        continue;
      }
      if (
        line.startsWith("|") &&
        i + 1 < lines.length &&
        /^\|?[\s:|\-]+\|/.test(lines[i + 1].trim())
      ) {
        const heads = cells(line);
        i += 2;
        const data = [];
        while (i < lines.length && lines[i].trim().startsWith("|"))
          data.push(cells(lines[i++]));
        out += `<div class="table-wrap"><table><thead><tr>${heads.map((c) => "<th>" + inline(c) + "</th>").join("")}</tr></thead><tbody>${data.map((r) => "<tr>" + r.map((c) => "<td>" + inline(c) + "</td>").join("") + "</tr>").join("")}</tbody></table></div>`;
        continue;
      }
      if (/^[-*] /.test(line) || /^\d+\. /.test(line)) {
        const ordered = /^\d+\./.test(line),
          items = [],
          regex = ordered ? /^\d+\. / : /^[-*] /;
        while (i < lines.length && regex.test(lines[i].trim()))
          items.push(lines[i++].trim().replace(regex, ""));
        const t = ordered ? "ol" : "ul";
        out += `<${t}>${items.map((s) => "<li>" + inline(s) + "</li>").join("")}</${t}>`;
        continue;
      }
      if (line.startsWith("> ")) {
        out += "<blockquote>" + inline(line.slice(2)) + "</blockquote>";
        i++;
        continue;
      }
      if (/^[-*_]{3,}$/.test(line)) {
        out += "<hr>";
        i++;
        continue;
      }
      const paragraph = [line];
      i++;
      while (i < lines.length && lines[i].trim() && !special(lines[i]))
        paragraph.push(lines[i++].trim());
      out += "<p>" + inline(paragraph.join(" ")) + "</p>";
    }
    return out;
  }
  function businessGuide(text) {
    // The Markdown keeps a plain roadmap table. Here it becomes the working controls.
    const [guide, section] = text.replace(/\r/g, "").split(/^(?=## 8\. )/m);
    const [heading, ...rest] = section.split("\n");
    const below = rest.filter((line) => !line.startsWith("|")).join("\n");
    return (markdown(guide) + markdown(heading) + roadmap(markdown(below)))
      .replace(
        /<strong>Use for:<\/strong>/g,
        '<strong class="use-for">Use for:</strong>',
      )
      .replace(
        /<strong>(Don.{1,6}t use for:)<\/strong>/g,
        '<strong class="avoid-for">$1</strong>',
      );
  }
  function documentation(id) {
    const doc = S.documents[id];
    const entry = DOCS.find((d) => d[0] === id);
    if (!doc || !entry) return notFound();
    return `<div class="page">${breadcrumb([["Sales Funnel", "#/product/sales-funnel"], [entry[2]]])}<div class="library-head"><a class="text-link" href="../${doc.path}" download>Download as Markdown ${icon("download")}</a></div><article class="library-doc single prose">${id === "business" ? businessGuide(doc.markdown) : markdown(doc.markdown)}</article>${footer()}</div>`;
  }
  function about() {
    return `<div class="page">${breadcrumb([["About this catalog"]])}<div class="page-heading"><div><h1>About this catalog<span class="heading-dot">.</span></h1></div></div><div class="single">
      <section class="detail-section"><h2>Why it exists</h2><p>Our mission is to make renewable energy accessible to everyone: affordable, independent and intelligently connected. We’re building Europe’s largest energy movement, on our way to its largest virtual power plant.</p><p>We take responsibility for people and the planet, and we hold ourselves to high quality standards.</p></section>
            <section class="detail-section"><h2>Requesting access</h2><p>Request access creates a draft on your device. Send it to the Analytics Engineering team.</p></section>
      <section class="detail-section"><h2>About the data</h2><p>The catalog shows a snapshot, not a live connection.</p><div class="table-wrap"><table><tbody><tr><td>Exported</td><td>${exported()}</td></tr><tr><td>Reporting window</td><td>${month(months[0])} to ${month(months.at(-1))}</td></tr><tr><td>Sales calls and new deals stop</td><td>13 September 2024</td></tr><tr><td>Deal stage changes stop</td><td>24 February 2025</td></tr></tbody></table></div></section>
      <section class="detail-section"><h2>Refreshing the snapshot</h2><p>Run this after a successful dbt build.</p>${codeBlock("python catalog/export_catalog.py", "Local terminal")}<p class="space-top"><a class="text-link" href="data/provenance.json" download>Download export metadata ${icon("download")}</a></p></section><p class="space-top">AI tools full disclosure: Codex and Claude Code were used.</p></div>${footer()}</div>`;
  }
  function basket() {
    const picked = state.basket.map(byId).filter(Boolean);
    return `<div class="page">${breadcrumb([["Access request"]])}<div class="page-heading"><div><div class="eyebrow">Sales Funnel</div><h1>Your access request<span class="heading-dot">.</span></h1></div></div>
      ${picked.length ? `<div class="detail-grid request-grid"><div class="detail-content"><section class="detail-section"><div class="section-head" style="margin-top:0"><h2>Selected Reports</h2><button class="text-button" data-action="clear-basket">Clear all</button></div><div class="basket-list">${picked.map((p) => `<article class="basket-item">${productIcon(p)}<div class="basket-item-main"><a href="${reportHref(p)}"><h3>${p.title}</h3></a><p>${p.question}</p></div><button class="icon-button" data-action="remove-request" data-id="${p.id}" aria-label="Remove ${p.title} from request">${icon("x")}</button></article>`).join("")}</div></section><section class="detail-section"><h2>What decision will this support?</h2><label class="request-purpose-label" for="request-purpose">Intended use <span>(optional)</span></label><textarea id="request-purpose" rows="4" placeholder="For example: compare monthly Qualified Lead volumes and see which months may be incomplete.">${esc(state.purpose)}</textarea></section></div><aside class="detail-aside"><div class="aside-card request-summary"><h3>${picked.length} ${picked.length === 1 ? "Report" : "Reports"}</h3><div class="request-summary-cta"><button class="button primary" data-action="download-request">${icon("download")}Download request</button><button class="button" data-action="copy-request">${icon("copy")}Copy request</button><span>Send the draft to the Analytics Engineering team.</span></div></div></aside></div>` : `<div class="empty basket-empty">${icon("bag")}<h2>No Reports selected yet.</h2><a class="button primary" href="#/">Browse the catalog ${icon("arrow")}</a></div>`}${footer()}</div>`;
  }
  function requestText() {
    const selected = state.basket.map(byId).filter(Boolean);
    return (
      "# Data access request — draft\n\n" +
      "**Status:** draft, not yet sent.\n**Data Product:** Sales Funnel\n**Requested access:** read\n**Delivery:** PostgreSQL tables and CSV exports\n\n" +
      "## Intended use\n\n" +
      (state.purpose.trim() || "To be completed.") +
      "\n\n" +
      "## Requested Reports\n\n" +
      selected
        .map(
          (p) =>
            "### " +
            p.title +
            "\n\nTable: `" +
            S.schema +
            "." +
            p.model +
            "`\n\nUse this Report for:\n" +
            p.use.map((x) => "- " + x).join("\n") +
            "\n\nDo not use this Report for:\n" +
            p.avoid.map((x) => "- " + x).join("\n") +
            "\n\nNote: " +
            p.caveat +
            "\n",
        )
        .join("\n") +
      "\n## Data context\n\nReporting window: " +
      month(months[0]) +
      " to " +
      month(months.at(-1)) +
      ".\nData exported: " +
      exported() +
      ".\nSales calls and new deals stop on 13 September 2024. Deal stage changes stop on 24 February 2025.\n\n" +
      "## What to do next\n\nSend this draft to the Analytics Engineering team. No access has been granted.\n"
    );
  }
  function notFound() {
    return `<div class="page">${breadcrumb([["Page not found"]])}<div class="empty"><h1>Page not found.</h1><p>This link doesn’t match a Data Product or Report.</p><a href="#/" class="button primary">Back to the catalog</a></div></div>`;
  }
  function render() {
    const route = location.hash.replace(/^#\/?/, "").split("/").filter(Boolean);
    state.route = route;
    codeRegistry.clear();
    let html = "",
      title = "Data Product Catalog";
    if (!route.length) html = home();
    else if (route[0] === "product" && route[1] === "sales-funnel") {
      html = product();
      title = "Sales Funnel";
    } else if (route[0] === "reports" && byId(route[1])) {
      const p = byId(route[1]);
      html = report(p, route[2] || "overview");
      title = p.title;
    } else if (route[0] === "docs") {
      html = documentation(route[1]);
      title = DOCS.find((d) => d[0] === route[1])?.[2] || "Documentation";
    } else if (route[0] === "about") {
      html = about();
      title = "About this catalog";
    } else if (route[0] === "request") {
      html = basket();
      title = "Your access request";
    } else html = notFound();
    $("#main").innerHTML = html;
    sideNav();
    document.title = title + " · Enpal data";
    if (!route.length) updateResults();
    $("#sidebar").classList.remove("open");
    $(".menu-button").setAttribute("aria-expanded", "false");
  }
  function routeTo(href) {
    if (location.hash === href) render();
    else location.hash = href;
  }
  function addRequest(id) {
    const ids = id === "product" ? P.map((p) => p.id) : [id];
    state.basket = [...new Set([...state.basket, ...ids.filter(byId)])];
    persist("basket", state.basket);
    routeTo("#/request");
  }
  async function copy(text) {
    if (navigator.clipboard?.writeText) {
      try {
        await navigator.clipboard.writeText(text);
        return true;
      } catch {
        /* file URLs may not allow the clipboard API */
      }
    }
    const box = document.createElement("textarea");
    box.value = text;
    box.style.position = "fixed";
    box.style.opacity = "0";
    document.body.append(box);
    box.select();
    let success = false;
    try {
      success = document.execCommand("copy");
    } catch {
      success = false;
    }
    box.remove();
    return success;
  }
  function download(name, text, type = "text/markdown;charset=utf-8") {
    const blob = new Blob([text], { type }),
      url = URL.createObjectURL(blob),
      link = document.createElement("a");
    link.href = url;
    link.download = name;
    document.body.append(link);
    link.click();
    link.remove();
    setTimeout(() => URL.revokeObjectURL(url), 1500);
  }
  function searchFocus() {
    if (state.route.length) {
      routeTo("#/");
      setTimeout(() => $("#catalog-search")?.focus(), 80);
    } else $("#catalog-search")?.focus();
  }
  document.addEventListener("click", async (event) => {
    const button = event.target.closest("[data-action]");
    if (!button) return;
    const action = button.dataset.action,
      id = button.dataset.id;
    if (action === "skip") {
      event.preventDefault();
      $("#main").focus();
      $("#main").scrollIntoView({ behavior: "instant" });
    } else if (action === "search") searchFocus();
    else if (action === "menu") {
      const open = $("#sidebar").classList.toggle("open");
      button.setAttribute("aria-expanded", open);
    } else if (action === "request") addRequest(id);
    else if (action === "remove-request") {
      state.basket = state.basket.filter((x) => x !== id);
      persist("basket", state.basket);
      render();
      toast("Removed from your request");
    } else if (action === "clear-basket") {
      state.basket = [];
      persist("basket", []);
      render();
      toast("Request cleared");
    } else if (action === "download-request") {
      download("sales-funnel-access-request.md", requestText());
      toast("Draft downloaded. Send it to the Analytics Engineering team.");
    } else if (action === "copy-request") {
      toast(
        (await copy(requestText()))
          ? "Draft copied. Send it to the Analytics Engineering team."
          : "Copy is unavailable here. Use Download request instead.",
      );
    } else if (action === "copy") {
      const code = codeRegistry.get(button.dataset.code);
      if (code !== undefined) {
        const ok = await copy(code);
        button.innerHTML =
          icon(ok ? "check" : "copy") + (ok ? "Copied" : "Copy unavailable");
        toast(
          ok
            ? "Code copied to clipboard"
            : "Select the code and copy it manually in this browser.",
        );
      }
    } else if (action === "clear-query") {
      state.query = "";
      $("#catalog-search").value = "";
      updateResults();
      $("#catalog-search").focus();
    } else if (action === "vote") {
      const dir = Number(button.dataset.dir);
      state.votes[id] = state.votes[id] === dir ? 0 : dir;
      persist("votes", state.votes);
      const item = ROADMAP.find((r) => r.id === id);
      $(`#vote-${id}`).outerHTML = voteControls(item);
      $(`#vote-${id} [data-dir="${dir}"]`).focus();
    } else if (action === "suggest") {
      $("#suggest-dialog").showModal();
    } else if (action === "page") {
      const p = byId(id);
      previewState(p).page += Number(button.dataset.dir);
      refreshPreview(p);
    }
  });
  document.addEventListener("input", (event) => {
    if (event.target.id === "catalog-search") {
      state.query = event.target.value;
      updateResults();
    } else if (event.target.id === "request-purpose") {
      state.purpose = event.target.value;
      persist("purpose", state.purpose);
    } else if (event.target.dataset.reviewSearch) {
      const p = byId(event.target.dataset.reviewSearch),
        v = previewState(p);
      v.query = event.target.value;
      v.page = 0;
      const pos = event.target.selectionStart;
      refreshPreview(p);
      const input = $("[data-review-search]");
      input.focus();
      try {
        input.setSelectionRange(pos, pos);
      } catch {
        /* search inputs do not always expose text selection */
      }
    }
  });
  document.addEventListener("change", (event) => {
    if (!event.target.dataset.preview) return;
    const p = byId(event.target.dataset.id),
      v = previewState(p);
    v[event.target.dataset.preview] = event.target.value;
    v.page = 0;
    refreshPreview(p);
  });
  document.addEventListener("keydown", (event) => {
    const editable =
      /INPUT|TEXTAREA|SELECT/.test(document.activeElement?.tagName || "") ||
      document.activeElement?.isContentEditable;
    if (
      (event.key === "/" && !editable) ||
      ((event.ctrlKey || event.metaKey) && event.key === "k")
    ) {
      event.preventDefault();
      searchFocus();
    }
    if (event.key === "Escape" && $("#sidebar").classList.contains("open")) {
      $("#sidebar").classList.remove("open");
      $(".menu-button").setAttribute("aria-expanded", "false");
      $(".menu-button").focus();
    }
  });
  window.addEventListener("hashchange", () => {
    render();
    window.scrollTo({ top: 0, behavior: "instant" });
    $("#main").focus({ preventScroll: true });
  });
  render();
})();
