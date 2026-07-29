import nbformat as nbf
from pathlib import Path
from textwrap import dedent


def md(text: str):
    return nbf.v4.new_markdown_cell(dedent(text).strip() + "\n")


def code(text: str):
    return nbf.v4.new_code_cell(dedent(text).strip() + "\n")


nb = nbf.v4.new_notebook()

nb.cells = [
    md(
        """
        # SSL Backbone Multitask Ensembles (Patient-Wise)

        This notebook trains **three full-finetune ensembles** using an SSL-pretrained MobileNetV3 backbone:

        1. **Binary ensemble** on merged patient-wise pool + TB + TC:
           - Sources: T5 (A), SMART-II (D), TB train/val (B), TC train/val (C)
        1. **5-class ensemble** on patient-wise **T5 only**:
           - Classes: `Benign, Healthy, OCA, OPMD, Unknown`
        1. **3-class ensemble** on patient-wise **T5 + SMART-II**:
           - Classes: `Healthy, Benign, OPMD_PLUS` where `OPMD_PLUS = OPMD ∪ OCA`

        All models are evaluated against **TM_v3** in binary view with:
        - AUROC
        - sensitivity at ~80% specificity
        - sensitivity at ~90% specificity
        """
    ),
    code(
        """
        import os
        import sys
        import json
        import random
        from copy import deepcopy
        from datetime import datetime
        from pathlib import Path
        from collections import Counter

        import numpy as np
        import pandas as pd
        from PIL import Image, ImageFile
        ImageFile.LOAD_TRUNCATED_IMAGES = True

        import torch
        import torch.nn as nn
        import torch.optim as optim
        from torch.utils.data import DataLoader, Dataset
        from torchvision import models, transforms

        from sklearn.model_selection import train_test_split
        from sklearn.utils.class_weight import compute_class_weight
        from sklearn.metrics import roc_auc_score, confusion_matrix, roc_curve

        try:
            import onnx
            HAS_ONNX = True
        except ImportError:
            HAS_ONNX = False

        NOTEBOOK_DIR = Path(".").resolve()
        FROZEN_DIR = NOTEBOOK_DIR / "frozen_test_sets"
        sys.path.insert(0, str(NOTEBOOK_DIR))

        from frozen_test_sets import (
            load_frozen_sets_v3,
            get_all_train_val_for_training_v3,
            get_tm_paths_labels_and_sources_v3,
            DEFAULT_DATA_DIR_5CLASS_PATIENTWISE,
            DEFAULT_DATA_DIR_SMART_PATIENTWISE,
        )
        """
    ),
    code(
        """
        def find_latest_ssl_backbone():
            root = NOTEBOOK_DIR / "results" / "ssl_caries_tmv3"
            if not root.exists():
                return None
            ckpts = sorted(root.glob("*/models/ssl_backbone_state_dict.pth"), key=lambda p: p.stat().st_mtime)
            return str(ckpts[-1]) if ckpts else None

        CONFIG = {
            "seed": 42,
            "paths": {
                "frozen_dir": str(FROZEN_DIR),
                "data_dir_5class_patientwise": DEFAULT_DATA_DIR_5CLASS_PATIENTWISE,
                "data_dir_smart_patientwise": DEFAULT_DATA_DIR_SMART_PATIENTWISE,
                "ssl_backbone_ckpt": find_latest_ssl_backbone(),  # set explicit path if needed
            },
            "image_size": 224,
            "batch_size": 32,
            "epochs": 40,
            "patience": 10,
            "num_workers": 0,
            "val_split_binary": 0.15,
            "lr": 1e-4,
            "weight_decay": 1e-4,
            "dropout_rates": [0.3, 0.1, 0.2],
            "ensemble_weights": [0.30, 0.40, 0.30],
            "eval_threshold": 0.5,
            "export_onnx": True,
        }

        if not CONFIG["paths"]["ssl_backbone_ckpt"] or not Path(CONFIG["paths"]["ssl_backbone_ckpt"]).exists():
            raise FileNotFoundError(
                "SSL backbone checkpoint not found. Set CONFIG['paths']['ssl_backbone_ckpt'] explicitly."
            )

        run_name = os.environ.get("EXPERIMENT_NAME") or f"ssl_multitask_ensembles_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        OUTPUT_DIR = NOTEBOOK_DIR / "results" / "ssl_multitask_ensembles" / run_name
        (OUTPUT_DIR / "models").mkdir(parents=True, exist_ok=True)
        (OUTPUT_DIR / "onnx").mkdir(parents=True, exist_ok=True)

        with open(OUTPUT_DIR / "config.json", "w") as f:
            json.dump(CONFIG, f, indent=2, default=str)

        print(f"Run: {run_name}")
        print(f"Output: {OUTPUT_DIR}")
        print(f"SSL ckpt: {CONFIG['paths']['ssl_backbone_ckpt']}")
        """
    ),
    code(
        """
        def seed_everything(seed: int):
            random.seed(seed)
            np.random.seed(seed)
            torch.manual_seed(seed)
            if torch.cuda.is_available():
                torch.cuda.manual_seed_all(seed)

        seed_everything(CONFIG["seed"])

        if torch.backends.mps.is_available():
            device = torch.device("mps")
        elif torch.cuda.is_available():
            device = torch.device("cuda")
        else:
            device = torch.device("cpu")
        print(f"Using device: {device}")
        """
    ),
    code(
        """
        IMAGENET_MEAN = [0.485, 0.456, 0.406]
        IMAGENET_STD = [0.229, 0.224, 0.225]

        train_tf = transforms.Compose([
            transforms.Resize((CONFIG["image_size"], CONFIG["image_size"])),
            transforms.RandomHorizontalFlip(),
            transforms.RandomRotation(10),
            transforms.ColorJitter(brightness=0.15, contrast=0.15),
            transforms.ToTensor(),
            transforms.Normalize(IMAGENET_MEAN, IMAGENET_STD),
        ])

        val_tf = transforms.Compose([
            transforms.Resize((CONFIG["image_size"], CONFIG["image_size"])),
            transforms.ToTensor(),
            transforms.Normalize(IMAGENET_MEAN, IMAGENET_STD),
        ])

        def load_image_rgb(path: str):
            with Image.open(path) as img:
                if img.mode == "P" and "transparency" in img.info:
                    img = img.convert("RGBA")
                return img.convert("RGB")

        class ClassificationDataset(Dataset):
            def __init__(self, paths, labels, transform):
                self.paths = paths
                self.labels = labels
                self.transform = transform

            def __len__(self):
                return len(self.paths)

            def __getitem__(self, idx):
                img = load_image_rgb(self.paths[idx])
                x = self.transform(img)
                y = int(self.labels[idx])
                return x, y
        """
    ),
    code(
        """
        def make_backbone_imagenet():
            try:
                m = models.mobilenet_v3_large(weights=models.MobileNet_V3_Large_Weights.IMAGENET1K_V2)
            except AttributeError:
                m = models.mobilenet_v3_large(pretrained=True)
            return m

        class ConservativeMobileNetV3(nn.Module):
            def __init__(self, num_classes, dropout_rate=0.2):
                super().__init__()
                self.backbone = make_backbone_imagenet()
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
                return self.classifier(x)

        def build_ensemble(num_classes):
            return [
                ConservativeMobileNetV3(num_classes=num_classes, dropout_rate=CONFIG["dropout_rates"][0]).to(device),
                ConservativeMobileNetV3(num_classes=num_classes, dropout_rate=CONFIG["dropout_rates"][1]).to(device),
                ConservativeMobileNetV3(num_classes=num_classes, dropout_rate=CONFIG["dropout_rates"][2]).to(device),
            ]

        ssl_backbone_state = torch.load(CONFIG["paths"]["ssl_backbone_ckpt"], map_location="cpu")
        """
    ),
    code(
        """
        def infer_probs_binary(model, loader):
            model.eval()
            yt, yp = [], []
            with torch.no_grad():
                for x, y in loader:
                    x = x.to(device)
                    logits = model(x)
                    p = torch.softmax(logits, dim=1)[:, 1].cpu().numpy()
                    yt.extend(y.numpy().tolist())
                    yp.extend(p.tolist())
            return np.array(yt), np.array(yp)

        def infer_probs_multiclass(model, loader):
            model.eval()
            yt, yp = [], []
            with torch.no_grad():
                for x, y in loader:
                    x = x.to(device)
                    logits = model(x)
                    p = torch.softmax(logits, dim=1).cpu().numpy()
                    yt.extend(y.numpy().tolist())
                    yp.append(p)
            return np.array(yt), np.concatenate(yp, axis=0)

        def calc_binary_metrics(y_true, y_prob, threshold=0.5):
            y_pred = (y_prob >= threshold).astype(int)
            tn, fp, fn, tp = confusion_matrix(y_true, y_pred, labels=[0, 1]).ravel()
            auc = roc_auc_score(y_true, y_prob) if len(np.unique(y_true)) > 1 else float("nan")
            return {
                "auc": float(auc),
                "accuracy": float((tp + tn) / max(len(y_true), 1)),
                "sensitivity": float(tp / max(tp + fn, 1)),
                "specificity": float(tn / max(tn + fp, 1)),
                "tp": int(tp), "tn": int(tn), "fp": int(fp), "fn": int(fn),
            }

        def sensitivity_at_target_specificity(y_true, y_prob, target_specificity):
            if len(np.unique(y_true)) < 2:
                return {
                    "target_specificity": float(target_specificity),
                    "achieved_specificity": float("nan"),
                    "sensitivity": float("nan"),
                    "threshold": float("nan"),
                }
            fpr, tpr, thresholds = roc_curve(y_true, y_prob)
            specificity = 1.0 - fpr
            valid = np.where(specificity >= target_specificity)[0]
            if len(valid) > 0:
                idx = valid[np.argmax(tpr[valid])]
            else:
                idx = int(np.argmin(np.abs(specificity - target_specificity)))
            return {
                "target_specificity": float(target_specificity),
                "achieved_specificity": float(specificity[idx]),
                "sensitivity": float(tpr[idx]),
                "threshold": float(thresholds[idx]),
            }

        def train_one_model(model, train_loader, val_loader, class_weights=None):
            model.backbone.features.load_state_dict(ssl_backbone_state, strict=True)
            for p in model.parameters():
                p.requires_grad = True

            criterion = nn.CrossEntropyLoss(
                weight=class_weights.to(device) if class_weights is not None else None
            )
            optimizer = optim.AdamW(
                model.parameters(), lr=CONFIG["lr"], weight_decay=CONFIG["weight_decay"]
            )

            best_auc = -1.0
            best_state = None
            bad = 0
            hist = []

            for epoch in range(1, CONFIG["epochs"] + 1):
                model.train()
                loss_sum = 0.0
                n = 0
                for x, y in train_loader:
                    x = x.to(device)
                    y = y.to(device)
                    logits = model(x)
                    loss = criterion(logits, y)
                    optimizer.zero_grad()
                    loss.backward()
                    optimizer.step()
                    bs = x.size(0)
                    loss_sum += float(loss.item()) * bs
                    n += bs

                # Validation AUC in binary view when num_classes>2
                if model.classifier[-1].out_features == 2:
                    yv, pv = infer_probs_binary(model, val_loader)
                elif model.classifier[-1].out_features == 5:
                    yv, p5 = infer_probs_multiclass(model, val_loader)
                    pv = p5[:, 2] + p5[:, 3]  # OCA + OPMD
                    yv = np.array([1 if yi in (2, 3) else 0 for yi in yv], dtype=int)
                else:
                    yv, p3 = infer_probs_multiclass(model, val_loader)
                    pv = p3[:, 2]  # OPMD_PLUS
                    yv = np.array([1 if yi == 2 else 0 for yi in yv], dtype=int)

                m = calc_binary_metrics(yv, pv, threshold=CONFIG["eval_threshold"])
                row = {"epoch": epoch, "train_loss": loss_sum / max(n, 1), "val_auc_binary_view": m["auc"]}
                hist.append(row)
                print(f"  Epoch {epoch:02d}: loss={row['train_loss']:.4f} val_auc_bin={m['auc']:.4f}")

                if m["auc"] > best_auc:
                    best_auc = m["auc"]
                    best_state = deepcopy(model.state_dict())
                    bad = 0
                else:
                    bad += 1
                    if bad >= CONFIG["patience"]:
                        print(f"  Early stop at epoch {epoch}")
                        break

            model.load_state_dict(best_state)
            return model, hist, float(best_auc)

        def train_ensemble(task_name, num_classes, train_paths, train_labels, val_paths, val_labels, class_weights=None):
            print(f"\\n=== Training {task_name} ensemble ({num_classes} classes) ===")
            train_ds = ClassificationDataset(train_paths, train_labels, train_tf)
            val_ds = ClassificationDataset(val_paths, val_labels, val_tf)
            train_loader = DataLoader(train_ds, batch_size=CONFIG["batch_size"], shuffle=True, num_workers=CONFIG["num_workers"])
            val_loader = DataLoader(val_ds, batch_size=CONFIG["batch_size"], shuffle=False, num_workers=CONFIG["num_workers"])

            ensemble = build_ensemble(num_classes=num_classes)
            task_hist = []
            for i, model in enumerate(ensemble, start=1):
                print(f"Model {i}/3")
                m, hist, best_auc = train_one_model(model, train_loader, val_loader, class_weights=class_weights)
                ensemble[i - 1] = m
                task_hist.append({"model_idx": i, "best_val_auc_binary_view": best_auc, "history": hist})
            return ensemble, task_hist
        """
    ),
    md("## Build Datasets (Patient-Wise Rules Applied)"),
    code(
        """
        frozen_dir = Path(CONFIG["paths"]["frozen_dir"])
        T5, T_SMART, TB, TC, TM, meta = load_frozen_sets_v3(frozen_dir)
        tm_paths, tm_labels, tm_sources = get_tm_paths_labels_and_sources_v3(frozen_dir)
        print(f"TM_v3 size: {len(tm_paths)}")

        # Binary: A+B+C+D merged train/val pool (patient-wise where applicable)
        bin_all_paths, bin_all_labels, bin_all_sources = get_all_train_val_for_training_v3(
            out_dir=frozen_dir,
            data_dir_5class=os.path.expanduser(CONFIG["paths"]["data_dir_5class_patientwise"]),
            data_dir_smart=os.path.expanduser(CONFIG["paths"]["data_dir_smart_patientwise"]),
        )
        bin_train_paths, bin_val_paths, bin_train_labels, bin_val_labels = train_test_split(
            bin_all_paths,
            bin_all_labels,
            test_size=CONFIG["val_split_binary"],
            random_state=CONFIG["seed"],
            stratify=bin_all_labels,
        )
        print(f"Binary train/val: {len(bin_train_paths)} / {len(bin_val_paths)}")

        # 5-class: T5 patient-wise only (train/val folders)
        t5_root = Path(os.path.expanduser(CONFIG["paths"]["data_dir_5class_patientwise"]))
        cls5 = ["Benign", "Healthy", "OCA", "OPMD", "Unknown"]
        map5 = {c: i for i, c in enumerate(cls5)}
        c5_train_paths, c5_train_labels, c5_val_paths, c5_val_labels = [], [], [], []
        for split, out_p, out_y in [("train", c5_train_paths, c5_train_labels), ("val", c5_val_paths, c5_val_labels)]:
            for c in cls5:
                d = t5_root / split / c
                if d.exists():
                    imgs = list(d.glob("*.jpg")) + list(d.glob("*.jpeg")) + list(d.glob("*.png")) + list(d.glob("*.JPG"))
                    out_p.extend([str(x) for x in imgs])
                    out_y.extend([map5[c]] * len(imgs))
        print(f"5-class (T5 only) train/val: {len(c5_train_paths)} / {len(c5_val_paths)}")

        # 3-class: T5 + SMART patient-wise
        # Labels: Healthy=0, Benign=1, OPMD_PLUS=2 (OPMD or OCA)
        map3 = {"Healthy": 0, "Benign": 1, "OPMD": 2, "OCA": 2}
        smart_root = Path(os.path.expanduser(CONFIG["paths"]["data_dir_smart_patientwise"]))
        c3_train_paths, c3_train_labels, c3_val_paths, c3_val_labels = [], [], [], []

        def add_split_3class(base_dir, split, classes):
            out_p = c3_train_paths if split == "train" else c3_val_paths
            out_y = c3_train_labels if split == "train" else c3_val_labels
            for c in classes:
                d = base_dir / split / c
                if not d.exists():
                    continue
                imgs = list(d.glob("*.jpg")) + list(d.glob("*.jpeg")) + list(d.glob("*.png")) + list(d.glob("*.JPG"))
                out_p.extend([str(x) for x in imgs])
                out_y.extend([map3[c]] * len(imgs))

        add_split_3class(t5_root, "train", ["Healthy", "Benign", "OPMD", "OCA"])
        add_split_3class(t5_root, "val", ["Healthy", "Benign", "OPMD", "OCA"])
        add_split_3class(smart_root, "train", ["Healthy", "Benign", "OPMD"])
        add_split_3class(smart_root, "val", ["Healthy", "Benign", "OPMD"])
        print(f"3-class (T5+SMART) train/val: {len(c3_train_paths)} / {len(c3_val_paths)}")
        """
    ),
    code(
        """
        def make_class_weights(labels, num_classes):
            classes = np.arange(num_classes)
            w = compute_class_weight(class_weight="balanced", classes=classes, y=np.array(labels))
            return torch.tensor(w, dtype=torch.float32)

        w_bin = make_class_weights(bin_train_labels, 2)
        w_5 = make_class_weights(c5_train_labels, 5)
        w_3 = make_class_weights(c3_train_labels, 3)

        print("Class distributions:")
        print("  Binary train:", Counter(bin_train_labels))
        print("  5-class train:", Counter(c5_train_labels))
        print("  3-class train:", Counter(c3_train_labels))
        """
    ),
    md("## Train Ensembles"),
    code(
        """
        binary_ensemble, binary_hist = train_ensemble(
            task_name="binary_ssl_fullft",
            num_classes=2,
            train_paths=bin_train_paths,
            train_labels=bin_train_labels,
            val_paths=bin_val_paths,
            val_labels=bin_val_labels,
            class_weights=w_bin,
        )

        class5_ensemble, class5_hist = train_ensemble(
            task_name="class5_ssl_fullft",
            num_classes=5,
            train_paths=c5_train_paths,
            train_labels=c5_train_labels,
            val_paths=c5_val_paths,
            val_labels=c5_val_labels,
            class_weights=w_5,
        )

        class3_ensemble, class3_hist = train_ensemble(
            task_name="class3_ssl_fullft",
            num_classes=3,
            train_paths=c3_train_paths,
            train_labels=c3_train_labels,
            val_paths=c3_val_paths,
            val_labels=c3_val_labels,
            class_weights=w_3,
        )

        train_summary = {
            "binary": binary_hist,
            "class5": class5_hist,
            "class3": class3_hist,
        }
        with open(OUTPUT_DIR / "training_history.json", "w") as f:
            json.dump(train_summary, f, indent=2)
        """
    ),
    md("## Evaluate All Ensembles On TM_v3 (Binary View)"),
    code(
        """
        tm_ds = ClassificationDataset(tm_paths, tm_labels, val_tf)
        tm_loader = DataLoader(tm_ds, batch_size=CONFIG["batch_size"], shuffle=False, num_workers=CONFIG["num_workers"])

        def ensemble_probs_binary(task_name, ensemble, loader):
            weights = np.array(CONFIG["ensemble_weights"], dtype=np.float32)
            weights = weights / weights.sum()
            probs = []
            y_true = np.array(loader.dataset.labels, dtype=int)
            for i, m in enumerate(ensemble):
                if task_name == "binary":
                    _, p = infer_probs_binary(m, loader)
                elif task_name == "class5":
                    _, p5 = infer_probs_multiclass(m, loader)
                    p = p5[:, 2] + p5[:, 3]
                elif task_name == "class3":
                    _, p3 = infer_probs_multiclass(m, loader)
                    p = p3[:, 2]
                else:
                    raise ValueError(task_name)
                probs.append(p * weights[i])
            return y_true, np.sum(np.stack(probs, axis=0), axis=0)

        results = {}
        for name, ens in [("binary", binary_ensemble), ("class5", class5_ensemble), ("class3", class3_ensemble)]:
            y_true, y_prob = ensemble_probs_binary(name, ens, tm_loader)
            overall = calc_binary_metrics(y_true, y_prob, threshold=CONFIG["eval_threshold"])
            s80 = sensitivity_at_target_specificity(y_true, y_prob, 0.80)
            s90 = sensitivity_at_target_specificity(y_true, y_prob, 0.90)

            src_rows = []
            src_arr = np.array(tm_sources)
            for src in sorted(set(tm_sources)):
                m = src_arr == src
                src_m = calc_binary_metrics(y_true[m], y_prob[m], threshold=CONFIG["eval_threshold"])
                src_m["source"] = src
                src_m["n"] = int(m.sum())
                src_rows.append(src_m)

            results[name] = {
                "overall": overall,
                "sensitivity_at_specificity_80": s80,
                "sensitivity_at_specificity_90": s90,
                "per_source": src_rows,
            }

            print(f"\\n{name} TM_v3 overall: {overall}")
            print(f"{name} sensitivity@~80% spec: {s80}")
            print(f"{name} sensitivity@~90% spec: {s90}")
            display(pd.DataFrame(src_rows).sort_values("source"))

        summary = []
        for k, v in results.items():
            summary.append({
                "ensemble": k,
                "auc": v["overall"]["auc"],
                "acc@0.5": v["overall"]["accuracy"],
                "sens@0.5": v["overall"]["sensitivity"],
                "spec@0.5": v["overall"]["specificity"],
                "sens@spec80": v["sensitivity_at_specificity_80"]["sensitivity"],
                "spec@spec80": v["sensitivity_at_specificity_80"]["achieved_specificity"],
                "thr@spec80": v["sensitivity_at_specificity_80"]["threshold"],
                "sens@spec90": v["sensitivity_at_specificity_90"]["sensitivity"],
                "spec@spec90": v["sensitivity_at_specificity_90"]["achieved_specificity"],
                "thr@spec90": v["sensitivity_at_specificity_90"]["threshold"],
            })
        summary_df = pd.DataFrame(summary).sort_values("sens@spec80", ascending=False)
        print("\\nTM_v3 summary (ranked by sensitivity@80% spec):")
        display(summary_df)

        with open(OUTPUT_DIR / "evaluation_tm_v3_all_ensembles.json", "w") as f:
            json.dump(results, f, indent=2)
        summary_df.to_csv(OUTPUT_DIR / "evaluation_tm_v3_summary.csv", index=False)
        """
    ),
    md("## Save Checkpoints + Export ONNX"),
    code(
        """
        def save_ensemble(ensemble, prefix):
            model_dir = OUTPUT_DIR / "models" / prefix
            model_dir.mkdir(parents=True, exist_ok=True)
            for i, m in enumerate(ensemble, start=1):
                p = model_dir / f"{prefix}_model_{i}.pth"
                torch.save(m.state_dict(), p)
                print("Saved", p)

        save_ensemble(binary_ensemble, "binary_ssl_fullft")
        save_ensemble(class5_ensemble, "class5_ssl_fullft")
        save_ensemble(class3_ensemble, "class3_ssl_fullft")

        def export_onnx_model(model, out_path):
            dummy = torch.randn(1, 3, CONFIG["image_size"], CONFIG["image_size"]).to(device)
            model.eval()
            torch.onnx.export(
                model,
                dummy,
                str(out_path),
                export_params=True,
                opset_version=17,
                do_constant_folding=True,
                input_names=["input"],
                output_names=["output"],
                dynamic_axes={"input": {0: "batch_size"}, "output": {0: "batch_size"}},
            )
            print("Exported", out_path)

        if CONFIG["export_onnx"]:
            if not HAS_ONNX:
                print("ONNX package not installed; skipping export.")
            else:
                onnx_dir = OUTPUT_DIR / "onnx"
                onnx_dir.mkdir(parents=True, exist_ok=True)
                for i, m in enumerate(binary_ensemble, start=1):
                    export_onnx_model(m, onnx_dir / f"binary_ssl_fullft_model_{i}.onnx")
                for i, m in enumerate(class5_ensemble, start=1):
                    export_onnx_model(m, onnx_dir / f"class5_ssl_fullft_model_{i}.onnx")
                for i, m in enumerate(class3_ensemble, start=1):
                    export_onnx_model(m, onnx_dir / f"class3_ssl_fullft_model_{i}.onnx")
        """
    ),
]

nb.metadata = {
    "kernelspec": {"display_name": "Python 3", "language": "python", "name": "python3"},
    "language_info": {"name": "python", "version": "3.11"},
}

out_path = Path(__file__).resolve().parent / "ssl_multitask_ensembles_patientwise.ipynb"
with open(out_path, "w", encoding="utf-8") as f:
    nbf.write(nb, f)

print(f"Notebook written to: {out_path}")
