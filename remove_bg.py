from PIL import Image

def remove_background(input_path, output_path, tolerance=30):
    img = Image.open(input_path)
    img = img.convert("RGBA")
    
    datas = img.getdata()
    
    # Get background color from top-left pixel
    bg_color = datas[0]
    print(f"Detected background color: {bg_color}")
    
    newData = []
    
    for item in datas:
        # Check if pixel is close to background color
        if (abs(item[0] - bg_color[0]) < tolerance and
            abs(item[1] - bg_color[1]) < tolerance and
            abs(item[2] - bg_color[2]) < tolerance):
            newData.append((255, 255, 255, 0)) # Make Transparent
        else:
            newData.append(item)
            
    img.putdata(newData)
    img.save(output_path, "PNG")
    print(f"Saved transparent icon to {output_path}")

if __name__ == "__main__":
    # Change the filename below to target a different icon if needed
    remove_background("assets/icon/icon_full.png", "assets/icon/icon_full.png")
