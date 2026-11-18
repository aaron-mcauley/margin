import json
import sys
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from trace_strokes import build_graph, find_components, trace_component_paths, simplify_path

FONT = Path(__file__).resolve().parent / 'fonts' / 'IndieFlower-Regular.ttf'


def glyph_paths(character, font):
    # Render glyph independently so the tracer cannot mix strokes from other letters.
    bbox = font.getbbox(character)
    if bbox is None:
        return [], 0
    advance = float(font.getlength(character))
    if character.isspace():
        return [], advance
    pad = 5
    w = max(1, bbox[2] - bbox[0]) + pad * 2
    h = max(1, bbox[3] - bbox[1]) + pad * 2
    image = Image.new('L', (w, h), 255)
    ImageDraw.Draw(image).text((pad - bbox[0], pad - bbox[1]), character, font=font, fill=0)
    arr = np.asarray(image)
    _, binary = cv2.threshold(arr, 200, 255, cv2.THRESH_BINARY_INV)
    if hasattr(cv2, "ximgproc"):
        thin = cv2.ximgproc.thinning(binary, thinningType=cv2.ximgproc.THINNING_ZHANGSUEN)
    else:
        from skimage.morphology import skeletonize
        thin = (skeletonize(binary > 0).astype(np.uint8) * 255)
    ys, xs = np.where(thin > 0)
    ink = set(zip(xs.tolist(), ys.tolist()))
    graph = build_graph(ink)
    paths = []
    for component in find_components(graph):
        if len(component) < 6:
            continue
        for path in trace_component_paths(component, graph):
            path = simplify_path(path)
            if len(path) >= 2:
                # Keep the path direction deterministic; within each character
                # choose the upper-left endpoint as the first pen contact.
                if (path[-1][0], path[-1][1]) < (path[0][0], path[0][1]):
                    path.reverse()
                paths.append(path)
    paths.sort(key=lambda p: (min(x for x, _ in p), min(y for _, y in p)))
    # Convert crop-relative points to baseline-relative coordinates.
    return [[(x + bbox[0] - pad, y + bbox[1] - pad) for x, y in path] for path in paths], advance


def generate(text, placement):
    line_height = float(placement.get('averageLineHeight', 24))
    font = ImageFont.truetype(str(FONT), max(18, int(line_height * 1.25)))
    max_width = float(placement.get('maxWidth', 520))
    if max_width <= 0:
        raise ValueError('maxWidth must be positive')
    line_step = max(line_height, float(font.size) * 1.2)
    x = y = 0.0
    result = []
    for index, character in enumerate(text):
        if character == '\n':
            x = 0.0
            y += line_step
            continue
        paths, advance = glyph_paths(character, font)
        if x > 0 and x + advance > max_width and not character.isspace():
            x = 0.0
            y += line_step
        if character.isspace() and x == 0:
            continue
        for path in paths:
            result.append({
                'characterIndex': index,
                'character': character,
                'points': [{'x': round(x + px, 3), 'y': round(y + py, 3)} for px, py in path],
            })
        x += advance
    return result


def main():
    payload = json.load(sys.stdin)
    print(json.dumps({'strokes': generate(payload['text'], payload['placement'])}))


if __name__ == '__main__':
    main()
