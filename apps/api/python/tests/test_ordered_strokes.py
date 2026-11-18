import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'handwriting'))
from ordered_strokes import generate


def test_character_order():
    strokes = generate('Hi!\nOK', {'averageLineHeight': 24, 'maxWidth': 520})
    indices = [s['characterIndex'] for s in strokes]
    assert indices == sorted(indices)
    assert 0 in indices and 1 in indices and 4 in indices


def test_wrap_and_spacing():
    strokes = generate('AAAA', {'averageLineHeight': 24, 'maxWidth': 25})
    first = next(s for s in strokes if s['characterIndex'] == 0)
    second = next(s for s in strokes if s['characterIndex'] == 1)
    assert min(p['y'] for p in second['points']) > min(p['y'] for p in first['points'])
