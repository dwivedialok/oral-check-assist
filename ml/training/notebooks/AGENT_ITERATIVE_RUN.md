# How to Run the Iterative ML Improvement Loop with the Agent

Use this when you want the Cursor agent to execute **all phases** (0 → 1 → 2 → 4) iteratively: run scripts, read results, fix or tune, and move on within iteration limits.

---

## How to Invoke the Agent

**Paste this (or a shortened version) into the Cursor chat:**

```
Run the iterative ML improvement loop from AGENT_ITERATIVE_RUN.md in ml/training/notebooks.

- Use Python from ml/training/venv_pytorch only (from repo root). Do not install any packages.
- Execute phases in order: Phase 0 → Phase 1 → Phase 2 → Phase 4. Skip Phase 3.
- For each phase: run the commands below, read the output/JSON, check success criteria. If not met and iterations remain, adjust config/code and re-run. If met or max iterations reached, proceed to the next phase.
- Enforce the iteration limits in the table below. When a limit is hit, document the best result and move on.
- Working directory for Python: run scripts from repo root with full paths, e.g. ml/training/venv_pytorch/bin/python ml/training/notebooks/run_full_evaluation.py ...
```

Or shorter:

```
Execute the iterative ML loop in ml/training/notebooks/AGENT_ITERATIVE_RUN.md phase by phase. Use venv ml/training/venv_pytorch, no pip installs. Respect the per-phase iteration limits and success criteria.
```

---

## Pre-flight (once)

From repo root:

```bash
ml/training/venv_pytorch/bin/pip install -r ml/training/requirements_pytorch.txt
```

---

## Phase 0 — Baseline and reproducible evaluation

**Max iterations: 3**

1. Run full evaluation (uses registry binary + 5-class ONNX dirs):

   ```bash
   ml/training/venv_pytorch/bin/python ml/training/notebooks/run_full_evaluation.py --run_id phase0_run
   ```

2. Check output:
   - `ml/training/notebooks/results/phase0_run/eval_report/binary_metrics.json`
   - `ml/training/notebooks/results/phase0_run/eval_report/fiveclass_metrics.json`
   - `ml/training/notebooks/results/phase0_run/eval_report/agreement_all_splits.json`
   - `ml/training/notebooks/results/phase0_run/eval_report/thresholds.json`

3. **Success:** Script exits 0 and all four files exist. Optionally re-run with same `--run_id` and same model dirs to confirm identical JSON.

4. If failed: fix script/config, re-run; increment iteration. After 3 iterations, proceed to Phase 1 anyway and document gaps.

---

## Phase 1 — Lock production decision

**Max iterations: 2**

1. Generate decision summary from the Phase 0 eval_report:

   ```bash
   ml/training/venv_pytorch/bin/python ml/training/notebooks/generate_decision_summary.py --eval_report_dir ml/training/notebooks/results/phase0_run/eval_report
   ```

2. Check:
   - `results/phase0_run/eval_report/decision.json`
   - `results/phase0_run/eval_report/decision.md`

3. **Success:** Both files exist; decision.json has `"locked": true` and correct binary/fiveclass_onnx_dir paths.

4. If failed: fix paths or script, re-run. After 2 iterations, use best available and proceed to Phase 2.

---

## Phase 2 — Gated fusion policy

**Max iterations: 5**

1. Run fusion policy evaluation (binary and 5-class ONNX dirs from registry or same as Phase 0):

   ```bash
  ml/training/venv_pytorch/bin/python ml/training/notebooks/evaluate_fusion_policy.py \
    --binary_dir ml/training/notebooks/results/freeze_comparison/freeze_comparison_20260208_121618/onnx \
    --fiveclass_dir ml/training/notebooks/results/improved_5class/improved_5class_20260209_172821/onnx \
    --output ml/training/notebooks/results/fusion_policy_results.json
   ```

   Or use paths from `model_registry.py` (BINARY_PROGRESSIVE_K5_ONNX_DIR, FIVECLASS_PROGRESSIVE_K5_ONNX_DIR).

2. Read `fusion_policy_results.json`: compare `gated_fusion.TM` vs `current_dart.TM` (sens_at_90spec, dangerous_misses).

3. **Success:** Gated fusion TM sens@90spec ≥ current Dart and dangerous_misses ≤ Dart (or acceptable per your target).

4. If not met: edit a small JSON config and pass `--config fusion_config.json` to `evaluate_fusion_policy.py` (e.g. change `referral_threshold`, `fusion`, `fusion_weight_binary`, `ood_unknown_threshold` in GatedFusionPolicy). Re-run. After 5 iterations, lock best config and document shortfall; proceed to Phase 4.

---

## Phase 4 — Architecture experiments

**No inner retry:** each experiment runs **once**. Run up to 4 experiments, then compare to baseline.

**Current Status (as of Feb 12, 2026, 11:14 AM):**
- ✅ **Experiment 1 (AdamW)**: Completed — checkpoint saved to `results/train_experiment/exp_adamw/models/best.pth` (12 MB, Feb 10 21:44)
- ✅ **Experiment 2 (Freeze BN)**: Completed — checkpoint saved to `results/train_experiment/exp_freeze_bn/models/best.pth` (12 MB, Feb 11 22:10)
- 🔄 **Experiment 3 (Focal loss)**: In Progress — TB logs active (79 event files, latest Feb 12 11:14); checkpoint not yet saved
- ⏳ **Experiment 4 (Temperature scaling)**: Pending — not started yet

**TensorBoard:** Experiments 3 and 4 will log metrics to TensorBoard (added Feb 12). View logs with:
```bash
tensorboard --logdir=ml/training/notebooks/results/train_experiment
```

1. **Baseline (optional, for comparison):**

   ```bash
   ml/training/venv_pytorch/bin/python ml/training/notebooks/train_experiment.py \
     --config ml/training/notebooks/experiment_configs/baseline_progressive_K5.json \
     --run_id baseline
   ```

2. **Experiment 1 — AdamW:** ✅ **Completed**

   ```bash
   ml/training/venv_pytorch/bin/python ml/training/notebooks/train_experiment.py \
     --config ml/training/notebooks/experiment_configs/adamw.json \
     --run_id exp_adamw
   ```

3. **Experiment 2 — Freeze BN:** ✅ **Completed**

   ```bash
   ml/training/venv_pytorch/bin/python ml/training/notebooks/train_experiment.py \
     --config ml/training/notebooks/experiment_configs/freeze_bn.json \
     --run_id exp_freeze_bn
   ```

4. **Experiment 3 — Focal loss:** 🔄 **In Progress**

   ```bash
   ml/training/venv_pytorch/bin/python ml/training/notebooks/train_experiment.py \
     --config ml/training/notebooks/experiment_configs/focal_loss.json \
     --run_id exp_focal
   ```

5. **Experiment 4 — Temperature scaling:** ⏳ **Pending**

   ```bash
   ml/training/venv_pytorch/bin/python ml/training/notebooks/train_experiment.py \
     --config ml/training/notebooks/experiment_configs/temperature_scaling.json \
     --run_id exp_temp
   ```

6. After each training run, evaluate that run’s model (export to ONNX if needed, or use the saved checkpoint with the same evaluation pipeline). Compare TM AUROC / ECE / Brier to baseline; keep or discard.

**Success:** At least one experiment improves AUROC or calibration on TM without degrading other splits.

---

## Iteration limits (mandatory)

| Phase   | Max iterations | When limit reached |
|--------|----------------|---------------------|
| Phase 0 | 3              | Stop; report what’s done and gaps; go to Phase 1. |
| Phase 1 | 2              | Use best metrics; lock decision; go to Phase 2.   |
| Phase 2 | 5              | Lock best policy; document shortfall; go to Phase 4. |
| Phase 4 | 1 per experiment (4 total) | No retry; run once, compare, keep or discard. |

---

## Command reference (all from repo root)

- Venv Python: `ml/training/venv_pytorch/bin/python`
- Scripts dir: `ml/training/notebooks/`
- Full evaluation: `ml/training/venv_pytorch/bin/python ml/training/notebooks/run_full_evaluation.py --run_id <id>`
- Decision summary: `ml/training/venv_pytorch/bin/python ml/training/notebooks/generate_decision_summary.py --eval_report_dir <path>`
- Fusion policy eval: `ml/training/venv_pytorch/bin/python ml/training/notebooks/evaluate_fusion_policy.py --binary_dir <dir> --fiveclass_dir <dir> [--config config.json] --output <path>`
- Training: `ml/training/venv_pytorch/bin/python ml/training/notebooks/train_experiment.py --config <json> [--run_id <id>]`

Training runs can take 20–50+ minutes on MPS; run in background or with a long timeout if the agent runs the command.
