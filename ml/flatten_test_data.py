import os
import shutil

def flatten_test_data(base_path="test_data"):
    """
    Reads images from label-named subfolders within a base path,
    prefixes the label to the image file name, and moves them
    to the base path. Then, removes the empty subfolders.

    Args:
        base_path (str): The path to the directory containing
                         the label subfolders (e.g., 'test_data').
    """
    # Check if the base_path exists
    if not os.path.isdir(base_path):
        print(f"Error: Directory '{base_path}' not found.")
        return

    print(f"Starting to flatten directory: {base_path}")

    # List all items in the base_path
    for item_name in os.listdir(base_path):
        item_path = os.path.join(base_path, item_name)

        # Check if it's a directory (i.e., a label subfolder)
        if os.path.isdir(item_path):
            label = item_name  # The directory name is the label
            print(f"\nProcessing label folder: '{label}'")

            # List all files within the label subfolder
            for file_name in os.listdir(item_path):
                old_file_path = os.path.join(item_path, file_name)

                # Ensure it's a file and not another directory
                if os.path.isfile(old_file_path):
                    # Create the new file name: label_originalfilename.extension
                    new_file_name = f"{label}_{file_name}"
                    new_file_path = os.path.join(base_path, new_file_name)

                    try:
                        # Move the file to the base_path with the new name
                        shutil.move(old_file_path, new_file_path)
                        print(f"  Moved '{file_name}' to '{new_file_name}'")
                    except Exception as e:
                        print(f"  Error moving '{file_name}': {e}")
                else:
                    print(f"  Skipping non-file item in '{label}' folder: {file_name}")

            # After moving all files, remove the now empty label subfolder
            try:
                shutil.rmtree(item_path)
                print(f"Removed empty label folder: '{label}'")
            except Exception as e:
                print(f"Error removing folder '{label}': {e}")
        else:
            print(f"Skipping non-directory item in base_path: {item_name}")

    print("\nFlattening complete!")

if __name__ == "__main__":
    # You can change 'test_data' if your folder has a different name
    flatten_test_data("test_data")