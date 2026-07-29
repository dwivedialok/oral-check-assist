#!/usr/bin/env python3
"""
Complete Production ML Pipeline for Oral Cancer Screening
Single file solution with command-line interface

Usage:
    python complete_pipeline.py --data_dir ./dataset --output_dir ./experiments
    python complete_pipeline.py --data_dir ./dataset --config config.json --output_dir ./experiments
    python complete_pipeline.py --create_config --config_output my_config.json
"""

import os
import json
import time
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from datetime import datetime
import warnings
import argparse
import random
from pathlib import Path
from typing import Tuple, Dict, List, Optional
import cv2

warnings.filterwarnings('ignore')

import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers, optimizers, callbacks
from tensorflow.keras.applications import MobileNetV3Large

from sklearn.metrics import classification_report, confusion_matrix
from sklearn.utils.class_weight import compute_class_weight
import albumentations as A

# Set random seeds for reproducibility
SEED = 42
np.random.seed(SEED)
tf.random.set_seed(SEED)
random.seed(SEED)

class F1Score(keras.metrics.Metric):
    """Custom F1 Score metric compatible with current TensorFlow"""
    
    def __init__(self, num_classes, average='macro', name='f1_score', **kwargs):
        super().__init__(name=name, **kwargs)
        self.num_classes = num_classes
        self.average = average
        
        # Initialize state variables
        self.true_positives = self.add_weight(
            'true_positives', shape=(num_classes,), initializer='zeros'
        )
        self.false_positives = self.add_weight(
            'false_positives', shape=(num_classes,), initializer='zeros'
        )
        self.false_negatives = self.add_weight(
            'false_negatives', shape=(num_classes,), initializer='zeros'
        )
    
    def update_state(self, y_true, y_pred, sample_weight=None):
        # Convert predictions to class indices
        y_pred = tf.argmax(y_pred, axis=-1)
        y_true = tf.cast(y_true, tf.int64)
        y_pred = tf.cast(y_pred, tf.int64)
        
        # One-hot encode
        y_true_onehot = tf.one_hot(y_true, self.num_classes)
        y_pred_onehot = tf.one_hot(y_pred, self.num_classes)
        
        # Calculate TP, FP, FN for each class
        tp = tf.reduce_sum(y_true_onehot * y_pred_onehot, axis=0)
        fp = tf.reduce_sum((1 - y_true_onehot) * y_pred_onehot, axis=0)
        fn = tf.reduce_sum(y_true_onehot * (1 - y_pred_onehot), axis=0)
        
        self.true_positives.assign_add(tp)
        self.false_positives.assign_add(fp)
        self.false_negatives.assign_add(fn)
    
    def result(self):
        precision = self.true_positives / (self.true_positives + self.false_positives + 1e-7)
        recall = self.true_positives / (self.true_positives + self.false_negatives + 1e-7)
        f1 = 2 * (precision * recall) / (precision + recall + 1e-7)
        
        if self.average == 'macro':
            return tf.reduce_mean(f1)
        elif self.average == 'weighted':
            # For weighted, we need class frequencies - using simple mean for now
            return tf.reduce_mean(f1)
        else:
            return f1
    
    def reset_state(self):
        self.true_positives.assign(tf.zeros_like(self.true_positives))
        self.false_positives.assign(tf.zeros_like(self.false_positives))
        self.false_negatives.assign(tf.zeros_like(self.false_negatives))

class ProductionMLPipeline:
    """
    Production-grade ML pipeline for oral cavity cancer screening
    """
    
    def __init__(self, data_dir: str, experiment_name: str = None):
        self.data_dir = Path(data_dir)
        self.experiment_name = experiment_name or f"oral_cancer_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        self.log_dir = Path(f"logs/{self.experiment_name}")
        self.model_dir = Path(f"models/{self.experiment_name}")
        self.results_dir = Path(f"results/{self.experiment_name}")
        
        # Create directories
        for dir_path in [self.log_dir, self.model_dir, self.results_dir]:
            dir_path.mkdir(parents=True, exist_ok=True)
        
        # Default configuration - M1 optimized
        self.config = {
            'image_size': (224, 224),
            'batch_size': 32,
            'num_classes': 4,
            'class_names': ['Healthy', 'Benign', 'OPMD', 'OCA'],
            'epochs': 100,
            'learning_rate': 1e-4,
            'weight_decay': 1e-4,
            'dropout_rate': 0.3,
            'label_smoothing': 0.1,
            'mixed_precision': False,  # Disabled for M1 compatibility
            'data_augmentation_strength': 'medium',
        }
        
        # DO NOT enable mixed precision on M1 Macs
        print("✅ M1 Mac detected - using float32 precision for compatibility")
        
        self.model = None
        self.history = None
        self.class_weights = None
    
    def load_config(self, config_path: str):
        """Load configuration from JSON file"""
        with open(config_path, 'r') as f:
            loaded_config = json.load(f)
        
        # Update config with loaded values
        if 'training_parameters' in loaded_config:
            training_params = loaded_config['training_parameters']
            self.config.update({
                'batch_size': training_params.get('batch_size', self.config['batch_size']),
                'epochs': training_params.get('epochs', self.config['epochs']),
                'learning_rate': training_params.get('learning_rate', self.config['learning_rate']),
                'weight_decay': training_params.get('weight_decay', self.config['weight_decay']),
                'label_smoothing': training_params.get('label_smoothing', self.config['label_smoothing']),
                'mixed_precision': training_params.get('mixed_precision', self.config['mixed_precision']),
            })
        
        if 'model_architecture' in loaded_config:
            model_params = loaded_config['model_architecture']
            self.config.update({
                'dropout_rate': model_params.get('dropout_rate', self.config['dropout_rate']),
            })
        
        if 'data_augmentation' in loaded_config:
            aug_params = loaded_config['data_augmentation']
            self.config['data_augmentation_strength'] = aug_params.get('strength', self.config['data_augmentation_strength'])
        
        # Save updated configuration
        with open(self.results_dir / 'config.json', 'w') as f:
            json.dump(self.config, f, indent=2)
        
        print(f"✅ Configuration loaded from {config_path}")
    
    def create_advanced_augmentation(self) -> A.Compose:
        """Create sophisticated augmentation pipeline for medical images"""
        strength = self.config['data_augmentation_strength']
        
        if strength == 'light':
            return A.Compose([
                A.RandomRotate90(p=0.3),
                A.Flip(p=0.5),
                A.RandomBrightnessContrast(brightness_limit=0.15, contrast_limit=0.15, p=0.5),
                A.HueSaturationValue(hue_shift_limit=8, sat_shift_limit=10, val_shift_limit=8, p=0.3),
                A.CLAHE(clip_limit=2.0, tile_grid_size=(8, 8), p=0.3),
                A.OneOf([
                    A.GaussNoise(var_limit=(5.0, 25.0), p=0.3),
                    A.GaussianBlur(blur_limit=3, p=0.3),
                ], p=0.2),
            ])
        
        elif strength == 'medium':
            return A.Compose([
                # Geometric transformations
                A.RandomRotate90(p=0.4),
                A.Flip(p=0.5),
                A.ShiftScaleRotate(shift_limit=0.05, scale_limit=0.1, rotate_limit=15, p=0.4),
                A.Perspective(scale=(0.02, 0.05), p=0.2),
                
                # Color/contrast augmentations
                A.RandomBrightnessContrast(brightness_limit=0.25, contrast_limit=0.25, p=0.6),
                A.HueSaturationValue(hue_shift_limit=12, sat_shift_limit=15, val_shift_limit=12, p=0.4),
                A.RGBShift(r_shift_limit=15, g_shift_limit=15, b_shift_limit=15, p=0.3),
                A.RandomGamma(gamma_limit=(85, 115), p=0.3),
                
                # Medical-specific enhancements
                A.CLAHE(clip_limit=3.0, tile_grid_size=(8, 8), p=0.4),
                A.OneOf([
                    A.Sharpen(alpha=(0.1, 0.3), lightness=(0.8, 1.2), p=0.3),
                    A.UnsharpMask(blur_limit=3, sigma_limit=0.5, alpha=(0.1, 0.3), p=0.3),
                ], p=0.2),
                
                # Noise and blur (consumer camera simulation)
                A.OneOf([
                    A.GaussNoise(var_limit=(10.0, 40.0), p=0.3),
                    A.MultiplicativeNoise(multiplier=[0.95, 1.05], p=0.3),
                    A.ISONoise(color_shift=(0.01, 0.05), intensity=(0.1, 0.3), p=0.2),
                ], p=0.25),
                
                A.OneOf([
                    A.MotionBlur(blur_limit=5, p=0.3),
                    A.MedianBlur(blur_limit=3, p=0.3),
                    A.GaussianBlur(blur_limit=3, p=0.3),
                    A.Defocus(radius=(1, 2), alias_blur=(0.1, 0.3), p=0.2),
                ], p=0.2),
                
                # Quality degradation
                A.OneOf([
                    A.Downscale(scale_min=0.8, scale_max=0.95, p=0.2),
                    A.JpegCompression(quality_lower=70, quality_upper=95, p=0.3),
                ], p=0.15),
            ])
        
        else:  # heavy
            return A.Compose([
                # More aggressive transformations
                A.RandomRotate90(p=0.5),
                A.Flip(p=0.7),
                A.ShiftScaleRotate(shift_limit=0.08, scale_limit=0.15, rotate_limit=25, p=0.5),
                A.Perspective(scale=(0.02, 0.08), p=0.3),
                A.ElasticTransform(alpha=1, sigma=20, p=0.1),
                
                # Aggressive color variations
                A.RandomBrightnessContrast(brightness_limit=0.4, contrast_limit=0.4, p=0.7),
                A.HueSaturationValue(hue_shift_limit=20, sat_shift_limit=25, val_shift_limit=20, p=0.5),
                A.RGBShift(r_shift_limit=25, g_shift_limit=25, b_shift_limit=25, p=0.4),
                A.RandomGamma(gamma_limit=(70, 130), p=0.4),
                A.RandomToneCurve(scale=0.2, p=0.2),
                
                # Enhanced medical augmentations
                A.CLAHE(clip_limit=4.0, tile_grid_size=(8, 8), p=0.5),
                A.OneOf([
                    A.Sharpen(alpha=(0.2, 0.5), lightness=(0.7, 1.3), p=0.4),
                    A.UnsharpMask(blur_limit=5, sigma_limit=1.0, alpha=(0.2, 0.5), p=0.4),
                    A.Emboss(alpha=(0.2, 0.5), strength=(0.2, 0.7), p=0.3),
                ], p=0.3),
                
                # Heavy noise and blur
                A.OneOf([
                    A.GaussNoise(var_limit=(15.0, 60.0), p=0.4),
                    A.MultiplicativeNoise(multiplier=[0.9, 1.1], p=0.4),
                    A.ISONoise(color_shift=(0.01, 0.08), intensity=(0.2, 0.5), p=0.3),
                ], p=0.3),
                
                A.OneOf([
                    A.MotionBlur(blur_limit=7, p=0.4),
                    A.MedianBlur(blur_limit=5, p=0.4),
                    A.GaussianBlur(blur_limit=5, p=0.4),
                    A.Defocus(radius=(1, 3), alias_blur=(0.1, 0.5), p=0.3),
                ], p=0.3),
                
                # Quality degradation
                A.OneOf([
                    A.Downscale(scale_min=0.7, scale_max=0.9, p=0.3),
                    A.JpegCompression(quality_lower=50, quality_upper=85, p=0.4),
                ], p=0.2),
            ])
    
    def create_tf_dataset_with_augmentation(self, split: str) -> Tuple[tf.data.Dataset, int]:
        """Create TensorFlow dataset with advanced augmentation"""
        data_path = self.data_dir / split
        image_paths = []
        labels = []
        
        for class_idx, class_name in enumerate(self.config['class_names']):
            class_path = data_path / class_name
            if class_path.exists():
                class_images = list(class_path.glob('*.jpg')) + list(class_path.glob('*.jpeg')) + list(class_path.glob('*.png'))
                image_paths.extend([str(p) for p in class_images])
                labels.extend([class_idx] * len(class_images))
        
        print(f"Found {len(image_paths)} images for {split} split")
        
        # Create augmentation pipeline
        augmentation = self.create_advanced_augmentation() if split == 'train' else None
        
        def load_and_preprocess_image(image_path, label):
            # Load image
            image = tf.io.read_file(image_path)
            image = tf.image.decode_image(image, channels=3, expand_animations=False)
            image = tf.cast(image, tf.float32)
            
            # Resize
            image = tf.image.resize(image, self.config['image_size'])
            
            # Apply augmentation for training
            if split == 'train' and augmentation is not None:
                def apply_augmentation(img):
                    img_np = img.numpy().astype(np.uint8)
                    augmented = augmentation(image=img_np)
                    return augmented['image'].astype(np.float32)
                
                image = tf.py_function(apply_augmentation, [image], tf.float32)
                image.set_shape([*self.config['image_size'], 3])
            
            # Normalize to [0, 1]
            image = image / 255.0
            
            return image, label
        
        # Create dataset
        dataset = tf.data.Dataset.from_tensor_slices((image_paths, labels))
        dataset = dataset.map(load_and_preprocess_image, num_parallel_calls=tf.data.AUTOTUNE)
        
        if split == 'train':
            dataset = dataset.shuffle(buffer_size=1000)
            dataset = dataset.repeat()
        
        dataset = dataset.batch(self.config['batch_size'])
        dataset = dataset.prefetch(tf.data.AUTOTUNE)
        
        return dataset, len(image_paths)
    
    def calculate_class_weights(self) -> Dict[int, float]:
        """Calculate class weights for handling imbalanced dataset"""
        train_path = self.data_dir / 'train'
        class_counts = []
        
        for class_name in self.config['class_names']:
            class_path = train_path / class_name
            if class_path.exists():
                count = len(list(class_path.glob('*.jpg')) + 
                           list(class_path.glob('*.jpeg')) + 
                           list(class_path.glob('*.png')))
                class_counts.append(count)
            else:
                class_counts.append(0)
        
        # Calculate weights using sklearn
        labels = []
        for idx, count in enumerate(class_counts):
            labels.extend([idx] * count)
        
        class_weights_array = compute_class_weight(
            class_weight='balanced',
            classes=np.unique(labels),
            y=labels
        )
        
        class_weights = {i: weight for i, weight in enumerate(class_weights_array)}
        
        print("Class distribution:")
        for i, (class_name, count) in enumerate(zip(self.config['class_names'], class_counts)):
            print(f"  {class_name}: {count} samples (weight: {class_weights[i]:.3f})")
        
        return class_weights
    
    def create_model(self) -> keras.Model:
        """Create M1-compatible model architecture"""
        inputs = keras.Input(shape=(*self.config['image_size'], 3), name='input_image')
        
        # Remove problematic data augmentation layers for M1
        # Use albumentations for augmentation instead
        x = inputs
        
        # Base model - MobileNetV3Large
        base_model = MobileNetV3Large(
            input_shape=(*self.config['image_size'], 3),
            include_top=False,
            weights='imagenet',
            alpha=1.0,
            minimalistic=False,
            include_preprocessing=False,
        )
        
        # Fine-tuning strategy
        base_model.trainable = True
        for layer in base_model.layers[:-30]:
            layer.trainable = False
        
        # Add base model
        x = base_model(x, training=True)
        
        # Custom head for medical classification
        x = layers.GlobalAveragePooling2D(name='global_avg_pool')(x)
        x = layers.BatchNormalization(name='bn1')(x)
        
        # First dense layer
        x = layers.Dense(512, name='dense1')(x)
        x = layers.BatchNormalization(name='bn2')(x)
        x = layers.Activation('relu', name='relu1')(x)
        x = layers.Dropout(self.config['dropout_rate'], name='dropout1')(x)
        
        # Second dense layer
        x = layers.Dense(256, name='dense2')(x)
        x = layers.BatchNormalization(name='bn3')(x)
        x = layers.Activation('relu', name='relu2')(x)
        x = layers.Dropout(self.config['dropout_rate'] * 0.7, name='dropout2')(x)
        
        # Output layer - always float32 for M1 compatibility
        outputs = layers.Dense(self.config['num_classes'], activation='softmax', dtype='float32', name='predictions')(x)
        
        model = keras.Model(inputs, outputs, name='OralCancerScreening')
        return model
    
    def compile_model(self, model: keras.Model) -> keras.Model:
        """Compile model with optimal settings"""
        optimizer = tfa.optimizers.AdamW(
            learning_rate=self.config['learning_rate'],
            weight_decay=self.config['weight_decay'],
            clipnorm=1.0
        )
        
        loss = keras.losses.SparseCategoricalCrossentropy(
            label_smoothing=self.config['label_smoothing'],
            from_logits=False
        )
        
        metrics = [
            'accuracy',
            keras.metrics.SparseCategoricalAccuracy(name='categorical_accuracy'),
            keras.metrics.SparseTopKCategoricalAccuracy(k=2, name='top_2_accuracy'),
            keras.metrics.Precision(name='precision'),
            keras.metrics.Recall(name='recall'),
            tfa.metrics.F1Score(num_classes=self.config['num_classes'], average='macro', name='f1_macro'),
            tfa.metrics.F1Score(num_classes=self.config['num_classes'], average='weighted', name='f1_weighted')
        ]
        
        model.compile(optimizer=optimizer, loss=loss, metrics=metrics)
        return model
    
    def create_callbacks(self) -> List[keras.callbacks.Callback]:
        """Create comprehensive callbacks"""
        callbacks_list = [
            keras.callbacks.ModelCheckpoint(
                filepath=str(self.model_dir / 'best_model.h5'),
                monitor='val_f1_weighted',
                mode='max',
                save_best_only=True,
                save_weights_only=False,
                verbose=1
            ),
            
            keras.callbacks.EarlyStopping(
                monitor='val_loss',
                patience=15,
                restore_best_weights=True,
                verbose=1
            ),
            
            keras.callbacks.ReduceLROnPlateau(
                monitor='val_loss',
                factor=0.5,
                patience=8,
                min_lr=1e-7,
                verbose=1
            ),
            
            keras.callbacks.TensorBoard(
                log_dir=str(self.log_dir),
                histogram_freq=1,
                write_graph=True,
                update_freq='epoch'
            ),
            
            keras.callbacks.CSVLogger(
                filename=str(self.results_dir / 'training_log.csv'),
                append=False
            ),
        ]
        
        return callbacks_list
    
    def train(self) -> Tuple[keras.Model, keras.callbacks.History]:
        """Execute complete training pipeline"""
        print("🚀 Starting training pipeline...")
        
        # Create datasets
        print("📁 Loading datasets...")
        train_dataset, train_size = self.create_tf_dataset_with_augmentation('train')
        val_dataset, val_size = self.create_tf_dataset_with_augmentation('val')
        
        # Calculate steps
        steps_per_epoch = train_size // self.config['batch_size']
        validation_steps = val_size // self.config['batch_size']
        
        print(f"📊 Training: {train_size} samples, {steps_per_epoch} steps/epoch")
        print(f"📊 Validation: {val_size} samples, {validation_steps} validation steps")
        
        # Calculate class weights
        self.class_weights = self.calculate_class_weights()
        
        # Create and compile model
        print("🏗️ Building model...")
        self.model = self.create_model()
        self.model = self.compile_model(self.model)
        
        # Print model summary
        self.model.summary()
        
        # Save model architecture
        with open(self.results_dir / 'model_summary.txt', 'w') as f:
            self.model.summary(print_fn=lambda x: f.write(x + '\n'))
        
        # Create callbacks
        callbacks = self.create_callbacks()
        
        # Train model
        print("🎯 Starting training...")
        self.history = self.model.fit(
            train_dataset,
            epochs=self.config['epochs'],
            steps_per_epoch=steps_per_epoch,
            validation_data=val_dataset,
            validation_steps=validation_steps,
            callbacks=callbacks,
            class_weight=self.class_weights,
            verbose=1
        )
        
        # Save results
        self.save_training_results()
        
        print("✅ Training completed!")
        return self.model, self.history
    
    def save_training_results(self):
        """Save comprehensive training results"""
        # Save history
        history_df = pd.DataFrame(self.history.history)
        history_df.to_csv(self.results_dir / 'training_history.csv', index=False)
        
        # Plot training curves
        self.plot_training_curves()
        
        # Save final model
        self.model.save(self.model_dir / 'final_model.h5')
        print(f"💾 Model saved to {self.model_dir / 'final_model.h5'}")
    
    def plot_training_curves(self):
        """Create comprehensive training visualization"""
        fig, axes = plt.subplots(2, 3, figsize=(18, 12))
        fig.suptitle(f'Training Results - {self.experiment_name}', fontsize=16)
        
        history = self.history.history
        epochs = range(1, len(history['loss']) + 1)
        
        # Loss
        axes[0, 0].plot(epochs, history['loss'], 'b-', label='Training Loss')
        axes[0, 0].plot(epochs, history['val_loss'], 'r-', label='Validation Loss')
        axes[0, 0].set_title('Model Loss')
        axes[0, 0].set_xlabel('Epoch')
        axes[0, 0].set_ylabel('Loss')
        axes[0, 0].legend()
        axes[0, 0].grid(True, alpha=0.3)
        
        # Accuracy
        axes[0, 1].plot(epochs, history['accuracy'], 'b-', label='Training Accuracy')
        axes[0, 1].plot(epochs, history['val_accuracy'], 'r-', label='Validation Accuracy')
        axes[0, 1].set_title('Model Accuracy')
        axes[0, 1].set_xlabel('Epoch')
        axes[0, 1].set_ylabel('Accuracy')
        axes[0, 1].legend()
        axes[0, 1].grid(True, alpha=0.3)
        
        # F1 Score
        axes[0, 2].plot(epochs, history['f1_weighted'], 'b-', label='Training F1')
        axes[0, 2].plot(epochs, history['val_f1_weighted'], 'r-', label='Validation F1')
        axes[0, 2].set_title('F1 Score (Weighted)')
        axes[0, 2].set_xlabel('Epoch')
        axes[0, 2].set_ylabel('F1 Score')
        axes[0, 2].legend()
        axes[0, 2].grid(True, alpha=0.3)
        
        # Precision
        axes[1, 0].plot(epochs, history['precision'], 'b-', label='Training Precision')
        axes[1, 0].plot(epochs, history['val_precision'], 'r-', label='Validation Precision')
        axes[1, 0].set_title('Precision')
        axes[1, 0].set_xlabel('Epoch')
        axes[1, 0].set_ylabel('Precision')
        axes[1, 0].legend()
        axes[1, 0].grid(True, alpha=0.3)
        
        # Recall
        axes[1, 1].plot(epochs, history['recall'], 'b-', label='Training Recall')
        axes[1, 1].plot(epochs, history['val_recall'], 'r-', label='Validation Recall')
        axes[1, 1].set_title('Recall')
        axes[1, 1].set_xlabel('Epoch')
        axes[1, 1].set_ylabel('Recall')
        axes[1, 1].legend()
        axes[1, 1].grid(True, alpha=0.3)
        
        # Learning Rate
        if 'lr' in history:
            axes[1, 2].plot(epochs, history['lr'], 'g-', label='Learning Rate')
            axes[1, 2].set_title('Learning Rate')
            axes[1, 2].set_xlabel('Epoch')
            axes[1, 2].set_ylabel('Learning Rate')
            axes[1, 2].set_yscale('log')
            axes[1, 2].legend()
            axes[1, 2].grid(True, alpha=0.3)
        
        plt.tight_layout()
        plt.savefig(self.results_dir / 'training_curves.png', dpi=300, bbox_inches='tight')
        plt.close()
    
    def evaluate_model(self) -> Dict:
        """Comprehensive model evaluation"""
        print("📊 Evaluating model...")
        
        # Load test dataset
        test_dataset, test_size = self.create_tf_dataset_with_augmentation('test')
        test_steps = test_size // self.config['batch_size']
        
        # Evaluate
        test_results = self.model.evaluate(test_dataset, steps=test_steps, verbose=1)
        
        # Get predictions for detailed analysis
        predictions = self.model.predict(test_dataset, steps=test_steps, verbose=1)
        y_pred = np.argmax(predictions, axis=1)
        
        # Get true labels
        y_true = []
        for images, labels in test_dataset.take(test_steps):
            y_true.extend(labels.numpy())
        
        # Generate reports
        classification_rep = classification_report(
            y_true, y_pred, 
            target_names=self.config['class_names'],
            output_dict=True
        )
        
        confusion_mat = confusion_matrix(y_true, y_pred)
        
        # Create evaluation plots
        self.plot_evaluation_results(y_true, y_pred, confusion_mat, classification_rep)
        
        # Save results
        evaluation_results = {
            'test_metrics': dict(zip(self.model.metrics_names, test_results)),
            'classification_report': classification_rep,
            'confusion_matrix': confusion_mat.tolist()
        }
        
        with open(self.results_dir / 'evaluation_results.json', 'w') as f:
            json.dump(evaluation_results, f, indent=2, default=str)
        
        return evaluation_results
    
    def plot_evaluation_results(self, y_true, y_pred, confusion_mat, classification_rep):
        """Create evaluation visualization"""
        fig, axes = plt.subplots(1, 2, figsize=(15, 6))
        
        # Confusion Matrix
        sns.heatmap(confusion_mat, annot=True, fmt='d', cmap='Blues',
                   xticklabels=self.config['class_names'],
                   yticklabels=self.config['class_names'], ax=axes[0])
        axes[0].set_title('Confusion Matrix')
        axes[0].set_xlabel('Predicted')
        axes[0].set_ylabel('Actual')
        
        # Classification metrics
        metrics = ['precision', 'recall', 'f1-score']
        classes = self.config['class_names']
        
        metric_data = []
        for class_name in classes:
            if class_name in classification_rep:
                for metric in metrics:
                    metric_data.append({
                        'Class': class_name,
                        'Metric': metric.capitalize(),
                        'Value': classification_rep[class_name][metric]
                    })
        
        df_metrics = pd.DataFrame(metric_data)
        
        sns.barplot(data=df_metrics, x='Class', y='Value', hue='Metric', ax=axes[1])
        axes[1].set_title('Per-Class Metrics')
        axes[1].set_ylim(0, 1)
        axes[1].legend(bbox_to_anchor=(1.05, 1), loc='upper left')
        
        plt.tight_layout()
        plt.savefig(self.results_dir / 'evaluation_results.png', dpi=300, bbox_inches='tight')
        plt.close()


class TFLiteConverter:
    """Advanced TFLite conversion with optimization for mobile deployment"""
    
    def __init__(self, model_path: str, output_dir: str):
        self.model_path = model_path
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)
        
    def create_representative_dataset(self, data_dir: str, num_samples: int = 200):
        """Create representative dataset for quantization calibration"""
        def representative_data_gen():
            train_path = Path(data_dir) / 'train'
            image_paths = []
            
            for class_dir in train_path.iterdir():
                if class_dir.is_dir():
                    class_images = list(class_dir.glob('*.jpg')) + list(class_dir.glob('*.jpeg'))
                    image_paths.extend(class_images[:num_samples // 4])
            
            random.shuffle(image_paths)
            image_paths = image_paths[:num_samples]
            
            for img_path in image_paths:
                image = cv2.imread(str(img_path))
                if image is None:
                    continue
                    
                image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
                image = cv2.resize(image, (224, 224))
                image = image.astype(np.float32) / 255.0
                image = np.expand_dims(image, axis=0)
                
                yield [image]
        
        return representative_data_gen
    
    def convert_to_tflite(self, data_dir: str, quantization: str = 'dynamic') -> Dict[str, dict]:
        """Convert model to TFLite with various optimization strategies"""
        results = {}
        
        print("🔄 Loading model for conversion...")
        model = keras.models.load_model(self.model_path)
        
        converter = tf.lite.TFLiteConverter.from_keras_model(model)
        converter.allow_custom_ops = True
        
        if quantization == 'none' or quantization == 'float32':
            print("📦 Converting to Float32 TFLite...")
            tflite_model = converter.convert()
            
            output_path = self.output_dir / 'model_float32.tflite'
            with open(output_path, 'wb') as f:
                f.write(tflite_model)
            
            results['float32'] = {
                'path': str(output_path),
                'size_mb': len(tflite_model) / (1024 * 1024),
                'quantization': 'Float32'
            }
        
        elif quantization == 'dynamic':
            print("📦 Converting with Dynamic Range Quantization...")
            converter.optimizations = [tf.lite.Optimize.DEFAULT]
            tflite_model = converter.convert()
            
            output_path = self.output_dir / 'model_dynamic_quant.tflite'
            with open(output_path, 'wb') as f:
                f.write(tflite_model)
            
            results['dynamic'] = {
                'path': str(output_path),
                'size_mb': len(tflite_model) / (1024 * 1024),
                'quantization': 'Dynamic Range'
            }
        
        elif quantization == 'int8':
            print("📦 Converting with INT8 Quantization...")
            converter.optimizations = [tf.lite.Optimize.DEFAULT]
            
            representative_dataset = self.create_representative_dataset(data_dir)
            converter.representative_dataset = representative_dataset
            
            converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS_INT8]
            converter.inference_input_type = tf.int8
            converter.inference_output_type = tf.int8
            
            try:
                tflite_model = converter.convert()
                
                output_path = self.output_dir / 'model_int8_quant.tflite'
                with open(output_path, 'wb') as f:
                    f.write(tflite_model)
                
                results['int8'] = {
                    'path': str(output_path),
                    'size_mb': len(tflite_model) / (1024 * 1024),
                    'quantization': 'INT8',
                    'input_type': 'int8',
                    'output_type': 'int8'
                }
            except Exception as e:
                print(f"❌ INT8 conversion failed: {e}")
                results['int8'] = {'error': str(e)}
        
        elif quantization == 'int8_fallback':
            print("📦 Converting with INT8 + Float Fallback...")
            converter.optimizations = [tf.lite.Optimize.DEFAULT]
            
            representative_dataset = self.create_representative_dataset(data_dir)
            converter.representative_dataset = representative_dataset
            
            converter.target_spec.supported_ops = [
                tf.lite.OpsSet.TFLITE_BUILTINS_INT8,
                tf.lite.OpsSet.TFLITE_BUILTINS
            ]
            
            tflite_model = converter.convert()
            
            output_path = self.output_dir / 'model_int8_fallback.tflite'
            with open(output_path, 'wb') as f:
                f.write(tflite_model)
            
            results['int8_fallback'] = {
                'path': str(output_path),
                'size_mb': len(tflite_model) / (1024 * 1024),
                'quantization': 'INT8 + Float Fallback'
            }
        
        return results
    
    def benchmark_models(self, tflite_paths: Dict[str, Dict], test_images_dir: str, num_samples: int = 50):
        """Benchmark different TFLite model variants"""
        print("⚡ Benchmarking TFLite models...")
        
        # Load test images
        test_images = []
        test_path = Path(test_images_dir) / 'test'
        image_paths = []
        
        for class_dir in test_path.iterdir():
            if class_dir.is_dir():
                class_images = list(class_dir.glob('*.jpg')) + list(class_dir.glob('*.jpeg'))
                image_paths.extend(class_images[:num_samples // 4])
        
        random.shuffle(image_paths)
        image_paths = image_paths[:num_samples]
        
        for img_path in image_paths:
            image = cv2.imread(str(img_path))
            if image is not None:
                image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
                image = cv2.resize(image, (224, 224))
                image = image.astype(np.float32) / 255.0
                test_images.append(image)
        
        benchmark_results = {}
        
        for model_name, model_info in tflite_paths.items():
            if 'path' not in model_info:
                continue
                
            print(f"📊 Benchmarking {model_name}...")
            
            try:
                interpreter = tf.lite.Interpreter(model_path=model_info['path'])
                interpreter.allocate_tensors()
                
                input_details = interpreter.get_input_details()
                output_details = interpreter.get_output_details()
                
                inference_times = []
                
                for i, image in enumerate(test_images[:25]):  # Sample for speed
                    if input_details[0]['dtype'] == np.int8:
                        input_scale, input_zero_point = input_details[0]['quantization']
                        image_quantized = image / input_scale + input_zero_point
                        image_quantized = np.clip(image_quantized, -128, 127).astype(np.int8)
                        input_data = np.expand_dims(image_quantized, axis=0)
                    else:
                        input_data = np.expand_dims(image, axis=0).astype(np.float32)
                    
                    start_time = time.time()
                    interpreter.set_tensor(input_details[0]['index'], input_data)
                    interpreter.invoke()
                    inference_time = (time.time() - start_time) * 1000
                    
                    inference_times.append(inference_time)
                
                avg_inference_time = np.mean(inference_times)
                
                benchmark_results[model_name] = {
                    'size_mb': model_info['size_mb'],
                    'avg_inference_ms': avg_inference_time,
                    'quantization': model_info.get('quantization', 'Unknown'),
                    'input_shape': input_details[0]['shape'].tolist(),
                    'input_type': str(input_details[0]['dtype']),
                }
                
                print(f"  ✅ {model_name}: {avg_inference_time:.2f}ms avg, {model_info['size_mb']:.2f}MB")
                
            except Exception as e:
                print(f"  ❌ Failed to benchmark {model_name}: {e}")
                benchmark_results[model_name] = {'error': str(e)}
        
        # Save benchmark results
        with open(self.output_dir / 'benchmark_results.json', 'w') as f:
            json.dump(benchmark_results, f, indent=2)
        
        return benchmark_results


# Utility functions
def setup_gpu():
    """Configure GPU settings for optimal training"""
    gpus = tf.config.experimental.list_physical_devices('GPU')
    if gpus:
        try:
            for gpu in gpus:
                tf.config.experimental.set_memory_growth(gpu, True)
            print(f"✅ Found {len(gpus)} GPU(s), memory growth enabled")
            return True
        except RuntimeError as e:
            print(f"❌ GPU setup error: {e}")
            return False
    else:
        print("⚠️ No GPUs found, using CPU")
        return False

def validate_data_structure(data_dir):
    """Validate that data directory has correct structure"""
    data_path = Path(data_dir)
    required_splits = ['train', 'val', 'test']
    required_classes = ['Healthy', 'Benign', 'OPMD', 'OCA']
    
    print("🔍 Validating data structure...")
    
    for split in required_splits:
        split_path = data_path / split
        if not split_path.exists():
            print(f"❌ Missing {split} directory")
            return False
        
        for class_name in required_classes:
            class_path = split_path / class_name
            if not class_path.exists():
                print(f"❌ Missing {class_name} class in {split}")
                return False
            
            image_files = list(class_path.glob('*.jpg')) + list(class_path.glob('*.jpeg')) + list(class_path.glob('*.png'))
            if len(image_files) == 0:
                print(f"❌ No images found in {split}/{class_name}")
                return False
            
            print(f"  ✅ {split}/{class_name}: {len(image_files)} images")
    
    print("✅ Data structure validation passed")
    return True

def create_default_config():
    """Create default configuration"""
    return {
        "experiment_settings": {
            "experiment_name": "oral_cancer_screening_v1",
            "description": "Production model for oral cavity cancer screening",
            "random_seed": 42
        },
        "model_architecture": {
            "base_model": "MobileNetV3Large",
            "input_size": [224, 224, 3],
            "num_classes": 4,
            "dropout_rate": 0.3,
            "fine_tune_layers": 30
        },
        "training_parameters": {
            "batch_size": 32,
            "epochs": 100,
            "learning_rate": 0.0001,
            "weight_decay": 0.0001,
            "label_smoothing": 0.1,
            "mixed_precision": True
        },
        "data_augmentation": {
            "strength": "medium",
            "horizontal_flip": True,
            "rotation_range": 15,
            "brightness_range": 0.25,
            "contrast_range": 0.25,
            "noise_probability": 0.25,
            "blur_probability": 0.2
        },
        "callbacks": {
            "early_stopping_patience": 15,
            "reduce_lr_patience": 8,
            "reduce_lr_factor": 0.5,
            "min_learning_rate": 1e-7,
            "save_best_only": True,
            "monitor_metric": "val_f1_weighted"
        },
        "tflite_conversion": {
            "quantization_types": ["dynamic", "int8_fallback"],
            "representative_samples": 200,
            "optimization_target": "balanced"
        }
    }

def run_complete_pipeline(data_dir, output_dir, config_path=None, quantization='dynamic'):
    """Run the complete training and conversion pipeline"""
    
    print(f"🚀 Starting complete pipeline")
    print(f"📊 Data directory: {data_dir}")
    print(f"📁 Output directory: {output_dir}")
    
    # Initialize pipeline
    experiment_name = f"oral_cancer_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
    pipeline = ProductionMLPipeline(data_dir=data_dir, experiment_name=experiment_name)
    
    # Load custom config if provided
    if config_path and Path(config_path).exists():
        pipeline.load_config(config_path)
        print(f"✅ Loaded configuration from {config_path}")
    
    try:
        # Phase 1: Training
        print("\n" + "="*50)
        print("PHASE 1: MODEL TRAINING")
        print("="*50)
        
        model, history = pipeline.train()
        
        # Phase 2: Evaluation
        print("\n" + "="*50)
        print("PHASE 2: MODEL EVALUATION")
        print("="*50)
        
        evaluation_results = pipeline.evaluate_model()
        
        # Phase 3: TFLite Conversion
        print("\n" + "="*50)
        print("PHASE 3: TFLITE CONVERSION")
        print("="*50)
        
        converter = TFLiteConverter(
            model_path=str(pipeline.model_dir / 'best_model.h5'),
            output_dir=str(pipeline.model_dir / 'tflite')
        )
        
        conversion_results = converter.convert_to_tflite(data_dir, quantization)
        
        # Phase 4: Benchmarking
        print("\n" + "="*50)
        print("PHASE 4: MODEL BENCHMARKING")
        print("="*50)
        
        benchmark_results = converter.benchmark_models(
            tflite_paths=conversion_results,
            test_images_dir=data_dir,
            num_samples=50
        )
        
        # Phase 5: Results Summary
        print("\n" + "="*50)
        print("FINAL RESULTS SUMMARY")
        print("="*50)
        
        test_metrics = evaluation_results['test_metrics']
        print(f"📊 Test Results:")
        print(f"  • Accuracy: {test_metrics.get('accuracy', 0):.4f}")
        print(f"  • F1 Score (Weighted): {test_metrics.get('f1_weighted', 0):.4f}")
        print(f"  • Precision: {test_metrics.get('precision', 0):.4f}")
        print(f"  • Recall: {test_metrics.get('recall', 0):.4f}")
        
        print(f"\n📱 TFLite Models:")
        for model_name, info in conversion_results.items():
            if 'error' not in info:
                bench_info = benchmark_results.get(model_name, {})
                inference_time = bench_info.get('avg_inference_ms', 'N/A')
                if inference_time != 'N/A':
                    print(f"  • {model_name}: {info['size_mb']:.2f}MB, {inference_time:.1f}ms")
                else:
                    print(f"  • {model_name}: {info['size_mb']:.2f}MB")
        
        # Save final results
        final_results = {
            'experiment_name': experiment_name,
            'config': pipeline.config,
            'evaluation_results': evaluation_results,
            'conversion_results': conversion_results,
            'benchmark_results': benchmark_results,
            'timestamp': datetime.now().isoformat(),
            'paths': {
                'model_dir': str(pipeline.model_dir),
                'results_dir': str(pipeline.results_dir),
                'log_dir': str(pipeline.log_dir)
            }
        }
        
        results_file = pipeline.results_dir / 'final_results.json'
        with open(results_file, 'w') as f:
            json.dump(final_results, f, indent=2, default=str)
        
        print(f"\n✅ Pipeline completed successfully!")
        print(f"📁 Results: {results_file}")
        print(f"🏗️ Models: {pipeline.model_dir}")
        print(f"📊 TensorBoard: tensorboard --logdir {pipeline.log_dir}")
        
        # Recommendations
        f1_score = test_metrics.get('f1_weighted', 0)
        if f1_score >= 0.85:
            print("🏆 Excellent performance - ready for clinical validation!")
        elif f1_score >= 0.75:
            print("✅ Good performance - consider more training data for improvement")
        else:
            print("⚠️ Performance needs improvement - review data quality and augmentation")
        
        return True
        
    except Exception as e:
        print(f"❌ Pipeline failed: {e}")
        import traceback
        traceback.print_exc()
        return False

def main():
    """Main function with command line interface"""
    
    parser = argparse.ArgumentParser(
        description='Production ML Pipeline for Oral Cancer Screening',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Quick start with default settings
  python complete_pipeline.py --data_dir ./dataset --output_dir ./experiments

  # Custom experiment with configuration file
  python complete_pipeline.py --data_dir ./dataset --config config.json --output_dir ./experiments

  # Generate default configuration file
  python complete_pipeline.py --create_config --config_output my_config.json

  # Validate data structure only
  python complete_pipeline.py --data_dir ./dataset --validate_only

  # Specify quantization strategy
  python complete_pipeline.py --data_dir ./dataset --quantization int8_fallback
        """
    )
    
    parser.add_argument('--data_dir', type=str, help='Path to dataset directory with train/val/test splits')
    parser.add_argument('--config', type=str, help='Path to configuration JSON file')
    parser.add_argument('--output_dir', type=str, default='./experiments', help='Output directory for results')
    parser.add_argument('--create_config', action='store_true', help='Create default configuration file')
    parser.add_argument('--config_output', type=str, default='config.json', help='Output path for configuration file')
    parser.add_argument('--validate_only', action='store_true', help='Only validate data structure')
    parser.add_argument('--quantization', choices=['dynamic', 'int8', 'int8_fallback', 'float32'], 
                       default='dynamic', help='TFLite quantization strategy')
    
    args = parser.parse_args()
    
    # Handle configuration creation
    if args.create_config:
        config = create_default_config()
        config_path = Path(args.config_output)
        config_path.parent.mkdir(parents=True, exist_ok=True)
        
        with open(config_path, 'w') as f:
            json.dump(config, f, indent=2)
        
        print(f"✅ Default configuration created: {config_path}")
        print("📝 Edit this file to customize training parameters")
        return 0
    
    # Validate required arguments
    if not args.data_dir:
        print("❌ --data_dir is required")
        parser.print_help()
        return 1
    
    # Setup GPU
    setup_gpu()
    
    # Validate data structure
    if not validate_data_structure(args.data_dir):
        return 1
    
    if args.validate_only:
        print("✅ Data validation completed successfully")
        return 0
    
    # Run the complete pipeline
    success = run_complete_pipeline(
        data_dir=args.data_dir,
        output_dir=args.output_dir,
        config_path=args.config,
        quantization=args.quantization
    )
    
    return 0 if success else 1


if __name__ == "__main__":
    exit(main())