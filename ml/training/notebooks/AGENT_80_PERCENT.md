# Agent Mode: Reaching 80% Accuracy (Binary Merged)

**Goal:** Test accuracy ≥ 80% on the binary merged dataset.  
**How:** Run the notebook with different configs in a loop until the target is met or configs are exhausted.

**Venv used:** `ml/training/venv_multihead_tflite`

---

## Start the agent (one config)

From **repo root**, using your venv:

```bash
ml/training/venv_multihead_tflite/bin/python ml/training/notebooks/train_binary_merged_agent.py \
  --config agent_configs/01_no_weights_light_aug.json
```

Or from `ml/training/notebooks/`:

```bash
cd ml/training/notebooks
../venv_multihead_tflite/bin/python train_binary_merged_agent.py --config agent_configs/01_no_weights_light_aug.json
```

To **run the full agent loop** (try configs 01 → 02 → 03 → 04 until 80% or done):

```bash
# From repo root
chmod +x ml/training/notebooks/run_agent.sh   # once
./ml/training/notebooks/run_agent.sh
```

Or from `ml/training/notebooks/`:

```bash
chmod +x run_agent.sh
./run_agent.sh
```

(Uses `ml/training/venv_multihead_tflite`; see `run_agent.sh` for the config list.)

---

## 1. One-shot run (single config)

From the repo root or from `ml/training/notebooks/`:

```bash
cd ml/training/notebooks
../venv_multihead_tflite/bin/python train_binary_merged_agent.py --config agent_configs/01_no_weights_light_aug.json
```

- Writes `agent_run_config.json` in the notebook dir.
- Executes `binary_classification_merged_dataset.ipynb` (same logic as interactive run).
- Reads `results/binary_merged/agent_result.json` after the run.
- **Exit code:** `0` if accuracy ≥ 80%, `1` if below target, `2`/`3` on config/result errors.

Optional:

- `--target 0.75` to use 75% as target.
- `--timeout 3600` to set notebook execution timeout in seconds (default 7200).

---

## 2. Agentic loop (try configs until 80% or list exhausted)

The **agent** (Cursor/IDE) can:

1. Run the script with the next config, e.g.  
   `python train_binary_merged_agent.py --config agent_configs/01_no_weights_light_aug.json`
2. **Wait for completion** (training can take 30–60+ minutes per run).
3. Read exit code and/or `results/binary_merged/agent_result.json` (accuracy, sensitivity, specificity).
4. If `accuracy >= 0.80`: stop and report success.
5. If not: try the next config (e.g. `02_weights_none_aug.json`, then `03_...`, `04_...`) and repeat.

Suggested order for the agent to try:

1. `agent_configs/01_no_weights_light_aug.json`
2. `agent_configs/02_weights_none_aug.json`
3. `agent_configs/03_no_weights_full_aug.json`
4. `agent_configs/04_weights_light_20ep.json`

(You can add more JSON files under `agent_configs/` with the same keys: `use_class_weights`, `augmentation`, `phase1_epochs`.)

---

## 3. Permissions and environment

### Running locally (e.g. MacBook)

- **Network:** Not required if datasets and packages are already on disk (e.g. `~/dev/oral_cavity_*`). Enable only if the script or notebook downloads data/models.
- **Timeout:** Each run can take **30–90 minutes**. For the agent to wait for completion:
  - Use a **long timeout** for the “run terminal command” step (e.g. **7200 seconds / 2 hours**).
- **Background run:** You can start the script in the **background** (e.g. `python train_binary_merged_agent.py --config ... &` or run in a separate terminal). Then the agent can **poll** for `results/binary_merged/agent_result.json` and, when it exists and is recent, read it and decide the next config (or report success).

### In Cursor

- For **“Run in background”**: allow the command to run in background; the agent can poll the result file.
- For **“Run and wait”**: grant a **long timeout** (e.g. 2 hours) so the run can finish before the agent checks the exit code and result file.

### Summary of what the agent needs

| Need | Suggestion |
|------|------------|
| Run terminal command | Yes (script path + config path). |
| Long timeout | Yes (e.g. 7200 s) if the agent waits for the run to finish. |
| Network | No, unless you add steps that download data. |
| Read result file | Yes: `ml/training/notebooks/results/binary_merged/agent_result.json`. |
| Write config file | Yes: script writes `agent_run_config.json` in the notebook dir. |

---

## 4. Result file

After each run, the notebook writes:

**Path:** `ml/training/notebooks/results/binary_merged/agent_result.json`

**Shape:**

```json
{
  "accuracy": 0.5658,
  "sensitivity": 0.727,
  "specificity": 0.3933,
  "output_dir": "results/binary_merged/run_20260129_152953",
  "config_used": {
    "use_class_weights": true,
    "augmentation": "full",
    "phase1_epochs": 15
  }
}
```

The agent should use `accuracy` to decide if the target (e.g. 80%) is reached and `output_dir` to point to the best run (models, TFLite, etc.).

---

## 5. Making it “background agent” style

- **Option A – Agent waits:** Agent runs `python train_binary_merged_agent.py --config ...` with a **2-hour timeout**, then reads `agent_result.json` and exit code. Repeats with the next config if accuracy < 80%.
- **Option B – You run, agent interprets:** You run the script (or the notebook) in a terminal/background. When it’s done, you tell the agent “run finished” or the agent periodically checks for `agent_result.json` and, when it exists, suggests the next config or reports success.

Both are “agentic” in the sense that the agent chooses the next config and interprets results; the only difference is whether the agent starts the run and waits, or you start it and the agent reacts when the result is ready.
