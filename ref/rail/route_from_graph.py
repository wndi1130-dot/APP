"""Find continuous shortest rail routes using only a saved graph and the stdlib."""

from __future__ import annotations

import argparse
from collections import defaultdict
import heapq
import json
import math
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent
ROUTE_FIELDS = ("status", "length_m", "start_node", "end_node", "waypoints", "path")


def calculate_route(graph, station_keys):
    """Run multi-source Dijkstra over (track node, ordered waypoint progress).

    Advancing a waypoint preserves the current track node. Station anchors are
    never joined, and independently optimal station-to-station legs are not
    concatenated. Keep the original fetch.py ordering and result schema so saved
    routes remain reproducible, including ties and reverse edge traversals.
    """
    if not station_keys:
        raise ValueError("경유역을 한 곳 이상 지정해야 합니다.")
    stations = {s["id"]: s for s in graph["stations"]}
    if any(key not in stations for key in station_keys):
        return {"status": "unconfirmed", "reason": "필수 경유역이 원본에서 미확인"}
    target_sets = [{a["node_id"] for a in stations[key]["anchors"]} for key in station_keys]
    adj = defaultdict(list)
    edge_ids = set()
    for edge in graph["edges"]:
        length = edge["length_m"]
        if isinstance(length, bool) or not isinstance(length, (int, float)) or not math.isfinite(length) or length <= 0:
            raise ValueError(f"구간 {edge['id']}: 길이는 유한한 양수여야 합니다.")
        if edge["id"] in edge_ids:
            raise ValueError(f"구간 ID가 중복되었습니다: {edge['id']}")
        edge_ids.add(edge["id"])
        adj[edge["from"]].append((edge["to"], length, edge["id"], True))
        adj[edge["to"]].append((edge["from"], length, edge["id"], False))
    distances, previous, queue = {}, {}, []
    for node in sorted(target_sets[0]):
        state = (node, 1)
        distances[state] = 0
        heapq.heappush(queue, (0, state))
    end = None
    while queue:
        cost, state = heapq.heappop(queue)
        if cost != distances.get(state):
            continue
        node, progress = state
        if progress == len(target_sets):
            end = state
            break
        if node in target_sets[progress]:
            next_state = node, progress + 1
            if cost < distances.get(next_state, math.inf):
                distances[next_state] = cost
                previous[next_state] = (state, None, True)
                heapq.heappush(queue, (cost, next_state))
        for neighbor, length, eid, forward in adj[node]:
            next_state, next_cost = (neighbor, progress), cost + length
            if next_cost < distances.get(next_state, math.inf):
                distances[next_state] = next_cost
                previous[next_state] = (state, eid, forward)
                heapq.heappush(queue, (next_cost, next_state))
    if end is None:
        return {"status": "unconfirmed", "reason": "선택된 OSM 선로에서 모든 경유역을 연결하는 경로가 미확인"}
    path, passes = [], []
    state = end
    while state in previous:
        prior, eid, forward = previous[state]
        if eid is not None:
            path.append({"edge_id": eid, "forward": forward})
        else:
            passes.append({"station_id": station_keys[state[1] - 1], "node_id": state[0],
                           "distance_from_start_m": round(distances[state], 3)})
        state = prior
    passes.append({"station_id": station_keys[0], "node_id": state[0], "distance_from_start_m": 0})
    return {"status": "connected", "length_m": round(distances[end], 3), "start_node": state[0], "end_node": end[0],
            "waypoints": list(reversed(passes)), "path": list(reversed(path))}


def same_route_value(actual, stored):
    """Compare route data without treating JSON booleans as numeric 0 or 1."""
    if isinstance(actual, bool) or isinstance(stored, bool):
        return type(actual) is type(stored) and actual == stored
    if isinstance(actual, dict) and isinstance(stored, dict):
        return actual.keys() == stored.keys() and all(same_route_value(actual[key], stored[key]) for key in actual)
    if isinstance(actual, list) and isinstance(stored, list):
        return len(actual) == len(stored) and all(same_route_value(a, b) for a, b in zip(actual, stored))
    return actual == stored


def check_saved_routes(graph):
    """Recompute saved station sequences; never use their cached paths as input."""
    saved_routes = graph.get("routes", [])
    if not saved_routes:
        raise ValueError("그래프에 대조할 저장 경로가 없습니다.")
    checks = []
    for saved in saved_routes:
        result = calculate_route(graph, saved["station_ids"])
        differences = [field for field in ROUTE_FIELDS if not same_route_value(result.get(field), saved.get(field))]
        passed = result["status"] == "connected" and not differences
        checks.append({"id": saved["id"], "status": "PASS" if passed else "FAIL",
                       "stored_length_m": saved.get("length_m"), "calculated_length_m": result.get("length_m"),
                       "different_fields": differences})
    return checks


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="graph.json만 읽어 실제 선로가 이어지는 역 간 최단 경로를 계산합니다.",
        epilog="예: python3 ref/rail/route_from_graph.py wolsztyn zbaszynek cottbus leipzig")
    parser.add_argument("stations", nargs="*", metavar="역_ID", help="출발역, 경유역, 도착역 ID를 순서대로 입력")
    parser.add_argument("--graph", type=Path, default=ROOT / "graph.json", help="읽을 그래프 JSON 경로")
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument("--route", metavar="경로_ID", help="저장 경로의 역 목록을 사용해 새로 계산")
    modes.add_argument("--check", action="store_true", help="저장된 모든 경로의 거리·선로·경유점을 다시 계산해 대조")
    modes.add_argument("--list-stations", action="store_true", help="사용할 수 있는 역 ID와 이름 표시")
    parser.add_argument("--json", action="store_true", help="선로 ID·방향·경유점까지 포함한 JSON 출력")
    args = parser.parse_args(argv)
    if args.stations and (args.route or args.check or args.list_stations):
        parser.error("역 ID 목록과 --route/--check/--list-stations는 함께 사용할 수 없습니다.")
    if not (args.route or args.check or args.list_stations) and len(args.stations) < 2:
        parser.error("출발역과 도착역을 지정하거나 --route, --check, --list-stations를 사용하세요.")
    try:
        graph = json.loads(args.graph.read_text(encoding="utf-8"))
        if args.check:
            checks = check_saved_routes(graph)
            if args.json:
                print(json.dumps(checks, ensure_ascii=False, indent=2))
            else:
                for check in checks:
                    length = check["calculated_length_m"]
                    measured = f"{length:.3f}m" if length is not None else "미확인"
                    print(f"[{check['status']}] {check['id']}: 재계산 {measured}, 저장 {check['stored_length_m']}m")
                    if check["different_fields"]:
                        print("  불일치: " + ", ".join(check["different_fields"]))
            return 0 if all(c["status"] == "PASS" for c in checks) else 1
        if args.list_stations:
            rows = [{key: station[key] for key in ("id", "name", "name_original")} for station in graph["stations"]]
            if args.json:
                print(json.dumps(rows, ensure_ascii=False, indent=2))
            else:
                for row in rows:
                    print(f"{row['id']}: {row['name']} ({row['name_original']})")
            return 0
        station_keys = args.stations
        if args.route:
            saved = next((route for route in graph.get("routes", []) if route["id"] == args.route), None)
            if saved is None:
                raise ValueError(f"저장 경로 ID를 찾을 수 없습니다: {args.route}")
            station_keys = saved["station_ids"]
        result = calculate_route(graph, station_keys)
        if args.json:
            report = {"station_ids": station_keys, **result,
                      "osm_base": graph.get("source", {}).get("osm_base"),
                      "attribution": graph.get("attribution"), "license": graph.get("license")}
            print(json.dumps(report, ensure_ascii=False, indent=2))
        elif result["status"] != "connected":
            print(f"[WATCH] {result['reason']}")
        else:
            stations = {s["id"]: s for s in graph["stations"]}
            print(" → ".join(stations[key].get("name", key) for key in station_keys))
            print(f"[PASS] 선로 연결 확인: {result['length_m'] / 1000:.3f}km ({result['length_m']:.3f}m)")
            for a, b in zip(result["waypoints"], result["waypoints"][1:]):
                length = b["distance_from_start_m"] - a["distance_from_start_m"]
                print(f"  {a['station_id']} → {b['station_id']}: {length / 1000:.3f}km; "
                      f"누적 {b['distance_from_start_m'] / 1000:.3f}km")
        return 0 if result["status"] == "connected" else 1
    except (OSError, ValueError, KeyError, TypeError) as exc:
        print(f"[FAIL] 경로 계산 오류: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
