"""Collect the first-route terrain and railway references, never map images.

Run from any working directory: python ref/map/collect.py [--offline]
Network responses are cached outside the committed dataset in .cache/.
OSM-derived exports: © OpenStreetMap contributors, ODbL 1.0.
OHM source data: CC0 except explicitly licensed elements (excluded here).
SRTM GL1 v3 source elevations: public domain, unrestricted use.
"""
from __future__ import annotations

import argparse
from bisect import bisect_right
from collections import Counter
import csv
from datetime import datetime, timezone
import hashlib
import json
import math
from pathlib import Path
import subprocess
import sys
import time
from typing import Any

import requests
from pyproj import Geod, Transformer
from shapely.geometry import LineString, MultiLineString, mapping
from shapely.ops import transform

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
sys.path.insert(0, str(HERE.parent / 'rail'))
from route_from_graph import calculate_route  # noqa: E402

STATIONS = ['wolsztyn', 'zbaszynek', 'cottbus', 'leipzig']
OSM = 'https://overpass-api.de/api/interpreter'
OHM = 'https://overpass-api.openhistoricalmap.org/api/interpreter'
DEM = 'https://api.opentopodata.org/v1/srtm30m'
ATTRIBUTION = '© OpenStreetMap contributors, ODbL'
ODBL = 'https://opendatacommons.org/licenses/odbl/1-0/'
CC0 = 'https://creativecommons.org/publicdomain/zero/1.0/'
GEOD = Geod(ellps='WGS84')
SPHERE = Geod(a=6371008.8, f=0)
TO_METRES = Transformer.from_crs(4326, 32633, always_xy=True)
TO_WGS84 = Transformer.from_crs(32633, 4326, always_xy=True)
BRIDGES = {318584357: (21.5, 'Obra'), 801395051: (96, 'Bóbr'),
           116512069: (162, 'Spree'), 33775391: (236, 'Schwarze Elster / Kleine Elster')}
TRACK_VALUES = {'rail', 'light_rail', 'narrow_gauge', 'tram', 'subway', 'monorail',
                'funicular', 'disused', 'abandoned', 'preserved', 'construction', 'razed', 'proposed'}


def utcnow() -> str:
    return datetime.now(timezone.utc).isoformat()


def sha256(path: Path) -> str:
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def input_sha256(path: Path) -> str:
    """Hash UTF-8 input text after LF normalization, independent of Git checkout EOLs."""
    return hashlib.sha256(path.read_text(encoding='utf-8').encode('utf-8')).hexdigest()


def write_json(path: Path, value: Any, compact: bool = False) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, allow_nan=False,
                               indent=None if compact else 2) + '\n', encoding='utf-8')


def write_csv(path: Path, fields: list[str], rows: list[dict]) -> None:
    with path.open('w', encoding='utf-8', newline='') as stream:
        writer = csv.DictWriter(stream, fieldnames=fields, lineterminator='\n')
        writer.writeheader()
        writer.writerows(rows)


def feature_collection(features: list, source: str, **metadata: Any) -> dict:
    return {'type': 'FeatureCollection',
            'attribution': ATTRIBUTION if source == 'osm' else f'OpenHistoricalMap (source CC0); corridor {ATTRIBUTION}',
            'license': ODBL,
            'source_license': ODBL if source == 'osm' else CC0,
            **metadata, 'features': features}


class Fetcher:
    """Sequential, cached public API reads. Never use incomplete Overpass output."""
    def __init__(self, offline: bool):
        self.offline = offline
        self.session = requests.Session()
        self.session.headers['User-Agent'] = 'APP-map-reference-research/1.0 (+https://github.com/wndi1130-dot/APP)'
        self.records: list[dict] = []

    def get(self, label: str, url: str, payload: dict, overpass: bool = False) -> dict:
        request_key = json.dumps({'url': url, 'payload': payload}, sort_keys=True)
        key = hashlib.sha256(request_key.encode()).hexdigest()[:16]
        cache = HERE / '.cache' / f'{label}-{key}.json'
        receipt_path = cache.with_suffix('.receipt.json')
        if cache.exists() and receipt_path.exists():
            receipt = json.loads(receipt_path.read_text(encoding='utf-8'))
            if sha256(cache) != receipt['response_sha256']:
                raise RuntimeError(f'Corrupt cache: {cache.name}')
            response = json.loads(cache.read_text(encoding='utf-8'))
            self.records.append(receipt)
            return response
        if self.offline:
            raise RuntimeError(f'Missing offline cache: {label}')
        cache.parent.mkdir(parents=True, exist_ok=True)
        errors = []
        for attempt in range(3):
            try:
                print('[WATCH] request', label, 'attempt', attempt + 1, flush=True)
                r = self.session.post(url, data=payload, timeout=(20, 230 if overpass else 90))
                if r.status_code == 429:
                    raise RuntimeError(f'HTTP 429 for {label}; stop rather than bypass service limit')
                r.raise_for_status()
                response = r.json()
                if overpass and (response.get('remark') or not isinstance(response.get('elements'), list)):
                    raise ValueError('Incomplete Overpass response: ' + str(response.get('remark')))
                if not overpass and response.get('status') != 'OK':
                    raise ValueError('API rejected request: ' + str(response))
                cache.write_bytes(r.content)
                receipt = {'label': label, 'endpoint': url, 'method': 'POST', 'payload': payload,
                           'retrieved_at_utc': utcnow(), 'http_status': r.status_code,
                           'response_bytes': len(r.content), 'response_sha256': sha256(cache),
                           'server_base_utc': response.get('osm3s', {}).get('timestamp_osm_base'),
                           'cache_filename': cache.name}
                write_json(receipt_path, receipt)
                self.records.append(receipt)
                time.sleep(1.2)
                return response
            except (requests.RequestException, ValueError) as exc:
                errors.append(str(exc))
                if attempt < 2:
                    time.sleep(5 * (attempt + 1))
        raise RuntimeError(f'{label}: failed after three attempts: {errors}')


def build_route() -> tuple[dict, list, list]:
    graph_path = HERE.parent / 'rail' / 'graph.json'
    core_path = HERE.parent / 'rail' / 'core.geojson'
    graph = json.loads(graph_path.read_text(encoding='utf-8'))
    core = json.loads(core_path.read_text(encoding='utf-8'))
    route = calculate_route(graph, STATIONS)
    if route['status'] != 'connected':
        raise RuntimeError(str(route))
    edges = {e['id']: e for e in graph['edges']}
    geometries = {f['id']: f['geometry']['coordinates'] for f in core['features'] if f['geometry']['type'] == 'LineString'}
    points, chainages = [], []
    cumulative = 0.0
    previous_node = route['start_node']
    for step in route['path']:
        edge = edges[step['edge_id']]
        start, end = (edge['from'], edge['to']) if step['forward'] else (edge['to'], edge['from'])
        if previous_node != start:
            raise ValueError('Disconnected route node sequence')
        previous_node = end
        coords = geometries[step['edge_id']]
        if not step['forward']:
            coords = list(reversed(coords))
        if points and points[-1] != coords[0]:
            raise ValueError('Noncoincident route geometry endpoints')
        distances = [SPHERE.inv(*a, *b)[2] for a, b in zip(coords, coords[1:])]
        total = sum(distances)
        if total <= 0:
            raise ValueError('Degenerate route geometry')
        if not points:
            points.append(coords[0])
            chainages.append(cumulative)
        local = 0.0
        for coord, distance in zip(coords[1:], distances):
            local += distance
            points.append(coord)
            chainages.append(cumulative + edge['length_m'] * local / total)
        cumulative += edge['length_m']
    if abs(cumulative - route['length_m']) > 0.001 or previous_node != route['end_node']:
        raise ValueError('Route distance or endpoint mismatch')
    if not all(b > a for a, b in zip(chainages, chainages[1:])):
        raise ValueError('Nonmonotonic route chainage')
    route['input_files'] = {p.name: {'sha256': input_sha256(p), 'hash_normalization': 'UTF-8 text; universal newlines normalized to LF', 'collected_worktree_raw_sha256': sha256(p)} for p in [graph_path, core_path, HERE.parent / 'rail' / 'route_from_graph.py']}
    route['station_ids'] = STATIONS
    route['source_graph_osm_base'] = graph['source'].get('osm_base')
    route['attribution'] = ATTRIBUTION
    route['license'] = ODBL
    route['geometry_vertices'] = len(points)
    route['simplified_geometry_length_m'] = sum(SPHERE.inv(*a, *b)[2] for a, b in zip(points, points[1:]))
    write_json(HERE / 'route_metadata.json', route)
    write_json(HERE / 'route.geojson', feature_collection([
        {'type': 'Feature', 'id': 'wolsztyn-leipzig', 'geometry': {'type': 'LineString', 'coordinates': points},
         'properties': {'station_ids': STATIONS, 'length_km': round(route['length_m'] / 1000, 6),
                        'chainage_m': [round(d, 6) for d in chainages]}}], 'osm'), compact=True)
    return route, points, chainages


def sample_at(points: list, chainages: list, metres: float) -> dict:
    if metres >= chainages[-1]:
        lon, lat = points[-1]
    else:
        i = max(0, bisect_right(chainages, metres) - 1)
        fraction = (metres - chainages[i]) / (chainages[i + 1] - chainages[i])
        azimuth, _, distance = SPHERE.inv(*points[i], *points[i + 1])
        lon, lat, _ = SPHERE.fwd(*points[i], azimuth, distance * fraction)
    return {'km': round(metres / 1000, 6), 'lat': round(lat, 7), 'lon': round(lon, 7)}


def collect_elevation(fetcher: Fetcher, points: list, chainages: list) -> dict:
    distances = list(range(0, math.floor(chainages[-1]) + 1, 1000))
    if abs(distances[-1] - chainages[-1]) > 0.001:
        distances.append(chainages[-1])
    rows = [sample_at(points, chainages, distance) for distance in distances]
    evidence = []
    for start in range(0, len(rows), 80):
        batch = rows[start:start + 80]
        payload = {'locations': '|'.join(f"{r['lat']:.7f},{r['lon']:.7f}" for r in batch),
                   'interpolation': 'bilinear', 'nodata_value': 'null'}
        result = fetcher.get(f'elevation-{start:03d}', DEM, payload)
        if len(result['results']) != len(batch):
            raise ValueError('Elevation row count mismatch')
        for row, value in zip(batch, result['results']):
            loc = value['location']
            if abs(loc['lat'] - row['lat']) > 1e-8 or abs(loc['lng'] - row['lon']) > 1e-8:
                raise ValueError('Elevation coordinate mismatch')
            elev = value.get('elevation')
            if value.get('dataset') != 'srtm30m' or elev is None or not math.isfinite(elev):
                raise ValueError('Missing or incorrect DEM dataset/elevation')
            row['elev_m'] = float(elev)
        evidence.append(result)
    write_csv(HERE / 'elevation_1km.csv', ['km', 'lat', 'lon', 'elev_m'], rows)
    write_json(HERE / 'evidence' / 'elevation_api.json', {'endpoint': DEM, 'dataset': 'SRTM GL1 v3',
               'source_license': 'Public domain; unrestricted use', 'coordinate_attribution': ATTRIBUTION,
               'responses': evidence}, compact=True)
    grades = []
    for a, b in zip(rows, rows[1:]):
        interval = b['km'] - a['km']
        grades.append({'from_km': a['km'], 'to_km': b['km'], 'interval_km': round(interval, 6),
                       'from_elev_m': a['elev_m'], 'to_elev_m': b['elev_m'],
                       'grade_pct': round((b['elev_m'] - a['elev_m']) / (interval * 10), 6),
                       'full_1km_interval': abs(interval - 1) < 1e-6})
    write_csv(HERE / 'grades_1km.csv', list(grades[0]), grades)
    full_grades = [r for r in grades if r['full_1km_interval']]
    six = [r for r in rows if r['km'] % 6 == 0]
    six_grades = [{'from_km': a['km'], 'to_km': b['km'],
                   'rise_m': b['elev_m'] - a['elev_m'],
                   'grade_pct': round((b['elev_m'] - a['elev_m']) / 60, 6)}
                  for a, b in zip(six, six[1:])]
    max_elev, min_elev = max(r['elev_m'] for r in rows), min(r['elev_m'] for r in rows)
    result = {'samples': len(rows), 'full_1km_intervals': len(full_grades),
              'highest': [r for r in rows if r['elev_m'] == max_elev],
              'lowest': [r for r in rows if r['elev_m'] == min_elev],
              'steepest_absolute_1km': max(full_grades, key=lambda r: abs(r['grade_pct'])),
              'steepest_uphill_1km': max(full_grades, key=lambda r: r['grade_pct']),
              'steepest_downhill_1km': min(full_grades, key=lambda r: r['grade_pct']),
              'last_interval': grades[-1],
              'six_km_highest': max(six, key=lambda r: r['elev_m']),
              'six_km_lowest': min(six, key=lambda r: r['elev_m']),
              'steepest_absolute_6km': max(six_grades, key=lambda r: abs(r['grade_pct'])),
              'six_km_186_192': next(r for r in six_grades if r['from_km'] == 186)}
    print('[PASS] elevation', json.dumps(result, ensure_ascii=False), flush=True)
    return result


def line_geometry(element: dict) -> LineString | None:
    coords = element.get('geometry', [])
    if len(coords) < 2 or any(c is None or 'lon' not in c or 'lat' not in c for c in coords):
        return None
    return LineString([(c['lon'], c['lat']) for c in coords])


def line_parts(geometry: Any) -> list:
    if geometry.is_empty:
        return []
    if geometry.geom_type == 'LineString':
        return [geometry] if geometry.length > 0 else []
    if hasattr(geometry, 'geoms'):
        return [part for child in geometry.geoms for part in line_parts(child)]
    return []


def length_km(geometry: Any) -> float:
    return sum(abs(GEOD.geometry_length(part)) for part in line_parts(geometry)) / 1000


def is_cc0(license_value: str | None) -> bool:
    if not license_value:
        return True  # OHM's documented default, not a claim of independent legal clearance.
    normalized = license_value.strip().lower().rstrip('/')
    return normalized in {'cc0', 'cc0-1.0', 'cc0 1.0', 'public domain',
                          'https://creativecommons.org/publicdomain/zero/1.0',
                          'http://creativecommons.org/publicdomain/zero/1.0'}


def collect_railways(fetcher: Fetcher, points: list, source: str) -> dict:
    route_m = transform(TO_METRES.transform, LineString(points))
    corridor = route_m.buffer(5000, quad_segs=64)
    # Query a deliberately broader rectangle, then geometrically clip; not just a proximity-to-vertices filter.
    west, south, east, north = transform(TO_WGS84.transform, corridor).bounds
    bbox = f'{south - .01:.7f},{west - .01:.7f},{north + .01:.7f},{east + .01:.7f}'
    selector = '["railway"~"^(disused|abandoned|preserved)$"]' if source == 'osm' else '["railway"]'
    query = f'[out:json][timeout:180];\nway{selector}({bbox});\nout meta geom;\n'
    if source == 'ohm':
        query += '>;\nout tags;\n'
    (HERE / 'queries').mkdir(exist_ok=True)
    (HERE / 'queries' / f'railways_{source}.overpassql').write_text(query, encoding='utf-8')
    data = fetcher.get('railways-' + source, OSM if source == 'osm' else OHM, {'data': query}, overpass=True)
    nodes = {e['id']: e for e in data['elements'] if e['type'] == 'node'}
    ways = {e['id']: e for e in data['elements'] if e['type'] == 'way'}
    if source == 'ohm':
        missing = {nid for way in ways.values() for nid in way.get('nodes', []) if nid not in nodes}
        if missing:
            raise ValueError(f'Cannot check OHM node licenses: {len(missing)} referenced nodes are missing')
    features, excluded, malformed = [], [], []
    node_license_count = 0
    for eid, element in sorted(ways.items()):
        tags = element.get('tags', {})
        if source == 'ohm' and tags.get('railway') not in TRACK_VALUES:
            continue
        geometry = line_geometry(element)
        if geometry is None:
            malformed.append(eid)
            continue
        projected = transform(TO_METRES.transform, geometry)
        if not projected.intersects(corridor):
            continue
        parts = line_parts(projected.intersection(corridor))
        if not parts:
            continue
        if source == 'ohm':
            licenses = [tags.get('license')]
            for nid in element.get('nodes', []):
                value = nodes.get(nid, {}).get('tags', {}).get('license')
                if value:
                    node_license_count += 1
                    licenses.append(value)
            exceptions = [value for value in licenses if not is_cc0(value)]
            if exceptions:
                excluded.append({'way_id': eid, 'name': tags.get('name'), 'licenses': exceptions})
                continue
        clipped = parts[0] if len(parts) == 1 else MultiLineString(parts)
        clipped_wgs = transform(TO_WGS84.transform, clipped)
        name = tags.get('name')
        status = tags.get('railway') if source == 'osm' else 'historical_record; present-day removal unconfirmed'
        properties = {'source': 'OpenStreetMap' if source == 'osm' else 'OpenHistoricalMap',
                      'way_id': eid, 'source_url': f'https://www.{"openstreetmap" if source == "osm" else "openhistoricalmap"}.org/way/{eid}',
                      'name': name, 'name_status': 'recorded' if name else 'unrecorded',
                      'status': status, 'railway': tags.get('railway'),
                      'length_km': round(length_km(clipped_wgs), 6),
                      'original_way_length_km': round(length_km(geometry), 6),
                      'start_date': tags.get('start_date'), 'end_date': tags.get('end_date'),
                      'license': ODBL,
                      'source_license': ODBL if source == 'osm' else CC0,
                      'source_license_basis': 'OSM ODbL' if source == 'osm' else ('element license tag' if tags.get('license') else 'OHM default CC0'),
                      'tags': tags}
        features.append({'type': 'Feature', 'id': f'{source}/way/{eid}', 'geometry': mapping(clipped_wgs), 'properties': properties})
    output = feature_collection(features, source, corridor_radius_m=5000,
                               buffer_crs='EPSG:32633', buffer_quad_segs=64,
                               length_method='WGS84 ellipsoidal geodesic; corridor-clipped way length',
                               server_base_utc=data.get('osm3s', {}).get('timestamp_osm_base'))
    write_json(HERE / f'railways_{source}_5km.geojson', output, compact=True)
    result = {'queried_ways': len(ways), 'exported_ways': len(features),
              'clipped_length_km': round(sum(f['properties']['length_km'] for f in features), 6),
              'railway_counts': dict(Counter(f['properties']['railway'] for f in features)),
              'unnamed_ways': sum(f['properties']['name'] is None for f in features),
              'malformed_way_ids': malformed, 'license_exclusions': excluded,
              'explicit_node_licenses_checked': node_license_count,
              'server_base_utc': data.get('osm3s', {}).get('timestamp_osm_base')}
    print('[PASS] railways', source, json.dumps(result, ensure_ascii=False), flush=True)
    return result


def collect_bridges(fetcher: Fetcher) -> dict:
    ids = ','.join(str(i) for i in BRIDGES)
    query = ('[out:json][timeout:90];\n' + f'way(id:{ids})->.bridges;\n' +
             'way(around.bridges:300)["waterway"]->.waters;\n(.bridges;.waters;);\nout meta geom;\n' +
             'rel(bw.waters)["type"="waterway"];\nout body;\n')
    (HERE / 'queries' / 'bridge_waterways.overpassql').write_text(query, encoding='utf-8')
    data = fetcher.get('bridge-waterways', OSM, {'data': query}, overpass=True)
    ways = {e['id']: e for e in data['elements'] if e['type'] == 'way'}
    waters = {eid: e for eid, e in ways.items() if 'waterway' in e.get('tags', {})}
    relations = [e for e in data['elements'] if e['type'] == 'relation']
    rows, features, used_waters = [], [], set()
    evidence = []
    for bid, (document_km, guessed) in BRIDGES.items():
        bridge = ways.get(bid)
        if bridge is None or line_geometry(bridge) is None:
            raise ValueError(f'Missing bridge {bid}')
        bg = line_geometry(bridge)
        bm = transform(TO_METRES.transform, bg)
        tags = bridge.get('tags', {})
        matches = []
        for wid, water in waters.items():
            wg = line_geometry(water)
            if wg is None:
                continue
            wm = transform(TO_METRES.transform, wg)
            if not bm.intersects(wm):
                continue
            wt = water.get('tags', {})
            rel_names = sorted({rel.get('tags', {}).get('name') for rel in relations
                                if rel.get('tags', {}).get('name') and
                                any(m['type'] == 'way' and m['ref'] == wid for m in rel.get('members', []))})
            matches.append({'way_id': wid, 'name': wt.get('name'), 'waterway': wt.get('waterway'),
                            'layer': wt.get('layer'), 'relation_names': rel_names,
                            'planar_intersection': True, 'crosses': bm.crosses(wm),
                            'distance_m': round(bm.distance(wm), 6)})
            used_waters.add(wid)
        names = sorted({m['name'] for m in matches if m['name']})
        status = '[PASS]' if (matches and len(names) == 1
                              and all(m['crosses'] and m['name'] for m in matches)
                              and tags.get('bridge') not in (None, 'no')
                              and tags.get('railway') == 'rail') else '[WATCH]'
        row = {'bridge_way_id': bid, 'document_km': document_km, 'document_guess': guessed,
               'confirmed_waterway_name': '; '.join(names), 'waterway_way_ids': ';'.join(str(m['way_id']) for m in matches),
               'bridge_tag': tags.get('bridge'), 'bridge_layer': tags.get('layer'),
               'planar_intersections': len(matches), 'status': status,
               'source_url': f'https://www.openstreetmap.org/way/{bid}'}
        rows.append(row)
        evidence.append({'bridge_way_id': bid, 'bridge_tags': tags, 'matches': matches})
        features.append({'type': 'Feature', 'id': f'bridge/{bid}', 'geometry': mapping(bg),
                         'properties': {'kind': 'railway_bridge', **row, 'tags': tags}})
    for wid in sorted(used_waters):
        water = waters[wid]
        features.append({'type': 'Feature', 'id': f'waterway/{wid}', 'geometry': mapping(line_geometry(water)),
                         'properties': {'kind': 'crossed_waterway', 'way_id': wid,
                                        'name': water.get('tags', {}).get('name'),
                                        'source_url': f'https://www.openstreetmap.org/way/{wid}',
                                        'tags': water.get('tags', {})}})
    write_csv(HERE / 'bridge_waterways.csv', list(rows[0]), rows)
    write_json(HERE / 'bridge_waterways.geojson', feature_collection(features, 'osm'), compact=True)
    write_json(HERE / 'evidence' / 'bridge_matches.json', {'attribution': ATTRIBUTION, 'license': ODBL,
               'server_base_utc': data.get('osm3s', {}).get('timestamp_osm_base'), 'matches': evidence})
    print('[PASS] bridges', json.dumps(rows, ensure_ascii=False), flush=True)
    return {'bridges': rows, 'checked': len(rows), 'named_intersections': sum(r['status'] == '[PASS]' for r in rows)}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--offline', action='store_true', help='Use exact saved HTTP responses only')
    args = parser.parse_args()
    fetcher = Fetcher(args.offline)
    route, points, chainages = build_route()
    try:
        source_commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=REPO, text=True).strip()
    except (OSError, subprocess.CalledProcessError):
        source_commit = None  # Input-file hashes still identify the actual route inputs.
    manifest = {'schema_version': 1, 'generated_at_utc': utcnow(),
                'source_commit': source_commit,
                'route_length_km': round(route['length_m'] / 1000, 6),
                'attribution': ATTRIBUTION, 'osm_license': ODBL,
                'ohm_source_license': 'CC0, except element-level exceptions; exceptions excluded',
                'clipped_ohm_export_license': 'ODbL; OHM source remains CC0, clipping corridor is OSM-derived',
                'srtm_source_license': 'Public domain; unrestricted use', 'tasks': {}, 'failures': {}}
    work = [('elevation', lambda: collect_elevation(fetcher, points, chainages)),
            ('railways_osm', lambda: collect_railways(fetcher, points, 'osm')),
            ('railways_ohm', lambda: collect_railways(fetcher, points, 'ohm')),
            ('bridges', lambda: collect_bridges(fetcher))]
    for name, task in work:
        try:
            manifest['tasks'][name] = task()
        except Exception as exc:
            manifest['failures'][name] = f'{type(exc).__name__}: {exc}'
            print('[BLOCKED]', name, str(exc), flush=True)
        manifest['requests'] = fetcher.records
        write_json(HERE / 'collection_manifest.json', manifest)
    print('[PASS]' if not manifest['failures'] else '[WATCH]', 'collection finished', flush=True)
    return 1 if manifest['failures'] else 0


if __name__ == '__main__':
    raise SystemExit(main())
