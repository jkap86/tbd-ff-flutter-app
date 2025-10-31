#!/usr/bin/env python3
"""
Convert PNG icon to ICO for Windows
"""
from PIL import Image
import sys

def convert_png_to_ico(png_path, ico_path):
    """Convert a PNG image to ICO format with multiple sizes"""
    try:
        # Open the PNG image
        img = Image.open(png_path)

        # Convert to RGBA if not already
        if img.mode != 'RGBA':
            img = img.convert('RGBA')

        # Create multiple sizes for the ICO
        sizes = [(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]

        # Save as ICO with multiple sizes
        img.save(ico_path, format='ICO', sizes=sizes)
        print(f"[OK] Successfully converted {png_path} to {ico_path}")
        return True
    except Exception as e:
        print(f"[ERROR] Error converting icon: {e}")
        return False

if __name__ == "__main__":
    png_path = "assets/icon/app_icon.png"
    ico_path = "windows/runner/resources/app_icon.ico"

    print(f"Converting {png_path} to {ico_path}...")
    if convert_png_to_ico(png_path, ico_path):
        print("\nIcon conversion complete!")
        print("Please rebuild the app with: flutter build windows")
    else:
        print("\nIcon conversion failed.")
        print("You may need to install Pillow: pip install Pillow")
        sys.exit(1)
