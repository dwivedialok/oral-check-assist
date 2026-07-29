#!/usr/bin/env python3
"""
Karpathy-style autoresearch harness for binary ONNX ensembles.

Commands:
  baseline        — Run evaluate_on_frozen_sets on registry baseline ONNX; write baseline_metrics.json
  run             — Train+eval iterations from a recipe; append ledger.jsonl + best_so_far.json
  promote         — Re-eval top candidates from ledger; write promotion_report.md
  agent-context   — Print ledger + baseline summary for Cursor agent (propose next config)

Uses repo venv: ml/training/venv_pytorch/bin/python (override with AUTORESEARCH_PYTHON).

See autoresearch_program.md for objectives and guardrails.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

NOTEBOOK_DIR = Path(__file__).resolve().parent
# oral-cavity-classifier/ml/training/notebooks -> repo root is 3 levels up
REPO_ROOT = NOTEBOOK_DIR.parent.parent.parent
sys.path.insert(0, str(NOTEBOOK_DIR))
AUTORESEARCH_DIR = NOTEBOOK_DIR / "results" / "autoresearch"
LEDGER_PATH = AUTORESEARCH_DIR / "ledger.jsonl"
BEST_PATH = AUTORESEARCH_DIR / "best_so_far.json"
BASELINE_PATH = AUTORESEARCH_DIR / "baseline_metrics.json"
REFERENCE_BASELINE_PATH = AUTORESEARCH_DIR / "baseline_metrics.reference.json"
LEDGER_VERSION = 1

# Default baseline ONNX: progressive_K5 binary ensemble (model_registry)
try:
    from model_registry import BINARY_PROGRESSIVE_K5_ONNX_DIR
except ImportError:  # pragma: no cover
    BINARY_PROGRESSIVE_K5_ONNX_DIR = NOTEBOOK_DIR / "results" / "freeze_comparison" / "freeze_comparison_20260208_121618" / "onnx"


def _venv_python() -> Path:
    env = os.environ.get("AUTORESEARCH_PYTHON")
    if env:
        return Path(env)
    return REPO_ROOT / "ml" / "training" / "venv_pytorch" / "bin" / "python"


def _run(
    cmd: list[str],
    cwd: Path | None = None,
    *,
    capture_output: bool = True,
) -> subprocess.CompletedProcess:
    """
    If capture_output is False, child stdout/stderr go to the terminal (live tqdm).
    Ledger rows will not include stdout/stderr tails for that run.
    """
    kw: dict = {"cwd": cwd or REPO_ROOT, "check": False}
    if capture_output:
        kw["capture_output"] = True
        kw["text"] = True
    return subprocess.run(cmd, **kw)


def run_frozen_eval(onnx_dir: Path, output_json: Path) -> dict:
    """Run evaluate_on_frozen_sets.py; return parsed JSON."""
    py = _venv_python()
    eval_script = NOTEBOOK_DIR / "evaluate_on_frozen_sets.py"
    output_json.parent.mkdir(parents=True, exist_ok=True)
    cmd = [
        str(py),
        str(eval_script),
        "--model",
        str(onnx_dir),
        "--model_type",
        "binary_onnx_ensemble",
        "--output",
        str(output_json),
    ]
    proc = _run(cmd)
    if proc.returncode != 0:
        raise RuntimeError(
            f"evaluate_on_frozen_sets failed ({proc.returncode}):\n{proc.stderr}\n{proc.stdout}"
        )
    with open(output_json) as f:
        return json.load(f)


def tm_primary_metrics(eval_blob: dict) -> dict:
    """Extract TM metrics used for scoring."""
    tm = eval_blob.get("TM") or {}
    return {
        "auroc": float(tm.get("auroc") or 0.0),
        "sens_at_90spec": float(tm.get("sens_at_90spec") or 0.0),
        "sens_at_85spec": float(tm.get("sens_at_85spec") or 0.0),
    }


def t5_auroc(eval_blob: dict) -> float:
    t5 = eval_blob.get("T5") or {}
    return float(t5.get("auroc") or 0.0)


def guardrails_ok(candidate: dict, baseline: dict) -> tuple[bool, list[str]]:
    """Return (pass, reasons). Uses TM AUROC + T5 AUROC deltas vs baseline."""
    reasons: list[str] = []
    c_tm = tm_primary_metrics(candidate)
    b_tm = tm_primary_metrics(baseline)
    if c_tm["auroc"] < b_tm["auroc"] - 0.01:
        reasons.append(
            f"TM AUROC dropped >0.01: candidate={c_tm['auroc']:.4f} baseline={b_tm['auroc']:.4f}"
        )
    c5 = t5_auroc(candidate)
    b5 = t5_auroc(baseline)
    if c5 < b5 - 0.02:
        reasons.append(
            f"T5 AUROC dropped >0.02: candidate={c5:.4f} baseline={b5:.4f}"
        )
    return (len(reasons) == 0, reasons)


def primary_score(eval_blob: dict) -> float:
    """Higher is better: sens@90spec on TM."""
    return tm_primary_metrics(eval_blob)["sens_at_90spec"]


def config_fingerprint(config_path: Path) -> str:
    raw = config_path.read_bytes()
    return hashlib.sha256(raw).hexdigest()[:16]


def append_ledger(row: dict) -> None:
    AUTORESEARCH_DIR.mkdir(parents=True, exist_ok=True)
    with open(LEDGER_PATH, "a") as f:
        f.write(json.dumps(row, default=str) + "\n")


def load_baseline() -> dict:
    if not BASELINE_PATH.exists():
        raise FileNotFoundError(
            f"Missing {BASELINE_PATH}. Run: python autoresearch_loop.py baseline"
        )
    with open(BASELINE_PATH) as f:
        return json.load(f)


def read_all_ledger_rows() -> list[dict]:
    if not LEDGER_PATH.exists():
        return []
    rows: list[dict] = []
    with open(LEDGER_PATH) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            rows.append(json.loads(line))
    return rows


def cmd_agent_context(args: argparse.Namespace) -> None:
    """
    Emit a report for a Cursor agent: baseline, best_so_far, last ledger row(s), available configs.
    The agent reads this (or the JSON variant) and proposes the next experiment JSON.
    """
    baseline: dict | None = None
    if BASELINE_PATH.exists():
        try:
            baseline = load_baseline()
        except OSError:
            baseline = None

    best_raw: dict | None = None
    if BEST_PATH.exists():
        try:
            best_raw = json.loads(BEST_PATH.read_text())
        except json.JSONDecodeError:
            best_raw = None

    rows = read_all_ledger_rows()
    last_n = max(1, getattr(args, "last_n", 5))
    tail = rows[-last_n:] if rows else []
    last_row = rows[-1] if rows else None

    experiment_dir = NOTEBOOK_DIR / "experiment_configs"
    config_files = sorted(experiment_dir.glob("*.json")) if experiment_dir.is_dir() else []

    payload = {
        "ledger_path": str(LEDGER_PATH),
        "ledger_line_count": len(rows),
        "baseline_path": str(BASELINE_PATH) if BASELINE_PATH.exists() else None,
        "baseline_tm": tm_primary_metrics(baseline) if baseline else None,
        "baseline_t5_auroc": t5_auroc(baseline) if baseline else None,
        "best_so_far": best_raw,
        "last_ledger_rows": tail,
        "last_ledger_row": last_row,
        "experiment_config_files": [str(p) for p in config_files],
    }

    if getattr(args, "output_format", "markdown") == "json":
        print(json.dumps(payload, indent=2, default=str))
        return

    lines: list[str] = [
        "# Autoresearch agent context",
        "",
        "Use this block with `autoresearch_program.md` scoring rules to propose **one** next `experiment_configs/*.json` ",
        "(new file or edit copy). Primary metric: TM `sens_at_90spec` (higher better); guardrails: TM/T5 AUROC vs baseline.",
        "",
        "## Baseline (`baseline_metrics.json`)",
        "",
    ]
    if baseline:
        lines.append("```json")
        lines.append(json.dumps({"TM": tm_primary_metrics(baseline), "T5_auroc": t5_auroc(baseline)}, indent=2))
        lines.append("```")
    else:
        lines.append("*Missing — run `autoresearch_loop.py baseline` or `baseline --from-reference`.*")
    lines.extend(["", "## Best so far (`best_so_far.json`)", ""])
    if best_raw:
        lines.append("```json")
        lines.append(json.dumps(best_raw, indent=2))
        lines.append("```")
    else:
        lines.append("*None yet (no improving run recorded).*")
    lines.extend(["", f"## Last ledger row (primary signal for **next** experiment) — `{LEDGER_PATH.name}`", ""])
    if last_row:
        lines.append("```json")
        lines.append(json.dumps(last_row, indent=2, default=str))
        lines.append("```")
    else:
        lines.append("*Ledger empty — start with `run` or seed demo.*")
    if len(tail) > 1:
        lines.extend(["", f"## Previous {len(tail) - 1} row(s) (context)", ""])
        lines.append("```json")
        lines.append(json.dumps(tail[:-1], indent=2, default=str))
        lines.append("```")
    lines.extend(["", "## Available configs (starting points)", ""])
    for p in config_files:
        lines.append(f"- `{p}`")
    lines.extend(
        [
            "",
            "## Agent checklist",
            "",
            "1. Compare `primary_score` / `TM` / `guardrails_ok` / `kept` in the last row to baseline.",
            "2. If last run **failed** (`status` / returncode), fix the underlying issue or try a smaller `epochs` / different loss.",
            "3. Propose **one** next JSON under `experiment_configs/` (e.g. `proposed_focal_gamma_2p5.json`) with a short rationale.",
            "4. User runs: `autoresearch_loop.py run --config .../proposed_....json --run-id-prefix ar_stepN`",
            "",
        ]
    )
    text = "\n".join(lines)
    out_path = getattr(args, "output", None)
    if out_path:
        Path(out_path).parent.mkdir(parents=True, exist_ok=True)
        Path(out_path).write_text(text)
        print(f"Wrote {out_path}", file=sys.stderr)
    print(text)


def cmd_baseline(args: argparse.Namespace) -> None:
    AUTORESEARCH_DIR.mkdir(parents=True, exist_ok=True)

    if getattr(args, "from_json", None):
        src = Path(args.from_json)
        if not src.is_file():
            raise SystemExit(f"--from-json not found: {src}")
        import shutil

        shutil.copyfile(src, BASELINE_PATH)
        blob = json.loads(BASELINE_PATH.read_text())
        meta = {
            "created_utc": datetime.now(timezone.utc).isoformat(),
            "source": "from_json",
            "from_path": str(src.resolve()),
            "eval_output": str(BASELINE_PATH.resolve()),
            "TM": tm_primary_metrics(blob),
            "T5_auroc": t5_auroc(blob),
            "ledger_version": LEDGER_VERSION,
        }
        (AUTORESEARCH_DIR / "baseline_meta.json").write_text(json.dumps(meta, indent=2))
        print(json.dumps(meta, indent=2))
        print(f"Wrote {BASELINE_PATH}")
        return

    if getattr(args, "from_reference", False):
        if not REFERENCE_BASELINE_PATH.is_file():
            raise SystemExit(f"Missing reference file: {REFERENCE_BASELINE_PATH}")
        import shutil

        shutil.copyfile(REFERENCE_BASELINE_PATH, BASELINE_PATH)
        blob = json.loads(BASELINE_PATH.read_text())
        meta = {
            "created_utc": datetime.now(timezone.utc).isoformat(),
            "source": "reference_snapshot",
            "note": "Pinned metrics when frozen image paths are unavailable; re-run live baseline when datasets are on disk.",
            "eval_output": str(BASELINE_PATH.resolve()),
            "TM": tm_primary_metrics(blob),
            "T5_auroc": t5_auroc(blob),
            "ledger_version": LEDGER_VERSION,
        }
        (AUTORESEARCH_DIR / "baseline_meta.json").write_text(json.dumps(meta, indent=2))
        print(json.dumps(meta, indent=2))
        print(f"Wrote {BASELINE_PATH} from reference snapshot")
        return

    onnx_dir = Path(args.onnx_dir) if args.onnx_dir else BINARY_PROGRESSIVE_K5_ONNX_DIR
    if not onnx_dir.is_dir():
        raise SystemExit(f"ONNX dir not found: {onnx_dir}")
    try:
        blob = run_frozen_eval(onnx_dir, BASELINE_PATH)
    except RuntimeError as e:
        print(str(e), file=sys.stderr)
        print(
            "\nTip: frozen eval needs local image paths from frozen_test_sets JSON. "
            f"Use: python autoresearch_loop.py baseline --from-reference\n"
            f"  or: python autoresearch_loop.py baseline --from-json <path/to/eval.json>",
            file=sys.stderr,
        )
        raise SystemExit(1) from e
    meta = {
        "created_utc": datetime.now(timezone.utc).isoformat(),
        "onnx_dir": str(onnx_dir.resolve()),
        "eval_output": str(BASELINE_PATH.resolve()),
        "TM": tm_primary_metrics(blob),
        "T5_auroc": t5_auroc(blob),
        "ledger_version": LEDGER_VERSION,
    }
    sidecar = AUTORESEARCH_DIR / "baseline_meta.json"
    with open(sidecar, "w") as f:
        json.dump(meta, f, indent=2)
    print(json.dumps(meta, indent=2))
    print(f"Wrote {BASELINE_PATH}")


def _load_recipe_config_paths(recipe_path: Path) -> list[Path]:
    """One JSON path per line; # and blank lines ignored. Relative paths are resolved from recipe file's directory."""
    text = recipe_path.read_text()
    base = recipe_path.resolve().parent
    out: list[Path] = []
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        p = Path(line).expanduser()
        if not p.is_absolute():
            p = (base / p).resolve()
        out.append(p)
    return out


def cmd_run(args: argparse.Namespace) -> None:
    baseline = load_baseline()
    tm_primary_metrics(baseline)
    config_paths: list[Path] = []
    if args.config:
        config_paths.extend(Path(x) for x in args.config)
    if getattr(args, "recipe", None):
        rp = Path(args.recipe)
        if not rp.is_file():
            raise SystemExit(f"--recipe not found: {rp}")
        config_paths.extend(_load_recipe_config_paths(rp))
    if not config_paths:
        raise SystemExit("Provide at least one of --config ... and/or --recipe FILE")

    recipes = []
    for p in config_paths:
        if not p.exists():
            raise SystemExit(f"Config not found: {p}")
        recipes.append((p.stem, p))

    py = _venv_python()
    train_script = NOTEBOOK_DIR / "train_experiment.py"
    max_iters = args.max_iterations or len(recipes)
    for i, (name, cfg_path) in enumerate(recipes[:max_iters]):
        run_id = args.run_id_prefix + f"_{name}_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        out_dir = NOTEBOOK_DIR / "results" / "train_experiment" / run_id
        onnx_dir = out_dir / "onnx"

        row = {
            "ledger_version": LEDGER_VERSION,
            "iteration": i,
            "run_id": run_id,
            "config_name": name,
            "config_path": str(cfg_path.resolve()),
            "config_fingerprint": config_fingerprint(cfg_path),
            "started_utc": datetime.now(timezone.utc).isoformat(),
        }

        cmd = [
            str(py),
            str(train_script),
            "--config",
            str(cfg_path),
            "--run_id",
            run_id,
            "--ensemble",
            "--export_onnx",
            "--evaluate",
        ]
        if getattr(args, "patientwise_v3", False):
            cmd.append("--patientwise-v3")
        capture = getattr(args, "capture_output", False)
        if not capture:
            print(f"\n--- Starting training (live logs; ~20–90+ min per 3-model ensemble) ---", flush=True)
            print(f"run_id={run_id}\n", flush=True)
        t0 = time.time()
        proc = _run(cmd, capture_output=capture)
        elapsed = time.time() - t0
        row_done: dict = {
            **row,
            "finished_utc": datetime.now(timezone.utc).isoformat(),
            "train_returncode": proc.returncode,
            "train_seconds": round(elapsed, 1),
            "stdout_tail": ((proc.stdout or "")[-4000:] if capture else "(streamed to terminal)"),
            "stderr_tail": ((proc.stderr or "")[-4000:] if capture else "(streamed to terminal)"),
        }

        eval_path = out_dir / "frozen_eval.json"
        if proc.returncode != 0 or not eval_path.exists():
            row_done["status"] = "failed_train_or_eval"
            append_ledger(row_done)
            print(f"[{name}] FAILED train/eval rc={proc.returncode} see ledger")
            continue

        with open(eval_path) as f:
            cand_eval = json.load(f)
        ok_g, reasons = guardrails_ok(cand_eval, baseline)
        score = primary_score(cand_eval)
        base_score = primary_score(baseline)
        improved = score > base_score and ok_g
        row_done["eval_path"] = str(eval_path)
        row_done["TM"] = tm_primary_metrics(cand_eval)
        row_done["T5_auroc"] = t5_auroc(cand_eval)
        row_done["primary_score"] = score
        row_done["baseline_primary"] = base_score
        row_done["guardrails_ok"] = ok_g
        row_done["guardrail_reasons"] = reasons
        row_done["kept"] = improved
        row_done["status"] = "completed"
        append_ledger(row_done)

        if improved:
            with open(BEST_PATH, "w") as f:
                json.dump(
                    {
                        "run_id": run_id,
                        "onnx_dir": str(onnx_dir),
                        "primary_score": score,
                        "eval_path": str(eval_path),
                        "updated_utc": datetime.now(timezone.utc).isoformat(),
                    },
                    f,
                    indent=2,
                )
            print(f"[{name}] KEPT primary={score:.4f} (baseline {base_score:.4f})")
        else:
            print(
                f"[{name}] REVERT primary={score:.4f} baseline={base_score:.4f} ok_g={ok_g} reasons={reasons}"
            )


def cmd_promote(args: argparse.Namespace) -> None:
    baseline = load_baseline()
    if not LEDGER_PATH.exists():
        raise SystemExit("No ledger yet; run `run` or `seed-demo-ledger` first.")

    rows = []
    with open(LEDGER_PATH) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            rows.append(json.loads(line))

    completed = [
        r
        for r in rows
        if r.get("status") == "completed" and r.get("eval_path") and Path(r["eval_path"]).exists()
    ]
    completed.sort(key=lambda r: r.get("primary_score", 0.0), reverse=True)
    top = completed[: max(1, args.top_k)]

    report_lines = [
        "# Autoresearch promotion report",
        "",
        f"Generated: {datetime.now(timezone.utc).isoformat()}",
        "",
        "## Baseline (frozen)",
        "",
        "```json",
        json.dumps(tm_primary_metrics(baseline), indent=2),
        "```",
        "",
        "## Top candidates"
        + (" (ledger metrics only)" if args.no_fresh_eval else " (re-evaluated on frozen sets)"),
        "",
    ]

    for idx, r in enumerate(top, 1):
        eval_path = Path(r["eval_path"])
        fresh_out = AUTORESEARCH_DIR / f"promote_confirm_{idx}.json"
        onnx_dir = NOTEBOOK_DIR / "results" / "train_experiment" / r["run_id"] / "onnx"

        if args.no_fresh_eval:
            with open(eval_path) as f:
                blob = json.load(f)
            ok_g, reasons = guardrails_ok(blob, baseline)
            report_lines.append(f"### {idx}. `{r.get('run_id')}`")
            report_lines.append(f"- Config: `{r.get('config_path', '')}`")
            report_lines.append(f"- Primary (TM sens@90spec): **{primary_score(blob):.4f}**")
            report_lines.append(f"- TM AUROC: {tm_primary_metrics(blob)['auroc']:.4f}")
            report_lines.append(f"- Guardrails vs baseline: {'PASS' if ok_g else 'FAIL'}")
            if reasons:
                report_lines.append(f"- Reasons: {reasons}")
            report_lines.append(f"- Source eval JSON: `{eval_path}`")
            report_lines.append("")
            continue

        if not onnx_dir.is_dir():
            report_lines.append(
                f"### {idx}. `{r.get('run_id')}` — **skip** (missing onnx dir; use --no-fresh-eval to score from ledger eval JSON)"
            )
            report_lines.append("")
            continue
        blob = run_frozen_eval(onnx_dir, fresh_out)
        ok_g, reasons = guardrails_ok(blob, baseline)
        report_lines.append(f"### {idx}. `{r.get('run_id')}`")
        report_lines.append(f"- Config: `{r.get('config_path', '')}`")
        report_lines.append(f"- Primary (TM sens@90spec): **{primary_score(blob):.4f}**")
        report_lines.append(f"- TM AUROC: {tm_primary_metrics(blob)['auroc']:.4f}")
        report_lines.append(f"- Guardrails vs baseline: {'PASS' if ok_g else 'FAIL'}")
        if reasons:
            report_lines.append(f"- Reasons: {reasons}")
        report_lines.append(f"- Fresh eval JSON: `{fresh_out}`")
        report_lines.append("")

    report_path = AUTORESEARCH_DIR / "promotion_report.md"
    report_path.write_text("\n".join(report_lines))
    print(f"Wrote {report_path}")


def cmd_seed_demo_ledger(args: argparse.Namespace) -> None:
    """Append two synthetic completed rows for testing promote without local image data."""
    load_baseline()  # ensure baseline exists
    AUTORESEARCH_DIR.mkdir(parents=True, exist_ok=True)
    base = json.loads(BASELINE_PATH.read_text())
    a = json.loads(json.dumps(base))
    b = json.loads(json.dumps(base))
    # Candidate B: slightly lower primary (illustrative)
    tm_b = b.get("TM") or {}
    tm_b["sens_at_90spec"] = float(tm_b.get("sens_at_90spec", 0)) - 0.02
    b["TM"] = tm_b

    p_a = AUTORESEARCH_DIR / "demo_candidate_a_eval.json"
    p_b = AUTORESEARCH_DIR / "demo_candidate_b_eval.json"
    p_a.write_text(json.dumps(a, indent=2))
    p_b.write_text(json.dumps(b, indent=2))

    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    for i, (name, p, score) in enumerate(
        [
            ("a", p_a, primary_score(a)),
            ("b", p_b, primary_score(b)),
        ]
    ):
        row = {
            "ledger_version": LEDGER_VERSION,
            "iteration": i,
            "run_id": f"demo_{name}_{ts}",
            "config_name": name,
            "config_path": str(p),
            "status": "completed",
            "demo": True,
            "eval_path": str(p.resolve()),
            "primary_score": score,
            "TM": tm_primary_metrics(json.loads(p.read_text())),
            "kept": False,
            "finished_utc": datetime.now(timezone.utc).isoformat(),
        }
        append_ledger(row)
    print(f"Appended 2 demo rows to {LEDGER_PATH} (demo_candidate_*_eval.json)")


def main() -> None:
    parser = argparse.ArgumentParser(description="Autoresearch loop for binary ensembles")
    sub = parser.add_subparsers(dest="command", required=True)

    p_base = sub.add_parser("baseline", help="Lock frozen eval baseline JSON")
    p_base.add_argument(
        "--onnx-dir",
        default=None,
        help="Binary ONNX ensemble directory (default: registry progressive_K5)",
    )
    p_base.add_argument(
        "--from-reference",
        action="store_true",
        help="Copy baseline_metrics.reference.json (no dataset required)",
    )
    p_base.add_argument(
        "--from-json",
        default=None,
        metavar="PATH",
        help="Copy an existing evaluate_on_frozen_sets JSON to baseline_metrics.json",
    )
    p_base.set_defaults(func=cmd_baseline)

    p_run = sub.add_parser(
        "run",
        help="Run training+eval for many configs in one process (overnight: pass all experiments upfront; no LLM between runs)",
    )
    p_run.add_argument(
        "--config",
        nargs="*",
        default=[],
        metavar="PATH",
        help="One or more train JSON configs (in order). Combine with --recipe.",
    )
    p_run.add_argument(
        "--recipe",
        default=None,
        metavar="FILE",
        help="Text file: one config path per line (# comments ok). Paths relative to this file's directory.",
    )
    p_run.add_argument(
        "--run-id-prefix",
        default="autoresearch",
        help="Prefix for train_experiment run_id",
    )
    p_run.add_argument(
        "--max-iterations",
        type=int,
        default=None,
        help="Cap number of configs executed",
    )
    p_run.add_argument(
        "--patientwise-v3",
        action="store_true",
        help="Pass --patientwise-v3 to train_experiment (same training pool as train_binary_ensemble_patientwise.ipynb)",
    )
    p_run.add_argument(
        "--capture-output",
        action="store_true",
        help="Buffer train logs until each run ends (quiet terminal; default is live streaming)",
    )
    p_run.set_defaults(func=cmd_run)

    p_pro = sub.add_parser("promote", help="Re-eval top ledger entries and write report")
    p_pro.add_argument("--top-k", type=int, default=3)
    p_pro.add_argument(
        "--no-fresh-eval",
        action="store_true",
        help="Score candidates from ledger eval JSON only (no onnx re-run; for offline/demo)",
    )
    p_pro.set_defaults(func=cmd_promote)

    p_seed = sub.add_parser(
        "seed-demo-ledger",
        help="Append two synthetic ledger rows (no training; for testing promote offline)",
    )
    p_seed.set_defaults(func=cmd_seed_demo_ledger)

    p_ctx = sub.add_parser(
        "agent-context",
        help="Print baseline + last ledger row(s) for Cursor agent to propose next config",
    )
    p_ctx.add_argument(
        "--last-n",
        type=int,
        default=5,
        metavar="N",
        help="Include last N ledger rows in detail (default 5)",
    )
    p_ctx.add_argument(
        "--output-format",
        dest="output_format",
        choices=("markdown", "json"),
        default="markdown",
        help="Output format (default markdown)",
    )
    p_ctx.add_argument(
        "--output",
        "-o",
        default=None,
        metavar="FILE",
        help="Write markdown report to file (still prints to stdout unless you redirect)",
    )
    p_ctx.set_defaults(func=cmd_agent_context)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
