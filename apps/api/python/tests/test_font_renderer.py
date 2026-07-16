import json
import subprocess
from pathlib import Path

API_ROOT = Path(__file__).resolve().parents[2]

SCRIPT_PATH = (
    API_ROOT
    / "python"
    / "handwriting"
    / "font_renderer.py"    
)

def test_font_renderer_returns_valid_image_data():
    payload = {
        "text": "Hello world",
        "placement": {
            "x": 100,
            "y": 200,
            "averageLineHeight": 24,
            "width": 1.3,
            "color": "#111111",
            "maxWidth": 520,
        },
    }

    result = subprocess.run(
        ["python3", str(SCRIPT_PATH)],
        input=json.dumps(payload),
        text=True,
        capture_output=True,
        check=False,
    )

    assert result.returncode == 0, result.stderr

    output = json.loads(result.stdout)

    assert output["width"] > 0
    assert output["height"] > 0
    assert isinstance(output["pixels"], list)

    expected_pixel_count = output["width"] * output["height"]

    assert len(output["pixels"]) == expected_pixel_count
    assert min(output["pixels"]) >= 0
    assert max(output["pixels"]) <= 255

    # A rendered image should contain at least some dark ink pixels
    assert any(pixel < 255 for pixel in output["pixels"])