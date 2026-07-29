#!/usr/bin/env python3
"""
Extract training metrics from saved checkpoints for Experiments 1 & 2.

This script loads the checkpoint, reconstructs the model and data loaders,
then evaluates on the validation set to extract metrics that weren't saved.

Usage:
  python extract_experiment_metrics.py --run_id exp_adamw
  python extract_experiment_metrics.py --run_id exp_freeze_bn
  python extract_experiment_metrics.py --all  # Extract for both experiments
"""

import argparse
import json
import sys
from pathlib import Path

import numpy as np
import torch
import torch.nn as nn
from sklearn.utils.class_weight import compute_class_weight
from torch.utils.data import DataLoader

# Add notebook dir to path
NOTEBOOK_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(NOTEBOOK_DIR))

from frozen_test_sets import get_all_train_val_for_training
# Import from train_experiment module
import train_experiment as te
from train_experiment import (
    BinaryDataset,
    ConservativeMobileNetV3,
    build_data,
    get_transforms,
    validate,
    FocalLoss,
)


def extract_metrics(run_id, output_dir=None):
    """Load checkpoint and extract validation metrics."""
    if output_dir is None:
        output_dir = NOTEBOOK_DIR / "results" / "train_experiment" / run_id
    
    output_dir = Path(output_dir)
    config_path = output_dir / "config.json"
    ckpt_path = output_dir / "models" / "best.pth"
    
    if not config_path.exists():
        print(f"❌ Config not found: {config_path}")
        return None
    
    if not ckpt_path.exists():
        print(f"❌ Checkpoint not found: {ckpt_path}")
        return None
    
    print(f"\n📊 Extracting metrics for {run_id}")
    print(f"   Config: {config_path}")
    print(f"   Checkpoint: {ckpt_path}")
    
    # Load config
    with open(config_path) as f:
        cfg = json.load(f)
    
    # Set up device
    device = torch.device("mps" if torch.backends.mps.is_available() else "cuda" if torch.cuda.is_available() else "cpu")
    print(f"   Device: {device}")
    
    # Reconstruct data loaders (same seed as training)
    torch.manual_seed(cfg["seed"])
    train_paths, val_paths, train_labels, val_labels = build_data(cfg)
    train_t, val_t, use_albu = get_transforms(cfg)
    val_ds = BinaryDataset(val_paths, val_labels, transform=val_t, use_albu=use_albu)
    val_loader = DataLoader(val_ds, batch_size=cfg["batch_size"], shuffle=False, num_workers=0)
    
    print(f"   Validation set size: {len(val_ds)}")
    
    # Reconstruct model
    model = ConservativeMobileNetV3(num_classes=2, dropout_rate=cfg.get("dropout_rate", 0.2)).to(device)
    
    # Load checkpoint
    state_dict = torch.load(ckpt_path, map_location=device)
    model.load_state_dict(state_dict)
    model.eval()
    print(f"   ✅ Model loaded")
    
    # Reconstruct criterion (for loss calculation)
    classes = np.unique(train_labels)
    weights = compute_class_weight("balanced", classes=classes, y=train_labels)
    if cfg.get("cancer_weight_multiplier", 1.0) != 1.0:
        weights[1] *= cfg["cancer_weight_multiplier"]
    class_weights = torch.tensor(weights, dtype=torch.float32).to(device)
    
    if cfg["loss"] == "focal":
        criterion = FocalLoss(gamma=cfg.get("focal_gamma", 2.0), weight=class_weights)
    else:
        criterion = nn.CrossEntropyLoss(weight=class_weights, label_smoothing=cfg.get("label_smoothing", 0.0))
    
    # Evaluate on validation set
    print(f"   Evaluating on validation set...")
    val_acc, val_auc, val_loss = validate(model, val_loader, criterion, device)
    
    # Extract metrics
    metrics = {
        "run_id": run_id,
        "final_val_accuracy": float(val_acc),
        "final_val_auc": float(val_auc),
        "final_val_loss": float(val_loss),
        "config": cfg
    }
    
    # Try to extract best AUC from terminal logs if available
    # (We know from logs that exp_freeze_bn had best_val_auc=0.8721)
    terminal_logs_dir = Path.home() / ".cursor" / "projects" / "Users-alokdwivedi-dev-github-3amwave-oral-cavity-classifier" / "terminals"
    best_auc_from_logs = None
    if terminal_logs_dir.exists():
        import glob
        log_files = glob.glob(str(terminal_logs_dir / "*.txt"))
        for log_file in log_files:
            try:
                with open(log_file, 'r') as f:
                    content = f.read()
                    if run_id in content and "Best val AUC:" in content:
                        # Extract the best AUC value
                        lines = content.split('\n')
                        for line in lines:
                            if "Best val AUC:" in line:
                                try:
                                    best_auc_from_logs = float(line.split("Best val AUC:")[1].strip())
                                    break
                                except:
                                    pass
                        if best_auc_from_logs:
                            break
            except:
                continue
    
    if best_auc_from_logs is not None:
        metrics["best_val_auc"] = best_auc_from_logs
        print(f"   ✅ Found best_val_auc from logs: {best_auc_from_logs:.4f}")
    else:
        # Use final_val_auc as best_val_auc (may not be exact, but close)
        metrics["best_val_auc"] = float(val_auc)
        print(f"   ⚠️  Could not find best_val_auc in logs, using final_val_auc: {val_auc:.4f}")
    
    # Save metrics
    metrics_path = output_dir / "training_metrics.json"
    with open(metrics_path, "w") as f:
        json.dump(metrics, f, indent=2)
    
    print(f"   ✅ Metrics saved to: {metrics_path}")
    print(f"\n   📈 Results:")
    print(f"      Best Val AUC:  {metrics['best_val_auc']:.4f}")
    print(f"      Final Val Acc: {metrics['final_val_accuracy']:.2f}%")
    print(f"      Final Val AUC: {metrics['final_val_auc']:.4f}")
    print(f"      Final Val Loss: {metrics['final_val_loss']:.4f}")
    
    return metrics


def main():
    parser = argparse.ArgumentParser(description="Extract metrics from experiment checkpoints")
    parser.add_argument("--run_id", help="Run ID (e.g., exp_adamw, exp_freeze_bn)")
    parser.add_argument("--all", action="store_true", help="Extract metrics for all completed experiments")
    parser.add_argument("--output_dir", help="Override output directory")
    args = parser.parse_args()
    
    if args.all:
        # Extract for both completed experiments
        results = {}
        for run_id in ["exp_adamw", "exp_freeze_bn"]:
            try:
                metrics = extract_metrics(run_id, args.output_dir)
                if metrics:
                    results[run_id] = metrics
            except Exception as e:
                print(f"❌ Error extracting metrics for {run_id}: {e}")
                import traceback
                traceback.print_exc()
        
        if results:
            print(f"\n✅ Successfully extracted metrics for {len(results)} experiment(s)")
    elif args.run_id:
        extract_metrics(args.run_id, args.output_dir)
    else:
        parser.print_help()
        sys.exit(1)


if __name__ == "__main__":
    main()
