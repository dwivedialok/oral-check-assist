# Phase 2: Model Architecture & Training - Step-by-Step Implementation

## 🎯 Overview
This document provides a step-by-step plan to upgrade your basic CNN model to a production-grade architecture optimized for **mobile deployment**. Each step is designed as a separate notebook cell for easy implementation and testing.

## 📱 Why MobileNetV3 for Mobile Apps?

### **MobileNetV3 vs EfficientNet for Mobile:**
| Feature | MobileNetV3Large | MobileNetV3Small | EfficientNet-B3 |
|---------|------------------|------------------|-----------------|
| **Model Size** | ~5.4 MB | ~2.9 MB | ~12 MB |
| **Parameters** | ~5.4M | ~2.9M | ~12M |
| **Inference Speed** | ⚡ Fast | ⚡⚡ Very Fast | 🐌 Slower |
| **Mobile Optimized** | ✅ Yes | ✅ Yes | ❌ No |
| **Accuracy** | 🎯 High | 🎯 Good | 🎯 Higher |
| **TFLite Support** | ✅ Excellent | ✅ Excellent | ⚠️ Good |

### **Key Advantages for Your Mobile App:**
- **Faster inference** on mobile devices (CPU/GPU)
- **Smaller app size** - better user experience
- **Lower battery consumption** - longer usage
- **Better TFLite optimization** - native mobile support
- **Proven mobile performance** - used in production apps

## 📋 Implementation Steps

### Step 1: Enhanced Model Architecture (Cell 1)
**Goal**: Replace basic CNN with MobileNetV3Large (mobile-optimized)
**Time**: 15 minutes
**Risk**: Low

```python
# Cell 1: Enhanced Model Architecture - MobileNetV3Large
from tensorflow.keras.applications import MobileNetV3Large
from tensorflow.keras import layers, Model

def build_mobilenetv3_model(input_shape=(224, 224, 3), num_classes=5, dropout_rate=0.3, variant='large'):
    """
    Build MobileNetV3 model with custom head for medical classification
    Optimized for mobile deployment with good accuracy/size trade-off
    """
    # Load pre-trained MobileNetV3
    if variant == 'large':
        base_model = MobileNetV3Large(
            weights='imagenet',
            include_top=False,
            input_shape=input_shape,
            alpha=1.0,  # Width multiplier
            minimalistic=False  # Use full MobileNetV3 features
        )
    else:  # small variant
        base_model = MobileNetV3Small(
            weights='imagenet',
            include_top=False,
            input_shape=input_shape,
            alpha=1.0,
            minimalistic=False
        )
    
    # Freeze base model initially
    base_model.trainable = False
    
    # Custom classification head optimized for mobile
    inputs = layers.Input(shape=input_shape)
    x = base_model(inputs, training=False)
    
    # Global average pooling
    x = layers.GlobalAveragePooling2D()(x)
    
    # Smaller dense layers for mobile optimization
    x = layers.Dense(256, activation='relu')(x)  # Reduced from 512
    x = layers.Dropout(dropout_rate)(x)
    x = layers.Dense(128, activation='relu')(x)  # Reduced from 256
    x = layers.Dropout(dropout_rate * 0.5)(x)
    
    # Output layer
    outputs = layers.Dense(num_classes, activation='softmax', dtype='float32')(x)
    
    model = Model(inputs, outputs)
    return model

# Test the new architecture
print("🏗️ Building MobileNetV3Large model...")
model = build_mobilenetv3_model((*config["image_size"], 3), len(config["class_names"]), variant='large')
model.summary()

# Count parameters
total_params = model.count_params()
print(f"📊 Total parameters: {total_params:,}")
print(f"📦 Model size estimate: {total_params * 4 / (1024*1024):.1f} MB")

# Also test small variant for comparison
print("\n🏗️ Building MobileNetV3Small model for comparison...")
model_small = build_mobilenetv3_model((*config["image_size"], 3), len(config["class_names"]), variant='small')
small_params = model_small.count_params()
print(f"📊 Small model parameters: {small_params:,}")
print(f"📦 Small model size estimate: {small_params * 4 / (1024*1024):.1f} MB")

print(f"\n📈 Size comparison:")
print(f"  MobileNetV3Large: {total_params * 4 / (1024*1024):.1f} MB")
print(f"  MobileNetV3Small: {small_params * 4 / (1024*1024):.1f} MB")
print(f"  Size reduction: {(1 - small_params/total_params)*100:.1f}%")
```

### Step 2: Focal Loss Implementation (Cell 2)
**Goal**: Implement Focal Loss for better handling of hard examples
**Time**: 10 minutes
**Risk**: Low

```python
# Cell 2: Focal Loss Implementation
import tensorflow as tf

def focal_loss(alpha=0.25, gamma=2.0):
    """
    Focal Loss implementation for handling class imbalance and hard examples
    """
    def focal_loss_fixed(y_true, y_pred):
        epsilon = tf.keras.backend.epsilon()
        y_pred = tf.clip_by_value(y_pred, epsilon, 1. - epsilon)
        
        # Convert sparse labels to one-hot
        y_true_one_hot = tf.one_hot(tf.cast(y_true, tf.int32), depth=tf.shape(y_pred)[-1])
        y_true_one_hot = tf.cast(y_true_one_hot, tf.float32)
        
        # Calculate focal loss
        alpha_t = y_true_one_hot * alpha + (1 - y_true_one_hot) * (1 - alpha)
        p_t = y_true_one_hot * y_pred + (1 - y_true_one_hot) * (1 - y_pred)
        focal_weight = alpha_t * tf.pow((1 - p_t), gamma)
        
        focal_loss = -focal_weight * tf.math.log(p_t)
        return tf.reduce_mean(focal_loss)
    
    return focal_loss_fixed

# Test focal loss
print("🎯 Implementing Focal Loss...")
focal_loss_fn = focal_loss(alpha=0.25, gamma=2.0)

# Compile model with focal loss
model.compile(
    optimizer=tf.keras.optimizers.legacy.Adam(learning_rate=1e-3),
    loss=focal_loss_fn,
    metrics=['accuracy']
)

print("✅ Model compiled with Focal Loss")
print("📝 Focal Loss parameters: alpha=0.25, gamma=2.0")
```

### Step 3: Multi-Stage Training Strategy (Cell 3)
**Goal**: Implement progressive training (freeze → unfreeze → fine-tune)
**Time**: 20 minutes
**Risk**: Medium

```python
# Cell 3: Multi-Stage Training Strategy
import time
from tensorflow.keras.callbacks import EarlyStopping, ReduceLROnPlateau, ModelCheckpoint

def create_callbacks(stage_name, patience=5):
    """Create callbacks for each training stage"""
    callbacks = [
        EarlyStopping(
            monitor='val_loss',
            patience=patience,
            restore_best_weights=True,
            verbose=1
        ),
        ReduceLROnPlateau(
            monitor='val_loss',
            factor=0.5,
            patience=3,
            min_lr=1e-7,
            verbose=1
        ),
        ModelCheckpoint(
            filepath=os.path.join(config["output_root"], f"model_{stage_name}.h5"),
            monitor='val_accuracy',
            save_best_only=True,
            verbose=1
        )
    ]
    return callbacks

def train_stage_1(model, train_ds, val_ds, epochs=10):
    """Stage 1: Train only the custom head (base model frozen)"""
    print("🚀 Stage 1: Training custom head (base model frozen)")
    print("=" * 60)
    
    # Ensure base model is frozen
    for layer in model.layers:
        if 'efficientnet' in layer.name:
            layer.trainable = False
    
    # Recompile with lower learning rate for head training
    model.compile(
        optimizer=tf.keras.optimizers.legacy.Adam(learning_rate=1e-3),
        loss=focal_loss_fn,
        metrics=['accuracy']
    )
    
    callbacks = create_callbacks("stage1")
    
    start_time = time.time()
    history = model.fit(
        train_ds,
        validation_data=val_ds,
        epochs=epochs,
        callbacks=callbacks,
        verbose=1,
        class_weight=class_weights if class_weights else None
    )
    
    training_time = time.time() - start_time
    print(f"⏱️ Stage 1 completed in {training_time:.1f} seconds")
    
    return history

# Start with Stage 1
print("🎯 Starting Multi-Stage Training...")
stage1_history = train_stage_1(model, train_ds, val_ds, epochs=5)
```

### Step 4: Stage 2 - Unfreeze and Fine-tune (Cell 4)
**Goal**: Unfreeze base model and fine-tune with lower learning rate
**Time**: 15 minutes
**Risk**: Medium

```python
# Cell 4: Stage 2 - Unfreeze and Fine-tune
def train_stage_2(model, train_ds, val_ds, epochs=15):
    """Stage 2: Unfreeze base model and fine-tune"""
    print("🚀 Stage 2: Fine-tuning entire model")
    print("=" * 60)
    
    # Unfreeze base model
    for layer in model.layers:
        if 'efficientnet' in layer.name:
            layer.trainable = True
    
    # Recompile with lower learning rate for fine-tuning
    model.compile(
        optimizer=tf.keras.optimizers.legacy.Adam(learning_rate=1e-4),
        loss=focal_loss_fn,
        metrics=['accuracy']
    )
    
    callbacks = create_callbacks("stage2")
    
    start_time = time.time()
    history = model.fit(
        train_ds,
        validation_data=val_ds,
        epochs=epochs,
        callbacks=callbacks,
        verbose=1,
        class_weight=class_weights if class_weights else None
    )
    
    training_time = time.time() - start_time
    print(f"⏱️ Stage 2 completed in {training_time:.1f} seconds")
    
    return history

# Continue with Stage 2
stage2_history = train_stage_2(model, train_ds, val_ds, epochs=10)
```

### Step 5: Model Evaluation and Comparison (Cell 5)
**Goal**: Evaluate the improved model and compare with basic model
**Time**: 10 minutes
**Risk**: Low

```python
# Cell 5: Model Evaluation and Comparison
def evaluate_model_comprehensive(model, test_ds, model_name="EfficientNet"):
    """Comprehensive model evaluation"""
    print(f"📊 Evaluating {model_name} model...")
    print("=" * 60)
    
    # Basic evaluation
    test_loss, test_accuracy = model.evaluate(test_ds, verbose=0)
    print(f"🎯 Test Accuracy: {test_accuracy:.4f} ({test_accuracy*100:.2f}%)")
    print(f"📉 Test Loss: {test_loss:.4f}")
    
    # Per-class predictions
    y_true, y_pred = [], []
    y_pred_proba = []
    
    for batch_x, batch_y in test_ds:
        predictions = model.predict(batch_x, verbose=0)
        y_true.extend(batch_y.numpy())
        y_pred.extend(np.argmax(predictions, axis=1))
        y_pred_proba.extend(predictions)
    
    y_true = np.array(y_true)
    y_pred = np.array(y_pred)
    y_pred_proba = np.array(y_pred_proba)
    
    # Per-class accuracy
    print("\n📈 Per-class accuracy:")
    for i, class_name in enumerate(config["class_names"]):
        class_mask = (y_true == i)
        if np.sum(class_mask) > 0:
            class_accuracy = np.mean(y_pred[class_mask] == i)
            class_count = np.sum(class_mask)
            print(f"  {class_name:8}: {class_accuracy:.3f} ({class_count} samples)")
    
    # Confusion matrix
    from sklearn.metrics import confusion_matrix
    cm = confusion_matrix(y_true, y_pred)
    
    print(f"\n🔍 Confusion Matrix:")
    print("     ", end="")
    for name in config["class_names"]:
        print(f"{name:8}", end="")
    print()
    
    for i, name in enumerate(config["class_names"]):
        print(f"{name:8}", end="")
        for j in range(len(config["class_names"])):
            print(f"{cm[i,j]:8}", end="")
        print()
    
    return {
        'accuracy': test_accuracy,
        'loss': test_loss,
        'y_true': y_true,
        'y_pred': y_pred,
        'y_pred_proba': y_pred_proba,
        'confusion_matrix': cm
    }

# Evaluate the improved model
efficientnet_results = evaluate_model_comprehensive(model, test_ds, "EfficientNet-B3")

# Compare with basic model if available
print("\n🔄 Comparison with Basic Model:")
print("=" * 60)
if 'eval_results' in locals():
    basic_accuracy = eval_results[1]  # Assuming eval_results[1] is accuracy
    print(f"Basic CNN Accuracy: {basic_accuracy:.4f} ({basic_accuracy*100:.2f}%)")
    print(f"EfficientNet Accuracy: {efficientnet_results['accuracy']:.4f} ({efficientnet_results['accuracy']*100:.2f}%)")
    improvement = efficientnet_results['accuracy'] - basic_accuracy
    print(f"Improvement: {improvement:+.4f} ({improvement*100:+.2f}%)")
```

### Step 6: Hyperparameter Optimization Setup (Cell 6)
**Goal**: Set up hyperparameter optimization framework
**Time**: 15 minutes
**Risk**: Low

```python
# Cell 6: Hyperparameter Optimization Setup
import optuna
from optuna.integration import TFKerasPruningCallback

def objective(trial):
    """Objective function for hyperparameter optimization"""
    
    # Suggest hyperparameters
    learning_rate = trial.suggest_float('learning_rate', 1e-5, 1e-2, log=True)
    dropout_rate = trial.suggest_float('dropout_rate', 0.1, 0.5)
    dense_units = trial.suggest_categorical('dense_units', [256, 512, 1024])
    focal_alpha = trial.suggest_float('focal_alpha', 0.1, 0.5)
    focal_gamma = trial.suggest_float('focal_gamma', 1.0, 3.0)
    
    # Build model with suggested hyperparameters
    model = build_mobilenetv3_model(
        input_shape=(*config["image_size"], 3),
        num_classes=len(config["class_names"]),
        dropout_rate=dropout_rate,
        variant='large'  # or 'small' for smaller model
    )
    
    # Custom head with suggested dense units
    # (This would require modifying the build_efficientnet_model function)
    
    # Compile with suggested hyperparameters
    focal_loss_fn = focal_loss(alpha=focal_alpha, gamma=focal_gamma)
    model.compile(
        optimizer=tf.keras.optimizers.legacy.Adam(learning_rate=learning_rate),
        loss=focal_loss_fn,
        metrics=['accuracy']
    )
    
    # Train for a few epochs
    history = model.fit(
        train_ds,
        validation_data=val_ds,
        epochs=3,  # Reduced for hyperparameter search
        verbose=0,
        class_weight=class_weights if class_weights else None
    )
    
    # Return validation accuracy
    return max(history.history['val_accuracy'])

def run_hyperparameter_optimization(n_trials=10):
    """Run hyperparameter optimization"""
    print("🔍 Starting Hyperparameter Optimization...")
    print("=" * 60)
    
    # Create study
    study = optuna.create_study(
        direction='maximize',
        pruner=optuna.pruners.MedianPruner(n_startup_trials=2, n_warmup_steps=1)
    )
    
    # Run optimization
    study.optimize(objective, n_trials=n_trials)
    
    print(f"\n🎯 Best hyperparameters:")
    for key, value in study.best_params.items():
        print(f"  {key}: {value}")
    
    print(f"\n📊 Best validation accuracy: {study.best_value:.4f}")
    
    return study

# Run hyperparameter optimization (optional - can be time-consuming)
# Uncomment to run:
# study = run_hyperparameter_optimization(n_trials=5)
```

### Step 7: Cross-Validation Framework (Cell 7)
**Goal**: Implement cross-validation for robust evaluation
**Time**: 20 minutes
**Risk**: Medium

```python
# Cell 7: Cross-Validation Framework
from sklearn.model_selection import StratifiedKFold
import tempfile

def cross_validate_model(data_dir, n_folds=3, epochs_per_fold=5):
    """Perform k-fold cross-validation"""
    print(f"🔄 Starting {n_folds}-fold Cross-Validation...")
    print("=" * 60)
    
    # Load all data for cross-validation
    full_dataset = tf.keras.preprocessing.image_dataset_from_directory(
        os.path.join(data_dir, 'train'),
        labels='inferred',
        label_mode='int',
        image_size=config["image_size"],
        batch_size=config["batch_size"],
        shuffle=False,
        seed=SEED
    )
    
    # Get labels for stratification
    labels = []
    for _, batch_labels in full_dataset:
        labels.extend(batch_labels.numpy())
    labels = np.array(labels)
    
    # Create stratified k-fold
    skf = StratifiedKFold(n_splits=n_folds, shuffle=True, random_state=SEED)
    
    fold_scores = []
    fold_histories = []
    
    for fold, (train_idx, val_idx) in enumerate(skf.split(np.zeros(len(labels)), labels)):
        print(f"\n📁 Fold {fold + 1}/{n_folds}")
        print("-" * 40)
        
        # Create fold datasets
        train_fold = full_dataset.skip(val_idx[0]).take(len(train_idx))
        val_fold = full_dataset.skip(train_idx[0]).take(len(val_idx))
        
        # Build fresh model for each fold
        model = build_mobilenetv3_model(
            input_shape=(*config["image_size"], 3),
            num_classes=len(config["class_names"]),
            variant='large'
        )
        
        # Compile model
        model.compile(
            optimizer=tf.keras.optimizers.legacy.Adam(learning_rate=1e-3),
            loss=focal_loss_fn,
            metrics=['accuracy']
        )
        
        # Train model
        history = model.fit(
            train_fold,
            validation_data=val_fold,
            epochs=epochs_per_fold,
            verbose=0,
            class_weight=class_weights if class_weights else None
        )
        
        # Evaluate
        val_loss, val_accuracy = model.evaluate(val_fold, verbose=0)
        fold_scores.append(val_accuracy)
        fold_histories.append(history)
        
        print(f"  Validation Accuracy: {val_accuracy:.4f}")
        print(f"  Validation Loss: {val_loss:.4f}")
    
    # Calculate statistics
    mean_score = np.mean(fold_scores)
    std_score = np.std(fold_scores)
    
    print(f"\n📊 Cross-Validation Results:")
    print(f"  Mean Accuracy: {mean_score:.4f} ± {std_score:.4f}")
    print(f"  Individual Scores: {[f'{score:.4f}' for score in fold_scores]}")
    
    return {
        'mean_score': mean_score,
        'std_score': std_score,
        'fold_scores': fold_scores,
        'fold_histories': fold_histories
    }

# Run cross-validation (optional - can be time-consuming)
# Uncomment to run:
# cv_results = cross_validate_model(config["data_dir"], n_folds=3, epochs_per_fold=3)
```

### Step 8: Model Saving and TFLite Conversion (Cell 8)
**Goal**: Save the improved model and convert to TFLite
**Time**: 10 minutes
**Risk**: Low

```python
# Cell 8: Model Saving and TFLite Conversion
def save_production_model(model, model_name="efficientnet_production"):
    """Save model in multiple formats for production"""
    print("💾 Saving Production Model...")
    print("=" * 60)
    
    # Create output directory
    output_dir = os.path.join(config["output_root"], "production_model")
    os.makedirs(output_dir, exist_ok=True)
    
    # Save Keras model
    keras_path = os.path.join(output_dir, f"{model_name}.h5")
    model.save(keras_path)
    print(f"✅ Keras model saved: {keras_path}")
    
    # Save SavedModel format
    savedmodel_path = os.path.join(output_dir, f"{model_name}_savedmodel")
    model.save(savedmodel_path, save_format='tf')
    print(f"✅ SavedModel saved: {savedmodel_path}")
    
    # Convert to TFLite
    print("\n🔄 Converting to TFLite...")
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    
    # Optimizations
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    converter.target_spec.supported_types = [tf.float16]
    
    try:
        tflite_model = converter.convert()
        tflite_path = os.path.join(output_dir, f"{model_name}.tflite")
        
        with open(tflite_path, 'wb') as f:
            f.write(tflite_model)
        
        print(f"✅ TFLite model saved: {tflite_path}")
        print(f"📦 TFLite model size: {len(tflite_model) / (1024*1024):.2f} MB")
        
        return {
            'keras_path': keras_path,
            'savedmodel_path': savedmodel_path,
            'tflite_path': tflite_path,
            'tflite_size_mb': len(tflite_model) / (1024*1024)
        }
        
    except Exception as e:
        print(f"❌ TFLite conversion failed: {e}")
        return None

# Save the production model
model_paths = save_production_model(model, "efficientnet_phase2")

# Update labels.txt
labels_path = os.path.join(config["output_root"], "production_model", "labels.txt")
with open(labels_path, 'w') as f:
    for class_name in config["class_names"]:
        f.write(f"{class_name}\n")

print(f"✅ Labels file updated: {labels_path}")
```

## 🎯 Implementation Order

1. **Start with Step 1** (Enhanced Architecture) - Test the new model builds correctly
2. **Add Step 2** (Focal Loss) - Verify loss function works
3. **Implement Step 3** (Stage 1 Training) - Train the head first
4. **Continue with Step 4** (Stage 2 Training) - Fine-tune the entire model
5. **Evaluate with Step 5** - Compare with your basic model
6. **Optional Steps 6-8** - Add hyperparameter optimization, cross-validation, and production saving

## ⚠️ Important Notes

- **Start small**: Use fewer epochs initially to test the pipeline
- **Monitor memory**: EfficientNet uses more memory than basic CNN
- **Save checkpoints**: Use the ModelCheckpoint callback to save best models
- **Compare results**: Always compare with your basic model to ensure improvement
- **Gradual implementation**: Implement one step at a time and test before moving to the next

## 🚀 Expected Improvements

- **Accuracy**: 15-25% improvement over basic CNN
- **OCA Detection**: Better sensitivity for rare cancer cases
- **Mobile Performance**: 
  - **Inference time**: <50ms on modern mobile devices
  - **Model size**: 2.9-5.4 MB (vs 12+ MB for EfficientNet)
  - **Battery efficiency**: 30-50% better than EfficientNet
- **Robustness**: More stable training with focal loss
- **Production Ready**: Optimized for mobile deployment with TFLite

Would you like me to help you implement any specific step, or shall we start with Step 1 (Enhanced Architecture)?
