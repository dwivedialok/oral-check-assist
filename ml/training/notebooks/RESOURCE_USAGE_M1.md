# Resource usage on Mac M1 (16 GB) – freeze comparison training

## Current snapshot (while one notebook is training)

- **Unified memory (vm_stat):** 32 GB total (M1 Pro). Active + wired + inactive in use; **swap activity** can occur under load.
- **Python / Jupyter:**
  - Training kernel (freeze_strategy_comparison): **~1 GB** RSS when measured; can **peak ~1.5–2.5 GB** during forward/backward (model, optimizer, batch on MPS).
  - **MPS (GPU) usage:** PyTorch does not use separate GPU RAM on M1—it uses the same 32 GB. To see how much of that is currently used by MPS tensors, run in the notebook (during or after training):
    ```python
    torch.mps.current_allocated_memory() / 1024**2  # MB
    ```
    The notebook has an optional “MPS memory” cell (after Device setup) that prints this. Typical for one MobileNetV3 + batch 32: **a few hundred MB to ~1 GB** MPS-allocated.
  - Other kernels (idle): ~7–15 MB each. Jupyter server: ~45 MB. TensorBoard: ~21 MB.
- **Other apps:** Cursor, Chrome, etc. use several GB.

## Can you run a second training in parallel (e.g. full_finetune only)?

- **Memory:** A second notebook running 3× full_finetune would add another **~1.5–2.5 GB** (second kernel + second model). That can push you into **12–15 GB** and more swap. **Risky on 16 GB.**
- **MPS (GPU):** On Apple Silicon, MPS uses the same unified memory and GPU. Two PyTorch jobs using MPS at once **share** that resource; they don’t get 2× throughput. You get time-slicing, so **both runs slow down** and memory use is roughly **additive** (two models, two optimizers, two batches in memory).
- **Recommendation:** **Do not** run a second **MPS** training in parallel. Either:
  1. **Wait** for the current run to finish, then in a **new** notebook (or the same one, second run) run **only** the `full_finetune` strategy and log to the **same** `tb_logs` directory (same `OUTPUT_DIR` or same `TB_LOG_DIR`), so TensorBoard shows all strategies together; or  
  2. If you really want overlap: run the second job with **CPU only** (e.g. `device = torch.device("cpu")` in that notebook). It will be much slower but won’t contend for MPS; memory will still increase by ~1–2 GB.

## Same TensorBoard when running full_finetune later

Use the **same** `OUTPUT_DIR` (and thus same `TB_LOG_DIR`) as the run you want to compare with. Easiest:

1. Set the same run name, e.g. in the config cell:
   ```python
   run_name = "freeze_comparison_20260208_121618"  # same as current run
   ```
2. Create `OUTPUT_DIR` and `TB_LOG_DIR` as in the main notebook (so `TB_LOG_DIR = OUTPUT_DIR / "tb_logs"`).
3. Run only the `full_finetune` strategy (e.g. `STRATEGY_NAMES = ["full_finetune"]`) and train; logs go to `tb_logs/full_finetune/ensemble_1`, etc.
4. TensorBoard is already pointing at `.../tb_logs`; after a refresh you’ll see the new runs next to head_only, progressive_K3, progressive_K5.

No need to start a second TensorBoard; one `tensorboard --logdir <...>/tb_logs` is enough.
