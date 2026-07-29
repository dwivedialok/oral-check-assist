#!/usr/bin/env python3
"""
Simple test to verify augmentation pipeline works
"""

import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

def test_augmentation_imports():
    """Test that all required augmentation methods can be imported and used"""
    try:
        import albumentations as A
        
        # Test basic augmentation methods
        print("Testing albumentations imports...")
        
        # Test basic methods
        basic_aug = A.Compose([
            A.HorizontalFlip(p=0.5),
            A.RandomRotate90(p=0.3),
            A.RandomBrightnessContrast(brightness_limit=0.1, contrast_limit=0.1, p=0.5),
        ])
        print("✅ Basic augmentation methods work")
        
        # Test medium strength methods
        medium_aug = A.Compose([
            A.RandomRotate90(p=0.4),
            A.HorizontalFlip(p=0.5),
            A.ShiftScaleRotate(shift_limit=0.05, scale_limit=0.1, rotate_limit=15, p=0.4),
            A.RandomBrightnessContrast(brightness_limit=0.25, contrast_limit=0.25, p=0.6),
            A.HueSaturationValue(hue_shift_limit=12, sat_shift_limit=15, val_shift_limit=12, p=0.4),
            A.RGBShift(r_shift_limit=15, g_shift_limit=15, b_shift_limit=15, p=0.3),
            A.RandomGamma(gamma_limit=(85, 115), p=0.3),
            A.CLAHE(clip_limit=3.0, tile_grid_size=(8, 8), p=0.4),
            A.GaussNoise(var_limit=(10.0, 40.0), p=0.3),
            A.GaussianBlur(blur_limit=3, p=0.3),
        ])
        print("✅ Medium augmentation methods work")
        
        # Test heavy strength methods
        heavy_aug = A.Compose([
            A.RandomRotate90(p=0.5),
            A.HorizontalFlip(p=0.7),
            A.ShiftScaleRotate(shift_limit=0.08, scale_limit=0.15, rotate_limit=25, p=0.5),
            A.RandomBrightnessContrast(brightness_limit=0.4, contrast_limit=0.4, p=0.7),
            A.HueSaturationValue(hue_shift_limit=20, sat_shift_limit=25, val_shift_limit=20, p=0.5),
            A.RGBShift(r_shift_limit=25, g_shift_limit=25, b_shift_limit=25, p=0.4),
            A.RandomGamma(gamma_limit=(70, 130), p=0.4),
            A.CLAHE(clip_limit=4.0, tile_grid_size=(8, 8), p=0.5),
            A.Sharpen(alpha=(0.2, 0.5), lightness=(0.7, 1.3), p=0.4),
            A.UnsharpMask(blur_limit=5, sigma_limit=1.0, alpha=(0.2, 0.5), p=0.4),
            A.GaussNoise(var_limit=(15.0, 60.0), p=0.4),
            A.GaussianBlur(blur_limit=5, p=0.4),
        ])
        print("✅ Heavy augmentation methods work")
        
        print("\n🎉 All augmentation tests passed!")
        return True
        
    except Exception as e:
        print(f"❌ Augmentation test failed: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    success = test_augmentation_imports()
    sys.exit(0 if success else 1)
