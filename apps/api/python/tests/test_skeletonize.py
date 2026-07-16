import json
import subprocess
from pathlib import Path

API_ROOT = Path(__file__).resolve().parents[2]

SCRIPT_PATH=(
    API_ROOT
    / "python"
    / "handwriting"
    / "skeletonize.py"
)

def test_skeletonize_returns_same_sized_binary_image():
    width = 7
    height = 7

    pixels = [
        255, 255, 255, 255, 255, 255, 255,
        255, 255,   0,   0,   0, 255, 255,
        255, 255,   0,   0,   0, 255, 255,
        255, 255,   0,   0,   0, 255, 255,
        255, 255,   0,   0,   0, 255, 255,
        255, 255, 255, 255, 255, 255, 255,
        255, 255, 255, 255, 255, 255, 255,
    ]

    payload = {
        "width": width,
        "height": height,
        "pixels": pixels,
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

    assert output["width"] == width
    assert output["height"] == height
    assert len(output["pixels"]) == width * height
    assert set(output["pixels"]).issubset({0, 255})
    assert any(pixel == 0 for pixel in output ["pixels"])
