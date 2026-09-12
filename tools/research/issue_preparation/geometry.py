"""Independent half-plane/square area reference for synthetic #19 tests.

Clipping and bisection are intentionally simple reference algorithms, not a
proposed per-fragment shader implementation. No upstream source code is copied.
"""
from __future__ import annotations
import math
from typing import Sequence

Point = tuple[float, float]
SQUARE: tuple[Point, ...] = ((-.5, -.5), (.5, -.5), (.5, .5), (-.5, .5))


def clip(nx: float, ny: float, alpha: float, polygon: Sequence[Point] = SQUARE) -> list[Point]:
    if not all(math.isfinite(v) for v in (nx, ny, alpha)) or nx == ny == 0:
        raise ValueError("finite, nonzero normal required")
    out: list[Point] = []
    if not polygon:
        return out
    previous = polygon[-1]
    dp = nx * previous[0] + ny * previous[1] - alpha
    for current in polygon:
        dc = nx * current[0] + ny * current[1] - alpha
        if (dc <= 0) != (dp <= 0):
            t = dp / (dp - dc)
            out.append((previous[0] + t * (current[0] - previous[0]),
                        previous[1] + t * (current[1] - previous[1])))
        if dc <= 0:
            out.append(current)
        previous, dp = current, dc
    return out


def area(polygon: Sequence[Point]) -> float:
    if len(polygon) < 3:
        return 0.0
    return abs(sum(a[0] * b[1] - b[0] * a[1]
                   for a, b in zip(polygon, (*polygon[1:], polygon[0])))) * .5


def intercept(nx: float, ny: float, fraction: float) -> float:
    if not math.isfinite(fraction) or not 0 <= fraction <= 1:
        raise ValueError("fraction must be finite and within [0,1]")
    if not all(math.isfinite(v) for v in (nx, ny)) or nx == ny == 0:
        raise ValueError("finite, nonzero normal required")
    extent = .5 * (abs(nx) + abs(ny))
    if fraction in (0, 1):
        return -extent if fraction == 0 else extent
    lo, hi = -extent, extent
    for _ in range(60):
        mid = (lo + hi) / 2
        if area(clip(nx, ny, mid)) < fraction:
            lo = mid
        else:
            hi = mid
    return (lo + hi) / 2


def sample(nx: float, ny: float, alpha: float, size: int, phase: float = .5) -> float:
    if type(size) is not int or size < 1 or not 0 < phase < 1:
        raise ValueError("positive integer grid and interior phase required")
    return sum(nx * ((x + phase) / size - .5) + ny * ((y + phase) / size - .5)
               <= alpha for x in range(size) for y in range(size)) / (size * size)


def normals() -> list[Point]:
    return [(round(math.cos(i * math.pi / 8), 15),
             round(math.sin(i * math.pi / 8), 15)) for i in range(16)]
