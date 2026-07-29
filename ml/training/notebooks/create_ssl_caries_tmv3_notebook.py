import nbformat as nbf
from textwrap import dedent
from pathlib import Path


def md(text: str):
    return nbf.v4.new_markdown_cell(dedent(text).strip() + "\n")


def code(text: str):
    return nbf.v4.new_code_cell(dedent(text).strip() + "\n")


nb = nbf.v4.new_notebook()

nb.cells = [
    md(
        """
        # SSL Pretraining on Caries + TM_V3 (ImageNet -> SSL -> TM_V3)

        This notebook implements **Option 3**:
        1. Start from **ImageNet MobileNetV3-Large** weights.
        1. Run **self-supervised pretraining** on **unlabeled** mixed pool:
           - dental caries images (`oral-dental-caries-dataset/Images`)
           - TM_V3 training pool images (labels ignored during SSL)
        1. Fine-tune supervised on TM_V3 training data.

        Output structure:
        - `results/ssl_caries_tmv3/<run_name>/models/ssl_backbone_state_dict.pth`
        - `results/ssl_caries_tmv3/<run_name>/models/<strategy>/best_supervised_model.pth`
        - JSON logs for SSL + supervised history and evaluation.
        """
    ),
    md(
        """
        ## Questions To Confirm Before Long Training

        This notebook is runnable with defaults, but please confirm these assumptions:
        1. **Task mode**: downstream training is binary (`0=non-cancer`, `1=cancer`) using TM_V3 manifests.
        1. **No frozen-test leakage in SSL**: by default, SSL uses TM_V3 train/val pool only (not TM_V3 frozen test images).
        1. **Data source scope**: TM_V3 train pool includes A/B/C/D sources via `get_all_train_val_for_training_v3`.

        You can change any of these in the `CONFIG` cell before launching long runs.
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

        import numpy as np
        import pandas as pd
        from PIL import Image, ImageFile
        ImageFile.LOAD_TRUNCATED_IMAGES = True

        import torch
        import torch.nn as nn
        import torch.nn.functional as F
        import torch.optim as optim
        from torch.utils.data import Dataset, DataLoader
        from torchvision import models, transforms

        from sklearn.model_selection import train_test_split
        from sklearn.metrics import roc_auc_score, confusion_matrix, roc_curve

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
        CONFIG = {
            "seed": 42,
            "paths": {
                "caries_images_dir": "~/dev/oral-images-dataset/oral-dental-caries-dataset/Images",
                "data_dir_5class_patientwise": DEFAULT_DATA_DIR_5CLASS_PATIENTWISE,
                "data_dir_smart_patientwise": DEFAULT_DATA_DIR_SMART_PATIENTWISE,
                "frozen_dir": str(FROZEN_DIR),
            },
            "image_size": 224,
            "num_workers": 0,
            "ssl": {
                "enabled": True,
                "epochs": 20,
                "batch_size": 64,
                "lr": 3e-4,
                "weight_decay": 1e-4,
                "temperature": 0.2,
                "include_frozen_tm_v3_unlabeled": False,  # keep False to avoid leakage
                "max_samples_debug": None,  # set int for smoke run, e.g. 2000
            },
            "finetune": {
                "strategy_runs": ["progressive_K5", "full_finetune"],  # add "progressive_K6" if needed
                "epochs": 40,
                "warmup_epochs": 5,
                "batch_size": 32,
                "lr_head": 1e-3,
                "lr_backbone": 1e-4,
                "weight_decay": 1e-4,
                "dropout_rate": 0.2,
                "val_split": 0.15,
                "patience": 10,
            },
            "eval": {
                "threshold": 0.5
            }
        }

        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        RUN_NAME = os.environ.get("EXPERIMENT_NAME", f"ssl_caries_tmv3_{timestamp}")
        OUTPUT_DIR = NOTEBOOK_DIR / "results" / "ssl_caries_tmv3" / RUN_NAME
        (OUTPUT_DIR / "models").mkdir(parents=True, exist_ok=True)

        with open(OUTPUT_DIR / "config.json", "w") as f:
            json.dump(CONFIG, f, indent=2)

        print(f"Run name: {RUN_NAME}")
        print(f"Output dir: {OUTPUT_DIR}")
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
    md("## Section A: Load Dental Caries Dataset (Unlabeled SSL Source)"),
    code(
        """
        IMG_EXTS = (".jpg", ".jpeg", ".png", ".JPG", ".JPEG", ".PNG")

        def collect_images_recursive(root: Path):
            paths = []
            if not root.exists():
                return paths
            for ext in IMG_EXTS:
                paths.extend(root.rglob(f"*{ext}"))
            return sorted(str(p) for p in paths)

        caries_images_dir = Path(os.path.expanduser(CONFIG["paths"]["caries_images_dir"]))
        caries_paths = collect_images_recursive(caries_images_dir)

        print(f"Caries images dir: {caries_images_dir}")
        print(f"Caries image count: {len(caries_paths):,}")
        if len(caries_paths) == 0:
            raise FileNotFoundError(
                f"No images found under {caries_images_dir}. Update CONFIG['paths']['caries_images_dir']."
            )
        """
    ),
    md("## Section B: Load TM_V3 Data (Unlabeled For SSL + Labeled For Fine-Tune)"),
    code(
        """
        frozen_dir = Path(CONFIG["paths"]["frozen_dir"])
        tm_v3_manifest = frozen_dir / "TM_v3.json"
        if not tm_v3_manifest.exists():
            raise FileNotFoundError(
                f"Missing {tm_v3_manifest}. Run from notebooks dir: python frozen_test_sets.py --v3"
            )

        T5, TSMART, TB, TC, TM, meta = load_frozen_sets_v3(frozen_dir)
        print("Frozen-set summary:")
        print(f"  T5_v3:   {len(T5):,}")
        print(f"  TSMART:  {len(TSMART):,}")
        print(f"  TB:      {len(TB):,}")
        print(f"  TC:      {len(TC):,}")
        print(f"  TM_v3:   {len(TM):,}")

        tm_trainval_paths, tm_trainval_labels, tm_trainval_sources = get_all_train_val_for_training_v3(
            out_dir=frozen_dir,
            data_dir_5class=os.path.expanduser(CONFIG["paths"]["data_dir_5class_patientwise"]),
            data_dir_smart=os.path.expanduser(CONFIG["paths"]["data_dir_smart_patientwise"]),
        )
        print(f"TM_v3 train/val pool (labeled): {len(tm_trainval_paths):,}")
        print(f"  positives: {sum(tm_trainval_labels):,}")
        print(f"  negatives: {len(tm_trainval_labels) - sum(tm_trainval_labels):,}")
        """
    ),
    code(
        """
        ssl_unlabeled_paths = sorted(set(caries_paths + tm_trainval_paths))

        if CONFIG["ssl"]["include_frozen_tm_v3_unlabeled"]:
            tm_eval_paths, _, _ = get_tm_paths_labels_and_sources_v3(frozen_dir)
            ssl_unlabeled_paths = sorted(set(ssl_unlabeled_paths + tm_eval_paths))

        if CONFIG["ssl"]["max_samples_debug"]:
            ssl_unlabeled_paths = ssl_unlabeled_paths[: int(CONFIG["ssl"]["max_samples_debug"])]

        print(f"Combined SSL unlabeled pool: {len(ssl_unlabeled_paths):,}")
        """
    ),
    md("## Build Data Splits For Supervised TM_V3 Fine-Tuning"),
    code(
        """
        sup_train_paths, sup_val_paths, sup_train_labels, sup_val_labels = train_test_split(
            tm_trainval_paths,
            tm_trainval_labels,
            test_size=CONFIG["finetune"]["val_split"],
            random_state=CONFIG["seed"],
            stratify=tm_trainval_labels,
        )
        print(f"Supervised train size: {len(sup_train_paths):,}")
        print(f"Supervised val size:   {len(sup_val_paths):,}")
        """
    ),
    md("## Transforms And Datasets"),
    code(
        """
        IMAGENET_MEAN = [0.485, 0.456, 0.406]
        IMAGENET_STD = [0.229, 0.224, 0.225]

        ssl_view_transform = transforms.Compose([
            transforms.RandomResizedCrop(CONFIG["image_size"], scale=(0.5, 1.0)),
            transforms.RandomHorizontalFlip(),
            transforms.RandomVerticalFlip(p=0.2),
            transforms.ColorJitter(brightness=0.3, contrast=0.3, saturation=0.2, hue=0.05),
            transforms.RandomGrayscale(p=0.1),
            transforms.GaussianBlur(kernel_size=9, sigma=(0.1, 2.0)),
            transforms.ToTensor(),
            transforms.Normalize(IMAGENET_MEAN, IMAGENET_STD),
        ])

        supervised_train_transform = transforms.Compose([
            transforms.Resize((CONFIG["image_size"], CONFIG["image_size"])),
            transforms.RandomHorizontalFlip(),
            transforms.RandomRotation(10),
            transforms.ColorJitter(brightness=0.15, contrast=0.15),
            transforms.ToTensor(),
            transforms.Normalize(IMAGENET_MEAN, IMAGENET_STD),
        ])

        supervised_val_transform = transforms.Compose([
            transforms.Resize((CONFIG["image_size"], CONFIG["image_size"])),
            transforms.ToTensor(),
            transforms.Normalize(IMAGENET_MEAN, IMAGENET_STD),
        ])

        def load_image_rgb(path: str):
            # Some PNG palette images store transparency as bytes; convert to RGBA first.
            with Image.open(path) as img:
                if img.mode == "P" and "transparency" in img.info:
                    img = img.convert("RGBA")
                return img.convert("RGB")

        class TwoCropsTransform:
            def __init__(self, base_transform):
                self.base_transform = base_transform

            def __call__(self, img):
                return self.base_transform(img), self.base_transform(img)

        class SSLImageDataset(Dataset):
            def __init__(self, paths, transform):
                self.paths = paths
                self.transform = transform

            def __len__(self):
                return len(self.paths)

            def __getitem__(self, idx):
                img = load_image_rgb(self.paths[idx])
                v1, v2 = self.transform(img)
                return v1, v2

        class BinaryImageDataset(Dataset):
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

        ssl_dataset = SSLImageDataset(ssl_unlabeled_paths, transform=TwoCropsTransform(ssl_view_transform))
        ssl_loader = DataLoader(
            ssl_dataset,
            batch_size=CONFIG["ssl"]["batch_size"],
            shuffle=True,
            num_workers=CONFIG["num_workers"],
            drop_last=True,
        )

        sup_train_ds = BinaryImageDataset(sup_train_paths, sup_train_labels, supervised_train_transform)
        sup_val_ds = BinaryImageDataset(sup_val_paths, sup_val_labels, supervised_val_transform)

        sup_train_loader = DataLoader(
            sup_train_ds,
            batch_size=CONFIG["finetune"]["batch_size"],
            shuffle=True,
            num_workers=CONFIG["num_workers"],
        )
        sup_val_loader = DataLoader(
            sup_val_ds,
            batch_size=CONFIG["finetune"]["batch_size"],
            shuffle=False,
            num_workers=CONFIG["num_workers"],
        )

        print(f"SSL loader steps/epoch: {len(ssl_loader)}")
        print(f"Supervised train steps/epoch: {len(sup_train_loader)}")
        print(f"Supervised val steps/epoch: {len(sup_val_loader)}")
        """
    ),
    md("## Models: SimSiam SSL Encoder + Binary Downstream Classifier"),
    code(
        """
        def make_mobilenet_backbone():
            try:
                base = models.mobilenet_v3_large(
                    weights=models.MobileNet_V3_Large_Weights.IMAGENET1K_V2
                )
            except AttributeError:
                base = models.mobilenet_v3_large(pretrained=True)
            return base

        class SimSiamMobileNet(nn.Module):
            def __init__(self, proj_dim=2048, pred_dim=512):
                super().__init__()
                base = make_mobilenet_backbone()
                self.encoder = base.features
                self.pool = nn.AdaptiveAvgPool2d((1, 1))
                self.projector = nn.Sequential(
                    nn.Linear(960, 2048),
                    nn.BatchNorm1d(2048),
                    nn.ReLU(inplace=True),
                    nn.Linear(2048, 2048),
                    nn.BatchNorm1d(2048),
                    nn.ReLU(inplace=True),
                    nn.Linear(2048, proj_dim),
                    nn.BatchNorm1d(proj_dim, affine=False),
                )
                self.predictor = nn.Sequential(
                    nn.Linear(proj_dim, pred_dim),
                    nn.BatchNorm1d(pred_dim),
                    nn.ReLU(inplace=True),
                    nn.Linear(pred_dim, proj_dim),
                )

            def forward_backbone(self, x):
                x = self.encoder(x)
                x = self.pool(x).flatten(1)
                return x

            def forward(self, x1, x2):
                f1 = self.forward_backbone(x1)
                f2 = self.forward_backbone(x2)
                z1 = self.projector(f1)
                z2 = self.projector(f2)
                p1 = self.predictor(z1)
                p2 = self.predictor(z2)
                return p1, p2, z1.detach(), z2.detach()

        def negative_cosine_similarity(p, z):
            p = F.normalize(p, dim=1)
            z = F.normalize(z, dim=1)
            return -(p * z).sum(dim=1).mean()

        class ConservativeMobileNetV3(nn.Module):
            def __init__(self, num_classes=2, dropout_rate=0.2):
                super().__init__()
                self.backbone = make_mobilenet_backbone()
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
        """
    ),
    md("## Train SSL Stage (ImageNet -> SSL on caries + TM_V3 unlabeled)"),
    code(
        """
        ssl_history = []
        ssl_backbone_ckpt = OUTPUT_DIR / "models" / "ssl_backbone_state_dict.pth"

        if CONFIG["ssl"]["enabled"]:
            ssl_model = SimSiamMobileNet().to(device)
            ssl_optimizer = optim.AdamW(
                ssl_model.parameters(),
                lr=CONFIG["ssl"]["lr"],
                weight_decay=CONFIG["ssl"]["weight_decay"],
            )

            best_ssl_loss = float("inf")
            best_backbone_state = None

            for epoch in range(1, CONFIG["ssl"]["epochs"] + 1):
                ssl_model.train()
                running_loss = 0.0

                for x1, x2 in ssl_loader:
                    x1 = x1.to(device, non_blocking=True)
                    x2 = x2.to(device, non_blocking=True)

                    p1, p2, z1, z2 = ssl_model(x1, x2)
                    loss = 0.5 * (negative_cosine_similarity(p1, z2) + negative_cosine_similarity(p2, z1))

                    ssl_optimizer.zero_grad()
                    loss.backward()
                    ssl_optimizer.step()

                    running_loss += float(loss.item()) * x1.size(0)

                epoch_loss = running_loss / max(len(ssl_dataset), 1)
                ssl_history.append({"epoch": epoch, "ssl_loss": epoch_loss})
                print(f"[SSL] Epoch {epoch:02d}/{CONFIG['ssl']['epochs']} | loss={epoch_loss:.5f}")

                if epoch_loss < best_ssl_loss:
                    best_ssl_loss = epoch_loss
                    best_backbone_state = deepcopy(ssl_model.encoder.state_dict())

            if best_backbone_state is None:
                best_backbone_state = ssl_model.encoder.state_dict()

            torch.save(best_backbone_state, ssl_backbone_ckpt)
            print(f"Saved SSL backbone to: {ssl_backbone_ckpt}")
        else:
            print("SSL disabled in config. Backbone will remain ImageNet-only.")

        with open(OUTPUT_DIR / "ssl_history.json", "w") as f:
            json.dump(ssl_history, f, indent=2)
        """
    ),
    md("## Fine-Tuning Stage (TM_V3 Supervised)"),
    code(
        """
        def set_strategy_trainable(model, strategy: str, warmup_done: bool):
            if strategy == "full_finetune":
                for p in model.parameters():
                    p.requires_grad = True
                return

            # Progressive: head-only warmup first
            for p in model.backbone.features.parameters():
                p.requires_grad = False
            for p in model.classifier.parameters():
                p.requires_grad = True

            if warmup_done:
                if strategy == "progressive_K5":
                    k = 5
                elif strategy == "progressive_K6":
                    k = 6
                else:
                    raise ValueError(f"Unknown strategy: {strategy}")

                children = list(model.backbone.features.children())
                for layer in children[-k:]:
                    for p in layer.parameters():
                        p.requires_grad = True

        def make_optimizer_for_strategy(model, strategy, lr_head, lr_backbone, weight_decay):
            if strategy == "full_finetune":
                return optim.AdamW(model.parameters(), lr=lr_backbone, weight_decay=weight_decay)

            head_params = [p for p in model.classifier.parameters() if p.requires_grad]
            backbone_params = [p for p in model.backbone.features.parameters() if p.requires_grad]
            groups = [{"params": head_params, "lr": lr_head}]
            if len(backbone_params) > 0:
                groups.append({"params": backbone_params, "lr": lr_backbone})
            return optim.AdamW(groups, weight_decay=weight_decay)

        def infer_probs(model, loader, device):
            model.eval()
            y_true, y_prob = [], []
            with torch.no_grad():
                for x, y in loader:
                    x = x.to(device, non_blocking=True)
                    logits = model(x)
                    probs = torch.softmax(logits, dim=1)[:, 1].cpu().numpy()
                    y_prob.extend(probs.tolist())
                    y_true.extend(y.numpy().tolist())
            return np.array(y_true), np.array(y_prob)

        def calc_basic_binary_metrics(y_true, y_prob, threshold=0.5):
            y_pred = (y_prob >= threshold).astype(int)
            tn, fp, fn, tp = confusion_matrix(y_true, y_pred, labels=[0, 1]).ravel()
            auc = roc_auc_score(y_true, y_prob) if len(np.unique(y_true)) > 1 else float("nan")
            accuracy = (tp + tn) / max(len(y_true), 1)
            sensitivity = tp / max(tp + fn, 1)
            specificity = tn / max(tn + fp, 1)
            return {
                "auc": float(auc),
                "accuracy": float(accuracy),
                "sensitivity": float(sensitivity),
                "specificity": float(specificity),
                "tp": int(tp),
                "tn": int(tn),
                "fp": int(fp),
                "fn": int(fn),
            }

        def sensitivity_at_target_specificity(y_true, y_prob, target_specificity):
            # Returns an operating point from ROC where specificity is >= target (or closest possible).
            if len(np.unique(y_true)) < 2:
                return {
                    "target_specificity": float(target_specificity),
                    "achieved_specificity": float("nan"),
                    "sensitivity": float("nan"),
                    "threshold": float("nan"),
                }

            fpr, tpr, thresholds = roc_curve(y_true, y_prob)
            specificity = 1.0 - fpr

            valid_idx = np.where(specificity >= target_specificity)[0]
            if len(valid_idx) > 0:
                # Among valid points, maximize sensitivity.
                best_local = valid_idx[np.argmax(tpr[valid_idx])]
            else:
                # If none meet target, choose closest specificity.
                best_local = int(np.argmin(np.abs(specificity - target_specificity)))

            return {
                "target_specificity": float(target_specificity),
                "achieved_specificity": float(specificity[best_local]),
                "sensitivity": float(tpr[best_local]),
                "threshold": float(thresholds[best_local]),
            }
        """
    ),
    code(
        """
        strategy_runs = CONFIG["finetune"]["strategy_runs"]
        warmup_epochs = CONFIG["finetune"]["warmup_epochs"]
        epochs = CONFIG["finetune"]["epochs"]
        patience = CONFIG["finetune"]["patience"]

        class_counts = np.bincount(np.array(sup_train_labels), minlength=2)
        class_weights = (class_counts.sum() / np.maximum(class_counts, 1)).astype(np.float32)
        class_weights = class_weights / class_weights.mean()
        criterion = nn.CrossEntropyLoss(weight=torch.tensor(class_weights, device=device))

        # Keep one backbone snapshot in CPU memory and reuse it for each strategy run.
        if CONFIG["ssl"]["enabled"]:
            initial_backbone_state = torch.load(ssl_backbone_ckpt, map_location="cpu")
            print("Using SSL-pretrained backbone for supervised runs.")
        else:
            initial_backbone_state = None
            print("Using ImageNet-only backbone for supervised runs.")

        all_supervised_history = {}
        best_model_paths = {}

        for strategy in strategy_runs:
            print("\\n" + "=" * 90)
            print(f"Starting supervised strategy: {strategy}")
            print("=" * 90)

            model = ConservativeMobileNetV3(
                num_classes=2,
                dropout_rate=CONFIG["finetune"]["dropout_rate"],
            ).to(device)

            if initial_backbone_state is not None:
                _ = model.backbone.features.load_state_dict(initial_backbone_state, strict=True)

            set_strategy_trainable(model, strategy, warmup_done=False)
            optimizer = make_optimizer_for_strategy(
                model,
                strategy=strategy,
                lr_head=CONFIG["finetune"]["lr_head"],
                lr_backbone=CONFIG["finetune"]["lr_backbone"],
                weight_decay=CONFIG["finetune"]["weight_decay"],
            )

            best_val_auc = -1.0
            best_epoch = -1
            best_state = None
            no_improve = 0
            sup_history = []

            for epoch in range(1, epochs + 1):
                if strategy in ("progressive_K5", "progressive_K6") and epoch == warmup_epochs + 1:
                    set_strategy_trainable(model, strategy, warmup_done=True)
                    optimizer = make_optimizer_for_strategy(
                        model,
                        strategy=strategy,
                        lr_head=CONFIG["finetune"]["lr_head"],
                        lr_backbone=CONFIG["finetune"]["lr_backbone"],
                        weight_decay=CONFIG["finetune"]["weight_decay"],
                    )
                    print(f"Switched to progressive unfreeze at epoch {epoch} ({strategy}).")

                model.train()
                train_loss_sum = 0.0
                train_n = 0

                for x, y in sup_train_loader:
                    x = x.to(device, non_blocking=True)
                    y = y.to(device, non_blocking=True)

                    logits = model(x)
                    loss = criterion(logits, y)

                    optimizer.zero_grad()
                    loss.backward()
                    optimizer.step()

                    bs = x.size(0)
                    train_loss_sum += float(loss.item()) * bs
                    train_n += bs

                train_loss = train_loss_sum / max(train_n, 1)
                val_true, val_prob = infer_probs(model, sup_val_loader, device)
                val_metrics = calc_basic_binary_metrics(val_true, val_prob, threshold=CONFIG["eval"]["threshold"])

                row = {
                    "epoch": epoch,
                    "train_loss": train_loss,
                    "val_auc": val_metrics["auc"],
                    "val_acc": val_metrics["accuracy"],
                    "val_sens": val_metrics["sensitivity"],
                    "val_spec": val_metrics["specificity"],
                }
                sup_history.append(row)
                print(
                    f"[SUP][{strategy}] Epoch {epoch:02d}/{epochs} | "
                    f"loss={train_loss:.4f} | "
                    f"val_auc={val_metrics['auc']:.4f} | "
                    f"val_acc={val_metrics['accuracy']:.4f}"
                )

                if val_metrics["auc"] > best_val_auc:
                    best_val_auc = val_metrics["auc"]
                    best_epoch = epoch
                    best_state = deepcopy(model.state_dict())
                    no_improve = 0
                else:
                    no_improve += 1
                    if no_improve >= patience:
                        print(f"Early stopping {strategy} at epoch {epoch} (patience={patience}).")
                        break

            strategy_model_dir = OUTPUT_DIR / "models" / strategy
            strategy_model_dir.mkdir(parents=True, exist_ok=True)
            best_model_ckpt = strategy_model_dir / "best_supervised_model.pth"
            torch.save(best_state, best_model_ckpt)
            best_model_paths[strategy] = str(best_model_ckpt)
            all_supervised_history[strategy] = {
                "best_epoch": best_epoch,
                "best_val_auc": float(best_val_auc),
                "history": sup_history,
            }
            print(f"Best epoch ({strategy}): {best_epoch} | best val AUC: {best_val_auc:.4f}")
            print(f"Saved best supervised checkpoint: {best_model_ckpt}")

        with open(OUTPUT_DIR / "supervised_history_by_strategy.json", "w") as f:
            json.dump(all_supervised_history, f, indent=2)

        with open(OUTPUT_DIR / "best_model_paths.json", "w") as f:
            json.dump(best_model_paths, f, indent=2)
        """
    ),
    md("## Evaluate Best Model On TM_V3 Frozen Test"),
    code(
        """
        tm_eval_paths, tm_eval_labels, tm_eval_sources = get_tm_paths_labels_and_sources_v3(frozen_dir)
        tm_eval_ds = BinaryImageDataset(tm_eval_paths, tm_eval_labels, supervised_val_transform)
        tm_eval_loader = DataLoader(
            tm_eval_ds,
            batch_size=CONFIG["finetune"]["batch_size"],
            shuffle=False,
            num_workers=CONFIG["num_workers"],
        )

        strategy_summaries = []
        all_eval_payload = {
            "counts": {
                "tm_v3_eval_n": int(len(tm_eval_paths)),
                "ssl_unlabeled_n": int(len(ssl_unlabeled_paths)),
                "supervised_train_n": int(len(sup_train_paths)),
                "supervised_val_n": int(len(sup_val_paths)),
            },
            "strategies": {},
        }

        src_arr = np.array(tm_eval_sources)
        for strategy in CONFIG["finetune"]["strategy_runs"]:
            best_model = ConservativeMobileNetV3(
                num_classes=2,
                dropout_rate=CONFIG["finetune"]["dropout_rate"],
            ).to(device)
            best_model_path = OUTPUT_DIR / "models" / strategy / "best_supervised_model.pth"
            best_model.load_state_dict(torch.load(best_model_path, map_location=device))

            y_true, y_prob = infer_probs(best_model, tm_eval_loader, device)
            overall = calc_basic_binary_metrics(y_true, y_prob, threshold=CONFIG["eval"]["threshold"])
            sens_at_spec_80 = sensitivity_at_target_specificity(y_true, y_prob, 0.80)
            sens_at_spec_90 = sensitivity_at_target_specificity(y_true, y_prob, 0.90)
            print(f"TM_V3 overall ({strategy}): {overall}")
            print(f"TM_V3 sensitivity@~80% specificity ({strategy}): {sens_at_spec_80}")
            print(f"TM_V3 sensitivity@~90% specificity ({strategy}): {sens_at_spec_90}")

            per_source_rows = []
            for src in sorted(set(tm_eval_sources)):
                mask = src_arr == src
                src_metrics = calc_basic_binary_metrics(
                    y_true[mask],
                    y_prob[mask],
                    threshold=CONFIG["eval"]["threshold"],
                )
                src_metrics["source"] = src
                src_metrics["n"] = int(mask.sum())
                per_source_rows.append(src_metrics)

            strategy_summaries.append({
                "strategy": strategy,
                "auc": overall["auc"],
                "accuracy": overall["accuracy"],
                "sensitivity": overall["sensitivity"],
                "specificity": overall["specificity"],
                "sens_at_spec80": sens_at_spec_80["sensitivity"],
                "spec_at_spec80": sens_at_spec_80["achieved_specificity"],
                "thr_at_spec80": sens_at_spec_80["threshold"],
                "sens_at_spec90": sens_at_spec_90["sensitivity"],
                "spec_at_spec90": sens_at_spec_90["achieved_specificity"],
                "thr_at_spec90": sens_at_spec_90["threshold"],
            })
            all_eval_payload["strategies"][strategy] = {
                "overall": overall,
                "sensitivity_at_specificity_80": sens_at_spec_80,
                "sensitivity_at_specificity_90": sens_at_spec_90,
                "per_source": per_source_rows,
                "model_path": str(best_model_path),
            }

            per_source_df = pd.DataFrame(per_source_rows).sort_values("source")
            print(f"Per-source metrics ({strategy}):")
            display(per_source_df)

        summary_df = pd.DataFrame(strategy_summaries).sort_values("auc", ascending=False)
        print("Strategy comparison (TM_V3 overall):")
        display(summary_df)

        with open(OUTPUT_DIR / "evaluation_tm_v3_by_strategy.json", "w") as f:
            json.dump(all_eval_payload, f, indent=2)

        print(f"Saved evaluation to: {OUTPUT_DIR / 'evaluation_tm_v3_by_strategy.json'}")
        """
    ),
    md(
        """
        ## Next Experiment Variants

        You are currently running both `progressive_K5` and `full_finetune` on the same SSL backbone.
        1. Add `"progressive_K6"` to `CONFIG["finetune"]["strategy_runs"]` for the next comparison.
        1. Compare strategy-wise outputs in `evaluation_tm_v3_by_strategy.json`.
        1. If SSL helps binary robustly, reuse `ssl_backbone_state_dict.pth` for 5-class fine-tuning.
        """
    ),
]

nb.metadata = {
    "kernelspec": {
        "display_name": "Python 3",
        "language": "python",
        "name": "python3",
    },
    "language_info": {
        "name": "python",
        "version": "3.11",
    },
}

out_path = Path(__file__).resolve().parent / "ssl_caries_tmv3_pretrain_then_finetune.ipynb"
with open(out_path, "w", encoding="utf-8") as f:
    nbf.write(nb, f)

print(f"Notebook written to: {out_path}")
