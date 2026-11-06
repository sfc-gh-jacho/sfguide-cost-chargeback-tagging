(function () {
  "use strict";

  function esc(s) {
    return String(s).replace(/[&<>"']/g, function (c) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c];
    });
  }

  // ── SQL blocks: split sql/cost_chargeback_setup.sql on "-- [step:<id>]" markers ──
  function splitSteps(sql) {
    var steps = {};
    var parts = sql.split(/^-- \[step:([a-z_-]+)\]\s*$/m);
    for (var i = 1; i < parts.length; i += 2) steps[parts[i]] = parts[i + 1].trim();
    return steps;
  }

  function renderCode(el, code) {
    el.innerHTML =
      '<div class="code-bar"><span class="code-lang">SQL</span>' +
      '<button class="copy-btn" type="button">Copy</button></div>' +
      '<pre class="language-sql"><code class="language-sql"></code></pre>';
    var codeEl = el.querySelector("code");
    codeEl.textContent = code;
    if (window.Prism) Prism.highlightElement(codeEl);
    el.querySelector(".copy-btn").addEventListener("click", function () {
      var btn = this;
      copyText(code).then(function () {
        btn.textContent = "Copied!";
        btn.classList.add("copied");
        setTimeout(function () { btn.textContent = "Copy"; btn.classList.remove("copied"); }, 1800);
      });
    });
  }

  function copyText(text) {
    if (navigator.clipboard && window.isSecureContext) return navigator.clipboard.writeText(text);
    var ta = document.createElement("textarea");
    ta.value = text;
    ta.style.position = "fixed";
    ta.style.opacity = "0";
    document.body.appendChild(ta);
    ta.select();
    document.execCommand("copy");
    document.body.removeChild(ta);
    return Promise.resolve();
  }

  var loadErr = '<div class="code-loading">Could not load content. If you opened this file directly, serve the folder over HTTP (e.g. <code>python3 -m http.server</code>).</div>';

  fetch("sql/cost_chargeback_setup.sql")
    .then(function (r) { if (!r.ok) throw new Error(r.status); return r.text(); })
    .then(function (sql) {
      var steps = splitSteps(sql);
      document.querySelectorAll(".code-wrap[data-step]").forEach(function (el) {
        var code = steps[el.getAttribute("data-step")];
        if (code) renderCode(el, code);
      });
    })
    .catch(function () {
      document.querySelectorAll(".code-wrap[data-step]").forEach(function (el) { el.innerHTML = loadErr; });
    });

  // ── Example-output tables from data/sample_results.json ──
  function fmtCell(col, v, row, cols) {
    if (col === "STATUS") return '<span class="status status-' + String(v).toLowerCase() + '">' + esc(v) + "</span>";
    if (typeof v === "number") {
      var cls = "num";
      if (col === "PCT_CHANGE" && v >= 50) cls += " bad";
      return '<span class="' + cls + '">' + esc(v.toLocaleString(undefined, { maximumFractionDigits: 2 })) + "</span>";
    }
    if (/IDLE/.test(v)) return '<span class="bad">' + esc(v) + "</span>";
    return esc(v);
  }

  function isFlagged(row, cols) {
    var pc = cols.indexOf("PCT_CHANGE"), st = cols.indexOf("STATUS"), q = cols.indexOf("TOTAL_QUERIES");
    return (pc >= 0 && typeof row[pc] === "number" && row[pc] >= 50) ||
           (st >= 0 && (row[st] === "CRITICAL" || row[st] === "EXCEEDED")) ||
           (q >= 0 && row[q] === 0);
  }

  function table(block, opts) {
    opts = opts || {};
    var cols = block.columns;
    var pctIdx = opts.bar ? cols.indexOf(opts.bar) : -1;
    var h = '<div class="table-scroll"><table class="results-table"><thead><tr>';
    cols.forEach(function (c) { h += "<th>" + esc(c) + "</th>"; });
    if (pctIdx >= 0) h += "<th></th>";
    h += "</tr></thead><tbody>";
    block.rows.forEach(function (row) {
      h += "<tr" + (isFlagged(row, cols) ? ' class="flag"' : "") + ">";
      row.forEach(function (v, i) {
        var td = typeof v === "number" ? '<td class="num">' : "<td>";
        h += td + fmtCell(cols[i], v, row, cols) + "</td>";
      });
      if (pctIdx >= 0) {
        var p = Math.min(100, Math.max(0, row[pctIdx]));
        h += '<td class="bar-cell"><div class="bar"><span style="width:' + p + '%"></span></div></td>';
      }
      h += "</tr>";
    });
    return h + "</tbody></table></div>";
  }

  fetch("data/sample_results.json")
    .then(function (r) { if (!r.ok) throw new Error(r.status); return r.json(); })
    .then(function (d) {
      var render = {
        "before_after": function () {
          return '<div class="ba-grid"><div><h4>Before: no tags</h4>' + table(d.before_after.before) +
                 '</div><div><h4>After: tag-based chargeback</h4>' +
                 table(d.before_after.after, { bar: "PCT_OF_TOTAL" }) + "</div></div>";
        },
        "dedicated": function () { return table(d.dedicated); },
        "shared": function () { return table(d.shared, { bar: "PCT_OF_WAREHOUSE_COST" }); },
        "summary": function () { return table(d.summary, { bar: "PCT_OF_TOTAL" }); },
        "budget_status": function () { return table(d.budget_status, { bar: "PCT_USED" }); },
        "idle": function () { return table(d.idle); },
        "wow": function () { return table(d.wow); }
      };
      document.querySelectorAll(".results[data-results]").forEach(function (el) {
        var fn = render[el.getAttribute("data-results")];
        if (fn) el.innerHTML = fn();
      });
    })
    .catch(function () {
      document.querySelectorAll(".results[data-results]").forEach(function (el) { el.innerHTML = loadErr; });
    });

  // ── Mobile Nav ──
  var btn = document.querySelector(".nav-hamburger");
  var links = document.querySelector(".nav-links");
  btn.addEventListener("click", function () {
    var open = links.classList.toggle("open");
    btn.classList.toggle("open", open);
    btn.setAttribute("aria-expanded", String(open));
  });
  links.querySelectorAll("a").forEach(function (a) {
    a.addEventListener("click", function () {
      links.classList.remove("open");
      btn.classList.remove("open");
      btn.setAttribute("aria-expanded", "false");
    });
  });

  // ── Nav Scroll Shadow ──
  var nav = document.getElementById("navbar");
  window.addEventListener("scroll", function () {
    nav.classList.toggle("scrolled", window.scrollY > 10);
  }, { passive: true });

  // ── Reveal on Scroll ──
  if (!window.matchMedia("(prefers-reduced-motion: reduce)").matches && "IntersectionObserver" in window) {
    var observer = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) {
        if (e.isIntersecting) { e.target.classList.add("visible"); observer.unobserve(e.target); }
      });
    }, { threshold: 0.08, rootMargin: "0px 0px -40px 0px" });
    document.querySelectorAll(".reveal").forEach(function (el) { observer.observe(el); });
  } else {
    document.querySelectorAll(".reveal").forEach(function (el) { el.classList.add("visible"); });
  }
})();
