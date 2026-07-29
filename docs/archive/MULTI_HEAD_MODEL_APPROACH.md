# Multi-Head Model for Oral Pre-Screening

**Purpose:** A detailed technical guide for building a single-model multi-head architecture that integrates your 4-class dataset (Healthy, Benign, OPMD, OCA, Unknown) and your binary cancer/non-cancer dataset. This document gives value proposition, dataset integration, architecture, training & inference workflows, pseudocode, deployment notes, evaluation guidance and practical tips.

---

## Table of contents

1. Executive summary & value proposition
2. Core architecture (backbone + heads)
3. Dataset mapping & preparation
4. Training pipeline (step-by-step + pseudocode)
5. Inference & multi-image aggregation
6. Evaluation metrics, thresholds & calibration
7. Data augmentation, semi-supervision & expanding the dataset
8. Deployment & inference-time optimizations
9. Practical tips, common pitfalls and mitigations
10. Suggested repo structure and checkpoints
11. Next steps / roadmap

---

## 1. Executive summary & value proposition

**Problem:** You have two partially overlapping datasets:

- Dataset A (4-class, \~3K): Healthy, Benign, OPMD, OCA, plus `Unknown` examples.
- Dataset B (binary, \~1.8–2K): Cancer vs Non-cancer.

**Goal:** Build a screening pipeline that maximizes sensitivity for high-risk lesions (OPMD & OCA) and provides interpretable outputs while using *all* available supervision.

**Value proposition for multi-head single-backbone approach:**

- **Data efficiency:** the binary dataset augments supervision for the risk decision while the 4-class dataset provides fine-grained supervision — both update the same shared representation.
- **Computational efficiency:** only one model to deploy (faster inference, easier maintenance).
- **Consistent predictions:** risk decisions and class labels are drawn from the same features, reducing contradictions.
- **Better generalization:** multi-task learning acts as a regulariser and improves robustness, especially with small datasets.

---

## 2. Core architecture (backbone + heads)

### 2.1 Backbone

Select a small/medium ImageNet-pretrained backbone depending on deployment target and compute budget:

- Mobile / mobile-friendly: `EfficientNet-Lite`, `MobileNetV3`, `ConvNeXt-Tiny`, `MobileViT`
- Server / more accurate: `EfficientNet-B4/B3`, `ResNet50`, `Swin-Tiny`, `ConvNeXt-Base`

Best practice: start with ImageNet weights, optionally use domain-specific pretraining (self-supervised on unlabeled oral images) if available.

### 2.2 Heads (task-specific)

- **Head A — Fine-grained multi-class (4-class + Unknown)**

  - Output units: `N_classes = 5` (Healthy, Benign, OPMD, OCA, Unknown)
  - Loss: `CrossEntropy` (CE)
  - Use dropout and a small MLP (e.g., `512 -> 256 -> N_classes`) with batchnorm/dropout.

- **Head B — Risk (binary)**

  - Output: single logit or two units (prefer `BCEWithLogits` on a single logit).
  - Label semantics: `1 = High-risk` (OPMD or OCA), `0 = Low-risk` (Healthy or Benign).
  - Loss: `BCEWithLogits` or `Binary CrossEntropy`.

- **Head C — Oral vs Not-Oral (unknown filter / pre-filter)**

  - Output: single logit (`Oral` vs `Not-Oral`).
  - Trains on `Unknown` vs `Oral` examples. Useful for rejecting non-oral uploads.

### 2.3 Why separate heads?

Heads let the network specialize to the label distribution of each task while the backbone captures shared visual features (texture, color, lesion borders, geometry). Each head is small and fast; only the backbone performs the expensive feature extraction once.

---

## 3. Dataset mapping & preparation

### 3.1 Mapping between label spaces

- From the 4-class dataset A: create derived labels for Heads B and C:

  - **Risk mapping (for Head B):**
    - `OCA` or `OPMD` → `High-risk` (1)
    - `Healthy` or `Benign` → `Low-risk` (0)
    - `Unknown` → *skip* mapping (no valid risk label)
  - **Oral mapping (for Head C):**
    - `Unknown` → `Not-Oral` (0)
    - All others → `Oral` (1)

- From binary dataset B:

  - Direct supervision for Head B: `Cancer` → `High-risk`, `Non-cancer` → `Low-risk`.
  - Only use Head B for these images (unless you have or can reliably map their oral-vs-not label).

### 3.2 Dataset splits

- Use stratified split by *risk* and *4-class* where possible. Example: 80/10/10 for train/val/test keeping class proportions.
- Keep a hold-out test set with images from a different distribution (different clinic/device) if possible.

### 3.3 Preprocessing

- Standardize image sizes (keep aspect, pad or crop to square depending on model).
- Normalize using ImageNet mean/std (if using ImageNet-pretrained backbone).
- Store label maps and dataset provenance (source, device, augmentation) in metadata.

---

## 4. Training pipeline (step-by-step + pseudocode)

### 4.1 High-level training strategy

1. Use a single optimizer updating backbone + heads.
2. Alternate or interleave batches from Dataset A (4-class) and Dataset B (binary) so the risk head sees both datasets.
3. Use **loss masking**: only compute losses for heads with valid labels for the current batch.
4. Use weighted sum of per-head losses. Optionally use learned task uncertainty weighting.
5. Monitor task-specific metrics on validation set.

### 4.2 Loss design

Let

- `L_A = CE(headA_logits, y_4class)` (skip or mask `Unknown` rows where appropriate for sub-components)
- `L_B = BCEWithLogits(headB_logit, y_risk)`
- `L_C = BCEWithLogits(headC_logit, y_oral)`

Total loss: `L = α * L_A + β * L_B + γ * L_C`

- Starter weights: `α = 1.0`, `β = 1.0`, `γ = 0.5`.
- Tune these on validation metrics. For screening use, bias towards higher recall on high-risk by increasing `β` or using class-weighting in `L_B`.

### 4.3 Batch composition and sampling

- Recommended: maintain two loaders and alternate steps or sample from a combined sampler that yields `('4class', batch)` or `('binary', batch)` events.
- Ensure the binary loader is not starved: you can upsample smaller dataset or control sampling frequency.

### 4.4 Pseudocode — training loop (detailed, not runnable code)

```text
# Components assumed defined:
# - loader_4class (yields batches: images, y_4class)
# - loader_binary (yields batches: images, y_binary)
# - model(images) -> (logits_A, logit_B, logit_C)
# - optimizer, scheduler
# - ce_loss, bce_loss functions

for epoch in range(1, N_epochs+1):
    model.train()
    for step in range(steps_per_epoch):
        # 1. sample a 4-class batch (if available) and train
        images_a, y_4class = next(loader_cycle_4class)
        logits_A, logit_B, logit_C = model(images_a)

        # Compute L_A
        L_A = ce_loss(logits_A, y_4class)

        # Compute mapped risk labels for valid rows
        mask_valid_for_risk = (y_4class != UNKNOWN)
        if mask_valid_for_risk.any():
            y_risk_from_a = ((y_4class == OPMD) | (y_4class == OCA)).float()
            L_B_from_a = bce_loss(logit_B[mask_valid_for_risk], y_risk_from_a[mask_valid_for_risk])
        else:
            L_B_from_a = 0.0

        # Compute oral/not-oral
        y_oral = (y_4class != UNKNOWN).float()
        L_C_from_a = bce_loss(logit_C, y_oral)

        # Total loss for this batch
        L_total_a = alpha * L_A + beta * L_B_from_a + gamma * L_C_from_a

        optimizer.zero_grad()
        L_total_a.backward()
        optimizer.step()

        # 2. sample a binary batch and train for risk head
        images_b, y_binary = next(loader_binary)
        _, logit_B_b, _ = model(images_b)
        L_B_from_b = bce_loss(logit_B_b, y_binary)

        optimizer.zero_grad()
        (beta * L_B_from_b).backward()
        optimizer.step()

    # end epoch: run validation, scheduler step, checkpoint
    val_metrics = run_validation(model, val_loaders)
    scheduler.step()
    save_checkpoint_if_improved(model, optimizer, val_metrics)
```

### 4.5 Validation and checkpointing

- Validate the 3 heads separately (and combined behavior):
  - Head A: per-class precision/recall/F1, confusion matrix.
  - Head B: ROC-AUC, precision/recall at several thresholds; emphasize **sensitivity (recall)** for high-risk.
  - Head C: precision/recall for Not-Oral detection.
- Save best checkpoint by a composite metric (e.g., prioritize Head B recall while keeping Head A F1 reasonable).

### 4.6 Suggested hyper-parameters (starter)

- Optimizer: `AdamW` with weight decay `1e-4`
- Backbone LR: `1e-4` (if fine-tuning); heads LR: `1e-3` (or 10× backbone)
- Batch size: 16–64 depending on memory; use gradient accumulation if needed.
- Epochs: 20–50 with early stopping
- Scheduler: cosine or ReduceLROnPlateau
- Augmentation: RandAugment, ColorJitter, RandomCrop, RandomRotate (small angle), Blur, JPEG compression

---

## 5. Inference & multi-image aggregation

### 5.1 Per-image scoring

- For each image compute: `p_oral = sigmoid(logit_C)`, `p_high_risk = sigmoid(logit_B)`, `p_4class = softmax(logits_A)`.
- If `p_oral < τ_oral` (suggested start `τ_oral = 0.8`) → mark as Not-Oral and request retake.

### 5.2 Aggregate across multiple photos (3–5 per user)

- **Unknown filtering:** if majority photos are Not-Oral → request retake.
- **Risk aggregation:** use **max(p\_high\_risk)** across photos (safer for screening; reduces missed positives). Option: use `1 - Π(1 - p_i)` to combine independent probabilities.
- **4-class aggregation:** average logits across valid oral photos then softmax the mean logits to get aggregated class probabilities. Alternatively use majority vote of per-photo argmaxes.
- **Decision logic:**
  - If aggregated `p_high_risk >= τ_risk` → label user `Refer` (urgent or non-urgent depending on p).
  - If aggregated 4-class `max_prob >= τ_class_display` (suggested `0.7`) → show the detailed label (e.g., `OPMD`) and provide recommended action.
  - Otherwise show `Indeterminate` with recommendation to consult clinician if symptomatic.

### 5.3 Example inference pseudocode

```text
results = []
for image in user_images:
    logits_A, logit_B, logit_C = model(image)
    p_oral = sigmoid(logit_C)
    if p_oral < tau_oral: continue  # skip non-oral
    p_high_risk = sigmoid(logit_B)
    p_4class = softmax(logits_A)
    results.append((p_high_risk, p_4class))

if len(results) == 0:
    return { 'status': 'retake_photos', 'reason': 'no oral photos detected' }

# aggregate risk
p_high_risk_agg = max(r for r, _ in results)
# aggregate 4-class
avg_logits = mean([logits_from_p(p) for _, p in results])
agg_4class = softmax(avg_logits)

# decision
if p_high_risk_agg >= tau_risk:
    return { 'action': 'refer', 'risk_score': p_high_risk_agg, 'class_probabilities': agg_4class }
elif max(agg_4class) >= tau_class_display:
    return { 'action': 'observe', 'predicted_class': argmax(agg_4class), 'confidence': max(agg_4class) }
else:
   
```
