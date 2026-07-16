import json
import subprocess
from pathlib import Path


API_ROOT = Path(__file__).resolve().parents[2]

SCRIPT_PATH = (
    API_ROOT
    / "python"
    / "handwriting"
    / "trace_strokes.py"
)


def test_trace_strokes_returns_ordered_paths():
    width = 9
    height = 9

    # White background with one thin black horizontal stroke.
    pixels = [
    255,255,255,255,255,255,255,255,255,
    255,255,255,255,255,255,255,255,255,
    255,255,255,255,255,255,255,255,255,

    255,0,0,0,0,0,0,0,255,

    255,255,255,255,255,255,255,255,255,
    255,255,255,255,255,255,255,255,255,
    255,255,255,255,255,255,255,255,255,
    255,255,255,255,255,255,255,255,255,
    255,255,255,255,255,255,255,255,255,
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

    assert "paths" in output
    assert isinstance(output["paths"], list)
    assert len(output["paths"]) == 1

    path = output["paths"][0]

    assert len(path) >= 2

    for point in path:
        assert "x" in point
        assert "y" in point
        assert isinstance(point["x"], int)
        assert isinstance(point["y"], int)

    xs = [point["x"] for point in path]
    ys = [point["y"] for point in path]

    assert min(xs) == 1
    assert max(xs) == 7
    assert set(ys) == {3}