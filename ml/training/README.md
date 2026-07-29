# Oral Cancer Screening ML Training Pipeline

This directory contains a production-grade machine learning pipeline for training oral cancer screening models.

## Features

- **Advanced Data Augmentation**: Sophisticated augmentation pipeline using albumentations
- **Mobile-Optimized Models**: Uses MobileNetV3Large for mobile deployment
- **Production Ready**: Includes comprehensive logging, callbacks, and evaluation
- **TFLite Conversion**: Automatic conversion to TFLite with multiple quantization strategies
- **Performance Benchmarking**: Built-in benchmarking for different model variants

## Installation

1. **Install Python dependencies:**
   ```bash
   pip install -r requirements.txt
   ```

2. **Verify installation:**
   ```bash
   # Quick test
   python simple_test.py
   
   # Comprehensive sanity test
   python sanity_test.py
   ```

## Usage

### Quick Start

```bash
# Basic training with default settings
python complete_pipeline.py --data_dir ./dataset --output_dir ./experiments

# Custom configuration
python complete_pipeline.py --data_dir ./dataset --config config.json --output_dir ./experiments

# Generate default configuration
python complete_pipeline.py --create_config --config_output my_config.json
```

### Data Structure

Your dataset should have the following structure:
```
dataset/
├── train/
│   ├── Healthy/
│   ├── Benign/
│   ├── OPMD/
│   ├── OCA/
│   └── Unknown/
├── val/
│   ├── Healthy/
│   ├── Benign/
│   ├── OPMD/
│   ├── OCA/
│   └── Unknown/
└── test/
    ├── Healthy/
    ├── Benign/
    ├── OPMD/
    ├── OCA/
    └── Unknown/
```

### Configuration

The pipeline supports custom configuration via JSON files. Key parameters:

- **Model Architecture**: Base model, input size, dropout rate
- **Training Parameters**: Batch size, epochs, learning rate, weight decay
- **Data Augmentation**: Strength level (light/medium/heavy)
- **TFLite Conversion**: Quantization strategies

### Output

The pipeline generates:
- Trained models (H5 and TFLite formats)
- Training logs and TensorBoard files
- Evaluation results and visualizations
- Benchmark results for different model variants

## Troubleshooting

### Common Issues

1. **Albumentations API errors**: The pipeline has been updated to use only stable albumentations methods. Use albumentations < 2.0.0 for best compatibility.
2. **Missing tensorflow_addons**: The pipeline will fall back to standard TensorFlow implementations
3. **GPU memory issues**: Enable memory growth or reduce batch size

### Testing

Run the test scripts to verify your setup:
```bash
# Quick augmentation test
python simple_test.py

# Comprehensive sanity test (recommended)
python sanity_test.py
```

The sanity test verifies all major components without requiring actual data.

## Performance Tips

- Use mixed precision training for faster training and lower memory usage
- Adjust augmentation strength based on your dataset size
- Monitor validation metrics to prevent overfitting
- Use early stopping and learning rate scheduling

## License

This project is part of the Oral Cavity Classifier App.
