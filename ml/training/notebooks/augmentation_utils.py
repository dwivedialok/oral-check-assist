"""
augmentation_utils.py — Albumentations pipelines for oral cavity classifier training.

get_low_end_android_train_transform() layers standard medical-image augmentations
on top of device-realistic degradations that simulate the cheap Android handsets
used in community screening deployments (mobile vans, village camps).

Motivation: supervised fine-tuning uses clinical images, but the app runs on low-end
phones in non-clinical settings. These transforms narrow that train/deploy distribution
gap without requiring any new labeled data.

Usage in notebook:
    from augmentation_utils import get_low_end_android_train_transform, get_val_transform

    train_tf = get_low_end_android_train_transform(image_size=CONFIG["image_size"])
    val_tf   = get_val_transform(image_size=CONFIG["image_size"])

    # ClassificationDataset.__getitem__ must pass numpy array, not PIL:
    #   result = self.transform(image=np.array(pil_img))
    #   x = result['image']   # already a CHW float32 tensor via ToTensorV2
"""

import albumentations as A
from albumentations.pytorch import ToTensorV2

IMAGENET_MEAN = [0.485, 0.456, 0.406]
IMAGENET_STD  = [0.229, 0.224, 0.225]


def get_low_end_android_train_transform(image_size: int = 224) -> A.Compose:
    """
    Training pipeline: standard medical augmentations + low-end Android camera
    artifact simulation.

    Device-realistic degradations (in order of application):
      - ImageCompression : cheap codec / low storage budget (quality 40-75)
      - Downscale        : low-res sensor up-interpolated to display size (0.4-0.7x)
      - MotionBlur       : hand-shake, no OIS (kernel 5-15 px)
      - GaussNoise       : sensor read noise in low light
      - ISONoise         : high-ISO colour noise in dark mouth cavity

    Probabilities are set so ~60-70% of training images receive at least one
    device artifact, which mirrors real deployment rates without destroying
    too much pathological signal in every batch.

    API targets albumentations>=2.0.0 (venv_pytorch).
    """
    return A.Compose([
        A.Resize(image_size, image_size),

        # ── Standard geometric ────────────────────────────────────────────────
        A.HorizontalFlip(p=0.5),
        A.Rotate(limit=10, p=0.5),
        # Affine replaces deprecated ShiftScaleRotate in albumentations 2.x
        A.Affine(
            translate_percent=(-0.04, 0.04),
            scale=(0.92, 1.08),
            rotate=(-8, 8),
            p=0.3,
        ),

        # ── Standard colour / contrast ────────────────────────────────────────
        A.RandomBrightnessContrast(
            brightness_limit=0.4, contrast_limit=0.3, p=0.6
        ),
        A.HueSaturationValue(
            hue_shift_limit=10, sat_shift_limit=20, val_shift_limit=15, p=0.4
        ),
        A.RandomGamma(gamma_limit=(80, 120), p=0.3),

        # ── Low-end Android camera simulation ────────────────────────────────
        # Aggressive JPEG: cheap codec, low per-photo storage budget
        A.ImageCompression(quality_range=(40, 75), p=0.5),

        # Low-resolution sensor: downscale then Resize re-interpolates to image_size,
        # leaving blocking/aliasing artefacts visible at pathology scale
        A.Downscale(scale_range=(0.4, 0.7), p=0.4),

        # Hand-shake / no optical image stabilisation
        A.MotionBlur(blur_limit=(5, 15), p=0.4),

        # Cheap sensor read-noise (worse in dimly lit oral cavity)
        # std_range is in [0,1] normalised units (albumentations 2.x)
        A.GaussNoise(std_range=(0.02, 0.1), p=0.4),

        # High-ISO colour speckle (user holds phone close in dark mouth)
        A.ISONoise(color_shift=(0.1, 0.4), intensity=(0.3, 0.7), p=0.4),

        # ── Normalize + convert to CHW tensor ────────────────────────────────
        A.Normalize(mean=IMAGENET_MEAN, std=IMAGENET_STD),
        ToTensorV2(),
    ])


def get_val_transform(image_size: int = 224) -> A.Compose:
    """Validation / test transform — deterministic, no augmentation."""
    return A.Compose([
        A.Resize(image_size, image_size),
        A.Normalize(mean=IMAGENET_MEAN, std=IMAGENET_STD),
        ToTensorV2(),
    ])
