import os
import nbformat as nbf

nb = nbf.v4.new_notebook()

nb.cells = [
    nbf.v4.new_markdown_cell("# Patient-Wise Models Comparison\n\nThis notebook rigorously compares 3 layers of models against the **new `TM_v3` test master** (which includes T5_v3, patient-wise SMART-II, TB, and TC).\n\nTo ensure a fair comparison, all inference is conducted using **ONNX models** across all 3 layers:\n1. **Production Baseline (1)**: The ONNX models currently deployed in `assets/`\n2. **Previous `progressive_K5` Models (2)**: Old models trained before patient-wise split\n3. **New Patient-Wise Models (3)**: The models trained in the preceding notebooks."),
    nbf.v4.new_code_cell("""
import os
from pathlib import Path
import json
import glob
import numpy as np
import pandas as pd
from PIL import Image, ImageFile
ImageFile.LOAD_TRUNCATED_IMAGES = True
import onnxruntime as ort
from sklearn.metrics import roc_auc_score, confusion_matrix, accuracy_score

NOTEBOOK_DIR = Path(".").resolve()
ROOT_DIR = NOTEBOOK_DIR.parent.parent.parent
FROZEN_DIR = NOTEBOOK_DIR / "frozen_test_sets"

# Add notebook dir to path to import frozen test sets
import sys
sys.path.insert(0, str(NOTEBOOK_DIR))
from frozen_test_sets import load_frozen_sets_v3, get_tm_paths_labels_and_sources_v3

import warnings
warnings.filterwarnings("ignore")
"""),
    nbf.v4.new_code_cell("""
T5, T_SMART, TB, TC, TM, meta = load_frozen_sets_v3(FROZEN_DIR)
tm_paths, tm_labels, tm_sources = get_tm_paths_labels_and_sources_v3(FROZEN_DIR)

print(f"TM_v3 loaded: {len(tm_paths)} images")
source_counts = pd.Series(tm_sources).value_counts()
print(f"Sources: A(T5)={source_counts.get('A',0)}, B(TB)={source_counts.get('B',0)}, C(TC)={source_counts.get('C',0)}, D(SMART)={source_counts.get('D',0)}")
"""),
    nbf.v4.new_code_cell("""
# --- Define Model Paths ---

def get_latest_run_dir(parent_dir):
    dirs = glob.glob(str(parent_dir / "*"))
    if not dirs:
        return None
    return Path(max(dirs, key=os.path.getctime))

# 1. Production Models
PROD_BINARY_DIR = ROOT_DIR / "assets"
PROD_5CLASS_DIR = ROOT_DIR / "assets"

prod_binary_onnx = [PROD_BINARY_DIR / f"binary_ensemble_mode_{i}.onnx" for i in [1, 2, 3]]
prod_5class_onnx = [PROD_5CLASS_DIR / f"ensemble_model_{i}.onnx" for i in [1, 2, 3]]

# 2. Previous progressive_K5 Models (from MODEL_DEVELOPMENT_AND_USAGE.md)
PREV_BINARY_DIR = NOTEBOOK_DIR / "results/freeze_comparison/freeze_comparison_20260208_121618/onnx"
PREV_5CLASS_DIR = NOTEBOOK_DIR / "results/improved_5class/improved_5class_20260209_172821/onnx"

# We must check if they exist, otherwise skip finding
prev_binary_onnx = [PREV_BINARY_DIR / f"ensemble_model_{i}.onnx" for i in [1, 2, 3]]
prev_5class_onnx = [PREV_5CLASS_DIR / f"ensemble_model_{i}.onnx" for i in [1, 2, 3]]

# 3. New Patient-Wise Models
NEW_BINARY_RUN = get_latest_run_dir(NOTEBOOK_DIR / "results/binary_patientwise")
NEW_5CLASS_RUN = get_latest_run_dir(NOTEBOOK_DIR / "results/5class_patientwise")

if NEW_BINARY_RUN:
    new_binary_onnx = [NEW_BINARY_RUN / "onnx" / f"binary_ensemble_model_{i}.onnx" for i in [1, 2, 3]]
else:
    new_binary_onnx = []

if NEW_5CLASS_RUN:
    new_5class_onnx = [NEW_5CLASS_RUN / "onnx" / f"ensemble_model_{i}.onnx" for i in [1, 2, 3]]
else:
    new_5class_onnx = []

models = {
    "Binary_Production": prod_binary_onnx,
    "Binary_Prev_ProgK5": prev_binary_onnx,
    "Binary_PatientWise": new_binary_onnx,
    "5Class_Production": prod_5class_onnx,
    "5Class_Prev_ProgK5": prev_5class_onnx,
    "5Class_PatientWise": new_5class_onnx
}

# Verify existence
for name, paths in models.items():
    missing = [p for p in paths if not p.exists()]
    if missing:
        print(f"Warning: {name} is missing {len(missing)} ONNX files!")
    elif not paths:
         print(f"Warning: {name} has no paths defined!")
    else:
        print(f"✅ {name} loaded ({len(paths)} ONNX files)")
"""),
    nbf.v4.new_code_cell("""
# Inference Engine

IMAGENET_MEAN = [0.485, 0.456, 0.406]
IMAGENET_STD = [0.229, 0.224, 0.225]
ENSEMBLE_WEIGHTS = [0.30, 0.40, 0.30]

def preprocess_image(path, image_size=(224, 224)):
    img = Image.open(path).convert("RGB").resize(image_size)
    arr = np.array(img).astype(np.float32) / 255.0
    arr = (arr - IMAGENET_MEAN) / IMAGENET_STD
    return np.transpose(arr, (2, 0, 1))[np.newaxis, ...].astype(np.float32)

def evaluate_binary_onnx_ensemble(onnx_paths, paths, labels):
    sessions = [ort.InferenceSession(str(p), providers=['CPUExecutionProvider']) for p in onnx_paths]
    input_name = sessions[0].get_inputs()[0].name
    
    y_true, y_prob = [], []
    for path, label in zip(paths, labels):
        x = preprocess_image(path)
        
        logits_sum = np.zeros((1, 2), dtype=np.float32)
        for sess, w in zip(sessions, ENSEMBLE_WEIGHTS):
            out = sess.run(None, {input_name: x})[0]
            logits_sum += out * w
            
        exp_logits = np.exp(logits_sum - np.max(logits_sum))
        prob_cancer = float(exp_logits[0, 1] / exp_logits.sum())
        
        y_prob.append(prob_cancer)
        y_true.append(label)
        
    return np.array(y_true), np.array(y_prob)

def evaluate_5class_onnx_ensemble_as_binary(onnx_paths, paths, labels):
    # OCA and OPMD are indices 2 and 3 in the 5-class model
    sessions = [ort.InferenceSession(str(p), providers=['CPUExecutionProvider']) for p in onnx_paths]
    input_name = sessions[0].get_inputs()[0].name
    
    y_true, y_prob = [], []
    for path, label in zip(paths, labels):
        x = preprocess_image(path)
        
        logits_sum = np.zeros((1, 5), dtype=np.float32)
        for sess, w in zip(sessions, ENSEMBLE_WEIGHTS):
            out = sess.run(None, {input_name: x})[0]
            logits_sum += out * w
            
        exp_logits = np.exp(logits_sum - np.max(logits_sum))
        probs = exp_logits / exp_logits.sum()
        prob_cancer = float(probs[0, 2] + probs[0, 3]) # P(OCA) + P(OPMD)
        
        y_prob.append(prob_cancer)
        y_true.append(label)
        
    return np.array(y_true), np.array(y_prob)
"""),
    nbf.v4.new_code_cell("""
results_db = []

def record_metrics(name, set_name, y_true, y_prob):
    y_pred = (y_prob >= 0.5).astype(int)
    tn, fp, fn, tp = confusion_matrix(y_true, y_pred, labels=[0, 1]).ravel()
    
    accuracy = (tp + tn) / len(y_true)
    sensitivity = tp / max(tp + fn, 1)
    specificity = tn / max(tn + fp, 1)
    
    try:
        auc = roc_auc_score(y_true, y_prob)
    except ValueError:
        auc = np.nan
        
    results_db.append({
        "Model": name,
        "Eval_Set": set_name,
        "N": len(y_true),
        "AUC": auc,
        "Accuracy": accuracy,
        "Sensitivity": sensitivity,
        "Specificity": specificity
    })
"""),
    nbf.v4.new_code_cell("""
print("Running ONNX evaluations on TM_v3 and its sub-sources...")
print("(This may take a few minutes...)")

for model_name, paths in models.items():
    if not paths or not all(p.exists() for p in paths):
        continue
        
    print(f"Evaluating: {model_name}")
    
    if "Binary" in model_name:
        y_true, y_prob = evaluate_binary_onnx_ensemble(paths, tm_paths, tm_labels)
    else:
        y_true, y_prob = evaluate_5class_onnx_ensemble_as_binary(paths, tm_paths, tm_labels)
        
    # Record overall TM_v3
    record_metrics(model_name, "TM_v3 (Overall)", y_true, y_prob)
    
    # Record Per-Source
    for src_id, src_name in [("A", "T5"), ("D", "SMART-II"), ("B", "TB"), ("C", "TC")]:
        mask = np.array(tm_sources) == src_id
        if np.any(mask):
            record_metrics(model_name, f"Source: {src_name}", y_true[mask], y_prob[mask])
""") ,
    nbf.v4.new_code_cell("""
# Display Results
df = pd.DataFrame(results_db)

print("\\n" + "="*80)
print("🏆 OVERALL TM_v3 PERFORMANCE")
print("="*80)
overall_df = df[df["Eval_Set"] == "TM_v3 (Overall)"].copy()
overall_df = overall_df.sort_values(by="AUC", ascending=False)
display(overall_df.style.format({
    "AUC": "{:.4f}", "Accuracy": "{:.2%}", "Sensitivity": "{:.2%}", "Specificity": "{:.2%}"
}))

print("\\n" + "="*80)
print("📊 SOURCE-LEVEL STABILITY (T5 vs SMART-II vs TB vs TC)")
print("="*80)
source_df = df[df["Eval_Set"] != "TM_v3 (Overall)"].copy()
pivot_df = source_df.pivot(index="Model", columns="Eval_Set", values="AUC")
# Calculate max delta (source gap)
pivot_df["Max_AUC_Gap"] = pivot_df.max(axis=1) - pivot_df.min(axis=1)
pivot_df = pivot_df.sort_values(by="Max_AUC_Gap", ascending=True)

display(pivot_df.style.format("{:.4f}").background_gradient(cmap='viridis', axis=1))
""")
]

with open(os.path.join(os.path.dirname(__file__), "compare_models_patientwise.ipynb"), "w") as f:
    nbf.write(nb, f)
