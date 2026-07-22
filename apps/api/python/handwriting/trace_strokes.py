import json
import sys
from collections import defaultdict


def neighbors(point):
    x, y = point

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


def build_graph(ink_pixels):
    graph = {}

    for point in ink_pixels:
        graph[point] = [
            neighbor
            for neighbor in neighbors(point)
            if neighbor in ink_pixels
        ]

    return graph


def find_components(graph):
    visited = set()
    components = []

    for start in graph:
        if start in visited:
            continue

        stack = [start]
        component = []

        while stack:
            point = stack.pop()

            if point in visited:
                continue

            visited.add(point)
            component.append(point)

            for neighbor in graph[point]:
                if neighbor not in visited:
                    stack.append(neighbor)

        components.append(component)

    return components


def edge_key(point_a, point_b):
    return tuple(sorted((point_a, point_b)))


def choose_next_point(previous, current, candidates):
    if len(candidates) == 1:
        return candidates[0]

    if previous is None:
        return min(candidates, key=lambda point: (point[1], point[0]))

    incoming_x = current[0] - previous[0]
    incoming_y = current[1] - previous[1]

    def direction_score(candidate):
        outgoing_x = candidate[0] - current[0]
        outgoing_y = candidate[1] - current[1]

        dot_product = (
            incoming_x * outgoing_x
            + incoming_y * outgoing_y
        )

        return dot_product

    return max(candidates, key=direction_score)


def trace_path(start, next_point, graph, used_edges, node_degrees):
    path = [start]
    previous = None
    current = start
    target = next_point

    while target is not None:
        edge = edge_key(current, target)

        if edge in used_edges:
            break

        used_edges.add(edge)
        path.append(target)

        previous, current = current, target

        available_neighbors = [
            neighbor
            for neighbor in graph[current]
            if edge_key(current, neighbor) not in used_edges
        ]

        if not available_neighbors:
            break

        if node_degrees[current] != 2:
            break

        target = choose_next_point(
            previous,
            current,
            available_neighbors,
        )

    return path


def trace_component_paths(component, graph):
    component_set = set(component)

    node_degrees = {
        point: len([
            neighbor
            for neighbor in graph[point]
            if neighbor in component_set
        ])
        for point in component
    }

    used_edges = set()
    paths = []

    important_nodes = [
        point
        for point in component
        if node_degrees[point] != 2
    ]

    important_nodes.sort(key=lambda point: (point[1], point[0]))

    for start in important_nodes:
        for neighbor in graph[start]:
            edge = edge_key(start, neighbor)

            if edge in used_edges:
                continue

            path = trace_path(
                start,
                neighbor,
                graph,
                used_edges,
                node_degrees,
            )

            if len(path) >= 2:
                paths.append(path)

    for start in component:
        for neighbor in graph[start]:
            edge = edge_key(start, neighbor)

            if edge in used_edges:
                continue

            path = trace_path(
                start,
                neighbor,
                graph,
                used_edges,
                node_degrees,
            )

            if len(path) >= 2:
                paths.append(path)

    return paths


def simplify_path(path, min_distance=2.0):
    if len(path) <= 2:
        return path

    simplified = [path[0]]
    last_x, last_y = path[0]

    for x, y in path[1:-1]:
        distance = (
            (x - last_x) ** 2
            + (y - last_y) ** 2
        ) ** 0.5

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

    graph = build_graph(ink_pixels)
    components = find_components(graph)

    paths = []

    for component in components:
        if len(component) < 6:
            continue

        component_paths = trace_component_paths(
            component,
            graph,
        )

        for path in component_paths:
            simplified = simplify_path(path)

            if len(simplified) < 2:
                continue

            paths.append([
                {
                    "x": x,
                    "y": y,
                }
                for x, y in simplified
            ])

    paths.sort(
        key=lambda path: (
            min(point["y"] for point in path),
            min(point["x"] for point in path),
        )
    )

    print(json.dumps({
        "paths": paths,
    }))


if __name__ == "__main__":
    main()