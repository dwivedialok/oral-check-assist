# Parallel Training Guide

## Can You Run Multiple Experiments in Parallel?

**Short Answer:** 
- **32GB+ unified memory (M1/M2/M3)**: ✅ **Yes, feasible** - Memory is not a concern
- **16GB unified memory**: ⚠️ **Possible but tight** - Monitor closely
- **8GB or less**: ❌ **Not recommended** - High OOM risk

**Performance Trade-off:** Parallel runs will be slower per experiment (~2× slower with 2 processes) due to GPU compute resource sharing, but total wall-clock time may be similar if you're running multiple experiments.

## Memory Analysis

### Per Experiment Memory Requirements

Each experiment (`--ensemble` mode) trains **3 models sequentially**, so only **1 model is in memory at a time**:

- **Model weights**: ~5.5M parameters × 4 bytes = **~22 MB**
- **Optimizer states** (Adam/AdamW): ~2× model size = **~44 MB**
- **Batch memory** (batch_size=32, 224×224×3): **~6-12 MB** (forward + backward)
- **Gradients**: ~22 MB
- **Total per model**: **~90-100 MB GPU memory**

### Parallel Run Memory

If you run **2 experiments in parallel**:
- **2 processes** × **~100 MB each** = **~200 MB GPU memory**
- Plus system RAM for data loading (~500 MB - 1 GB per process)

## Hardware Considerations

### Apple Silicon (MPS) - 32GB Unified Memory
- ✅ **Excellent memory headroom**: 32GB is plenty for 2-3 parallel experiments
- ✅ **Safe from OOM**: Each experiment uses ~100MB GPU memory, so 2 experiments = ~200MB (well within limits)
- ⚠️ **GPU compute sharing**: Both processes compete for Neural Engine/GPU cores
- ⚠️ **Slower per experiment**: Each process gets ~50% GPU time, so each experiment takes ~2× longer
- ✅ **Total time**: If running 2+ experiments, total wall-clock time may be similar or faster than sequential

### CUDA (NVIDIA GPU)
- ✅ **Multiple processes** can share GPU memory
- ⚠️ **Memory fragmentation** can cause OOM errors
- ⚠️ **CUDA context switching** overhead

### CPU Only
- ✅ **Safe** - no GPU memory limits
- ❌ **Very slow** - not recommended

## Recommendations

### ✅ **Recommended: Sequential Runs**
Run experiments one at a time for:
- **Faster training** (full GPU utilization)
- **No memory conflicts**
- **Easier monitoring**
- **Lower risk of crashes**

```bash
# Run sequentially
python train_experiment.py --config experiment_configs/adamw.json --run_id exp_adamw_ensemble --ensemble --export_onnx --evaluate

# Wait for completion, then:
python train_experiment.py --config experiment_configs/freeze_bn.json --run_id exp_freeze_bn_ensemble --ensemble --export_onnx --evaluate
```

### ✅ **Running in Parallel on 32GB M1 MacBook**

**Your Setup:**
- ✅ **32GB unified memory**: Excellent headroom for parallel runs
- ✅ **M1 Neural Engine**: Can handle 2 processes, but they'll share compute
- ✅ **Memory safe**: 2 experiments = ~200MB GPU memory (well within 32GB limit)

**Recommendation for 32GB:**
- ✅ **2 experiments in parallel**: Safe and reasonable
- ⚠️ **3+ experiments**: Possible but diminishing returns (each gets ~33% GPU time)
- ✅ **Monitor**: Still good to keep an eye on memory, but OOM risk is very low

**How to Monitor:**

1. **Check GPU/MPS memory usage:**
   ```bash
   # Apple Silicon (MPS)
   sudo powermetrics --samplers gpu_power -i 1000 -n 1 | grep -i "gpu\|memory"
   
   # Or use Activity Monitor → Window → GPU History
   ```

2. **Check system memory:**
   ```bash
   # macOS
   vm_stat
   
   # Or use Activity Monitor
   ```

3. **Monitor Python processes:**
   ```bash
   ps aux | grep train_experiment.py
   ```

**Run in background with logging:**
```bash
# Terminal 1
python train_experiment.py --config experiment_configs/adamw.json \
  --run_id exp_adamw_ensemble --ensemble --export_onnx --evaluate \
  > exp_adamw.log 2>&1 &

# Terminal 2
python train_experiment.py --config experiment_configs/freeze_bn.json \
  --run_id exp_freeze_bn_ensemble --ensemble --export_onnx --evaluate \
  > exp_freeze_bn.log 2>&1 &

# Monitor both
tail -f exp_adamw.log exp_freeze_bn.log
```

## Performance Impact

### Sequential (Recommended)
- **Training time**: ~30-60 min per experiment (3 models × 10-20 min each)
- **GPU utilization**: ~95-100%
- **Memory**: Stable, predictable

### Parallel (2 experiments)
- **Training time**: ~60-120 min per experiment (due to resource sharing)
- **GPU utilization**: ~50% per process
- **Memory**: Higher risk, less predictable
- **Total wall-clock time**: Similar, but higher risk of failures

## Best Practice: Queue System

For multiple experiments, consider a simple queue:

```bash
# Create a queue file
cat > experiment_queue.txt << EOF
experiment_configs/adamw.json exp_adamw_ensemble
experiment_configs/freeze_bn.json exp_freeze_bn_ensemble
experiment_configs/focal.json exp_focal_ensemble
experiment_configs/temperature.json exp_temp_ensemble
EOF

# Run sequentially
while IFS= read -r line; do
  config=$(echo $line | cut -d' ' -f1)
  run_id=$(echo $line | cut -d' ' -f2)
  echo "Starting: $run_id"
  python train_experiment.py --config $config --run_id $run_id --ensemble --export_onnx --evaluate
  echo "Completed: $run_id"
done < experiment_queue.txt
```

## Current Status Check

If you've already started `exp_adamw_ensemble`:

1. **Check if it's using GPU:**
   ```bash
   ps aux | grep train_experiment | grep -v grep
   ```

2. **Monitor its progress:**
   ```bash
   # Check TensorBoard logs
   ls -lh results/train_experiment/exp_adamw_ensemble/ensemble_*/tb_logs/
   
   # Or tail the output if running in foreground
   ```

3. **Decision:**
   - **If it's early** (< 10% complete): Consider stopping and running sequentially
   - **If it's far along** (> 50% complete): Let it finish, then start the next one
   - **If you have 32GB+ memory**: Parallel is safer, but still slower

## Summary for 32GB M1 MacBook

| Approach | Speed per Exp | Total Time (4 exps) | Memory Risk | Recommended? |
|----------|---------------|---------------------|-------------|-------------|
| Sequential | Fast (~30-60 min) | ~2-4 hours | Very Low | ✅ **Best for single experiment** |
| Parallel (2) | Slower (~60-120 min) | ~2-4 hours | Very Low | ✅ **Good for multiple experiments** |
| Parallel (3+) | Very Slow (~90-180 min) | ~3-6 hours | Low | ⚠️ **Possible but slow** |

**Recommendation for 32GB M1:**
- ✅ **2 experiments in parallel**: Safe and reasonable - good use of your hardware
- ✅ **Sequential**: Still fastest per experiment, but parallel can save total time if running multiple
- ✅ **Your choice**: With 32GB, parallel is viable - choose based on whether you want faster individual experiments (sequential) or faster total completion time (parallel)
