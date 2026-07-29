import os
import nbformat as nbf

nb = nbf.v4.new_notebook()

nb.cells = [
    nbf.v4.new_markdown_cell("# Train Binary Ensemble (Patient-Wise)\nThis notebook trains the production binary ensemble using the `progressive_K5` strategy on the newly created patient-wise data splits (T5, SMART-II, TB, TC)."),
    nbf.v4.new_code_cell("""
import os
from pathlib import Path
from datetime import datetime
import json

import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader, Dataset
import torchvision.transforms as transforms
from torchvision import models
from PIL import Image, ImageFile
ImageFile.LOAD_TRUNCATED_IMAGES = True
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.utils.class_weight import compute_class_weight
from sklearn.metrics import (
    roc_auc_score, average_precision_score, confusion_matrix,
    brier_score_loss, classification_report
)

try:
    import albumentations as A
    from albumentations.pytorch import ToTensorV2
    HAS_ALBUMENTATIONS = True
except ImportError:
    HAS_ALBUMENTATIONS = False

try:
    import onnx
    import onnxruntime as ort
    HAS_ONNX = True
except ImportError:
    HAS_ONNX = False

try:
    from torch.utils.tensorboard import SummaryWriter
    HAS_TENSORBOARD = True
except ImportError:
    HAS_TENSORBOARD = False

NOTEBOOK_DIR = Path(".").resolve()
FROZEN_DIR = NOTEBOOK_DIR / "frozen_test_sets"

# Add notebook dir to path to import frozen test sets
import sys
sys.path.insert(0, str(NOTEBOOK_DIR))
from frozen_test_sets import (
    load_frozen_sets_v3,
    get_all_train_val_for_training_v3,
    get_tc_paths_labels,
    get_tb_paths_labels,
    get_tm_paths_labels_and_sources_v3
)

timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
run_name = os.environ.get("EXPERIMENT_NAME") or f"binary_patientwise_{timestamp}"

CONFIG = {
    "image_size": (224, 224),
    "batch_size": 32,
    "num_epochs": 50,
    "patience": 12,
    "val_split": 0.15,
    "num_workers": 0,
    "seed": 42,
    "augmentation": "medical",
    "cancer_weight_multiplier": 1.5,
    "label_smoothing": 0.05,
    "dropout_rates": [0.3, 0.1, 0.2],
    "ensemble_weights": [0.30, 0.40, 0.30],
    
    # We only use progressive_K5 here
    "strategy": {
        "lr_head": 1e-3,
        "lr_backbone": 1e-4,
        "warmup_epochs": 5,
        "unfreeze_last_k": 5,
    }
}

OUTPUT_DIR = NOTEBOOK_DIR / f"results/binary_patientwise/{run_name}"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
(OUTPUT_DIR / "models").mkdir(exist_ok=True)
(OUTPUT_DIR / "onnx").mkdir(exist_ok=True)
TB_LOG_DIR = OUTPUT_DIR / "tb_logs"
TB_LOG_DIR.mkdir(exist_ok=True)

with open(OUTPUT_DIR / "config.json", "w") as f:
    json.dump({**CONFIG, "run_name": run_name, "image_size": list(CONFIG["image_size"])}, f, indent=2, default=str)

print(f"Output: {OUTPUT_DIR}")
"""),
    nbf.v4.new_code_cell("""
if torch.backends.mps.is_available():
    device = torch.device("mps")
elif torch.cuda.is_available():
    device = torch.device("cuda")
else:
    device = torch.device("cpu")
print(f"Using: {device}")

torch.manual_seed(CONFIG["seed"])
np.random.seed(CONFIG["seed"])
"""),
    nbf.v4.new_code_cell("""
# Load Frozen Test Sets v3
T5, T_SMART, TB, TC, TM, meta = load_frozen_sets_v3(FROZEN_DIR)
print(f"Frozen test set summary:")
print(f"  T5 (v3): {len(T5)}")
print(f"  TSMART: {len(T_SMART)}")
print(f"  TB: {len(TB)}")
print(f"  TC: {len(TC)}")
print(f"  TM_v3: {len(TM)}")

# Get aggregated train/val from all patient-wise sources
all_paths, all_labels, all_sources = get_all_train_val_for_training_v3(FROZEN_DIR)

print(f"Merged training pool: {len(all_paths)} images")
cancer_count = sum(all_labels)
print(f"  Cancer: {cancer_count} ({(cancer_count/len(all_paths))*100:.1f}%)")
print(f"  Non-cancer: {len(all_paths)-cancer_count} ({((len(all_paths)-cancer_count)/len(all_paths))*100:.1f}%)")
"""),
    nbf.v4.new_code_cell("""
train_paths, val_paths, train_labels, val_labels = train_test_split(
    all_paths, all_labels,
    test_size=CONFIG["val_split"],
    random_state=CONFIG["seed"],
    stratify=all_labels,
)
print(f"Train: {len(train_paths)}")
print(f"Val:   {len(val_paths)}")
"""),
    nbf.v4.new_code_cell("""
IMAGENET_MEAN = [0.485, 0.456, 0.406]
IMAGENET_STD = [0.229, 0.224, 0.225]

def get_augmentation_pipeline(mode="medical", image_size=(224, 224)):
    if HAS_ALBUMENTATIONS and mode in ["medical", "strong"]:
        return A.Compose([
            A.Resize(image_size[0], image_size[1]),
            A.RandomRotate90(p=0.4),
            A.HorizontalFlip(p=0.5),
            A.VerticalFlip(p=0.2),
            A.ShiftScaleRotate(shift_limit=0.05, scale_limit=0.1, rotate_limit=15, p=0.4),
            A.RandomBrightnessContrast(brightness_limit=0.25, contrast_limit=0.25, p=0.6),
            A.HueSaturationValue(hue_shift_limit=12, sat_shift_limit=15, val_shift_limit=12, p=0.4),
            A.CLAHE(clip_limit=3.0, tile_grid_size=(8, 8), p=0.4),
            A.OneOf([
                A.GaussNoise(var_limit=(10.0, 40.0), p=0.3),
                A.ISONoise(color_shift=(0.01, 0.05), intensity=(0.1, 0.3), p=0.2),
            ], p=0.25),
            A.OneOf([
                A.MotionBlur(blur_limit=5, p=0.3),
                A.GaussianBlur(blur_limit=3, p=0.3),
            ], p=0.2),
            A.ImageCompression(quality_lower=70, quality_upper=95, p=0.15),
            A.Normalize(mean=IMAGENET_MEAN, std=IMAGENET_STD),
            ToTensorV2(),
        ])
    return None

def get_val_transform(image_size=(224, 224)):
    if HAS_ALBUMENTATIONS:
        return A.Compose([
            A.Resize(image_size[0], image_size[1]),
            A.Normalize(mean=IMAGENET_MEAN, std=IMAGENET_STD),
            ToTensorV2(),
        ])
    return None

basic_train_transform = transforms.Compose([
    transforms.Resize(CONFIG["image_size"]),
    transforms.RandomHorizontalFlip(),
    transforms.RandomRotation(15),
    transforms.ColorJitter(brightness=0.2, contrast=0.2),
    transforms.ToTensor(),
    transforms.Normalize(mean=IMAGENET_MEAN, std=IMAGENET_STD),
])

basic_val_transform = transforms.Compose([
    transforms.Resize(CONFIG["image_size"]),
    transforms.ToTensor(),
    transforms.Normalize(mean=IMAGENET_MEAN, std=IMAGENET_STD),
])

train_aug = get_augmentation_pipeline(CONFIG["augmentation"], CONFIG["image_size"])
val_aug = get_val_transform(CONFIG["image_size"])

class BinaryDataset(Dataset):
    def __init__(self, paths, labels, albu_transform=None, torch_transform=None):
        self.paths = paths
        self.labels = labels
        self.albu_transform = albu_transform
        self.torch_transform = torch_transform

    def __len__(self):
        return len(self.paths)

    def __getitem__(self, idx):
        img = Image.open(self.paths[idx]).convert("RGB")
        label = self.labels[idx]
        if self.albu_transform is not None:
            img = self.albu_transform(image=np.array(img))["image"]
        elif self.torch_transform is not None:
            img = self.torch_transform(img)
        return img, label

if train_aug is not None:
    train_ds = BinaryDataset(train_paths, train_labels, albu_transform=train_aug)
    val_ds = BinaryDataset(val_paths, val_labels, albu_transform=val_aug)
else:
    train_ds = BinaryDataset(train_paths, train_labels, torch_transform=basic_train_transform)
    val_ds = BinaryDataset(val_paths, val_labels, torch_transform=basic_val_transform)

train_loader = DataLoader(
    train_ds, batch_size=CONFIG["batch_size"], shuffle=True,
    num_workers=CONFIG["num_workers"], pin_memory=False,
)
val_loader = DataLoader(
    val_ds, batch_size=CONFIG["batch_size"], shuffle=False,
    num_workers=CONFIG["num_workers"],
)
"""),
    nbf.v4.new_code_cell("""
NUM_CLASSES = 2

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

class EnsembleModel1(ConservativeMobileNetV3):
    def __init__(self, num_classes=2):
        super().__init__(num_classes=num_classes, dropout_rate=CONFIG["dropout_rates"][0])


class EnsembleModel2(ConservativeMobileNetV3):
    def __init__(self, num_classes=2):
        super().__init__(num_classes=num_classes, dropout_rate=CONFIG["dropout_rates"][1])


class EnsembleModel3(ConservativeMobileNetV3):
    def __init__(self, num_classes=2):
        super().__init__(num_classes=num_classes, dropout_rate=CONFIG["dropout_rates"][2])
        self.classifier = nn.Sequential(
            nn.AdaptiveAvgPool2d((1, 1)),
            nn.Flatten(),
            nn.Dropout(0.2),
            nn.Linear(960, 512),
            nn.ReLU(inplace=True),
            nn.Dropout(0.1),
            nn.Linear(512, num_classes),
        )

ENSEMBLE_CLASSES = [EnsembleModel1, EnsembleModel2, EnsembleModel3]
"""),
    nbf.v4.new_code_cell("""
classes = np.unique(train_labels)
weights = compute_class_weight("balanced", classes=classes, y=train_labels)
class_weights = torch.tensor(weights, dtype=torch.float32)

cancer_multiplier = float(CONFIG.get("cancer_weight_multiplier", 1.0))
if cancer_multiplier != 1.0:
    class_weights = class_weights.clone()
    class_weights[1] = class_weights[1] * cancer_multiplier

print(f"Class weights: non-cancer={class_weights[0]:.4f}, cancer={class_weights[1]:.4f}")
"""),
    nbf.v4.new_code_cell("""
def _make_criterion(class_weights, device, label_smoothing):
    return nn.CrossEntropyLoss(
        weight=class_weights.to(device) if class_weights is not None else None,
        label_smoothing=label_smoothing,
    )

def _train_one_epoch(model, train_loader, criterion, optimizer, device):
    model.train()
    total_loss, correct, total = 0.0, 0, 0
    for data, target in train_loader:
        data, target = data.to(device), target.to(device).long()
        optimizer.zero_grad()
        out = model(data)
        loss = criterion(out, target)
        loss.backward()
        optimizer.step()
        total_loss += loss.item()
        _, pred = out.max(1)
        total += target.size(0)
        correct += pred.eq(target).sum().item()
    return total_loss / len(train_loader), 100.0 * correct / total

def _validate(model, val_loader, criterion, device):
    model.eval()
    correct, total = 0, 0
    val_loss = 0.0
    probs_list, targets_list = [], []
    with torch.no_grad():
        for data, target in val_loader:
            data, target = data.to(device), target.to(device).long()
            out = model(data)
            loss = criterion(out, target)
            val_loss += loss.item()
            probs = torch.softmax(out, dim=1)
            _, pred = out.max(1)
            total += target.size(0)
            correct += pred.eq(target).sum().item()
            probs_list.extend(probs[:, 1].cpu().numpy())
            targets_list.extend(target.cpu().numpy())
    acc = 100.0 * correct / total
    auc = roc_auc_score(targets_list, probs_list)
    return acc, auc, val_loss / len(val_loader)

def _tb_log(writer, epoch, train_loss, train_acc, val_acc, val_auc, lr):
    if writer is None:
        return
    writer.add_scalar("loss/train", train_loss, epoch)
    writer.add_scalar("acc/train", train_acc, epoch)
    writer.add_scalar("acc/val", val_acc, epoch)
    writer.add_scalar("auc/val", val_auc, epoch)
    writer.add_scalar("lr", lr, epoch)
    writer.flush()
"""),
    nbf.v4.new_code_cell("""
def train_progressive_K5(model_class, model_name, train_loader, val_loader, device, config, class_weights, tb_log_dir=None):
    strat = config["strategy"]
    warmup_epochs = strat["warmup_epochs"]
    main_epochs = config["num_epochs"]
    unfreeze_k = strat["unfreeze_last_k"]
    writer = SummaryWriter(log_dir=tb_log_dir) if (HAS_TENSORBOARD and tb_log_dir) else None

    model = model_class(num_classes=NUM_CLASSES).to(device)
    model.freeze_backbone()
    criterion = _make_criterion(class_weights, device, config.get("label_smoothing", 0.0))

    # Phase 1
    optimizer = optim.Adam(model.classifier.parameters(), lr=strat["lr_head"])
    print(f"[{model_name}] Phase 1 (warmup {warmup_epochs} ep)")
    for epoch in range(warmup_epochs):
        avg_loss, train_acc = _train_one_epoch(model, train_loader, criterion, optimizer, device)
        val_acc, val_auc, _ = _validate(model, val_loader, criterion, device)
        _tb_log(writer, epoch, avg_loss, train_acc, val_acc, val_auc, strat["lr_head"])
        if epoch == warmup_epochs - 1:
            print(f"  Warmup done (ep {warmup_epochs}): val_acc={val_acc:.2f}%, val_auc={val_auc:.4f}")

    # Phase 2
    model.unfreeze_last_k_blocks(unfreeze_k)
    print(f"[{model_name}] Phase 2 (last {unfreeze_k} blocks unfreezed, {main_epochs} ep)")
    param_groups = model.get_param_groups(lr_head=strat["lr_head"], lr_backbone=strat["lr_backbone"])
    optimizer = optim.Adam(param_groups)
    scheduler = optim.lr_scheduler.CosineAnnealingLR(optimizer, T_max=main_epochs, eta_min=1e-6)

    best_auc, best_acc, best_state, patience_ctr = 0.0, 0.0, None, 0
    history = {"val_auc": []}

    for epoch in range(main_epochs):
        avg_loss, train_acc = _train_one_epoch(model, train_loader, criterion, optimizer, device)
        val_acc, val_auc, val_loss = _validate(model, val_loader, criterion, device)
        lr_now = optimizer.param_groups[0]["lr"]
        
        _tb_log(writer, warmup_epochs + epoch, avg_loss, train_acc, val_acc, val_auc, lr_now)
        history["val_auc"].append(val_auc)

        if val_auc > best_auc:
            best_auc, best_acc = val_auc, val_acc
            best_state = {k: v.cpu().clone() for k, v in model.state_dict().items()}
            patience_ctr = 0
        else:
            patience_ctr += 1

        if (epoch + 1) % 5 == 0 or epoch == 0:
            print(f"  Ep {warmup_epochs + epoch + 1:3d} loss={avg_loss:.4f} train={train_acc:.2f}% val={val_acc:.2f}% auc={val_auc:.4f} lr={lr_now:.2e}")

        if patience_ctr >= config["patience"]:
            print(f"  Early stop at epoch {warmup_epochs + epoch + 1}")
            break

        scheduler.step()

    if writer:
        writer.close()
    if best_state:
        model.load_state_dict(best_state)
    return model, best_acc, best_auc, history
"""),
    nbf.v4.new_code_cell("""
print("Training Progressive K=5 models")
trained_models = []

for i, model_class in enumerate(ENSEMBLE_CLASSES):
    model_name = f"ensemble_model_{i+1}"
    print(f"\\n--- {model_name} ---")
    
    torch.manual_seed(CONFIG["seed"] + i)
    np.random.seed(CONFIG["seed"] + i)
    
    run_tb_dir = TB_LOG_DIR / "progressive_K5" / model_name
    run_tb_dir.mkdir(parents=True, exist_ok=True)
    
    model, best_acc, best_auc, hist = train_progressive_K5(
        model_class, model_name, train_loader, val_loader, device, CONFIG, class_weights, tb_log_dir=str(run_tb_dir)
    )
    
    save_path = OUTPUT_DIR / "models" / f"{model_name}.pth"
    torch.save(model.state_dict(), save_path)
    trained_models.append(model)
    print(f"Saved to {save_path} (Best AUC: {best_auc:.4f})")
"""),
    nbf.v4.new_code_cell("""
# Export ONNX

def export_to_onnx(model, model_name, save_dir):
    model.eval()
    model.to("cpu")
    dummy_input = torch.randn(1, 3, 224, 224, device="cpu")
    onnx_path = save_dir / f"{model_name}.onnx"
    
    torch.onnx.export(
        model,
        dummy_input,
        str(onnx_path),
        export_params=True,
        opset_version=18,
        do_constant_folding=True,
        input_names=["input"],
        output_names=["output"],
        dynamic_axes={"input": {0: "batch_size"}, "output": {0: "batch_size"}}
    )
    print(f"Exported {model_name} to {onnx_path}")

for i, m in enumerate(trained_models):
    export_to_onnx(m, f"binary_ensemble_model_{i+1}", OUTPUT_DIR / "onnx")
""")
]

with open(os.path.join(os.path.dirname(__file__), "train_binary_ensemble_patientwise.ipynb"), "w") as f:
    nbf.write(nb, f)
