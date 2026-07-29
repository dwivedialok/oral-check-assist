# TFLite optional GPU delegate - avoid R8 missing-class error when not using GPU
-dontwarn org.tensorflow.lite.gpu.GpuDelegateFactory$Options

# ONNX Runtime - keep native classes (flutter_onnxruntime)
-keep class ai.onnxruntime.** { *; }
