import json
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

FONT_DIR = Path(__file__).resolve().parent / "fonts"
FONT_PATH = FONT_DIR / "IndieFlower-Regular.ttf"

def main():
    payload = json.loads(sys.stdin.read())

    text = payload["text"]
    placement = payload["placement"]
    line_height = int(placement.get("averageLineHeight", 24))
    font_size = max(18, int(line_height * 1.25))

    if not FONT_PATH.exists():
        raise FileNotFoundError(
            f"Font file not found: {FONT_PATH}"
        )

    font = ImageFont.truetype(str(FONT_PATH), font_size)

    padding = 24
    max_width = int(placement.get("maxWidth", 520))

    dummy = Image.new("L", (18, 10), 255)
    draw = ImageDraw.Draw(dummy)

    words = text.split(" ")
    lines: list[str] = []
    current = ""

    for word in words:
        test_line = word if not current else f"{current} {word}"
        bbox = draw.textbbox((0, 0), test_line, font=font)
        test_width = bbox[2] - bbox[0]

        if test_width > max_width and current:
            lines.append(current)
            current = word
        else:
            current = test_line
    
    if current:
        lines.append(current)

    line_spacing = int(font_size * 1.2)
    image_width = max_width + padding * 2
    image_height = max(
        line_spacing * len(lines) + padding * 2, 
        font_size + padding * 2,
        )
    
    image = Image.new("L", (image_width, image_height), 255)
    draw = ImageDraw.Draw(image)

    y = padding

    for line in lines:
        draw.text(
            (padding, y), 
            line, 
            font=font, 
            fill=0,
        )
        y += line_spacing
    
    pixels = list(image.getdata())

    print(
        json.dumps(
            {
                "width": image.width,
                "height": image.height,
                "pixels": pixels,
            }
        )
    )

if __name__ == "__main__":
    main()
