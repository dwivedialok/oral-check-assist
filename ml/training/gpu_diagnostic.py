#!/usr/bin/env python3
"""
GPU Diagnostic Script for TensorFlow
Helps identify why TensorFlow isn't detecting your GPU
"""

import sys
import subprocess
import os

def check_system_gpu():
    """Check system-level GPU information"""
    print("🔍 SYSTEM GPU INFORMATION")
    print("=" * 50)
    
    # Check nvidia-smi
    try:
        result = subprocess.run(['nvidia-smi'], capture_output=True, text=True)
        if result.returncode == 0:
            print("✅ nvidia-smi found and working:")
            print(result.stdout)
        else:
            print("❌ nvidia-smi failed or not found")
            print("Error:", result.stderr)
    except FileNotFoundError:
        print("❌ nvidia-smi not found - NVIDIA drivers may not be installed")
    
    # Check GPU devices
    try:
        result = subprocess.run(['lspci', '|', 'grep', '-i', 'nvidia'], 
                              shell=True, capture_output=True, text=True)
        if result.stdout.strip():
            print("✅ NVIDIA GPU found in PCI devices:")
            print(result.stdout)
        else:
            print("❌ No NVIDIA GPU found in PCI devices")
    except Exception as e:
        print(f"❌ Error checking PCI devices: {e}")

def check_tensorflow_gpu():
    """Check TensorFlow GPU detection"""
    print("\n🔍 TENSORFLOW GPU DETECTION")
    print("=" * 50)
    
    try:
        import tensorflow as tf
        print(f"✅ TensorFlow version: {tf.__version__}")
        
        # Check if TensorFlow was built with GPU support
        print(f"✅ TensorFlow built with CUDA: {tf.test.is_built_with_cuda()}")
        print(f"✅ TensorFlow built with GPU: {tf.test.is_built_with_gpu_support()}")
        
        # Check available devices
        print("\n📱 Available devices:")
        devices = tf.config.list_physical_devices()
        for device in devices:
            print(f"  • {device.device_type}: {device.name}")
        
        # Check GPU devices specifically
        gpus = tf.config.list_physical_devices('GPU')
        if gpus:
            print(f"\n🎯 Found {len(gpus)} GPU(s):")
            for gpu in gpus:
                print(f"  • {gpu.name}")
                print(f"    - Device type: {gpu.device_type}")
                print(f"    - Memory growth: {gpu.memory_growth if hasattr(gpu, 'memory_growth') else 'N/A'}")
        else:
            print("\n❌ No GPUs detected by TensorFlow")
        
        # Check CUDA availability
        try:
            import tensorflow.python.platform.build_info as build_info
            print(f"\n🔧 Build info:")
            print(f"  • CUDA version: {build_info.build_info.get('cuda_version', 'Unknown')}")
            print(f"  • cuDNN version: {build_info.build_info.get('cudnn_version', 'Unknown')}")
        except ImportError:
            print("\n⚠️ Could not get detailed build info")
        
        return len(gpus) > 0
        
    except ImportError as e:
        print(f"❌ TensorFlow import error: {e}")
        return False
    except Exception as e:
        print(f"❌ TensorFlow GPU check error: {e}")
        return False

def check_cuda_installation():
    """Check CUDA installation"""
    print("\n🔍 CUDA INSTALLATION CHECK")
    print("=" * 50)
    
    # Check CUDA version
    try:
        result = subprocess.run(['nvcc', '--version'], capture_output=True, text=True)
        if result.returncode == 0:
            print("✅ CUDA compiler (nvcc) found:")
            print(result.stdout)
        else:
            print("❌ CUDA compiler (nvcc) not found or failed")
    except FileNotFoundError:
        print("❌ CUDA compiler (nvcc) not found - CUDA may not be installed")
    
    # Check CUDA runtime
    try:
        result = subprocess.run(['cat', '/usr/local/cuda/version.txt'], 
                              capture_output=True, text=True)
        if result.returncode == 0:
            print("✅ CUDA runtime version:")
            print(result.stdout)
        else:
            print("❌ Could not read CUDA version file")
    except Exception as e:
        print(f"❌ Error reading CUDA version: {e}")
    
    # Check environment variables
    print("\n🔧 CUDA Environment Variables:")
    cuda_vars = ['CUDA_HOME', 'CUDA_PATH', 'LD_LIBRARY_PATH', 'PATH']
    for var in cuda_vars:
        value = os.environ.get(var, 'Not set')
        print(f"  • {var}: {value}")

def check_python_environment():
    """Check Python environment"""
    print("\n🔍 PYTHON ENVIRONMENT")
    print("=" * 50)
    
    print(f"✅ Python version: {sys.version}")
    print(f"✅ Python executable: {sys.executable}")
    
    # Check if we're in a virtual environment
    if hasattr(sys, 'real_prefix') or (hasattr(sys, 'base_prefix') and sys.base_prefix != sys.prefix):
        print("✅ Running in virtual environment")
        print(f"  • Virtual env: {sys.prefix}")
        print(f"  • Base prefix: {sys.base_prefix}")
    else:
        print("⚠️ Not running in virtual environment")
    
    # Check pip packages
    try:
        result = subprocess.run([sys.executable, '-m', 'pip', 'list'], 
                              capture_output=True, text=True)
        if result.returncode == 0:
            packages = result.stdout.split('\n')
            tensorflow_packages = [p for p in packages if 'tensorflow' in p.lower()]
            if tensorflow_packages:
                print("✅ TensorFlow packages found:")
                for pkg in tensorflow_packages:
                    print(f"  • {pkg}")
            else:
                print("❌ No TensorFlow packages found")
        else:
            print("❌ Could not list pip packages")
    except Exception as e:
        print(f"❌ Error checking pip packages: {e}")

def run_gpu_test():
    """Run a simple GPU test"""
    print("\n🔍 GPU FUNCTIONALITY TEST")
    print("=" * 50)
    
    try:
        import tensorflow as tf
        
        # Try to create a simple tensor on GPU
        gpus = tf.config.list_physical_devices('GPU')
        if gpus:
            print("🎯 Testing GPU functionality...")
            
            # Enable memory growth
            for gpu in gpus:
                tf.config.experimental.set_memory_growth(gpu, True)
            
            # Create a simple computation
            with tf.device('/GPU:0'):
                a = tf.constant([[1.0, 2.0], [3.0, 4.0]])
                b = tf.constant([[1.0, 1.0], [0.0, 1.0]])
                c = tf.matmul(a, b)
                print(f"✅ GPU computation successful: {c}")
                print(f"✅ Tensor device: {c.device}")
        else:
            print("❌ No GPUs available for testing")
            
    except Exception as e:
        print(f"❌ GPU test failed: {e}")

def main():
    """Run all diagnostics"""
    print("🚀 TENSORFLOW GPU DIAGNOSTIC TOOL")
    print("=" * 60)
    
    # Run all checks
    check_system_gpu()
    check_tensorflow_gpu()
    check_cuda_installation()
    check_python_environment()
    run_gpu_test()
    
    print("\n" + "=" * 60)
    print("📋 DIAGNOSTIC SUMMARY")
    print("=" * 60)
    
    # Provide recommendations
    print("\n💡 COMMON SOLUTIONS:")
    print("1. Install NVIDIA drivers: sudo apt install nvidia-driver-xxx")
    print("2. Install CUDA toolkit: https://developer.nvidia.com/cuda-downloads")
    print("3. Install cuDNN: https://developer.nvidia.com/cudnn")
    print("4. Reinstall TensorFlow with GPU support: pip install tensorflow[gpu]")
    print("5. Check environment variables: CUDA_HOME, LD_LIBRARY_PATH")
    print("6. Restart system after driver installation")
    
    print("\n🔗 USEFUL LINKS:")
    print("• TensorFlow GPU Guide: https://www.tensorflow.org/install/gpu")
    print("• CUDA Installation: https://docs.nvidia.com/cuda/")
    print("• cuDNN Installation: https://docs.nvidia.com/deeplearning/cudnn/")

if __name__ == "__main__":
    main()
