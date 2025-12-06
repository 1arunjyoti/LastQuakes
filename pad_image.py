from PIL import Image

def add_padding(input_path, output_path, padding_ratio=0.5):
    try:
        img = Image.open(input_path).convert("RGBA")
        width, height = img.size
        
        # Calculate new size based on padding ratio (e.g., 0.5 means original is 50% of new size)
        # So new_size = original_size / padding_ratio
        new_width = int(width / padding_ratio)
        new_height = int(height / padding_ratio)
        
        # Create a new transparent image
        new_img = Image.new("RGBA", (new_width, new_height), (0, 0, 0, 0))
        
        # Paste the original image in the center
        x_offset = (new_width - width) // 2
        y_offset = (new_height - height) // 2
        new_img.paste(img, (x_offset, y_offset), img)
        
        new_img.save(output_path)
        print(f"Successfully created padded image at {output_path}")
    except Exception as e:
        print(f"Error processing image: {e}")

if __name__ == "__main__":
    add_padding('assets/icon/icon_full.png', 'assets/splash/icon_foreground_padded.png', 0.6)
