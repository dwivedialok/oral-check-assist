import os
import numpy as np
import tensorflow as tf
from PIL import Image
from pathlib import Path


# Define your class labels (ensure they match your model's training)
class_labels = ['Benign', 'Healthy', 'OCA', 'OPMD', 'Unknown']

# Update model path to match the directory structure and correct filename
tflite_model_path = "../assets/oral-cavity-model.tflite"

def load_model():
    # Check if model file exists
    if not os.path.exists(tflite_model_path):
        raise FileNotFoundError(f"Model file not found at {tflite_model_path}. Please ensure the model file exists in the assets directory.")

    # Load the TFLite model and allocate tensors
    try:
        interpreter = tf.lite.Interpreter(model_path=tflite_model_path)
        interpreter.allocate_tensors()
        input_details = interpreter.get_input_details()
        output_details = interpreter.get_output_details()

        print("INPUT:", input_details)
        print("OUTPUT:", output_details)
        return interpreter
    except Exception as e:
        raise RuntimeError(f"Failed to load TFLite model: {str(e)}")

def preprocess_image_for_tflite(image_path, input_details):
    # Get expected input shape from TFLite model details
    input_shape = input_details[0]['shape'] # [1, 3, 224, 224] for NCHW
    input_dtype = input_details[0]['dtype'] # e.g., numpy.float32

    img = Image.open(image_path).convert('RGB') # Ensure RGB

    # Resize the image to the model's expected dimensions
    # input_shape[2] is height, input_shape[3] is width (for NCHW format)
    img = img.resize((input_shape[3], input_shape[2]))
    img_np = np.array(img, dtype=input_dtype)

    # Normalize pixel values to [0.0, 1.0]
    img_np = img_np / 255.0

    # Add batch dimension (e.g., from [224, 224, 3] to [1, 224, 224, 3])
    input_tensor = np.expand_dims(img_np, axis=0)

    # Convert from NHWC to NCHW format
    # From [1, 224, 224, 3] to [1, 3, 224, 224]
    input_tensor = np.transpose(input_tensor, (0, 3, 1, 2))

    return input_tensor

def softmax(logits):
    exp_logits = np.exp(logits - np.max(logits))  # for numerical stability
    return exp_logits / np.sum(exp_logits)

def run_inference(interpreter, image_path):
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()
    
    # Preprocess the image
    input_data = preprocess_image_for_tflite(image_path, input_details)
    
    # Set the input tensor
    interpreter.set_tensor(input_details[0]['index'], input_data)
    
    # Run inference
    interpreter.invoke()
    
    # Get the output tensor
    output_data = interpreter.get_tensor(output_details[0]['index'])
    
    # Process the output
    print("OUTPUT:", output_data)
    probabilities = softmax(output_data[0])
    print("PROBABILITIES:", probabilities)
    predicted_index = np.argmax(probabilities)
    predicted_label = class_labels[predicted_index]
    confidence = probabilities[predicted_index] * 100
    
    return predicted_label, confidence

def process_test_data():
    interpreter = load_model()
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()
    
    print("TFLite Model Input Details:", input_details)
    print("TFLite Model Output Details:", output_details)
    
    test_data_path = "test_data"
    total_images = 0
    correct_predictions = 0
    
    # First process files directly in the test_data folder
    print("\nProcessing images directly in test_data folder:")
    print("=" * 60)
    
    for image_name in os.listdir(test_data_path):
        if not image_name.lower().endswith(('.png', '.jpg', '.jpeg')):
            continue
            
        # Extract expected label from filename prefix (e.g., "benign_26.jpg" -> "benign")
        filename_parts = image_name.split('_')
        if len(filename_parts) < 2:
            print(f"Skipping {image_name}: filename doesn't follow <label>_<name>.<ext> format")
            continue
            
        expected_label = filename_parts[0].lower()
        
        # Validate that the extracted label is one of our known classes
        if expected_label not in [label.lower() for label in class_labels]:
            print(f"Skipping {image_name}: extracted label '{expected_label}' not in known classes")
            continue
            
        image_path = os.path.join(test_data_path, image_name)
        try:
            predicted_label, confidence = run_inference(interpreter, image_path)
            total_images += 1
            
            # Compare labels (case-insensitive)
            is_correct = predicted_label.lower() == expected_label
            if is_correct:
                correct_predictions += 1
            
            print(f"Image: {image_name}")
            print(f"Expected: {expected_label}")
            print(f"Predicted: {predicted_label} (Confidence: {confidence:.2f}%)")
            print(f"Correct: {'Yes' if is_correct else 'No'}")
            print("-" * 50)
            
        except Exception as e:
            print(f"Error processing {image_name}: {str(e)}")
    
    # Process each subfolder (each subfolder name is the expected label)
    for label_folder in os.listdir(test_data_path):
        label_path = os.path.join(test_data_path, label_folder)
        if not os.path.isdir(label_path):
            continue
            
        expected_label = label_folder.lower()
        print(f"\nProcessing images in folder: {label_folder}")
        print("=" * 60)
        
        # Process each image in the folder
        for image_name in os.listdir(label_path):
            if not image_name.lower().endswith(('.png', '.jpg', '.jpeg')):
                continue
                
            image_path = os.path.join(label_path, image_name)
            try:
                predicted_label, confidence = run_inference(interpreter, image_path)
                total_images += 1
                
                # Compare labels (case-insensitive)
                is_correct = predicted_label.lower() == expected_label
                if is_correct:
                    correct_predictions += 1
                
                print(f"Image: {image_name}")
                print(f"Expected: {expected_label}")
                print(f"Predicted: {predicted_label} (Confidence: {confidence:.2f}%)")
                print(f"Correct: {'Yes' if is_correct else 'No'}")
                print("-" * 50)
                
            except Exception as e:
                print(f"Error processing {image_name}: {str(e)}")
    
    # Calculate and print accuracy
    if total_images > 0:
        accuracy = (correct_predictions / total_images) * 100
        print(f"\nResults Summary:")
        print(f"Total images processed: {total_images}")
        print(f"Correct predictions: {correct_predictions}")
        print(f"Accuracy: {accuracy:.2f}%")
    else:
        print("\nNo images were processed.")

if __name__ == "__main__":
    process_test_data()