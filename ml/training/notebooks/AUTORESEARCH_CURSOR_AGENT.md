# Cursor agent: propose the next autoresearch experiment

This wires **Cursor** (you, in chat) as the “researcher” that Karpathy’s `program.md` describes: the **machine** runs train/eval/ledger; **you** choose the next hypothesis using fresh context.

## One-shot context (run this first)

From repo root, with `ml/training/venv_pytorch/bin/python`:

```bash
ml/training/venv_pytorch/bin/python ml/training/notebooks/autoresearch_loop.py agent-context
```

Optional:

- Machine-readable JSON: add `--output-format json`
- Save markdown to a file: `-o ml/training/notebooks/results/autoresearch/last_context.md`
- More history: `--last-n 10`

Paste the **markdown output** into Cursor (or `@`-reference the `-o` file) and ask: *“Given this ledger and autoresearch_program.md, propose the next single experiment JSON.”*

## What the agent should do

1. Read [autoresearch_program.md](autoresearch_program.md) (objective, guardrails, primary metric).
2. Read the **last ledger row** from the context output (`primary_score`, `TM`, `guardrails_ok`, `kept`, `status`, `config_path`).
3. Compare to baseline / best-so-far in the same output.
4. Propose **exactly one** new file under `experiment_configs/`, e.g. `experiment_configs/proposed_YYYYMMDD_description.json`, by copying an existing config and changing a **small** set of knobs (loss, `focal_gamma`, `epochs`, `cancer_weight_multiplier`, etc.).
5. Tell the user the run command:

   ```bash
   ml/training/venv_pytorch/bin/python ml/training/notebooks/autoresearch_loop.py run \
     --patientwise-v3 \
     --config ml/training/notebooks/experiment_configs/proposed_YYYYMMDD_description.json \
     --run-id-prefix ar_cursor_step
   ```

## What the agent should not do

- Edit `frozen_test_sets/` or `evaluate_on_frozen_sets.py` during a search (breaks comparability).
- Change scoring in code without updating `autoresearch_program.md` and re-baselining.

## Optional: adaptive loop in chat

After each `run` finishes, run `agent-context` again and repeat. No separate LLM server is required—Cursor is the policy that maps **ledger → next JSON**.
