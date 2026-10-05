"""Topology and attribute regression cases; synthetic fixtures, no network."""

import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import fetch


def node(nid, lon, lat, **tags):
    return {"type": "node", "id": nid, "lon": lon, "lat": lat, "tags": tags}


def way(wid, ids, **tags):
    return {"type": "way", "id": wid, "nodes": ids, "tags": {"railway": "rail", **tags}}


class RailTopologyTests(unittest.TestCase):
    def compress(self, elements):
        with patch.object(fetch, "STATION_SPECS", []):
            return fetch.compress_graph(elements)

    def test_grade_separated_crossing_keeps_two_components(self):
        elements = [node(1, 12, 51), node(2, 12.01, 51.01), node(3, 12.02, 51.02),
                    node(4, 12, 51.02), node(5, 12.01, 51.01), node(6, 12.02, 51),
                    way(10, [1, 2, 3]), way(11, [4, 5, 6], bridge="yes", layer="1")]
        nodes, edges, *_ = self.compress(elements)
        self.assertEqual(len(edges), 2)
        self.assertEqual(len(nodes), 4)
        self.assertFalse(set([edges[0]["from"], edges[0]["to"]]) & set([edges[1]["from"], edges[1]["to"]]))

    def test_shared_osm_node_retains_junction(self):
        elements = [node(1, 12, 51), node(2, 12.01, 51), node(3, 12.02, 51), node(4, 12.01, 51.01),
                    way(10, [1, 2, 3]), way(11, [2, 4])]
        nodes, edges, *_ = self.compress(elements)
        junction = next(n for n in nodes if n["id"] == "n2")
        self.assertEqual(junction["kind"], "junction")
        self.assertEqual(len(edges), 3)

    def test_attribute_change_survives_degree_two_compression(self):
        elements = [node(1, 12, 51), node(2, 12.01, 51), node(3, 12.02, 51),
                    way(10, [1, 2], electrified="no", gauge="1435"),
                    way(11, [2, 3], electrified="contact_line", gauge="1435", incline="2%")]
        _, edges, *_ = self.compress(elements)
        self.assertEqual(len(edges), 1)
        self.assertIsNone(edges[0]["electrified"])
        self.assertEqual(edges[0]["gauge_mm"], [1435])
        self.assertEqual(len(edges[0]["segments"]), 2)

    def test_closed_loop_is_not_lost(self):
        elements = [node(1, 12, 51), node(2, 12.01, 51), node(3, 12.01, 51.01), way(10, [1, 2, 3, 1])]
        nodes, edges, *_ = self.compress(elements)
        self.assertEqual(nodes[0]["kind"], "loop_anchor")
        self.assertEqual(edges[0]["from"], edges[0]["to"])
        self.assertGreater(edges[0]["length_m"], 0)

    def test_tracks_one_does_not_claim_corridor_is_single_track(self):
        self.assertIsNone(fetch.attributes({"tracks": "1"})["double_track"])
        self.assertTrue(fetch.attributes({"tracks": "2"})["double_track"])
        self.assertEqual(fetch.attributes({"incline": "3%"}, False)["incline_percent"], -3)
        self.assertIsNone(fetch.incline_percent("up"))

    def test_multi_anchor_station_never_teleports_between_tracks(self):
        graph = {"stations": [
            {"id": "a", "anchors": [{"node_id": "1"}]},
            {"id": "b", "anchors": [{"node_id": "2"}, {"node_id": "3"}]},
            {"id": "c", "anchors": [{"node_id": "4"}]},
        ], "edges": [
            {"id": "e1", "from": "1", "to": "2", "length_m": 100},
            {"id": "e2", "from": "3", "to": "4", "length_m": 100},
        ]}
        self.assertEqual(fetch.calculate_route(graph, ["a", "b", "c"])["status"], "unconfirmed")
        graph["edges"].append({"id": "e3", "from": "2", "to": "3", "length_m": 40})
        result = fetch.calculate_route(graph, ["a", "b", "c"])
        self.assertEqual(result["length_m"], 240)
        self.assertEqual(len(result["path"]), 3)

    def test_yard_marker_takes_priority_over_passenger_marker(self):
        elements = [node(1, 13, 52), node(2, 13.01, 52), way(10, [1, 2]),
                    node(20, 13.002, 52, railway="station", name="Seddin"),
                    node(21, 13.003, 52, railway="yard", name="Seddin Süd")]
        with patch.object(fetch, "STATION_SPECS", [("seddin", "제딘", r"^Seddin( Süd)?$")]):
            _, _, stations, *_ = fetch.compress_graph(elements)
        self.assertEqual(stations[0]["osm_id"], 21)
        self.assertEqual(stations[0]["kind"], "freight_station")

    def test_historical_snapshot_is_distinct_from_server_timestamp(self):
        snapshot = "2026-10-05T10:45:21Z"
        raw = json.dumps({"osm3s": {"timestamp_osm_base": "2026-10-05T11:10:05Z"},
                          "elements": [node(1, 13, 52)]}).encode()
        (fetch.ROOT / ".cache").mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(dir=fetch.ROOT / ".cache") as temp:
            with patch.object(fetch.urllib.request, "urlopen", return_value=io.BytesIO(raw)):
                _, source = fetch.acquire(Path(temp), snapshot, False, False)
            self.assertEqual(source["osm_base"], snapshot)
            self.assertEqual(source["server_osm_base"], "2026-10-05T11:10:05Z")
            with patch.object(fetch.urllib.request, "urlopen", side_effect=AssertionError("Network forbidden")):
                _, replay = fetch.acquire(Path(temp), snapshot, False, True)
            self.assertEqual(source, replay)


class RailGaugeTests(unittest.TestCase):
    def graph_with_gauges(self, gauges):
        profiles = {}
        segments = []
        for index, gauge in enumerate(gauges):
            profile_id = f"a{index}"
            profiles[profile_id] = fetch.attributes({"gauge": gauge} if gauge is not None else {})
            segments.append({"attribute_id": profile_id, "osm_way_id": 10 + index})
        return {"attribute_profiles": profiles,
                "edges": [{"id": "e1", "gauge_mm": None, "segments": segments}]}

    def test_known_gauges_are_not_anomalies(self):
        for gauge in (600, 750, 760, 900, 1000, 1435, 1520):
            with self.subTest(gauge=gauge):
                graph = self.graph_with_gauges([str(gauge)])
                self.assertEqual(fetch.find_gauge_anomalies(graph), [])

    def test_multiple_known_gauges_are_not_anomalies(self):
        graph = self.graph_with_gauges(["750;1435", "760;1435", "1000;1435;1520"])
        self.assertEqual(fetch.find_gauge_anomalies(graph), [])

    def test_missing_null_and_empty_gauges_are_not_anomalies(self):
        graph = self.graph_with_gauges([None, None, None])
        del graph["attribute_profiles"]["a0"]["gauge_mm"]
        graph["attribute_profiles"]["a2"]["gauge_mm"] = []
        self.assertEqual(fetch.find_gauge_anomalies(graph), [])

    def test_unexpected_gauge_in_mixed_edge_identifies_source_way(self):
        graph = self.graph_with_gauges(["1435", "6000"])
        before = json.dumps(graph, sort_keys=True)
        self.assertIsNone(graph["edges"][0]["gauge_mm"])
        self.assertEqual(fetch.find_gauge_anomalies(graph), [{
            "edge_id": "e1", "osm_way_id": 11,
            "source_url": "https://www.openstreetmap.org/way/11", "gauge_mm": 6000,
        }])
        self.assertEqual(json.dumps(graph, sort_keys=True), before)

    def test_unknown_member_of_multiple_gauges_is_reported_once(self):
        graph = self.graph_with_gauges(["1435;6000"])
        graph["edges"][0]["segments"].append(dict(graph["edges"][0]["segments"][0]))
        anomalies = fetch.find_gauge_anomalies(graph)
        self.assertEqual(len(anomalies), 1)
        self.assertEqual(anomalies[0]["gauge_mm"], 6000)

    def test_check_warns_but_succeeds_without_network_or_mutation(self):
        graph = self.graph_with_gauges(["1435", "6000"])
        coordinates = [[13, 52], [13.001, 52]]
        length = round(fetch.distance(*coordinates), 3)
        graph.update({"nodes": [{"id": "n1", "coordinates": coordinates[0]},
                                {"id": "n2", "coordinates": coordinates[1]}],
                      "stations": [], "routes": [],
                      "source": {"attribution": fetch.ATTRIBUTION}})
        edge = graph["edges"][0]
        edge.update({"from": "n1", "to": "n2", "length_m": length})
        for segment in edge["segments"]:
            segment["length_m"] = length / 2
        core = {"type": "FeatureCollection", "license": fetch.LICENSE,
                "features": [{"id": "e1", "geometry": {"type": "LineString", "coordinates": coordinates}}]}
        with tempfile.TemporaryDirectory() as temp:
            output = Path(temp)
            for name, payload in (("graph.json", graph), ("core.geojson", core)):
                (output / name).write_text(json.dumps(payload), encoding="utf-8")
            before = {path.name: path.read_bytes() for path in output.iterdir()}
            with patch("sys.argv", ["fetch.py", "--check", "--output", temp]), \
                    patch("sys.stdout", new_callable=io.StringIO) as stdout, \
                    patch.object(fetch, "acquire", side_effect=AssertionError("Acquisition forbidden")), \
                    patch.object(fetch, "build_outputs", side_effect=AssertionError("Rebuild forbidden")), \
                    patch.object(fetch.urllib.request, "urlopen", side_effect=AssertionError("Network forbidden")):
                self.assertIsNone(fetch.main())
            self.assertIn("[WATCH] 궤간 검토 필요: 6000mm", stdout.getvalue())
            self.assertIn("구간 e1", stdout.getvalue())
            self.assertIn("https://www.openstreetmap.org/way/11", stdout.getvalue())
            self.assertIn("[PASS] 구조 검사 통과", stdout.getvalue())
            self.assertIn("궤간 경고 1건", stdout.getvalue())
            self.assertEqual({path.name: path.read_bytes() for path in output.iterdir()}, before)


if __name__ == "__main__":
    unittest.main()
