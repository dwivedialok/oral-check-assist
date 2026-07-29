#!/bin/bash
# Cleanup script for Jupyter checkpoints and other junk files

echo "🧹 Cleaning up junk files..."

# Delete all .ipynb_checkpoints directories
find results -type d -name ".ipynb_checkpoints" -exec rm -rf {} + 2>/dev/null
echo "✅ Deleted .ipynb_checkpoints directories"

# Delete .DS_Store files (macOS)
find results -type f -name ".DS_Store" -delete 2>/dev/null
echo "✅ Deleted .DS_Store files"

# Delete __pycache__ directories
find results -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null
echo "✅ Deleted __pycache__ directories"

echo ""
echo "✅ Cleanup complete!"
