import json
import sys
from collections import defaultdict

def neighbors(x, y):
    return [
        (x - 1, y - 1),
        (x, y - 1),
        (x + 1, y - 1),
        (x - 1, y),
        (x + 1, y),
        (x - 1, y + 1),
        (x, y + 1),
        (x + 1, y + 1),
    ]

def trace_component(start, ink_pixels, visited):
    stack = [start]
    component = []

    while stack:
        point = stack.pop()

        if point in visited:
            continue

        visited.add(point)
        component.append(point)

        x, y = point

        for n in neighbors(x, y):
            if n in ink_pixels and n not in visited:
                stack.append(n)

    return component

def order_path(component):
    component_set = set(component)

    neighbor_count = defaultdict(int)

    for x, y in component:
        for n in neighbors(x, y):
            if n in component_set:
                neighbor_count[(x, y)] += 1

    endpoints = [point for point in component if neighbor_count[point] == 1]

    start = endpoints[0] if endpoints else component[0]

    ordered = []
    visited = set()
    current = start 

    while current:
        ordered.append(current)
        visited.add(current)

        x, y = current

        next_points = [
            n for n in neighbors(x, y)
            if n in component_set and n not in visited
        ]

        current = next_points[0] if next_points else None

    return ordered

def simplify_path(path, min_distance=2):
    if len(path) <= 2:
        return path
    
    simplified = [path[0]]
    last_x, last_y = path[0]

    for x, y in path[1:]:
        distance = ((x - last_x) ** 2 + (y - last_y) ** 2) ** 0.5

        if distance >= min_distance:
            simplified.append((x, y))
            last_x, last_y = x, y
        
    if simplified[-1] != path[-1]:
        simplified.append(path[-1])

    return simplified

def main(): 
    payload = json.loads(sys.stdin.read())

    width = payload["width"]
    height = payload["height"]
    pixels = payload["pixels"]

    ink_pixels = set()

    for y in range(height):
        for x in range(width):
            value = pixels[y * width + x]

            if value < 128:
                ink_pixels.add((x, y))

    visited = set()
    paths = []

    for point in ink_pixels:
        if point in visited:
            continue

        component = trace_component(point, ink_pixels, visited)

        if len(component) < 6:
            continue

        ordered = order_path(component)
        simplified = simplify_path(ordered)

        if len(simplified) < 2:
            continue
        paths.append([
            {"x": x, "y": y}
            for x, y in simplified
        ])

    paths.sort(key=lambda path: (path[0]["y"], path[0]["x"]))

    print (json.dumps({"paths": paths}))


if __name__ == "__main__":
    main()
