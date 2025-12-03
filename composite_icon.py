from PIL import Image
import os

try:
    # Open foreground
    fg_path = 'assets/icon/icon_foreground.png'
    if not os.path.exists(fg_path):
        print(f"Error: {fg_path} not found")
        exit(1)
        
    fg = Image.open(fg_path).convert("RGBA")

    # Create background
    bg = Image.new('RGBA', fg.size, '#001f3f')

    # Composite
    # Paste fg onto bg using fg as mask
    bg.paste(fg, (0, 0), fg)

    # Save
    bg.save('assets/icon/icon_full.png')
    print("Created icon_full.png")
except Exception as e:
    print(f"Error: {e}")
    exit(1)
