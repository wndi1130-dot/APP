"""Fetch OSM rail data and build a reproducible, topology-preserving reference."""

from __future__ import annotations

import argparse
from collections import defaultdict
from datetime import datetime, timezone
import gzip
import hashlib
import heapq
import html
import json
import math
from pathlib import Path
import re
import time
import urllib.error
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parent
BBOX = (48.45, 10.7, 54.8, 19.0)  # south, west, north, east
ENDPOINT = "https://overpass-api.de/api/interpreter"
ATTRIBUTION = "© OpenStreetMap contributors"
LICENSE = "https://opendatacommons.org/licenses/odbl/1-0/"

# Regional hubs and the requested route stops; names are only selectors.
# Coordinates and names in the outputs always come from OSM, never this list.
STATION_SPECS = [
    ("wolsztyn", "볼슈틴", r"^Wolsztyn$"),
    ("poznan", "포즈난 중앙역", r"^Poznań Główny$"),
    ("zbaszyn", "즈봉신", r"^Zbąszyń$"),
    ("zbaszynek", "즈봉시네크", r"^Zbąszynek$"),
    ("rzepin", "제핀", r"^Rzepin$"),
    ("leszno", "레슈노", r"^Leszno$"),
    ("wroclaw", "브로츠와프 중앙역", r"^Wrocław Główny$"),
    ("legnica", "레그니차", r"^Legnica$"),
    ("wegliniec", "벵글리니에츠", r"^Węgliniec$"),
    ("zielona_gora", "지엘로나구라 중앙역", r"^Zielona Góra Główna$"),
    ("glogow", "그워구프", r"^Głogów$"),
    ("zagan", "자간", r"^Żagań$"),
    ("jelenia_gora", "옐레니아구라", r"^Jelenia Góra$"),
    ("walbrzych", "바우브지흐 중앙역", r"^Wałbrzych Główny$"),
    ("opole", "오폴레 중앙역", r"^Opole Główne$"),
    ("szczecin", "슈체친 중앙역", r"^Szczecin Główny$"),
    ("kostrzyn", "코스트신", r"^Kostrzyn$"),
    ("gorzow", "고주프비엘코폴스키", r"^Gorzów Wielkopolski$"),
    ("pila", "피와 중앙역", r"^Piła Główna$"),
    ("krzyz", "크시시", r"^Krzyż$"),
    ("poznan_franowo", "포즈난 프라노보 화물역", r"^Poznań Franowo$"),
    ("wroclaw_brochow", "브로츠와프 브로후프 화물역", r"^Wrocław Brochów$"),
    ("leipzig", "라이프치히 중앙역", r"^Leipzig (Hbf|Hauptbahnhof)$"),
    ("berlin", "베를린 중앙역", r"^Berlin (Hbf|Hauptbahnhof)$"),
    ("frankfurt", "프랑크푸르트 오데르", r"^Frankfurt \(Oder\)$"),
    ("cottbus", "콧부스 중앙역", r"^Cottbus (Hbf|Hauptbahnhof)($| /)"),
    ("dresden", "드레스덴 중앙역", r"^Dresden (Hbf|Hauptbahnhof)$"),
    ("goerlitz", "괴를리츠", r"^Görlitz$"),
    ("halle", "할레 중앙역", r"^Halle \(Saale\) (Hbf|Hauptbahnhof)$"),
    ("erfurt", "에르푸르트 중앙역", r"^Erfurt (Hbf|Hauptbahnhof)$"),
    ("magdeburg", "마그데부르크 중앙역", r"^Magdeburg (Hbf|Hauptbahnhof)$"),
    ("dessau", "데사우 중앙역", r"^Dessau (Hbf|Hauptbahnhof)$"),
    ("wittenberg", "루터슈타트 비텐베르크 중앙역", r"^Lutherstadt Wittenberg (Hbf|Hauptbahnhof)$"),
    ("chemnitz", "켐니츠 중앙역", r"^Chemnitz (Hbf|Hauptbahnhof)$"),
    ("zwickau", "츠비카우 중앙역", r"^Zwickau \(Sachs(en)?\) (Hbf|Hauptbahnhof)$"),
    ("rostock", "로스토크 중앙역", r"^Rostock (Hbf|Hauptbahnhof)$"),
    ("schwerin", "슈베린 중앙역", r"^Schwerin (Hbf|Hauptbahnhof)$"),
    ("wittenberge", "비텐베르게", r"^Wittenberge$"),
    ("neubrandenburg", "노이브란덴부르크", r"^Neubrandenburg$"),
    ("pasewalk", "파제발크", r"^Pasewalk$"),
    ("stralsund", "슈트랄준트 중앙역", r"^Stralsund (Hbf|Hauptbahnhof)$"),
    ("ruegendamm", "슈트랄준트 뤼겐담역", r"^Stralsund Rügendamm$"),
    ("bergen", "베르겐 아우프 뤼겐", r"^Bergen auf Rügen$"),
    ("lietzow", "리초", r"^Lietzow( \(Rügen\))?$"),
    ("sassnitz", "자스니츠", r"^Sassnitz$"),
    ("seddin", "제딘 화물역", r"^(Seddin( Süd)?|Rangierbahnhof Seddin)$"),
    ("mukran", "무크란 화물역", r"^(Mukran|Sassnitz-Mukran)( Gbf .*)?$"),
    ("engelsdorf", "라이프치히 엥겔스도르프 화물역", r"^(Leipzig[- ]Engelsdorf|Engelsdorf)$"),
    ("friedrichstadt", "드레스덴 프리드리히슈타트", r"^Dresden[- ]Friedrichstadt$"),
    ("praha", "프라하 중앙역", r"^Praha hlavní nádraží$"),
    ("brno", "브르노 중앙역", r"^Brno hlavní nádraží$"),
    ("ostrava", "오스트라바 중앙역", r"^Ostrava hlavní nádraží$"),
    ("olomouc", "올로모우츠 중앙역", r"^Olomouc hlavní nádraží$"),
    ("plzen", "플젠 중앙역", r"^Plzeň hlavní nádraží$"),
    ("pardubice", "파르두비체 중앙역", r"^Pardubice hlavní nádraží$"),
    ("ceska_trebova", "체스카트르제보바", r"^Česká Třebová$"),
    ("decin", "데친 중앙역", r"^Děčín hlavní nádraží$"),
    ("usti", "우스티나트라벰 중앙역", r"^Ústí nad Labem hlavní nádraží$"),
    ("liberec", "리베레츠", r"^Liberec$"),
    ("hradec", "흐라데츠크랄로베 중앙역", r"^Hradec Králové hlavní nádraží$"),
    ("budejovice", "체스케부데요비체", r"^České Budějovice$"),
    ("jihlava", "이흘라바", r"^Jihlava$"),
    ("cheb", "헤프", r"^Cheb$"),
    ("karlovy_vary", "카를로비바리", r"^Karlovy Vary$"),
    ("prerov", "프르제로프", r"^Přerov$"),
    ("chomutov", "호무토프", r"^Chomutov$"),
    ("havlickuv_brod", "하블리치쿠프브로트", r"^Havlíčkův Brod$"),
]
ROUTE_SPECS = [
    ("west_via_berlin", "볼슈틴에서 라이프치히: 오데르·베를린 경유", ["wolsztyn", "poznan", "zbaszynek", "rzepin", "frankfurt", "berlin", "leipzig"]),
    ("west_via_dresden", "볼슈틴에서 라이프치히: 브로츠와프·드레스덴 경유", ["wolsztyn", "poznan", "leszno", "wroclaw", "legnica", "wegliniec", "goerlitz", "dresden", "leipzig"]),
    ("north_to_sassnitz", "라이프치히에서 자스니츠: 베를린·뤼겐 둑길 경유", ["leipzig", "berlin", "stralsund", "ruegendamm", "bergen", "lietzow", "sassnitz"]),
    ("czech_corridor", "체코 간선: 데친·프라하·브르노·오스트라바", ["decin", "praha", "pardubice", "ceska_trebova", "brno", "prerov", "ostrava"]),
]


def distance(a, b):
    lon1, lat1, lon2, lat2 = map(math.radians, (*a, *b))
    h = math.sin((lat2 - lat1) / 2) ** 2 + math.cos(lat1) * math.cos(lat2) * math.sin((lon2 - lon1) / 2) ** 2
    return 6371008.8 * 2 * math.asin(min(1, math.sqrt(h)))


def xy(point):
    return point[0] * 111195 * math.cos(math.radians(51.6)), point[1] * 111195


def simplify(points, tolerance=25):
    """Iterative Douglas-Peucker in a local metric projection; retain endpoints."""
    if len(points) <= 2:
        return points
    projected = list(map(xy, points))
    keep = {0, len(points) - 1}
    stack = [(0, len(points) - 1)]
    while stack:
        lo, hi = stack.pop()
        ax, ay = projected[lo]
        bx, by = projected[hi]
        dx, dy = bx - ax, by - ay
        denom = dx * dx + dy * dy
        best, index = tolerance * tolerance, None
        for i in range(lo + 1, hi):
            px, py = projected[i]
            t = max(0, min(1, ((px - ax) * dx + (py - ay) * dy) / denom)) if denom else 0
            error = (px - ax - t * dx) ** 2 + (py - ay - t * dy) ** 2
            if error > best:
                best, index = error, i
        if index is not None:
            keep.add(index)
            stack.extend([(lo, index), (index, hi)])
    return [points[i] for i in sorted(keep)]


def incline_percent(value):
    if not value:
        return None
    try:
        if value.endswith("%"):
            return float(value[:-1])
        if value.endswith("°"):
            return math.tan(math.radians(float(value[:-1]))) * 100
    except ValueError:
        pass
    return None


def attributes(tags, forward=True):
    electrified = tags.get("electrified")
    track_count = int(tags["tracks"]) if tags.get("tracks", "").isdigit() else None
    slope = incline_percent(tags.get("incline"))
    return {
        "electrified": electrified,
        "voltage": tags.get("voltage"), "frequency": tags.get("frequency"),
        "gauge_mm": [int(v) for v in tags["gauge"].split(";")] if re.fullmatch(r"\d+(;\d+)*", tags.get("gauge", "")) else None,
        "tracks_tag": track_count,
        "double_track": True if track_count and track_count >= 2 else None,
        "incline_percent": slope if forward or slope is None else -slope,
        "incline_tag": tags.get("incline"), "usage": tags.get("usage"),
        "service": tags.get("service"), "bridge": tags.get("bridge"),
        "tunnel": tags.get("tunnel"), "layer": tags.get("layer"),
        "bridge_name_original": tags.get("bridge:name"),
        "ref": tags.get("ref"), "name_original": tags.get("name"),
    }


def select_stations(elements, ways, coords):
    candidates = [e for e in elements if e.get("tags", {}).get("railway") in ("station", "halt", "yard")
                  and e.get("tags", {}).get("station") not in ("subway", "light_rail", "tram")
                  and e.get("tags", {}).get("train") != "no"]
    # A small spatial index avoids a scan of every rail node for every station.
    grid = defaultdict(list)
    for nid, coord in coords.items():
        grid[(int(coord[0] * 100), int(coord[1] * 100))].append(nid)
    memberships = defaultdict(list)
    for way in ways:
        if way.get("tags", {}).get("service") != "crossover":
            for nid in way["nodes"]:
                memberships[nid].append(way["id"])
    stations, missing = [], []
    for sid, name, pattern in STATION_SPECS:
        matches = [e for e in candidates if re.search(pattern, e["tags"].get("name", ""))]
        # Prefer explicit station nodes, then area/relation markers, then halts.
        freight_reference = sid in {"poznan_franowo", "wroclaw_brochow", "seddin", "mukran", "engelsdorf", "friedrichstadt"}
        matches.sort(key=lambda e: (freight_reference and e["tags"].get("railway") != "yard", e["tags"].get("railway") == "halt", e["type"] != "node", e["id"]))
        selected = None
        for marker in matches:
            center = marker.get("center", marker)
            if "lon" not in center:
                continue
            coord = [center["lon"], center["lat"]]
            cx, cy = int(coord[0] * 100), int(coord[1] * 100)
            nearest = {}
            for gx in range(cx - 1, cx + 2):
                for gy in range(cy - 1, cy + 2):
                    for nid in grid.get((gx, gy), []):
                        d = distance(coord, coords[nid])
                        if d <= 350:
                            for wid in memberships[nid]:
                                if wid not in nearest or (d, nid) < nearest[wid]:
                                    nearest[wid] = (d, nid)
            anchors = sorted({nid for _, nid in nearest.values()})
            if anchors:
                selected = {
                    "id": sid, "name": name, "name_original": marker["tags"]["name"],
                    "osm_type": marker["type"], "osm_id": marker["id"], "coordinates": coord,
                    "kind": "freight_station" if marker["tags"].get("railway") == "yard" or marker["tags"].get("station") in ("freight", "yard") else "passenger_station",
                    "freight_reference": freight_reference,
                    "marker_tags": {k: marker["tags"][k] for k in ("railway", "station", "train", "passenger", "freight") if k in marker["tags"]},
                    "source_url": f"https://www.openstreetmap.org/{marker['type']}/{marker['id']}",
                    "anchors": [{"node_id": f"n{nid}", "distance_m": round(distance(coord, coords[nid]), 1)} for nid in anchors],
                }
                break
        if selected:
            stations.append(selected)
        else:
            missing.append({"id": sid, "name": name, "reason": "역 표식 또는 350m 이내의 선택된 본선이 미확인"})
    return stations, missing


def compress_graph(elements):
    by_key = {}
    for item in elements:
        key = item["type"], item["id"]
        by_key[key] = {**by_key.get(key, {}), **item}
    elements = list(by_key.values())
    ways = sorted([e for e in elements if e["type"] == "way" and e.get("tags", {}).get("railway") == "rail"
                   and e.get("tags", {}).get("service") not in ("yard", "siding", "spur")], key=lambda e: e["id"])
    used = {nid for way in ways for nid in way["nodes"]}
    coords = {e["id"]: [e["lon"], e["lat"]] for e in elements if e["type"] == "node" and e["id"] in used and "lon" in e}
    if used - coords.keys():
        raise ValueError("Missing referenced rail nodes in source")
    atoms, adjacency = [], defaultdict(list)
    for way in ways:
        for a, b in zip(way["nodes"], way["nodes"][1:]):
            if a == b or distance(coords[a], coords[b]) == 0:
                continue
            index = len(atoms)
            atoms.append((a, b, way["id"], way["tags"], distance(coords[a], coords[b])))
            adjacency[a].append(index)
            adjacency[b].append(index)
    stations, missing = select_stations(elements, ways, coords)
    station_ids = defaultdict(list)
    for station in stations:
        for anchor in station["anchors"]:
            station_ids[int(anchor["node_id"][1:])].append(station["id"])
    anchors = {nid for nid, adj in adjacency.items() if len(adj) != 2} | station_ids.keys()
    explicit_junctions = {e["id"] for e in elements if e["type"] == "node" and e["id"] in adjacency and e.get("tags", {}).get("railway") == "junction"}
    anchors |= explicit_junctions
    # A degree-two closed component needs one retained node to preserve its loop.
    seen_nodes = set()
    for nid in sorted(adjacency):
        if nid in seen_nodes:
            continue
        component, stack = [], [nid]
        while stack:
            current = stack.pop()
            if current in seen_nodes:
                continue
            seen_nodes.add(current)
            component.append(current)
            for index in adjacency[current]:
                a, b = atoms[index][:2]
                stack.append(b if a == current else a)
        if not anchors.intersection(component):
            anchors.add(min(component))
    nodes = [{"id": f"n{nid}", "osm_node_id": nid, "coordinates": coords[nid],
              "kind": "station" if nid in station_ids else "junction" if len(adjacency[nid]) >= 3 or nid in explicit_junctions else "terminal" if len(adjacency[nid]) == 1 else "loop_anchor",
              "degree": len(adjacency[nid]), "station_ids": sorted(station_ids.get(nid, []))} for nid in sorted(anchors)]
    edges, geometries, visited = [], {}, set()
    for start in sorted(anchors):
        for index in adjacency[start]:
            if index in visited:
                continue
            current, points, segments = start, [coords[start]], []
            while True:
                visited.add(index)
                a, b, wid, tags, length = atoms[index]
                forward = a == current
                following = b if forward else a
                props = attributes(tags, forward)
                if segments and segments[-1]["osm_way_id"] == wid and segments[-1]["attributes"] == props:
                    segments[-1]["length_m"] += length
                else:
                    segments.append({"osm_way_id": wid, "length_m": length, "attributes": props})
                points.append(coords[following])
                current = following
                if current in anchors:
                    break
                index = next(i for i in adjacency[current] if i not in visited)
            eid = f"e{len(edges):06d}"
            length = sum(s["length_m"] for s in segments)
            aggregate = {}
            for prop in ("electrified", "gauge_mm", "double_track", "incline_percent"):
                values = [s["attributes"][prop] for s in segments]
                aggregate[prop] = values[0] if all(v == values[0] for v in values) else None
            for segment in segments:
                segment["length_m"] = round(segment["length_m"], 3)
            edges.append({"id": eid, "from": f"n{start}", "to": f"n{current}", "length_m": round(length, 3),
                          **aggregate, "segments": segments})
            geometries[eid] = [[round(c, 7) for c in point] for point in simplify(points)]
    if len(visited) != len(atoms):
        raise ValueError("Compression lost rail segments")
    return nodes, edges, stations, missing, geometries, {"rail_ways": len(ways), "rail_nodes": len(coords), "atomic_segments": len(atoms)}


def calculate_route(graph, station_keys):
    stations = {s["id"]: s for s in graph["stations"]}
    if any(key not in stations for key in station_keys):
        return {"status": "unconfirmed", "reason": "필수 경유역이 원본에서 미확인"}
    target_sets = [{a["node_id"] for a in stations[key]["anchors"]} for key in station_keys]
    adj = defaultdict(list)
    for edge in graph["edges"]:
        adj[edge["from"]].append((edge["to"], edge["length_m"], edge["id"], True))
        adj[edge["to"]].append((edge["from"], edge["length_m"], edge["id"], False))
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
        if eid:
            path.append({"edge_id": eid, "forward": forward})
        else:
            passes.append({"station_id": station_keys[state[1] - 1], "node_id": state[0], "distance_from_start_m": round(distances[state], 3)})
        state = prior
    passes.append({"station_id": station_keys[0], "node_id": state[0], "distance_from_start_m": 0})
    return {"status": "connected", "length_m": round(distances[end], 3), "start_node": state[0], "end_node": end[0],
            "waypoints": list(reversed(passes)), "path": list(reversed(path))}


def write_json(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8", newline="\n")


def build_outputs(payload, source, output):
    output.mkdir(parents=True, exist_ok=True)
    nodes, edges, stations, missing, geometries, counts = compress_graph(payload["elements"])
    graph = {"schema_version": 1, "source": source, "bbox": list(BBOX),
             "attribution": ATTRIBUTION, "license": LICENSE,
             "simplification": {"geometry_tolerance_m": 25, "station_anchor_radius_m": 350},
             "source_counts": counts, "nodes": nodes, "edges": edges, "stations": stations,
             "unconfirmed_stations": missing, "routes": []}
    graph["unconfirmed_freight_references"] = [{"station_id": s["id"], "name": s["name"],
                                               "reason": "화물 야드 표식은 미확인이고 인근 여객역 표식만 수록"}
                                              for s in stations if s["freight_reference"] and s["kind"] != "freight_station"]
    for rid, title, keys in ROUTE_SPECS:
        route = {"id": rid, "name": title, "station_ids": keys, **calculate_route(graph, keys)}
        graph["routes"].append(route)
        print(f"Route {rid}: {route['status']} {route.get('length_m', 0) / 1000:.3f} km", flush=True)
    # Repeated per-way tags dominate size; store each distinct profile once.
    profiles, profile_ids = {}, {}
    for edge in edges:
        for segment in edge["segments"]:
            attrs = {key: value for key, value in segment.pop("attributes").items() if value is not None}
            signature = json.dumps(attrs, sort_keys=True, ensure_ascii=False)
            if signature not in profile_ids:
                pid = f"a{len(profiles):05d}"
                profile_ids[signature] = pid
                profiles[pid] = attrs
            segment["attribute_id"] = profile_ids[signature]
    graph["attribute_profiles"] = profiles
    north = next(r for r in graph["routes"] if r["id"] == "north_to_sassnitz")
    edge_lookup = {e["id"]: e for e in edges}
    bridges = []
    for part in north.get("path", []):
        for segment in edge_lookup[part["edge_id"]]["segments"]:
            props = profiles[segment["attribute_id"]]
            if props.get("bridge_name_original") in ("Rügendammbrücke", "Ziegelgrabenbrücke"):
                bridges.append({"osm_way_id": segment["osm_way_id"], "length_m": segment["length_m"],
                                "name_original": props["bridge_name_original"]})
    north["ruegen_causeway_bridges"] = bridges
    features = [{"type": "Feature", "id": e["id"], "geometry": {"type": "LineString", "coordinates": geometries[e["id"]]},
                 "properties": {k: e[k] for k in ("id", "from", "to", "length_m", "electrified", "gauge_mm", "double_track", "incline_percent")}}
                for e in edges]
    features += [{"type": "Feature", "id": s["id"], "geometry": {"type": "Point", "coordinates": s["coordinates"]},
                  "properties": {k: s[k] for k in ("id", "name", "name_original", "kind", "source_url")}} for s in stations]
    core = {"type": "FeatureCollection", "attribution": ATTRIBUTION, "license": LICENSE,
            "osm_base": source["osm_base"], "bbox": [BBOX[1], BBOX[0], BBOX[3], BBOX[2]], "features": features}
    write_json(output / "graph.json", graph)
    write_json(output / "core.geojson", core)
    write_routes(graph, output)
    write_preview(graph, geometries, output)
    validate_outputs(output)
    print(f"Built {len(nodes)} nodes, {len(edges)} edges, {len(stations)} station groups", flush=True)


def write_routes(graph, output):
    stations = {s["id"]: s for s in graph["stations"]}
    lines = ["# 실제 철도망 경로 후보", "", f"OSM 기준 시각: `{graph['source']['osm_base']}`. 출처: [OpenStreetMap](https://www.openstreetmap.org/copyright), [OpenRailwayMap](https://www.openrailwaymap.org/).", "",
             "거리는 단순화 전 OSM 선로 중심선의 구면 거리 합계다. 지정된 역을 순서대로 지나는 무방향 최단 경로이며, 운행표·운행 허가·화물열차 통과 가능성·열차의 방향 전환 가능성은 미확인이다. 역 표식과 실제 선로의 연결점 차이는 최대 350m다. 역 안의 선로 사이에 가상의 연결은 넣지 않았다.", "",
             "뤼겐 둑길 경유는 슈트랄준트 뤼겐담역에서 베르겐으로 이어지는 실제 선로의 다리 구간으로 확인한다. 도로 전용 뤼겐교는 경로에 넣지 않는다.", ""]
    for route in graph["routes"]:
        lines += [f"## {route['name']}", "", " → ".join(stations[k]["name"] if k in stations else k + "(미확인)" for k in route["station_ids"]), ""]
        if route["status"] != "connected":
            lines += [f"**미확인:** {route['reason']}", ""]
            continue
        lines += [f"총 **{route['length_m'] / 1000:.1f}km**. 그래프 경로 ID: `{route['id']}`.", "", "| 구간 | 거리 | 누적 거리 |", "|---|---:|---:|"]
        for a, b in zip(route["waypoints"], route["waypoints"][1:]):
            length = b["distance_from_start_m"] - a["distance_from_start_m"]
            lines.append(f"| {stations[a['station_id']]['name']} → {stations[b['station_id']]['name']} | {length / 1000:.1f}km | {b['distance_from_start_m'] / 1000:.1f}km |")
        lines += ["", "### 경유역 원본", ""]
        for key in route["station_ids"]:
            s = stations[key]
            lines.append(f"- [{s['name']} ({s['name_original']})]({s['source_url']})")
        if route.get("ruegen_causeway_bridges"):
            lines += ["", "### 뤼겐 둑길 통과 근거", "", "계산된 경로에 아래 철도 교량의 실제 OSM way가 포함된다. 둑길 전체 길이가 아니라 이름이 기록된 교량 부분의 선로 길이만 나열한다.", ""]
            for bridge in route["ruegen_causeway_bridges"]:
                lines.append(f"- [{bridge['name_original']} · OSM way {bridge['osm_way_id']}](https://www.openstreetmap.org/way/{bridge['osm_way_id']}): {bridge['length_m']:.1f}m")
        lines.append("")
    lines += ["## 해석 범위와 남은 문제", "", "- 이 데이터는 현재 OSM 기록을 바탕으로 한 게임 참고 자료다. 재난 이후의 운행 가능성을 뜻하지 않는다.",
              "- 보존 철도·폐선·공사 중 선로·협궤 경전철은 제외했다. 체코 전체와 서부 폴란드·동부 독일을 둘러싸는 사각 범위여서 경계 주변의 다른 지역도 일부 포함된다.",
              "- 복선 여부와 경사 등 누락 태그는 미확인이다. 경사에 표고 모델은 사용하지 않았다.",
              "- 세부 경유역을 바꾸면 같은 데이터에서도 다른 후보가 나올 수 있다. 소규모 여객 정차장은 의도적으로 생략했다.",
              "- 데이터 배포 시 © OpenStreetMap contributors와 [ODbL 1.0](https://opendatacommons.org/licenses/odbl/1-0/)을 표시한다.", ""]
    for item in graph["unconfirmed_freight_references"]:
        lines.append(f"- {item['name']}: {item['reason']}.")
    (output / "routes.md").write_text("\n".join(lines), encoding="utf-8")


def write_preview(graph, geometries, output):
    def screen(coord):
        return (coord[0] - BBOX[1]) / (BBOX[3] - BBOX[1]) * 1050 + 40, (BBOX[2] - coord[1]) / (BBOX[2] - BBOX[0]) * 1000 + 50
    route_edges = {p["edge_id"] for r in graph["routes"] for p in r.get("path", [])}
    paths = []
    for eid, points in geometries.items():
        d = " ".join(("M" if i == 0 else "L") + f"{screen(p)[0]:.2f},{screen(p)[1]:.2f}" for i, p in enumerate(points))
        paths.append(f'<path d="{d}" stroke="{"#e55b37" if eid in route_edges else "#607c92"}" stroke-width="{"2.4" if eid in route_edges else "0.65"}"/>')
    labels = []
    route_stations = {k for r in graph["routes"] for k in r["station_ids"]}
    for station in graph["stations"]:
        x, y = screen(station["coordinates"])
        labels.append(f'<circle cx="{x:.2f}" cy="{y:.2f}" r="3" fill="#192b38"/>')
        if station["id"] in route_stations and station["id"] not in {"ruegendamm", "bergen", "lietzow"}:
            labels.append(f'<text x="{x+5:.2f}" y="{y-5:.2f}" font-size="11">{html.escape(station["name"])}</text>')
    # An inset makes the narrow sea crossing inspectable at overview scale.
    ix, iy, iw, ih = 780, 40, 340, 240
    def inset_screen(coord):
        return ix + 15 + (coord[0] - 13.04) / 0.66 * 310, iy + 30 + (54.58 - coord[1]) / 0.29 * 185
    inset_paths, inset_labels = [], []
    for eid, points in geometries.items():
        if any(13.04 <= p[0] <= 13.7 and 54.29 <= p[1] <= 54.58 for p in points):
            d = " ".join(("M" if i == 0 else "L") + f"{inset_screen(p)[0]:.2f},{inset_screen(p)[1]:.2f}" for i, p in enumerate(points))
            inset_paths.append(f'<path d="{d}" fill="none" stroke="{"#e55b37" if eid in route_edges else "#607c92"}" stroke-width="1.5"/>')
    offsets = {"stralsund": (5, 15), "ruegendamm": (6, -7), "bergen": (-14, 16), "lietzow": (-7, -9), "sassnitz": (-40, -9)}
    for station in graph["stations"]:
        if station["id"] in offsets:
            x, y = inset_screen(station["coordinates"])
            dx, dy = offsets[station["id"]]
            short_name = {"stralsund": "슈트랄준트", "ruegendamm": "뤼겐담역", "bergen": "베르겐"}.get(station["id"], station["name"])
            inset_labels.append(f'<circle cx="{x:.2f}" cy="{y:.2f}" r="3" fill="#192b38"/><text x="{x+dx:.2f}" y="{y+dy:.2f}" font-size="12">{html.escape(short_name)}</text>')
    inset = f'<rect x="{ix}" y="{iy}" width="{iw}" height="{ih}" fill="#fffaf2" stroke="#607c92"/><text x="{ix+12}" y="{iy+20}" font-size="15">뤼겐 둑길·자스니츠 확대</text><clipPath id="ruegen"><rect x="{ix+2}" y="{iy+25}" width="{iw-4}" height="{ih-28}"/></clipPath><g clip-path="url(#ruegen)">{"".join(inset_paths)}{"".join(inset_labels)}</g>'
    content = f'''<!doctype html><html lang="ko"><meta charset="utf-8"><title>핵심 지역 실제 철도망 검토</title>
<style>body{{font:16px system-ui;background:#f5f2eb;color:#192b38;margin:24px}}svg{{max-width:100%;background:white;border:1px solid #ccd5db}}text{{font-family:system-ui}}</style>
<h1>핵심 지역 실제 철도망</h1><p>OSM 기준 {html.escape(graph['source']['osm_base'])} · 주황: 계산된 경로 후보 · 청회색: 본선 · 점: 주요 역</p>
<p>위경도를 사각 범위에 배치한 검토 그림이다. 외부 지도·타일·네트워크 요청 없이 열린다.</p>
<svg viewBox="0 0 1150 1110" xmlns="http://www.w3.org/2000/svg"><g fill="none">{''.join(paths)}</g>{''.join(labels)}{inset}</svg>
<p>{ATTRIBUTION} · <a href="{LICENSE}">ODbL 1.0</a></p></html>'''
    (output / "preview.local.html").write_text(content, encoding="utf-8")


def validate_outputs(output):
    graph = json.loads((output / "graph.json").read_text(encoding="utf-8"))
    core = json.loads((output / "core.geojson").read_text(encoding="utf-8"))
    nodes, edges = {n["id"]: n for n in graph["nodes"]}, {e["id"]: e for e in graph["edges"]}
    features = {f["id"]: f for f in core["features"]}
    assert len(nodes) == len(graph["nodes"]) and len(edges) == len(graph["edges"])
    assert core["type"] == "FeatureCollection" and core["license"] == LICENSE
    assert graph["source"]["attribution"] == ATTRIBUTION
    for edge in edges.values():
        assert edge["from"] in nodes and edge["to"] in nodes and edge["length_m"] > 0
        assert abs(sum(s["length_m"] for s in edge["segments"]) - edge["length_m"]) < 0.01
        assert all(s["attribute_id"] in graph["attribute_profiles"] for s in edge["segments"])
        feature = features[edge["id"]]
        assert feature["geometry"]["type"] == "LineString"
        coords = feature["geometry"]["coordinates"]
        assert len(coords) >= 2
        assert distance(coords[0], nodes[edge["from"]]["coordinates"]) < 0.02
        assert distance(coords[-1], nodes[edge["to"]]["coordinates"]) < 0.02
        simplified_length = sum(distance(a, b) for a, b in zip(coords, coords[1:]))
        assert simplified_length <= edge["length_m"] + 0.1
        for point in coords:
            assert len(point) == 2 and -180 <= point[0] <= 180 and -90 <= point[1] <= 90
    stations = {s["id"]: s for s in graph["stations"]}
    for station in stations.values():
        assert features[station["id"]]["geometry"]["type"] == "Point"
        for anchor in station["anchors"]:
            assert station["id"] in nodes[anchor["node_id"]]["station_ids"]
            assert anchor["distance_m"] <= 350
    for route in graph["routes"]:
        assert route["status"] == "connected", f"Required route is unconfirmed: {route['id']}"
        current, total = route["start_node"], 0
        visits = [current]
        for part in route["path"]:
            edge = edges[part["edge_id"]]
            a, b = (edge["from"], edge["to"]) if part["forward"] else (edge["to"], edge["from"])
            assert a == current
            current = b
            total += edge["length_m"]
            visits.append(current)
        assert current == route["end_node"] and abs(total - route["length_m"]) < 0.01
        position = 0
        for waypoint in route["waypoints"]:
            position = visits.index(waypoint["node_id"], position)
            assert waypoint["node_id"] in {a["node_id"] for a in stations[waypoint["station_id"]]["anchors"]}
        if route["id"] == "north_to_sassnitz":
            assert {b["name_original"] for b in route.get("ruegen_causeway_bridges", [])} == {"Rügendammbrücke", "Ziegelgrabenbrücke"}
    print(f"Validation passed: {len(nodes)} nodes, {len(edges)} edges, {len(stations)} stations, {len(graph['routes'])} connected routes", flush=True)


def make_query(date=None):
    snapshot = f'[date:"{date}"]' if date else ""
    box = ",".join(map(str, BBOX))
    return f'''[out:json][timeout:240][maxsize:536870912]{snapshot};
way["railway"="rail"]["service"!~"^(yard|siding|spur)$"]({box})->.rails;
.rails out body qt;
node(w.rails); out body qt;
nwr["railway"~"^(station|halt)$"]({box}); out center body qt;
'''


def acquire(cache, date, refresh, offline, query=None):
    cache.mkdir(parents=True, exist_ok=True)
    query = make_query(date) if query is None else query
    key = hashlib.sha256(query.encode()).hexdigest()[:16]
    path = cache / f"osm-{key}.json.gz"
    receipt = path.with_suffix(".receipt.json")
    if path.exists() and not refresh:
        raw = gzip.decompress(path.read_bytes())
        source = json.loads(receipt.read_text(encoding="utf-8"))
    elif offline:
        raise ValueError(f"Missing offline cache: {path}")
    else:
        body = urllib.parse.urlencode({"data": query}).encode("utf-8")
        request = urllib.request.Request(ENDPOINT, data=body, headers={
            "User-Agent": "APP-B4-rail-reference/1.0 (github.com/wndi1130-dot/APP)",
            "Content-Type": "application/x-www-form-urlencoded",
        })
        print(f"Requesting OSM data; query bytes={len(body)}", flush=True)
        for attempt in range(3):
            try:
                with urllib.request.urlopen(request, timeout=300) as response:
                    raw = response.read()
                payload = json.loads(raw)
                if payload.get("remark"):
                    raise ValueError(f"Incomplete Overpass result: {payload['remark']}")
                break
            except (urllib.error.URLError, TimeoutError) as exc:
                if attempt == 2:
                    raise
                print(f"Download retry {attempt + 1}: {exc}", flush=True)
                time.sleep(20 * (attempt + 1))
        source = {
            "endpoint": ENDPOINT, "method": "POST",
            "query": query, "query_sha256": hashlib.sha256(query.encode()).hexdigest(),
            "request_bytes": len(body), "response_bytes": len(raw),
            "response_sha256": hashlib.sha256(raw).hexdigest(),
            "downloaded_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
            "requested_snapshot": date,
        }
        # No incomplete result is ever cached. Cache is deliberately gitignored.
        path.write_bytes(gzip.compress(raw, mtime=0))
        receipt.write_text(json.dumps(source, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    if hashlib.sha256(raw).hexdigest() != source["response_sha256"]:
        raise ValueError("Cached response hash mismatch")
    payload = json.loads(raw)
    if payload.get("remark") or not payload.get("elements"):
        raise ValueError("Empty or incomplete OSM response")
    source["server_osm_base"] = payload["osm3s"]["timestamp_osm_base"]
    source["osm_base"] = date or source["server_osm_base"]
    source["request_sha256"] = hashlib.sha256(urllib.parse.urlencode({"data": query}).encode("utf-8")).hexdigest()
    source["requested_snapshot"] = date
    source["attribution"] = ATTRIBUTION
    source["license"] = LICENSE
    print(f"Loaded {len(payload['elements'])} elements; {len(raw):,} raw bytes; snapshot={source['osm_base']}", flush=True)
    return payload, source


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--date", help="Overpass historical snapshot in UTC (ISO 8601)")
    parser.add_argument("--refresh", action="store_true", help="Fetch even if cache exists")
    parser.add_argument("--offline", action="store_true", help="Only use the matching local cache")
    parser.add_argument("--download-only", action="store_true")
    parser.add_argument("--check", action="store_true", help="Validate committed outputs, without network access")
    parser.add_argument("--output", type=Path, default=ROOT)
    args = parser.parse_args()
    if args.date and not re.fullmatch(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z", args.date):
        parser.error("--date must use YYYY-MM-DDTHH:MM:SSZ")
    if args.offline and args.refresh:
        parser.error("--offline and --refresh are mutually exclusive")
    if args.check:
        validate_outputs(args.output)
        return
    payload, source = acquire(ROOT / ".cache", args.date, args.refresh, args.offline)
    if not args.download_only:
        snapshot = args.date or source["osm_base"]
        yard_query = make_yard_query(snapshot)
        yards, yard_source = acquire(ROOT / ".cache", snapshot, args.refresh, args.offline, yard_query)
        payload["elements"].extend(yards["elements"])
        source["supplemental_sources"] = [yard_source]
        build_outputs(payload, source, args.output)


def make_yard_query(snapshot):
    # Name-filter first: avoid expensive geometry tests on every yard relation.
    return f'[out:json][timeout:120][date:"{snapshot}"];nwr["railway"="yard"]["name"~"Franowo|Mukran|Seddin|Engelsdorf|Friedrichstadt|Brochów"];out center body qt;'


if __name__ == "__main__":
    main()
