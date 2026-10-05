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


if __name__ == "__main__":
    unittest.main()
