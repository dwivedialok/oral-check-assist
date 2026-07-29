#!/usr/bin/env python3
"""
Standalone training script for binary oral classification with configurable options.

Accepts a JSON config for strategy (progressive_K5 / full_finetune), optimizer (adam / adamw),
weight_decay, freeze_bn, loss (ce / focal), etc. Saves checkpoint to results/train_experiment/<run_id>/.

Usage:
  # Single model (backward compatible)
  python train_experiment.py --config experiment.json [--run_id exp1] [--export_onnx]
  
  # 3-model ensemble with automatic evaluation (recommended)
  python train_experiment.py --config experiment.json --ensemble --export_onnx --evaluate [--run_id exp1]
  
Options:
  --ensemble: Train 3 models with dropout rates [0.3, 0.1, 0.2] and seeds [base, base+1, base+2]
  --export_onnx: Export trained model(s) to ONNX format
  --evaluate: Automatically evaluate ensemble on frozen test sets after training (requires --ensemble --export_onnx)
  --eval-no-skip-missing: Fail eval if any frozen-manifest path is missing (default skips missing files with warnings)
  --run_id: Experiment identifier (default: train_exp_<timestamp>)

Monitoring:
  - Progress prints every 2 epochs (val_acc, val_auc)
  - TensorBoard logs: results/train_experiment/<run_id>/ensemble_*/tb_logs/ (if TB available)
  - View TB: tensorboard --logdir=results/train_experiment/<run_id>
"""

import argparse
import json
import os
import subprocess
import sys
from datetime import datetime
from pathlib import Path

try:
    import psutil
    HAS_PSUTIL = True
except ImportError:
    HAS_PSUTIL = False

import numpy as np
import torch
import torch.nn as nn
import torch.optim as optim
from PIL import Image, ImageFile

# Match train_binary_ensemble_patientwise.ipynb: tolerate truncated downloads / bad JPEG tails.
ImageFile.LOAD_TRUNCATED_IMAGES = True
from sklearn.model_selection import train_test_split
from sklearn.utils.class_weight import compute_class_weight
from torch.utils.data import DataLoader, Dataset
from torchvision import models
from tqdm import tqdm

NOTEBOOK_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(NOTEBOOK_DIR))

from frozen_test_sets import (
    get_all_train_val_for_training,
    get_all_train_val_for_training_v3,
)

try:
    from torch.utils.tensorboard import SummaryWriter
    HAS_TB = True
except ImportError:
    HAS_TB = False

try:
    import albumentations as A
    from albumentations.pytorch import ToTensorV2
    HAS_ALB = True
except ImportError:
    HAS_ALB = False

# Legacy only: image-wise 5-class tree (not used when patientwise_v3 is True, the default).
DATA_DIR_5CLASS_IMAGEWISE = os.path.expanduser("~/dev/oral_cavity_5class_dataset")
CLASS_TO_BINARY = {"Benign": 0, "Healthy": 0, "OCA": 1, "OPMD": 1, "Unknown": None}
IMAGENET_MEAN = [0.485, 0.456, 0.406]
IMAGENET_STD = [0.229, 0.224, 0.225]


def _other_train_processes_with_run_id(run_id):
    """Return list of (pid, cmdline) for other processes running train_experiment.py with this run_id."""
    my_pid = os.getpid()
    matches = []
    run_id_arg = f"run_id {run_id}"  # e.g. "run_id exp_focal"
    if HAS_PSUTIL:
        for p in psutil.process_iter(["pid", "cmdline"]):
            try:
                cmdline = p.info.get("cmdline") or []
                if p.info["pid"] == my_pid:
                    continue
                cmdstr = " ".join(str(c) for c in cmdline) if isinstance(cmdline, list) else str(cmdline)
                if "train_experiment.py" in cmdstr and run_id_arg in cmdstr:
                    matches.append((p.info["pid"], cmdstr))
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                pass
    else:
        out = subprocess.run(
            ["ps", "-eo", "pid,command"],
            capture_output=True,
            text=True,
            timeout=5,
        )
        if out.returncode != 0:
            return matches
        for line in out.stdout.splitlines():
            if "train_experiment.py" not in line or run_id_arg not in line:
                continue
            parts = line.strip().split(None, 1)
            if len(parts) < 2:
                continue
            try:
                pid = int(parts[0])
            except ValueError:
                continue
            if pid == my_pid:
                continue
            matches.append((pid, parts[1]))
    return matches


def load_config(config_path):
    with open(config_path) as f:
        cfg = json.load(f)
    defaults = {
        "task": "binary",
        "strategy": "progressive_K5",
        "optimizer": "adam",
        "weight_decay": 0.0,
        "freeze_bn": False,
        "loss": "ce",
        "focal_gamma": 2.0,
        "epochs": 50,
        "warmup_epochs": 5,
        "batch_size": 32,
        "lr": 1e-4,
        "lr_head": 1e-3,
        "lr_backbone": 1e-4,
        "patience": 12,
        "dropout_rate": 0.2,
        "label_smoothing": 0.05,
        "cancer_weight_multiplier": 1.5,
        "seed": 42,
        # Same training pool as train_binary_ensemble_patientwise.ipynb (patient-wise T5/SMART + manifests).
        "patientwise_v3": True,
    }
    for k, v in defaults.items():
        cfg.setdefault(k, v)
    return cfg


class BinaryDataset(Dataset):
    def __init__(self, paths, labels, transform=None, use_albu=True):
        self.paths = paths
        self.labels = labels
        self.transform = transform
        self.use_albu = use_albu

    def __len__(self):
        return len(self.paths)

    def __getitem__(self, idx):
        # RGBA first avoids PIL palette+transparency warnings on some oral images.
        img = Image.open(self.paths[idx]).convert("RGBA").convert("RGB")
        label = self.labels[idx]
        if self.transform:
            if self.use_albu:
                img = np.array(img)
                img = self.transform(image=img)["image"]
            else:
                img = self.transform(img)
        else:
            img = np.array(img)
            import torch
            img = torch.from_numpy(img).permute(2, 0, 1).float() / 255.0
        return img, label


class ConservativeMobileNetV3(nn.Module):
    def __init__(self, num_classes=2, dropout_rate=0.2):
        super().__init__()
        try:
            self.backbone = models.mobilenet_v3_large(
                weights=models.MobileNet_V3_Large_Weights.IMAGENET1K_V2
            )
        except AttributeError:
            self.backbone = models.mobilenet_v3_large(pretrained=True)
        self.backbone.classifier = nn.Identity()
        self.classifier = nn.Sequential(
            nn.AdaptiveAvgPool2d((1, 1)),
            nn.Flatten(),
            nn.Dropout(dropout_rate),
            nn.Linear(960, 256),
            nn.ReLU(inplace=True),
            nn.Linear(256, num_classes),
        )

    def forward(self, x):
        x = self.backbone.features(x)
        x = self.classifier(x)
        return x

    def freeze_backbone(self):
        for p in self.backbone.features.parameters():
            p.requires_grad = False

    def unfreeze_last_k_blocks(self, k):
        children = list(self.backbone.features.children())
        for layer in children[-k:]:
            for p in layer.parameters():
                p.requires_grad = True

    def get_param_groups(self, lr_head, lr_backbone=None):
        groups = [{"params": list(self.classifier.parameters()), "lr": lr_head}]
        backbone_trainable = [p for p in self.backbone.features.parameters() if p.requires_grad]
        if backbone_trainable and lr_backbone is not None:
            groups.append({"params": backbone_trainable, "lr": lr_backbone})
        return groups

    def trainable_param_count(self):
        return sum(p.numel() for p in self.parameters() if p.requires_grad)


def build_data(cfg):
    """
    Training pool for binary task.

    - Default (patientwise_v3=True): same as ``train_binary_ensemble_patientwise.ipynb`` —
      ``get_all_train_val_for_training_v3`` → patient-wise T5 + SMART under
      ``~/dev/oral_cavity_5class_dataset_patientwise`` and ``~/dev/oral_cavity_smart_ii_patientwise``,
      plus TB/TC manifests (see ``frozen_test_sets.py``).

    - patientwise_v3=False (opt-in legacy): binary manifests + image-wise
      ``~/dev/oral_cavity_5class_dataset`` train/val scan (old train_experiment behavior only).
    """
    frozen_dir = NOTEBOOK_DIR / "frozen_test_sets"
    if cfg.get("patientwise_v3"):
        all_paths, all_labels, _ = get_all_train_val_for_training_v3(frozen_dir)
        train_paths, val_paths, train_labels, val_labels = train_test_split(
            all_paths,
            all_labels,
            test_size=0.15,
            random_state=cfg["seed"],
            stratify=all_labels,
        )
        return train_paths, val_paths, train_labels, val_labels

    binary_paths, binary_labels, _ = get_all_train_val_for_training(frozen_dir)
    five_dir = Path(DATA_DIR_5CLASS_IMAGEWISE)
    train_paths_5, train_labels_5 = [], []
    for split in ("train", "val"):
        d = five_dir / split
        if not d.exists():
            continue
        for cls, bin_val in CLASS_TO_BINARY.items():
            if bin_val is None:
                continue
            for p in d.glob(f"{cls}/*"):
                if p.suffix.lower() in (".jpg", ".jpeg", ".png"):
                    train_paths_5.append(str(p))
                    train_labels_5.append(bin_val)
    all_paths = list(binary_paths) + list(train_paths_5)
    all_labels = list(binary_labels) + list(train_labels_5)
    train_paths, val_paths, train_labels, val_labels = train_test_split(
        all_paths, all_labels, test_size=0.15, random_state=cfg["seed"], stratify=all_labels
    )
    return train_paths, val_paths, train_labels, val_labels


def get_transforms(cfg):
    if HAS_ALB:
        train_t = A.Compose([
            A.Resize(224, 224),
            A.Normalize(mean=IMAGENET_MEAN, std=IMAGENET_STD),
            ToTensorV2(),
        ])
        val_t = A.Compose([
            A.Resize(224, 224),
            A.Normalize(mean=IMAGENET_MEAN, std=IMAGENET_STD),
            ToTensorV2(),
        ])
        return train_t, val_t, True
    else:
        import torchvision.transforms as T
        t = T.Compose([
            T.Resize((224, 224)),
            T.ToTensor(),
            T.Normalize(IMAGENET_MEAN, IMAGENET_STD),
        ])
        return t, t, False


class FocalLoss(nn.Module):
    def __init__(self, gamma=2.0, weight=None):
        super().__init__()
        self.gamma = gamma
        self.weight = weight

    def forward(self, logits, targets):
        ce = nn.functional.cross_entropy(logits, targets, weight=self.weight, reduction="none")
        pt = torch.exp(-ce)
        return ( (1 - pt) ** self.gamma * ce ).mean()


def train_one_epoch(model, loader, criterion, optimizer, device, freeze_bn=False):
    model.train()
    if freeze_bn:
        for m in model.modules():
            if isinstance(m, (nn.BatchNorm2d, nn.BatchNorm1d)):
                m.eval()
    total_loss, correct, n = 0.0, 0, 0
    for x, y in tqdm(loader, leave=False):
        x, y = x.to(device), y.to(device)
        optimizer.zero_grad()
        out = model(x)
        loss = criterion(out, y)
        loss.backward()
        optimizer.step()
        total_loss += loss.item() * x.size(0)
        correct += (out.argmax(1) == y).sum().item()
        n += x.size(0)
    return total_loss / n, 100.0 * correct / n


@torch.no_grad()
def validate(model, loader, criterion, device):
    model.eval()
    total_loss, correct, probs_list, targets_list = 0.0, 0, [], []
    for x, y in loader:
        x, y = x.to(device), y.to(device)
        out = model(x)
        loss = criterion(out, y)
        total_loss += loss.item() * x.size(0)
        correct += (out.argmax(1) == y).sum().item()
        probs_list.append(torch.softmax(out, 1)[:, 1].cpu().numpy())
        targets_list.append(y.cpu().numpy())
    n = len(loader.dataset)
    probs = np.concatenate(probs_list)
    targets = np.concatenate(targets_list)
    from sklearn.metrics import roc_auc_score
    auc = roc_auc_score(targets, probs) if np.unique(targets).size >= 2 else 0.0
    return 100.0 * correct / n, auc, total_loss / n


def run_training(cfg, output_dir):
    torch.manual_seed(cfg["seed"])
    device = torch.device("mps" if torch.backends.mps.is_available() else "cuda" if torch.cuda.is_available() else "cpu")

    # TensorBoard (logs to output_dir/tb_logs; safe to add — only new processes use this file)
    writer = None
    if HAS_TB:
        tb_dir = output_dir / "tb_logs"
        tb_dir.mkdir(parents=True, exist_ok=True)
        writer = SummaryWriter(log_dir=str(tb_dir))

    train_paths, val_paths, train_labels, val_labels = build_data(cfg)
    train_t, val_t, use_albu = get_transforms(cfg)
    train_ds = BinaryDataset(train_paths, train_labels, transform=train_t, use_albu=use_albu)
    val_ds = BinaryDataset(val_paths, val_labels, transform=val_t, use_albu=use_albu)
    train_loader = DataLoader(train_ds, batch_size=cfg["batch_size"], shuffle=True, num_workers=0)
    val_loader = DataLoader(val_ds, batch_size=cfg["batch_size"], shuffle=False, num_workers=0)

    classes = np.unique(train_labels)
    weights = compute_class_weight("balanced", classes=classes, y=train_labels)
    if cfg.get("cancer_weight_multiplier", 1.0) != 1.0:
        weights[1] *= cfg["cancer_weight_multiplier"]
    class_weights = torch.tensor(weights, dtype=torch.float32).to(device)

    if cfg["loss"] == "focal":
        criterion = FocalLoss(gamma=cfg.get("focal_gamma", 2.0), weight=class_weights)
    else:
        criterion = nn.CrossEntropyLoss(weight=class_weights, label_smoothing=cfg.get("label_smoothing", 0.0))

    model = ConservativeMobileNetV3(num_classes=2, dropout_rate=cfg.get("dropout_rate", 0.2)).to(device)
    strategy = cfg["strategy"]
    optim_name = cfg.get("optimizer", "adam").lower()
    wd = cfg.get("weight_decay", 0.0)
    freeze_bn = cfg.get("freeze_bn", False)

    epochs_trained = 0
    early_stopped = False
    if strategy == "progressive_K5":
        model.freeze_backbone()
        warmup_epochs = cfg.get("warmup_epochs", 5)
        main_epochs = cfg["epochs"]
        optimizer = optim.Adam(model.classifier.parameters(), lr=cfg["lr_head"], weight_decay=wd)
        for ep in range(warmup_epochs):
            loss, acc = train_one_epoch(model, train_loader, criterion, optimizer, device, freeze_bn)
            val_acc, val_auc, _ = validate(model, val_loader, criterion, device)
            if writer is not None:
                writer.add_scalar("train/loss", loss, ep)
                writer.add_scalar("train/acc", acc, ep)
                writer.add_scalar("val/acc", val_acc, ep)
                writer.add_scalar("val/auc", val_auc, ep)
                writer.add_scalar("train/lr", optimizer.param_groups[0]["lr"], ep)
            if (ep + 1) % 2 == 0:
                print(f"  Warmup {ep+1}/{warmup_epochs}  train_acc={acc:.2f}%  val_auc={val_auc:.4f}")
        model.unfreeze_last_k_blocks(5)
        param_groups = model.get_param_groups(cfg["lr_head"], cfg["lr_backbone"])
        optimizer = optim.AdamW(param_groups, weight_decay=wd) if optim_name == "adamw" else optim.Adam(param_groups, weight_decay=wd)
        scheduler = optim.lr_scheduler.CosineAnnealingLR(optimizer, T_max=main_epochs, eta_min=1e-6)
        best_auc, best_state, patience = 0.0, None, 0
        for ep in range(main_epochs):
            loss, acc = train_one_epoch(model, train_loader, criterion, optimizer, device, freeze_bn)
            val_acc, val_auc, _ = validate(model, val_loader, criterion, device)
            scheduler.step()
            step = warmup_epochs + ep
            if writer is not None:
                writer.add_scalar("train/loss", loss, step)
                writer.add_scalar("train/acc", acc, step)
                writer.add_scalar("val/acc", val_acc, step)
                writer.add_scalar("val/auc", val_auc, step)
                lr = optimizer.param_groups[0]["lr"]
                writer.add_scalar("train/lr", lr, step)
            if val_auc > best_auc:
                best_auc = val_auc
                best_state = {k: v.cpu().clone() for k, v in model.state_dict().items()}
                patience = 0
            else:
                patience += 1
            if (ep + 1) % 2 == 0 or ep == 0:
                print(f"  Ep {ep+1}/{main_epochs}  val_acc={val_acc:.2f}%  val_auc={val_auc:.4f}")
            if patience >= cfg.get("patience", 12):
                print(f"  Early stop at epoch {ep+1}")
                epochs_trained = warmup_epochs + ep + 1
                early_stopped = True
                break
        if not early_stopped:
            epochs_trained = warmup_epochs + main_epochs
        if best_state:
            model.load_state_dict(best_state)
    else:
        main_epochs = cfg["epochs"]
        optimizer = (optim.AdamW(model.parameters(), lr=cfg["lr"], weight_decay=wd)
                    if optim_name == "adamw" else optim.Adam(model.parameters(), lr=cfg["lr"], weight_decay=wd))
        scheduler = optim.lr_scheduler.CosineAnnealingLR(optimizer, T_max=main_epochs, eta_min=1e-6)
        best_auc, best_state, patience = 0.0, None, 0
        for ep in range(main_epochs):
            loss, acc = train_one_epoch(model, train_loader, criterion, optimizer, device, freeze_bn)
            val_acc, val_auc, _ = validate(model, val_loader, criterion, device)
            scheduler.step()
            if writer is not None:
                writer.add_scalar("train/loss", loss, ep)
                writer.add_scalar("train/acc", acc, ep)
                writer.add_scalar("val/acc", val_acc, ep)
                writer.add_scalar("val/auc", val_auc, ep)
                lr = optimizer.param_groups[0]["lr"]
                writer.add_scalar("train/lr", lr, ep)
            if val_auc > best_auc:
                best_auc = val_auc
                best_state = {k: v.cpu().clone() for k, v in model.state_dict().items()}
                patience = 0
            else:
                patience += 1
            if (ep + 1) % 2 == 0 or ep == 0:
                print(f"  Ep {ep+1}/{main_epochs}  val_acc={val_acc:.2f}%  val_auc={val_auc:.4f}")
            if patience >= cfg.get("patience", 12):
                epochs_trained = ep + 1
                early_stopped = True
                break
        if not early_stopped:
            epochs_trained = main_epochs
        if best_state:
            model.load_state_dict(best_state)

    if writer is not None:
        writer.close()

    ckpt_path = output_dir / "models" / "best.pth"
    ckpt_path.parent.mkdir(parents=True, exist_ok=True)
    torch.save(model.state_dict(), ckpt_path)
    with open(output_dir / "config.json", "w") as f:
        json.dump(cfg, f, indent=2)
    print(f"Saved {ckpt_path}")

    # Evaluate best model on validation set and save metrics
    model.eval()
    final_val_acc, final_val_auc, final_val_loss = validate(model, val_loader, criterion, device)
    metrics = {
        "best_val_auc": float(best_auc),
        "final_val_accuracy": float(final_val_acc),
        "final_val_auc": float(final_val_auc),
        "final_val_loss": float(final_val_loss),
        "epochs_trained": epochs_trained,
        "early_stopped": early_stopped
    }
    with open(output_dir / "training_metrics.json", "w") as f:
        json.dump(metrics, f, indent=2)
    print(f"Saved training metrics to {output_dir / 'training_metrics.json'}")

    if cfg.get("temperature_scaling"):
        T_val = apply_temperature_scaling(model, val_loader, device)
        with open(output_dir / "temperature.json", "w") as f:
            json.dump({"temperature": T_val}, f)
        print(f"Temperature scaling: T={T_val:.4f} saved to {output_dir / 'temperature.json'}")

    return best_auc


def apply_temperature_scaling(model, val_loader, device):
    """Find T that minimizes NLL on validation logits; logits are scaled by 1/T before softmax."""
    model.eval()
    logits_list, targets_list = [], []
    with torch.no_grad():
        for x, y in val_loader:
            x = x.to(device)
            logits_list.append(model(x).cpu().numpy())
            targets_list.append(y.numpy())
    logits = np.concatenate(logits_list)
    targets = np.concatenate(targets_list).astype(int)

    def nll(T):
        T = max(1e-3, float(T))
        probs = torch.softmax(torch.tensor(logits / T), 1).numpy()
        eps = 1e-8
        probs = np.clip(probs, eps, 1 - eps)
        return -np.mean(np.log(probs[np.arange(len(targets)), targets]))

    best_T, best_nll = 1.0, nll(1.0)
    for T in np.linspace(0.5, 5.0, 46):
        nll_val = nll(T)
        if nll_val < best_nll:
            best_nll = nll_val
            best_T = T
    return float(best_T)


def export_to_onnx(model, onnx_path, device):
    """Export PyTorch model to ONNX format."""
    try:
        import onnx
        HAS_ONNX = True
    except ImportError:
        HAS_ONNX = False
    
    model.eval()
    model.to(device)
    dummy = torch.randn(1, 3, 224, 224).to(device)
    
    torch.onnx.export(
        model, dummy, str(onnx_path),
        export_params=True,
        opset_version=18,
        do_constant_folding=True,
        input_names=["input"],
        output_names=["output"],
        dynamic_axes={"input": {0: "batch_size"}, "output": {0: "batch_size"}},
    )
    
    if HAS_ONNX:
        onnx_model = onnx.load(str(onnx_path))
        onnx.save_model(onnx_model, str(onnx_path), save_as_external_data=False)
        data_file = Path(str(onnx_path) + ".data")
        if data_file.exists():
            data_file.unlink()
    
    size_mb = onnx_path.stat().st_size / 1024 / 1024
    return size_mb


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", required=True, help="JSON config path")
    parser.add_argument("--run_id", default=None, help="Run ID (default: train_exp_<timestamp>)")
    parser.add_argument("--output_dir", default=None, help="Output dir (default: results/train_experiment/<run_id>)")
    parser.add_argument("--ensemble", action="store_true", help="Train 3-model ensemble (different dropout rates and seeds)")
    parser.add_argument("--export_onnx", action="store_true", help="Export trained models to ONNX")
    parser.add_argument("--evaluate", action="store_true", help="Automatically evaluate ensemble on frozen test sets after training (requires --ensemble --export_onnx)")
    parser.add_argument(
        "--eval-no-skip-missing",
        action="store_true",
        help="Fail frozen eval if any manifest path is missing (default: skip missing files with stderr warnings)",
    )
    parser.add_argument(
        "--patientwise-v3",
        action="store_true",
        help="Force patient-wise v3 pool (default; same as train_binary_ensemble_patientwise.ipynb)",
    )
    parser.add_argument(
        "--legacy-image-wise-5class",
        action="store_true",
        help="Opt in to old pool: manifests + image-wise ~/dev/oral_cavity_5class_dataset train/val (not patient-wise)",
    )
    args = parser.parse_args()
    
    # Validate --evaluate requires --ensemble and --export_onnx
    if args.evaluate and (not args.ensemble or not args.export_onnx):
        print("Error: --evaluate requires --ensemble and --export_onnx", file=sys.stderr)
        sys.exit(1)

    if args.legacy_image_wise_5class and args.patientwise_v3:
        print("Error: use only one of --legacy-image-wise-5class or --patientwise-v3", file=sys.stderr)
        sys.exit(1)

    cfg = load_config(args.config)
    if args.legacy_image_wise_5class:
        cfg["patientwise_v3"] = False
    elif args.patientwise_v3:
        cfg["patientwise_v3"] = True
    run_id = args.run_id or f"train_exp_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
    output_dir = Path(args.output_dir) if args.output_dir else NOTEBOOK_DIR / "results" / "train_experiment" / run_id

    # Warn if other processes are already running this run_id (avoids "phantom" duplicate runs)
    others = _other_train_processes_with_run_id(run_id)
    if others:
        pids = [p[0] for p in others]
        print(f"WARNING: {len(others)} other process(es) already running train_experiment with run_id={run_id}:", file=sys.stderr)
        for pid, _ in others[:5]:
            print(f"  PID {pid}", file=sys.stderr)
        if len(others) > 5:
            print(f"  ... and {len(others) - 5} more", file=sys.stderr)
        print(f"To stop them all:  pkill -f 'run_id {run_id}'", file=sys.stderr)
        print("Continuing in 5s (Ctrl+C to abort)...", file=sys.stderr)
        import time
        time.sleep(5)

    output_dir.mkdir(parents=True, exist_ok=True)

    if args.ensemble:
        # Train 3-model ensemble (like baseline)
        print(f"Run: {run_id}  strategy={cfg['strategy']}  optimizer={cfg.get('optimizer')}  loss={cfg.get('loss')}")
        if cfg.get("patientwise_v3"):
            print("Training data: patient-wise v3 pool (train_binary_ensemble_patientwise.ipynb equivalent)")
        print(f"Training 3-model ensemble...")
        
        dropout_rates = [0.3, 0.1, 0.2]  # Same as baseline
        ensemble_weights = [0.30, 0.40, 0.30]
        base_seed = cfg["seed"]
        device = torch.device("mps" if torch.backends.mps.is_available() else "cuda" if torch.cuda.is_available() else "cpu")
        
        models_dir = output_dir / "models"
        models_dir.mkdir(parents=True, exist_ok=True)
        val_aucs = []
        
        for i in range(3):
            model_name = f"ensemble_{i+1}"
            print(f"\n  [{i+1}/3] {model_name}")
            
            # Create model-specific config with different dropout and seed
            model_cfg = cfg.copy()
            model_cfg["dropout_rate"] = dropout_rates[i]
            model_cfg["seed"] = base_seed + i
            
            # Train this model
            model_output_dir = output_dir / model_name
            model_output_dir.mkdir(parents=True, exist_ok=True)
            best_auc = run_training(model_cfg, model_output_dir)
            val_aucs.append(best_auc)
            
            # Move checkpoint to ensemble models dir
            src_ckpt = model_output_dir / "models" / "best.pth"
            dst_ckpt = models_dir / f"ensemble_model_{i+1}.pth"
            if src_ckpt.exists():
                import shutil
                shutil.move(str(src_ckpt), str(dst_ckpt))
                print(f"    Saved: {dst_ckpt}")
            
            # Export to ONNX if requested
            if args.export_onnx:
                onnx_dir = output_dir / "onnx"
                onnx_dir.mkdir(parents=True, exist_ok=True)
                onnx_path = onnx_dir / f"ensemble_model_{i+1}.onnx"
                
                # Load model for export
                model = ConservativeMobileNetV3(num_classes=2, dropout_rate=dropout_rates[i]).to(device)
                state = torch.load(dst_ckpt, map_location=device)
                model.load_state_dict(state)
                
                size_mb = export_to_onnx(model, onnx_path, device)
                print(f"    Exported: {onnx_path} ({size_mb:.2f} MB)")
        
        mean_auc = sum(val_aucs) / len(val_aucs)
        print(f"\n  Ensemble mean val AUC: {mean_auc:.4f}")
        print(f"  Individual AUCs: {', '.join(f'{a:.4f}' for a in val_aucs)}")
        
        # Save ensemble metadata
        ensemble_meta = {
            "run_id": run_id,
            "ensemble_weights": ensemble_weights,
            "dropout_rates": dropout_rates,
            "val_aucs": val_aucs,
            "mean_val_auc": mean_auc,
            "config": cfg
        }
        with open(output_dir / "ensemble_metadata.json", "w") as f:
            json.dump(ensemble_meta, f, indent=2)
        
        if args.export_onnx:
            print(f"\n✅ Ensemble ONNX models saved to: {output_dir / 'onnx'}")
            
            # Automatically evaluate on frozen test sets if requested
            if args.evaluate:
                print(f"\n📊 Evaluating ensemble on frozen test sets...")
                eval_output = output_dir / "frozen_eval.json"
                cmd = [
                    sys.executable,
                    str(NOTEBOOK_DIR / "evaluate_on_frozen_sets.py"),
                    "--model", str(output_dir / "onnx"),
                    "--model_type", "binary_onnx_ensemble",
                    "--output", str(eval_output),
                ]
                if not args.eval_no_skip_missing:
                    cmd.append("--skip-missing-images")
                try:
                    result = subprocess.run(cmd, check=True, capture_output=True, text=True)
                    print(result.stdout)
                    print(f"\n✅ Evaluation complete! Results saved to: {eval_output}")
                    
                    # Parse and display key metrics
                    if eval_output.exists():
                        with open(eval_output) as f:
                            eval_results = json.load(f)
                        if "TM" in eval_results:
                            tm = eval_results["TM"]
                            print(f"\n📈 Key Metrics (TM - Frozen Test Set):")
                            print(f"   TM AUC:     {tm.get('auroc', 0):.4f}")
                            print(f"   TM Accuracy: {tm.get('accuracy', 0)*100:.2f}%")
                            # JSON uses 'sens_at_90spec', not 'sensitivity_at_90_specificity'
                            sens_at_90spec = tm.get('sens_at_90spec', tm.get('sensitivity_at_90_specificity', 0))
                            print(f"   TM Sens@90Spec: {sens_at_90spec*100:.2f}%")
                            print(f"   Baseline TM AUC: 0.9291")
                            if tm.get('auroc', 0) > 0.9291:
                                print(f"   ✅ Improvement: +{tm.get('auroc', 0) - 0.9291:.4f}")
                            else:
                                print(f"   ⚠️  Below baseline: {tm.get('auroc', 0) - 0.9291:.4f}")
                except subprocess.CalledProcessError as e:
                    print(f"❌ Evaluation failed: {e}", file=sys.stderr)
                    print(f"   Error output: {e.stderr}", file=sys.stderr)
                except Exception as e:
                    print(f"❌ Evaluation error: {e}", file=sys.stderr)
            else:
                print(f"   Evaluate with: python evaluate_on_frozen_sets.py --model {output_dir / 'onnx'} --model_type binary_onnx_ensemble")
    else:
        # Single model training (backward compatible)
        print(f"Run: {run_id}  strategy={cfg['strategy']}  optimizer={cfg.get('optimizer')}  loss={cfg.get('loss')}")
        best_auc = run_training(cfg, output_dir)
        print(f"Best val AUC: {best_auc:.4f}")
        
        if args.export_onnx:
            onnx_dir = output_dir / "onnx"
            onnx_dir.mkdir(parents=True, exist_ok=True)
            onnx_path = onnx_dir / "model.onnx"
            
            # Load model for export
            device = torch.device("mps" if torch.backends.mps.is_available() else "cuda" if torch.cuda.is_available() else "cpu")
            ckpt_path = output_dir / "models" / "best.pth"
            if ckpt_path.exists():
                model = ConservativeMobileNetV3(num_classes=2, dropout_rate=cfg.get("dropout_rate", 0.2)).to(device)
                state = torch.load(ckpt_path, map_location=device)
                model.load_state_dict(state)
                size_mb = export_to_onnx(model, onnx_path, device)
                print(f"✅ ONNX model saved: {onnx_path} ({size_mb:.2f} MB)")


if __name__ == "__main__":
    main()
