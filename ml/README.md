# Oral Cancer Initial Check Model Inference

This directory contains the code for running inference using the TFLite model for an AI-assisted initial visual check of oral images to help determine whether professional evaluation may be advisable.

## Setup

1. Create a virtual environment (recommended):
```bash
python -m venv .venv
source venv/bin/activate  # On Windows use: venv\Scripts\activate
```

2. Install dependencies:
```bash
pip install -r requirements.txt
```

## Directory Structure

Python script uses following directory structure:
```
├── assets/
│   └── oral_cavity_model.tflite
|── ml/
    ├── test_data/
    │       └── healthy/
    │           └── C-4-6-2.jpg
    ├── sample_inference.py
    ├── requirements.txt
    └── README.md
```

## Running Inference

To run inference on a sample image:

```bash
python sample_inference.py
```

The script will:
1. Load the TFLite model
2. Process the input image
3. Run inference
4. Display the predicted class and confidence score

## Model Details

The model classifies images into the following categories:
- Benign
- Healthy
- OCA (Oral Cancer)
- OPMD (Oral Potentially Malignant Disorders)
- Unknown

## Notes

- The script expects the TFLite model to be in the `assets` directory
- Input images should be in RGB format
- The model expects images to be resized to 224x224 pixels
- Pixel values are normalized to [0, 1] range 