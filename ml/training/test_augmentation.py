#!/usr/bin/env python3
"""
Test script to verify augmentation pipeline works correctly
"""

import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from complete_pipeline import ProductionMLPipeline

def test_augmentation():
    """Test that augmentation pipeline can be created without errors"""
    try:
        # Create pipeline instance
        pipeline = ProductionMLPipeline(data_dir="./test_data", experiment_name="test")
        
        # Test augmentation creation
        print("Testing light augmentation...")
        light_aug = pipeline.create_advanced_augmentation()
        print("✅ Light augmentation created successfully")
        
        print("Testing medium augmentation...")
        pipeline.config['data_augmentation_strength'] = 'medium'
        medium_aug = pipeline.create_advanced_augmentation()
        print("✅ Medium augmentation created successfully")
        
        print("Testing heavy augmentation...")
        pipeline.config['data_augmentation_strength'] = 'heavy'
        heavy_aug = pipeline.create_advanced_augmentation()
        print("✅ Heavy augmentation created successfully")
        
        print("\n🎉 All augmentation tests passed!")
        return True
        
    except Exception as e:
        print(f"❌ Augmentation test failed: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    success = test_augmentation()
    sys.exit(0 if success else 1)
