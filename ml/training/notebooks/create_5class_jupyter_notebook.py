import os
import nbformat as nbf

nb = nbf.v4.new_notebook()

nb.cells = [
    nbf.v4.new_markdown_cell("# Train 5-Class Ensemble (Patient-Wise)\nThis notebook trains the 5-class ensemble using the `progressive_K5` strategy on the newly created patient-wise data splits (T5 + SMART-II)."),
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
from sklearn.utils.class_weight import compute_class_weight
from sklearn.metrics import roc_auc_score, classification_report, confusion_matrix

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
    DEFAULT_DATA_DIR_5CLASS_PATIENTWISE,
    DEFAULT_DATA_DIR_SMART_PATIENTWISE
)

timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
run_name = os.environ.get("EXPERIMENT_NAME") or f"5class_patientwise_{timestamp}"

CONFIG = {
    "image_size": (224, 224),
    "batch_size": 32,
    "num_epochs": 50,
    "patience": 12,
    "num_workers": 0,
    "seed": 42,
    "augmentation": "medical",
    "label_smoothing": 0.05,
    "class_names": ["Benign", "Healthy", "OCA", "OPMD", "Unknown"],
    "num_classes": 5,
    "dropout_rates": [0.3, 0.1, 0.2],
    "ensemble_weights": [0.30, 0.40, 0.30],
    
    # progressive_K5
    "strategy": {
        "lr_head": 1e-3,
        "lr_backbone": 1e-4,
        "warmup_epochs": 5,
        "unfreeze_last_k": 5,
    }
}

OUTPUT_DIR = NOTEBOOK_DIR / f"results/5class_patientwise/{run_name}"
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
# Load explicitly from patient-wise train and val directories to maintain strict patient split
train_paths, train_labels = [], []
val_paths, val_labels = [], []

label_map = {name: i for i, name in enumerate(CONFIG["class_names"])}

data_sources = [
    (Path(os.path.expanduser(DEFAULT_DATA_DIR_5CLASS_PATIENTWISE)), CONFIG["class_names"]),
    (Path(os.path.expanduser(DEFAULT_DATA_DIR_SMART_PATIENTWISE)), ["Benign", "Healthy", "OPMD"])
]

def collect_images_for_split(split, paths_list, labels_list):
    for base_dir, classes in data_sources:
        for class_name in classes:
            class_dir = base_dir / split / class_name
            if class_dir.exists():
                images = list(class_dir.glob("*.jpg")) + list(class_dir.glob("*.jpeg")) + \
                         list(class_dir.glob("*.png")) + list(class_dir.glob("*.JPG"))
                paths_list.extend([str(p) for p in images])
                labels_list.extend([label_map[class_name]] * len(images))

collect_images_for_split("train", train_paths, train_labels)
collect_images_for_split("val", val_paths, val_labels)

print(f"Train samples: {len(train_paths)}")
print(f"Val samples:   {len(val_paths)}")

from collections import Counter
t_counts = Counter(train_labels)
v_counts = Counter(val_labels)
for i, name in enumerate(CONFIG["class_names"]):
    print(f"  {name:7s}: train={t_counts.get(i, 0):4d}, val={v_counts.get(i, 0):4d}")
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

class FiveClassDataset(Dataset):
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
    train_ds = FiveClassDataset(train_paths, train_labels, albu_transform=train_aug)
    val_ds = FiveClassDataset(val_paths, val_labels, albu_transform=val_aug)
else:
    train_ds = FiveClassDataset(train_paths, train_labels, torch_transform=basic_train_transform)
    val_ds = FiveClassDataset(val_paths, val_labels, torch_transform=basic_val_transform)

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
NUM_CLASSES = 5

class ConservativeMobileNetV3(nn.Module):
    def __init__(self, num_classes=5, dropout_rate=0.2):
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
    def __init__(self, num_classes=5):
        super().__init__(num_classes=num_classes, dropout_rate=CONFIG["dropout_rates"][0])

class EnsembleModel2(ConservativeMobileNetV3):
    def __init__(self, num_classes=5):
        super().__init__(num_classes=num_classes, dropout_rate=CONFIG["dropout_rates"][1])

class EnsembleModel3(ConservativeMobileNetV3):
    def __init__(self, num_classes=5):
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
classes_ar = np.unique(train_labels)
weights = compute_class_weight("balanced", classes=classes_ar, y=train_labels)
class_weights = torch.tensor(weights, dtype=torch.float32)

# Optional: boost OCA/OPMD (indices 2, 3) since they are cancer
for i, name in enumerate(CONFIG["class_names"]):
    if name in ("OCA", "OPMD"):
        class_weights[i] *= 1.2
print("Class weights:", dict(zip(CONFIG["class_names"], class_weights.tolist())))
"""),
    nbf.v4.new_code_cell("""
def _make_criterion(class_weights, device, label_smoothing):
    return nn.CrossEntropyLoss(
        weight=class_weights.to(device) if class_weights is not None else None,
        label_smoothing=label_smoothing,
    )

def _validate_5class(model, val_loader, criterion, device):
    model.eval()
    correct, total = 0, 0
    val_loss = 0.0
    all_probs, all_targets = [], []
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
            all_probs.append(probs.cpu().numpy())
            all_targets.append(target.cpu().numpy())
    acc = 100.0 * correct / total
    probs_np = np.vstack(all_probs)
    targets_np = np.concatenate(all_targets)
    try:
        auc = roc_auc_score(targets_np, probs_np, multi_class="ovr", average="macro")
    except Exception:
        auc = 0.0
    return acc, auc, val_loss / len(val_loader)

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

def _tb_log_5class(writer, epoch, train_loss, train_acc, val_acc, val_auc, lr):
    if writer is None:
        return
    writer.add_scalar("loss/train", train_loss, epoch)
    writer.add_scalar("acc/train", train_acc, epoch)
    writer.add_scalar("acc/val", val_acc, epoch)
    writer.add_scalar("auc_macro/val", val_auc, epoch)
    writer.add_scalar("lr", lr, epoch)
    writer.flush()"""),
    nbf.v4.new_code_cell("""
def train_progressive_K5_5class(model_class, model_name, train_loader, val_loader, device, config, class_weights=None, tb_log_dir=None):
    strat = config["strategy"]
    warmup_epochs = strat["warmup_epochs"]
    main_epochs = config["num_epochs"]
    unfreeze_k = strat["unfreeze_last_k"]
    writer = SummaryWriter(log_dir=tb_log_dir) if (HAS_TENSORBOARD and tb_log_dir) else None

    model = model_class(num_classes=NUM_CLASSES).to(device)
    model.freeze_backbone()
    criterion = _make_criterion(class_weights, device, config.get("label_smoothing", 0.0))

    # Phase 1: warmup
    print(f"[{model_name}] Phase 1 (warmup {warmup_epochs} ep)")
    optimizer = optim.Adam(model.classifier.parameters(), lr=strat["lr_head"])
    for epoch in range(warmup_epochs):
        avg_loss, train_acc = _train_one_epoch(model, train_loader, criterion, optimizer, device)
        val_acc, val_auc, _ = _validate_5class(model, val_loader, criterion, device)
        _tb_log_5class(writer, epoch, avg_loss, train_acc, val_acc, val_auc, strat["lr_head"])
        if epoch == warmup_epochs - 1:
            print(f"  Warmup done (ep {warmup_epochs}): val_acc={val_acc:.2f}%, val_auc_macro={val_auc:.4f}")

    # Phase 2: unfreeze last K
    model.unfreeze_last_k_blocks(unfreeze_k)
    print(f"[{model_name}] Phase 2 (last {unfreeze_k} blocks, {main_epochs} ep)")
    param_groups = model.get_param_groups(lr_head=strat["lr_head"], lr_backbone=strat["lr_backbone"])
    optimizer = optim.Adam(param_groups)
    scheduler = optim.lr_scheduler.CosineAnnealingLR(optimizer, T_max=main_epochs, eta_min=1e-6)

    best_auc, best_acc, best_state, patience_ctr = 0.0, 0.0, None, 0
    history = {"val_auc_macro": []}
    
    for epoch in range(main_epochs):
        avg_loss, train_acc = _train_one_epoch(model, train_loader, criterion, optimizer, device)
        val_acc, val_auc, _ = _validate_5class(model, val_loader, criterion, device)
        lr_now = optimizer.param_groups[0]["lr"]
        
        _tb_log_5class(writer, warmup_epochs + epoch, avg_loss, train_acc, val_acc, val_auc, lr_now)
        history["val_auc_macro"].append(val_auc)
        
        if val_auc > best_auc:
            best_auc, best_acc = val_auc, val_acc
            best_state = {k: v.cpu().clone() for k, v in model.state_dict().items()}
            patience_ctr = 0
        else:
            patience_ctr += 1
            
        if (epoch + 1) % 5 == 0 or epoch == 0:
            print(f"  Ep {warmup_epochs + epoch + 1:3d}  loss={avg_loss:.4f}  train={train_acc:.2f}%  val={val_acc:.2f}%  auc_macro={val_auc:.4f}  lr={lr_now:.2e}")
            
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
print("Training Progressive K=5 models (5-class)")
trained_models = []

for i, model_class in enumerate(ENSEMBLE_CLASSES):
    model_name = f"ensemble_model_{i+1}"
    print(f"\\n--- {model_name} ---")
    
    torch.manual_seed(CONFIG["seed"] + i)
    np.random.seed(CONFIG["seed"] + i)
    
    run_tb_dir = TB_LOG_DIR / "progressive_K5" / model_name
    run_tb_dir.mkdir(parents=True, exist_ok=True)
    
    model, best_acc, best_auc, hist = train_progressive_K5_5class(
        model_class, model_name, train_loader, val_loader, device, CONFIG, class_weights, tb_log_dir=str(run_tb_dir)
    )
    
    save_path = OUTPUT_DIR / "models" / f"{model_name}.pth"
    torch.save(model.state_dict(), save_path)
    trained_models.append(model)
    print(f"Saved to {save_path} (Best Macro AUC: {best_auc:.4f})")
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
    export_to_onnx(m, f"ensemble_model_{i+1}", OUTPUT_DIR / "onnx")
""")
]

with open(os.path.join(os.path.dirname(__file__), "train_5class_ensemble_patientwise.ipynb"), "w") as f:
    nbf.write(nb, f)
