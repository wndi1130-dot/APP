"""The decor cells of the eight cars a player dresses (결정 506·510·511): which 0.5 m floor and wall cells are free.

Reads the cars' layouts (s2/game/train/train_life.json) and writes s2/game/train/decor_cells.json,
the one table the decorating rules (open places) and the decorating view (the grid it draws) both read.
game/train/decor_grid.gd works out the same table in the game; tests/game/test_decor_grid.gd keeps
the two equal, so run this again whenever a layout row moves.

A floor cell is blocked when a thing standing on the floor (its bottom under 0.4 m) covers more than a
tenth of it; a rug or bedding laid flat (3 cm or less) blocks nothing. The first and last columns in
front of the end doors are the door's way, and the row z3 is the walking line from door to door. Where
a thing on the back side reaches into that row (the dining car's bench before its table), the walking
line keeps its 0.5 m from that thing's edge, so the row before it is the walking line there too, and
it joins z3 four ways (a step down in a column where both rows are clear, never across a corner).
A wall cell: G a window, # something already hung there (its bottom 0.6 m up or more) or a thing
standing against that wall that rises above a wall place's foot (1.15 m), . a wall place. The end walls:
the two cells behind each door's way, left then right. Ties (a footprint covering just a tenth of a
cell, a bottom at just 0.4 m) go to free, the same in the game.

    python tools/decor_cells.py
"""
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LIFE = ROOT / "s2/game/train/train_life.json"
OUT = ROOT / "s2/game/train/decor_cells.json"
CARS = {"tail1": "coach", "tail2": "coach", "tail3": "coach", "medtech": "medical", "guard": "guard", "front": "front",
        "captain": "captain", "dining": "dining"}
CELL = 0.5
NX, NZ = 31, 5
X0, Z0 = 0.25, -1.25
DOOR = (0.2, 1.1)
WALK_ROW = 3
WALK_WIDTH = 0.5
AISLE_Z = 0.65          # where the train's people walk (train_scene.gd AISLE_Z)
FLOOR_BOTTOM = 0.4
FLAT = 0.03
SHARE = 0.10
HUNG = 0.6
PLACE_LOW = 1.15        # a wall place's foot (decor_view.gd: 1.45 m middle, 0.6 m high)
BACK_WALL = -1.24
END_WALLS = (0.15, 15.85)
EPS = 1e-6
WINDOWS = [(1.2, 2.8), (5.2, 6.8), (9.2, 10.8), (13.2, 14.8)]


def footprint(at, size, yaw):
    """Corners of the turned footprint on the floor (x, z), as Godot turns about y."""
    hx, hz = size[0] / 2, size[2] / 2
    c, s = math.cos(yaw), math.sin(yaw)
    return [(at[0] + dx * c + dz * s, at[2] - dx * s + dz * c) for dx, dz in [(-hx, -hz), (hx, -hz), (hx, hz), (-hx, hz)]]


def clip(poly, edge):
    out = []
    for i in range(len(poly)):
        a, b = poly[i], poly[(i + 1) % len(poly)]
        fa, fb = edge(a), edge(b)
        if fa >= 0:
            out.append(a)
        if (fa >= 0) != (fb >= 0):
            t = fa / (fa - fb)
            out.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
    return out


def area(poly):
    if len(poly) < 3:
        return 0.0
    return abs(sum(poly[i][0] * poly[(i + 1) % len(poly)][1] - poly[(i + 1) % len(poly)][0] * poly[i][1] for i in range(len(poly)))) / 2


def covered(poly, x0, z0):
    p = poly
    for e in [lambda q: q[0] - x0, lambda q: x0 + CELL - q[0], lambda q: q[1] - z0, lambda q: z0 + CELL - q[1]]:
        p = clip(p, e)
        if not p:
            return 0.0
    return area(p)


def bounds(row):
    """x0, x1, z0, z1, bottom, top of a row's turned box."""
    at, size = row["at"], row.get("size", [0.8, 1.0, 0.8])
    pts = footprint(at, size, float(row.get("yaw", 0.0)))
    return (min(p[0] for p in pts), max(p[0] for p in pts), min(p[1] for p in pts), max(p[1] for p in pts),
            at[1] - size[1] / 2, at[1] + size[1] / 2)


def on_floor(row):
    size = row.get("size", [0.8, 1.0, 0.8])
    return size[1] > FLAT + EPS and row["at"][1] - size[1] / 2 < FLOOR_BOTTOM - EPS


def blocks_wall(b):
    """Something hung, or standing against the wall above a wall place's foot."""
    return b[4] >= HUNG - EPS or b[5] > PLACE_LOW + EPS


def car_cells(rows):
    grid = [["." for _ in range(NX)] for _ in range(NZ)]
    reach = [Z0 + WALK_ROW * CELL] * NX     # how far the things behind the walking line reach, per column
    for row in rows:
        if not on_floor(row):
            continue
        poly = footprint(row["at"], row.get("size", [0.8, 1.0, 0.8]), float(row.get("yaw", 0.0)))
        b = bounds(row)
        mark = "S" if row.get("system") == "stove" else "#"
        for iz in range(NZ):
            for ix in range(NX):
                if covered(poly, X0 + ix * CELL, Z0 + iz * CELL) > SHARE * CELL * CELL + EPS:
                    grid[iz][ix] = mark
        if b[3] < AISLE_Z:
            for ix in range(NX):
                x0 = X0 + ix * CELL
                if b[0] < x0 + CELL - EPS and b[1] > x0 + EPS:
                    reach[ix] = max(reach[ix], b[3])
    for iz in range(NZ):
        z0 = Z0 + iz * CELL
        if z0 < DOOR[1] and z0 + CELL > DOOR[0]:
            for ix in (0, NX - 1):
                if grid[iz][ix] == ".":
                    grid[iz][ix] = "D"
    for ix in range(NX):
        for iz in range(WALK_ROW, NZ):
            z0 = Z0 + iz * CELL
            if (iz == WALK_ROW or z0 < reach[ix] + WALK_WIDTH - EPS) and grid[iz][ix] == ".":
                grid[iz][ix] = "W"
    # The way walks four ways, never across a corner (코디 10-30, the decorating rules' path check): a run
    # of a row past z3 walked for a thing reaching into z3 joins z3 in its own end column, or else the
    # column beside it walks that row too, so the people step down where both rows are clear.
    for iz in range(WALK_ROW + 1, NZ):
        ix = 0
        while ix < NX:
            if grid[iz][ix] != "W":
                ix += 1
                continue
            a = ix
            while ix < NX and grid[iz][ix] == "W":
                ix += 1
            b = ix - 1
            for end, side in ((a, a - 1), (b, b + 1)):
                if grid[iz - 1][end] not in "WD" and 0 <= side < NX and grid[iz][side] == ".":
                    grid[iz][side] = "W"
                    ix = max(ix, side + 1)
    back = []
    for ix in range(NX):
        x0 = X0 + ix * CELL
        mark = "G" if any(x0 < w1 and x0 + CELL > w0 for w0, w1 in WINDOWS) else "."
        for row in rows:
            b = bounds(row)
            if b[2] <= BACK_WALL + EPS and blocks_wall(b) and x0 < b[1] - 0.05 and x0 + CELL > b[0] + 0.05:
                mark = "#"
        back.append(mark)
    ends = []
    for left in (True, False):
        for iz in (0, 1):
            z0 = Z0 + iz * CELL
            mark = "."
            for row in rows:
                b = bounds(row)
                near = b[0] <= END_WALLS[0] + EPS if left else b[1] >= END_WALLS[1] - EPS
                if near and blocks_wall(b) and z0 < b[3] and z0 + CELL > b[2]:
                    mark = "#"
            ends.append(mark)
    floor = ["".join(r) for r in grid]
    return {"floor": floor, "back_wall": "".join(back), "end_walls": "".join(ends),
            "floor_free": sum(r.count(".") for r in floor), "wall_free": back.count(".") + ends.count(".")}


def main():
    layouts = json.loads(LIFE.read_text(encoding="utf-8"))["layouts"]
    cars = {}
    for car, lay in CARS.items():
        rows = [r for r in layouts[lay]["props"] if "cars" not in r or car in r["cars"]]
        cars[car] = {"layout": lay, **car_cells(rows)}
    table = {"cell_m": CELL, "origin": [X0, Z0], "cells": [NX, NZ], "walk_row": WALK_ROW,
             "marks": {".": "free", "#": "a thing", "S": "the stove", "D": "a door's way", "W": "the walking line", "G": "a window"},
             "cars": cars}
    text = json.dumps(table, ensure_ascii=False, indent=1) + "\n"
    # Written only when it changes, so a run that finds nothing new leaves the file (and git) alone.
    if not OUT.exists() or OUT.read_text(encoding="utf-8").replace("\r\n", "\n") != text:
        OUT.write_text(text, encoding="utf-8", newline="\n")
    print({c: (v["floor_free"], v["wall_free"]) for c, v in cars.items()})


if __name__ == "__main__":
    main()
