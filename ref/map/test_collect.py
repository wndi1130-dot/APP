"""Offline checks of committed survey data; no cache or live HTTP is required."""
from collections import Counter
import csv
import json
import math
from pathlib import Path
import unittest

from shapely.geometry import shape
from shapely.ops import transform

import collect as survey

HERE = Path(__file__).resolve().parent


def read_json(name):
    return json.loads((HERE / name).read_text(encoding='utf-8'))


def read_csv(name):
    with (HERE / name).open(encoding='utf-8', newline='') as stream:
        return list(csv.DictReader(stream))


class SurveyDataTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.manifest = read_json('collection_manifest.json')
        cls.route = read_json('route_metadata.json')
        cls.route_feature = read_json('route.geojson')['features'][0]
        cls.route_geometry = shape(cls.route_feature['geometry'])
        cls.route_metres = transform(survey.TO_METRES.transform, cls.route_geometry)
        cls.corridor = cls.route_metres.buffer(5000, quad_segs=64)
        cls.elev = [{k: float(v) for k, v in r.items()} for r in read_csv('elevation_1km.csv')]
        cls.rail = {s: read_json(f'railways_{s}_5km.geojson') for s in ['osm', 'ohm']}

    def test_route_input_hashes_and_recalculation(self):
        for name, metadata in self.route['input_files'].items():
            self.assertEqual(survey.input_sha256(HERE.parent / 'rail' / name), metadata['sha256'])
            self.assertEqual(metadata['hash_normalization'], 'UTF-8 text; universal newlines normalized to LF')
        graph = json.loads((HERE.parent / 'rail' / 'graph.json').read_text(encoding='utf-8'))
        result = survey.calculate_route(graph, survey.STATIONS)
        for key in ['path', 'length_m', 'start_node', 'end_node', 'waypoints']:
            self.assertEqual(result[key], self.route[key])
        self.assertAlmostEqual(result['length_m'], 311875.372, places=3)
        self.assertEqual([w['station_id'] for w in result['waypoints']], survey.STATIONS)

    def test_route_geometry_orientation(self):
        core = json.loads((HERE.parent / 'rail' / 'core.geojson').read_text(encoding='utf-8'))
        geometries = {f['id']: f['geometry']['coordinates'] for f in core['features'] if f['geometry']['type'] == 'LineString'}
        expected = []
        for step in self.route['path']:
            pts = geometries[step['edge_id']]
            pts = pts if step['forward'] else list(reversed(pts))
            if expected:
                self.assertEqual(expected[-1], pts[0])
            expected.extend(pts if not expected else pts[1:])
        self.assertEqual(expected, self.route_feature['geometry']['coordinates'])
        self.assertEqual(len(expected), self.route['geometry_vertices'])

    def test_csv_schema_grid_and_endpoint(self):
        self.assertEqual(list(self.elev[0]), ['km', 'lat', 'lon', 'elev_m'])
        self.assertEqual(len(self.elev), 313)
        self.assertEqual([r['km'] for r in self.elev[:-1]], list(range(312)))
        self.assertEqual(self.elev[-1]['km'], 311.875372)
        for r in self.elev:
            self.assertTrue(all(math.isfinite(v) for v in r.values()))
            self.assertTrue(51 < r['lat'] < 53)
            self.assertTrue(12 < r['lon'] < 17)

    def test_sample_coordinates_against_chainage(self):
        pts = self.route_feature['geometry']['coordinates']
        chain = self.route_feature['properties']['chainage_m']
        self.assertEqual(len(pts), len(chain))
        self.assertTrue(all(b > a for a, b in zip(chain, chain[1:])))
        self.assertAlmostEqual(chain[-1], self.route['length_m'], places=5)
        for r in self.elev:
            expected = survey.sample_at(pts, chain, r['km'] * 1000)
            self.assertAlmostEqual(r['lat'], expected['lat'], places=7)
            self.assertAlmostEqual(r['lon'], expected['lon'], places=7)

    def test_elevation_values_against_api_evidence(self):
        evidence = read_json('evidence/elevation_api.json')
        records = [r for response in evidence['responses'] for r in response['results']]
        self.assertEqual(len(records), len(self.elev))
        for row, record in zip(self.elev, records):
            self.assertEqual(record['dataset'], 'srtm30m')
            self.assertEqual(record['elevation'], row['elev_m'])
            self.assertEqual(record['location'], {'lat': row['lat'], 'lng': row['lon']})

    def test_grades_and_terminal_interval(self):
        grades = read_csv('grades_1km.csv')
        self.assertEqual(len(grades), len(self.elev) - 1)
        for a, b, g in zip(self.elev, self.elev[1:], grades):
            expected = (b['elev_m'] - a['elev_m']) / ((b['km'] - a['km']) * 10)
            self.assertEqual(float(g['from_km']), a['km'])
            self.assertEqual(float(g['to_km']), b['km'])
            self.assertAlmostEqual(float(g['grade_pct']), expected, places=6)
        self.assertTrue(all(g['full_1km_interval'] == 'True' for g in grades[:-1]))
        self.assertEqual(grades[-1]['full_1km_interval'], 'False')
        full = grades[:-1]
        steep = max(full, key=lambda g: abs(float(g['grade_pct'])))
        self.assertEqual((float(steep['from_km']), float(steep['to_km']), float(steep['grade_pct'])), (129, 130, 1.8))

    def test_extrema_and_six_km_comparison(self):
        self.assertEqual(max(r['elev_m'] for r in self.elev), 139)
        self.assertEqual([r['km'] for r in self.elev if r['elev_m'] == 139], [197])
        self.assertEqual(min(r['elev_m'] for r in self.elev), 39)
        self.assertEqual([r['km'] for r in self.elev if r['elev_m'] == 39], [94, 96])
        six = [r for r in self.elev if r['km'] % 6 == 0]
        self.assertEqual(max(six, key=lambda r: r['elev_m'])['elev_m'], 134)
        grade = max((b['elev_m'] - a['elev_m']) / 60 for a, b in zip(six, six[1:]))
        self.assertAlmostEqual(grade, 46 / 60)
        self.assertAlmostEqual(self.manifest['tasks']['elevation']['six_km_186_192']['grade_pct'], grade, places=6)

    def test_railway_geometry_and_clipping(self):
        generous_corridor = self.corridor.buffer(0.05)
        for source, data in self.rail.items():
            for feature in data['features']:
                g = shape(feature['geometry'])
                p = feature['properties']
                self.assertIn(g.geom_type, {'LineString', 'MultiLineString'})
                self.assertTrue(g.is_valid and not g.is_empty)
                self.assertTrue(generous_corridor.covers(transform(survey.TO_METRES.transform, g)), feature['id'])
                self.assertAlmostEqual(survey.length_km(g), p['length_km'], places=6)
                self.assertLessEqual(p['length_km'], p['original_way_length_km'] + .000002)
                self.assertGreater(p['length_km'], 0)

    def test_way_counts_filters_names_and_lengths(self):
        for source, data in self.rail.items():
            fs = data['features']
            stats = self.manifest['tasks']['railways_' + source]
            self.assertEqual(len(fs), stats['exported_ways'])
            self.assertEqual(len(fs), len({f['id'] for f in fs}))
            self.assertEqual(Counter(f['properties']['railway'] for f in fs), stats['railway_counts'])
            self.assertAlmostEqual(sum(f['properties']['length_km'] for f in fs), stats['clipped_length_km'], places=6)
            self.assertEqual(sum(f['properties']['name'] is None for f in fs), stats['unnamed_ways'])
            for f in fs:
                p = f['properties']
                self.assertEqual(p['name'], p['tags'].get('name'))
                if source == 'osm':
                    self.assertIn(p['railway'], {'abandoned', 'disused', 'preserved'})
                    self.assertEqual(p['status'], p['railway'])
                else:
                    self.assertIn(p['railway'], survey.TRACK_VALUES)
                    self.assertIn('unconfirmed', p['status'])

    def test_licenses_and_unknown_license_rejection(self):
        for source, data in self.rail.items():
            self.assertIn(survey.ATTRIBUTION, data['attribution'])
            self.assertEqual(data['license'], survey.ODBL)
            for f in data['features']:
                p = f['properties']
                self.assertEqual(p['license'], survey.ODBL)
                self.assertEqual(p['source_license'], survey.CC0 if source == 'ohm' else survey.ODBL)
                if source == 'ohm':
                    self.assertTrue(survey.is_cc0(p['tags'].get('license')))
        self.assertFalse(survey.is_cc0('CC-BY-SA-4.0'))
        self.assertFalse(survey.is_cc0('unknown'))

    def test_bridge_names_and_crossing_geometry(self):
        features = {f['id']: f for f in read_json('bridge_waterways.geojson')['features']}
        rows = read_csv('bridge_waterways.csv')
        expected = {318584357: ('Obra', 24769175), 801395051: ('Bóbr', 801855025),
                    116512069: ('Spree', 117860615), 33775391: ('Schwarze Elster', 22990464)}
        self.assertEqual({int(r['bridge_way_id']) for r in rows}, set(expected))
        for r in rows:
            bid = int(r['bridge_way_id'])
            name, wid = expected[bid]
            self.assertEqual(r['confirmed_waterway_name'], name)
            self.assertEqual(r['waterway_way_ids'], str(wid))
            self.assertEqual(r['status'], '[PASS]')
            bridge, water = features[f'bridge/{bid}'], features[f'waterway/{wid}']
            bm, wm = [transform(survey.TO_METRES.transform, shape(f['geometry'])) for f in [bridge, water]]
            self.assertTrue(bm.crosses(wm))
            self.assertEqual(bridge['properties']['tags']['bridge'], 'yes')
            self.assertEqual(bridge['properties']['tags']['layer'], '1')
            self.assertEqual(water['properties']['tags']['name'], name)
            self.assertEqual(water['properties']['tags']['waterway'], 'river')

    def test_request_receipts_and_no_failed_tasks(self):
        self.assertFalse(self.manifest['failures'])
        self.assertEqual(set(self.manifest['tasks']), {'elevation', 'railways_osm', 'railways_ohm', 'bridges'})
        self.assertEqual(len(self.manifest['requests']), 7)
        for receipt in self.manifest['requests']:
            self.assertEqual(receipt['http_status'], 200)
            self.assertGreater(receipt['response_bytes'], 0)
            self.assertEqual(len(receipt['response_sha256']), 64)
            if 'overpass' in receipt['endpoint']:
                self.assertTrue(receipt['server_base_utc'])


if __name__ == '__main__':
    unittest.main()
