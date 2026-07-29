#!/usr/bin/env python3
"""
Comprehensive sanity test for the complete training pipeline
Tests all major components without requiring actual data
"""

import sys
import os
import tempfile
import shutil
from pathlib import Path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

def test_imports():
    """Test that all required packages can be imported"""
    print("🔍 Testing imports...")
    
    try:
        import tensorflow as tf
        print(f"✅ TensorFlow {tf.__version__}")
        
        import albumentations as A
        print(f"✅ Albumentations {A.__version__}")
        
        import cv2
        print(f"✅ OpenCV {cv2.__version__}")
        
        import numpy as np
        print(f"✅ NumPy {np.__version__}")
        
        import pandas as pd
        print(f"✅ Pandas {pd.__version__}")
        
        import matplotlib.pyplot as plt
        print("✅ Matplotlib")
        
        import seaborn as sns
        print("✅ Seaborn")
        
        from sklearn.metrics import classification_report, confusion_matrix
        print("✅ Scikit-learn")
        
        # Test tensorflow_addons
        try:
            import tensorflow_addons as tfa
            print(f"✅ TensorFlow Addons {tfa.__version__}")
        except ImportError:
            print("⚠️ TensorFlow Addons not available (will use fallbacks)")
        
        return True
        
    except Exception as e:
        print(f"❌ Import test failed: {e}")
        import traceback
        traceback.print_exc()
        return False

def test_augmentation_pipeline():
    """Test that augmentation pipeline can be created"""
    print("\n🔍 Testing augmentation pipeline...")
    
    try:
        from complete_pipeline import ProductionMLPipeline
        
        # Create temporary directory
        with tempfile.TemporaryDirectory() as temp_dir:
            pipeline = ProductionMLPipeline(data_dir=temp_dir, experiment_name="sanity_test")
            
            # Test all augmentation strengths
            for strength in ['light', 'medium', 'heavy']:
                pipeline.config['data_augmentation_strength'] = strength
                aug = pipeline.create_advanced_augmentation()
                print(f"✅ {strength.capitalize()} augmentation created successfully")
            
            return True
            
    except Exception as e:
        print(f"❌ Augmentation test failed: {e}")
        import traceback
        traceback.print_exc()
        return False

def test_model_creation():
    """Test that model can be created and compiled"""
    print("\n🔍 Testing model creation...")
    
    try:
        from complete_pipeline import ProductionMLPipeline
        
        with tempfile.TemporaryDirectory() as temp_dir:
            pipeline = ProductionMLPipeline(data_dir=temp_dir, experiment_name="sanity_test")
            
            # Create model
            model = pipeline.create_model()
            print(f"✅ Model created successfully: {model.name}")
            print(f"✅ Model parameters: {model.count_params():,}")
            
            # Compile model
            compiled_model = pipeline.compile_model(model)
            print("✅ Model compiled successfully")
            
            # Test model summary
            model.summary()
            
            return True
            
    except Exception as e:
        print(f"❌ Model creation test failed: {e}")
        import traceback
        traceback.print_exc()
        return False

def test_callbacks_creation():
    """Test that callbacks can be created"""
    print("\n🔍 Testing callbacks creation...")
    
    try:
        from complete_pipeline import ProductionMLPipeline
        
        with tempfile.TemporaryDirectory() as temp_dir:
            pipeline = ProductionMLPipeline(data_dir=temp_dir, experiment_name="sanity_test")
            
            # Create callbacks
            callbacks = pipeline.create_callbacks()
            print(f"✅ {len(callbacks)} callbacks created successfully")
            
            # Check callback types
            callback_types = [type(cb).__name__ for cb in callbacks]
            print(f"✅ Callback types: {callback_types}")
            
            return True
            
    except Exception as e:
        print(f"❌ Callbacks test failed: {e}")
        import traceback
        traceback.print_exc()
        return False

def test_tflite_converter():
    """Test that TFLite converter can be imported and initialized"""
    print("\n🔍 Testing TFLite converter...")
    
    try:
        from complete_pipeline import TFLiteConverter
        
        with tempfile.TemporaryDirectory() as temp_dir:
            # Create a dummy model file path
            dummy_model_path = os.path.join(temp_dir, "dummy_model.h5")
            
            # Test converter initialization
            converter = TFLiteConverter(model_path=dummy_model_path, output_dir=temp_dir)
            print("✅ TFLite converter initialized successfully")
            
            return True
            
    except Exception as e:
        print(f"❌ TFLite converter test failed: {e}")
        import traceback
        traceback.print_exc()
        return False

def test_config_handling():
    """Test configuration creation and loading"""
    print("\n🔍 Testing configuration handling...")
    
    try:
        from complete_pipeline import create_default_config
        
        # Test default config creation
        config = create_default_config()
        print("✅ Default configuration created successfully")
        
        # Check key sections
        required_sections = ['experiment_settings', 'model_architecture', 'training_parameters', 'data_augmentation']
        for section in required_sections:
            if section in config:
                print(f"✅ Config section '{section}' present")
            else:
                print(f"❌ Config section '{section}' missing")
                return False
        
        return True
        
    except Exception as e:
        print(f"❌ Configuration test failed: {e}")
        import traceback
        traceback.print_exc()
        return False

def test_utility_functions():
    """Test utility functions"""
    print("\n🔍 Testing utility functions...")
    
    try:
        from complete_pipeline import setup_gpu, validate_data_structure
        
        # Test GPU setup (should work even without GPU)
        gpu_available = setup_gpu()
        print(f"✅ GPU setup completed: {'GPU available' if gpu_available else 'CPU only'}")
        
        # Test data validation function (should handle missing data gracefully)
        with tempfile.TemporaryDirectory() as temp_dir:
            # Create minimal structure for all 5 classes
            classes = ["Healthy", "Benign", "OPMD", "OCA", "Unknown"]
            for split in ["train", "val", "test"]:
                for class_name in classes:
                    os.makedirs(os.path.join(temp_dir, split, class_name), exist_ok=True)
                    # Add a dummy image
                    dummy_image_path = os.path.join(temp_dir, split, class_name, "dummy.jpg")
                    with open(dummy_image_path, 'w') as f:
                        f.write("dummy")
            
            # This should fail validation but not crash
            try:
                result = validate_data_structure(temp_dir)
                print(f"✅ Data validation completed: {result}")
            except Exception as e:
                print(f"⚠️ Data validation failed as expected: {e}")
        
        return True
        
    except Exception as e:
        print(f"❌ Utility functions test failed: {e}")
        import traceback
        traceback.print_exc()
        return False

def run_sanity_test():
    """Run all sanity tests"""
    print("🧪 Starting comprehensive sanity test...")
    print("=" * 60)
    
    tests = [
        ("Imports", test_imports),
        ("Augmentation Pipeline", test_augmentation_pipeline),
        ("Model Creation", test_model_creation),
        ("Callbacks Creation", test_callbacks_creation),
        ("TFLite Converter", test_tflite_converter),
        ("Configuration Handling", test_config_handling),
        ("Utility Functions", test_utility_functions),
    ]
    
    passed = 0
    total = len(tests)
    
    for test_name, test_func in tests:
        print(f"\n{'='*20} {test_name} {'='*20}")
        try:
            if test_func():
                passed += 1
                print(f"✅ {test_name} PASSED")
            else:
                print(f"❌ {test_name} FAILED")
        except Exception as e:
            print(f"❌ {test_name} CRASHED: {e}")
            import traceback
            traceback.print_exc()
    
    print("\n" + "=" * 60)
    print(f"🧪 SANITY TEST RESULTS: {passed}/{total} tests passed")
    
    if passed == total:
        print("🎉 All tests passed! The pipeline is ready for training.")
        return True
    else:
        print("⚠️ Some tests failed. Please fix the issues before proceeding with training.")
        return False

if __name__ == "__main__":
    success = run_sanity_test()
    sys.exit(0 if success else 1)
