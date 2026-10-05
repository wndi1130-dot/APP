"""Continuous routing regressions using synthetic fixtures and committed data."""

from decimal import Decimal
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import unittest

import route_from_graph as routing


ROOT = Path(__file__).resolve().parent
EXISTING_LENGTHS = {
    "west_via_berlin": 514743.385,
    "west_via_dresden": 628002.522,
    "north_to_sassnitz": 449545.406,
    "czech_corridor": 550623.158,
}
FIRST_LEGS = {
    "first_leg_direct": (["wolsztyn", "zbaszynek", "cottbus", "leipzig"], 311875.372),
    "first_leg_via_berlin": (
        ["wolsztyn", "zbaszynek", "rzepin", "frankfurt", "berlin", "leipzig"], 383745.771
    ),
}


def station(key, *anchors):
    return {"id": key, "name": key, "name_original": key,
            "anchors": [{"node_id": anchor} for anchor in anchors]}


def edge(key, start, end, length):
    return {"id": key, "from": start, "to": end, "length_m": length}


def basic_graph():
    return {
        "nodes": [{"id": "1"}, {"id": "2"}],
        "stations": [station("a", "1"), station("b", "2")],
        "edges": [edge("ab", "1", "2", 100.25)],
        "routes": [{
            "id": "saved", "station_ids": ["a", "b"], "status": "connected",
            "length_m": 100.25, "start_node": "1", "end_node": "2",
            "path": [{"edge_id": "ab", "forward": True}],
            "waypoints": [
                {"station_id": "a", "node_id": "1", "distance_from_start_m": 0},
                {"station_id": "b", "node_id": "2", "distance_from_start_m": 100.25},
            ],
        }],
    }


class RouteAssertions:
    def assert_continuous_route(self, graph, keys, result):
        """Replay physical edges and check ordered visits without running a solver."""
        self.assertEqual(result["status"], "connected")
        edges = {item["id"]: item for item in graph["edges"]}
        stations = {item["id"]: item for item in graph["stations"]}
        current = result["start_node"]
        total = Decimal(0)
        visits = [(current, total)]
        for part in result["path"]:
            self.assertIsInstance(part["forward"], bool)
            item = edges[part["edge_id"]]
            start, end = (item["from"], item["to"]) if part["forward"] else (item["to"], item["from"])
            self.assertEqual(current, start, f"Disconnected edge: {part['edge_id']}")
            current = end
            total += Decimal(str(item["length_m"]))
            visits.append((current, total))
        self.assertEqual(current, result["end_node"])
        self.assertLessEqual(abs(total - Decimal(str(result["length_m"]))), Decimal("0.0005"))
        self.assertEqual([item["station_id"] for item in result["waypoints"]], keys)
        self.assertEqual(result["waypoints"][0]["node_id"], result["start_node"])
        self.assertEqual(result["waypoints"][-1]["node_id"], result["end_node"])
        visit_index = 0
        for waypoint in result["waypoints"]:
            anchors = {anchor["node_id"] for anchor in stations[waypoint["station_id"]]["anchors"]}
            self.assertIn(waypoint["node_id"], anchors)
            measured = Decimal(str(waypoint["distance_from_start_m"]))
            match = next((index for index in range(visit_index, len(visits))
                          if visits[index][0] == waypoint["node_id"]
                          and abs(visits[index][1] - measured) <= Decimal("0.0005")), None)
            self.assertIsNotNone(match, f"Waypoint is not reached in order: {waypoint}")
            visit_index = match


class RouteTopologyTests(RouteAssertions, unittest.TestCase):
    def test_station_anchors_require_a_real_connecting_track(self):
        graph = {"stations": [station("a", "1"), station("b", "2", "3"), station("c", "4")],
                 "edges": [edge("ab", "1", "2", 100), edge("bc", "3", "4", 100)]}
        self.assertEqual(routing.calculate_route(graph, ["a", "b", "c"])["status"], "unconfirmed")
        graph["edges"].append(edge("connection", "3", "2", 40))
        result = routing.calculate_route(graph, ["a", "b", "c"])
        self.assertEqual(result["length_m"], 240)
        self.assertEqual(result["path"], [{"edge_id": "ab", "forward": True},
                                          {"edge_id": "connection", "forward": False},
                                          {"edge_id": "bc", "forward": True}])
        self.assert_continuous_route(graph, ["a", "b", "c"], result)

    def test_total_route_can_use_a_farther_intermediate_anchor(self):
        graph = {"stations": [station("a", "a"), station("b", "near", "far"), station("c", "c")],
                 "edges": [edge("near", "a", "near", 1), edge("long", "near", "c", 100),
                           edge("far", "a", "far", 10), edge("short", "far", "c", 1)]}
        result = routing.calculate_route(graph, ["a", "b", "c"])
        self.assertEqual(result["length_m"], 11)
        self.assertEqual(result["waypoints"][1]["node_id"], "far")
        self.assert_continuous_route(graph, ["a", "b", "c"], result)

    def test_early_future_waypoint_must_be_revisited_in_order(self):
        graph = {"stations": [station("a", "a"), station("b", "b"), station("c", "c")],
                 "edges": [edge("ac", "a", "c", 100), edge("cb", "c", "b", 40)]}
        result = routing.calculate_route(graph, ["a", "b", "c"])
        self.assertEqual(result["length_m"], 180)
        self.assertEqual([item["distance_from_start_m"] for item in result["waypoints"]], [0, 140, 180])
        self.assert_continuous_route(graph, ["a", "b", "c"], result)

    def test_all_start_anchors_are_considered(self):
        graph = {"stations": [station("a", "0-isolated", "1-connected"), station("b", "b")],
                 "edges": [edge("ab", "1-connected", "b", 7)]}
        result = routing.calculate_route(graph, ["a", "b"])
        self.assertEqual(result["start_node"], "1-connected")
        self.assertEqual(result["length_m"], 7)
        self.assert_continuous_route(graph, ["a", "b"], result)

    def test_undirected_edges_preserve_reverse_traversal(self):
        graph = basic_graph()
        result = routing.calculate_route(graph, ["b", "a"])
        self.assertEqual(result["length_m"], 100.25)
        self.assertEqual(result["path"], [{"edge_id": "ab", "forward": False}])
        self.assert_continuous_route(graph, ["b", "a"], result)

    def test_repeated_waypoints_and_return_trip_keep_continuity(self):
        graph = basic_graph()
        for keys, expected in [(["a"], 0), (["a", "a"], 0), (["a", "a", "b", "a"], 200.5)]:
            with self.subTest(keys=keys):
                result = routing.calculate_route(graph, keys)
                self.assertEqual(result["length_m"], expected)
                self.assert_continuous_route(graph, keys, result)

    def test_unknown_and_unanchored_stations_remain_unconfirmed(self):
        graph = basic_graph()
        graph["stations"].append(station("empty"))
        for keys in (["a", "missing"], ["a", "empty"], ["empty", "b"]):
            with self.subTest(keys=keys):
                result = routing.calculate_route(graph, keys)
                self.assertEqual(result["status"], "unconfirmed")
                self.assertNotIn("path", result)

    def test_empty_station_sequence_is_rejected(self):
        with self.assertRaises(ValueError):
            routing.calculate_route(basic_graph(), [])

    def test_invalid_edge_weights_are_rejected(self):
        for value in (0, -1, True, "100", None, float("nan"), float("inf"), float("-inf")):
            with self.subTest(value=value):
                graph = basic_graph()
                graph["edges"][0]["length_m"] = value
                with self.assertRaises(ValueError):
                    routing.calculate_route(graph, ["a", "b"])

    def test_duplicate_edge_ids_are_rejected(self):
        graph = basic_graph()
        graph["edges"].append(edge("ab", "1", "2", 1))
        with self.assertRaises(ValueError):
            routing.calculate_route(graph, ["a", "b"])

    def test_parallel_edges_use_the_shorter_real_track(self):
        graph = basic_graph()
        graph["edges"].append(edge("shorter", "1", "2", 25))
        result = routing.calculate_route(graph, ["a", "b"])
        self.assertEqual(result["length_m"], 25)
        self.assertEqual(result["path"], [{"edge_id": "shorter", "forward": True}])
        self.assert_continuous_route(graph, ["a", "b"], result)


class CommittedRouteTests(RouteAssertions, unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.graph = json.loads((ROOT / "graph.json").read_text(encoding="utf-8"))
        cls.results = {saved["id"]: routing.calculate_route(cls.graph, saved["station_ids"])
                       for saved in cls.graph["routes"]}
        cls.results.update({key: routing.calculate_route(cls.graph, keys)
                            for key, (keys, _) in FIRST_LEGS.items()})

    def test_existing_routes_match_saved_distance_path_and_waypoints(self):
        self.assertEqual({saved["id"] for saved in self.graph["routes"]}, set(EXISTING_LENGTHS))
        for saved in self.graph["routes"]:
            with self.subTest(route=saved["id"]):
                result = self.results[saved["id"]]
                self.assertEqual(result["length_m"], EXISTING_LENGTHS[saved["id"]])
                for field in ("status", "length_m", "start_node", "end_node", "path", "waypoints"):
                    self.assertEqual(result[field], saved[field], field)
                self.assert_continuous_route(self.graph, saved["station_ids"], result)

    def test_first_leg_routes_match_continuous_reference_distances(self):
        for key, (keys, expected) in FIRST_LEGS.items():
            with self.subTest(route=key):
                self.assertEqual(self.results[key]["length_m"], expected)
                self.assert_continuous_route(self.graph, keys, self.results[key])

    def test_routes_markdown_totals_and_leg_tables_match_recalculation(self):
        markdown = (ROOT / "routes.md").read_text(encoding="utf-8")
        sections = re.split(r"(?m)^## ", markdown)
        names = {item["id"]: item["name"] for item in self.graph["stations"]}
        for key, result in self.results.items():
            with self.subTest(route=key):
                matches = [section for section in sections
                           if re.search(rf"경로 ID:\s*`{re.escape(key)}`", section)]
                self.assertEqual(len(matches), 1, f"Missing or duplicate route section: {key}")
                section = matches[0]
                total = re.search(r"총\s+\*\*([\d,.]+)km\*\*", section)
                self.assertIsNotNone(total, f"Missing total: {key}")
                digits = len(total[1].split(".")[-1]) if "." in total[1] else 0
                self.assertEqual(total[1].replace(",", ""), f"{result['length_m'] / 1000:.{digits}f}")
                rows = re.findall(r"(?m)^\|\s*([^|]+?)\s*\|\s*([\d,.]+)km\s*\|\s*([\d,.]+)km\s*\|", section)
                self.assertEqual(len(rows), len(result["waypoints"]) - 1)
                precision = 3 if key in FIRST_LEGS else 1
                for row, start, end in zip(rows, result["waypoints"], result["waypoints"][1:]):
                    labels = [label.strip() for label in row[0].split("→")]
                    self.assertEqual(len(labels), 2)
                    for label, waypoint in zip(labels, (start, end)):
                        accepted = {names[waypoint["station_id"]]}
                        if waypoint["station_id"] == "cottbus":
                            accepted.update({"코트부스", "코트부스 중앙역"})
                        self.assertIn(label, accepted)
                    length = end["distance_from_start_m"] - start["distance_from_start_m"]
                    self.assertEqual(row[1].replace(",", ""), f"{length / 1000:.{precision}f}")
                    self.assertEqual(row[2].replace(",", ""), f"{end['distance_from_start_m'] / 1000:.{precision}f}")
                if key in FIRST_LEGS:
                    self.assertIn(f"{result['length_m']:,.3f}m", section)


class RouteCliTests(unittest.TestCase):
    def setUp(self):
        temporary_root = ROOT / ".cache"
        temporary_root.mkdir(exist_ok=True)
        self.temporary = tempfile.TemporaryDirectory(prefix="routing-test-", dir=temporary_root)
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.script = self.directory / "route_from_graph.py"
        self.graph_file = self.directory / "graph.json"
        shutil.copyfile(ROOT / "route_from_graph.py", self.script)
        self.write_graph(basic_graph())

    def write_graph(self, graph):
        self.graph_file.write_text(json.dumps(graph), encoding="utf-8")

    def run_cli(self, *arguments):
        return subprocess.run([sys.executable, "-I", "-S", "-B", str(self.script), *arguments],
                              cwd=self.directory, capture_output=True, text=True, encoding="utf-8", timeout=30)

    def test_only_graph_and_script_support_all_real_data_modes(self):
        shutil.copyfile(ROOT / "graph.json", self.graph_file)
        self.assertEqual({path.name for path in self.directory.iterdir()}, {"route_from_graph.py", "graph.json"})
        direct = self.run_cli("--json", *FIRST_LEGS["first_leg_direct"][0])
        self.assertEqual(direct.returncode, 0, direct.stderr)
        self.assertEqual(json.loads(direct.stdout)["length_m"], FIRST_LEGS["first_leg_direct"][1])
        saved = self.run_cli("--route", "west_via_berlin", "--json")
        self.assertEqual(saved.returncode, 0, saved.stderr)
        self.assertEqual(json.loads(saved.stdout)["length_m"], EXISTING_LENGTHS["west_via_berlin"])
        checked = self.run_cli("--check", "--json")
        self.assertEqual(checked.returncode, 0, checked.stderr)
        self.assertEqual({row["id"] for row in json.loads(checked.stdout)}, set(EXISTING_LENGTHS))
        self.assertTrue(all(row["status"] == "PASS" for row in json.loads(checked.stdout)))
        listed = self.run_cli("--list-stations", "--json")
        self.assertEqual(listed.returncode, 0, listed.stderr)
        stations = json.loads(listed.stdout)
        self.assertEqual(len(stations), 67)
        self.assertIn("frankfurt", {item["id"] for item in stations})
        self.assertEqual({path.name for path in self.directory.iterdir()}, {"route_from_graph.py", "graph.json"})

    def test_graph_option_reads_selected_file_without_default_graph(self):
        selected = self.directory / "selected.json"
        self.graph_file.rename(selected)
        result = self.run_cli("--graph", str(selected), "a", "b", "--json")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["length_m"], 100.25)

    def test_invalid_requests_return_nonzero_status(self):
        for arguments in ((), ("a",), ("--route", "missing"), ("a", "b", "--check")):
            with self.subTest(arguments=arguments):
                self.assertEqual(self.run_cli(*arguments).returncode, 2)
        unknown = self.run_cli("a", "missing", "--json")
        self.assertEqual(unknown.returncode, 1)
        self.assertEqual(json.loads(unknown.stdout)["status"], "unconfirmed")

    def test_check_rejects_tampered_distance_path_and_waypoints(self):
        for field in ("length_m", "path", "waypoints"):
            with self.subTest(field=field):
                graph = basic_graph()
                saved = graph["routes"][0]
                if field == "length_m":
                    saved[field] += 1
                elif field == "path":
                    saved[field][0]["forward"] = False
                else:
                    saved[field][1]["distance_from_start_m"] += 1
                self.write_graph(graph)
                result = self.run_cli("--check", "--json")
                self.assertEqual(result.returncode, 1, result.stderr)
                checked = json.loads(result.stdout)[0]
                self.assertEqual(checked["status"], "FAIL")
                self.assertIn(field, checked["different_fields"])

    def test_check_rejects_invalid_weights_and_missing_saved_routes(self):
        for value in (0, -1, True, float("nan"), float("inf")):
            with self.subTest(value=value):
                graph = basic_graph()
                graph["edges"][0]["length_m"] = value
                self.write_graph(graph)
                self.assertEqual(self.run_cli("--check").returncode, 2)
        graph = basic_graph()
        graph["routes"] = []
        self.write_graph(graph)
        self.assertEqual(self.run_cli("--check").returncode, 2)

    def test_check_rejects_numeric_path_direction(self):
        graph = basic_graph()
        graph["routes"][0]["path"][0]["forward"] = 1
        self.write_graph(graph)
        result = self.run_cli("--check", "--json")
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("path", json.loads(result.stdout)[0]["different_fields"])

    def test_check_rejects_boolean_waypoint_distance(self):
        graph = basic_graph()
        graph["routes"][0]["waypoints"][0]["distance_from_start_m"] = False
        self.write_graph(graph)
        result = self.run_cli("--check", "--json")
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("waypoints", json.loads(result.stdout)[0]["different_fields"])

    def test_saved_route_mode_recomputes_instead_of_echoing_cached_path(self):
        graph = basic_graph()
        graph["routes"][0]["length_m"] = 999
        graph["routes"][0]["path"] = []
        self.write_graph(graph)
        result = self.run_cli("--route", "saved", "--json")
        self.assertEqual(result.returncode, 0, result.stderr)
        calculated = json.loads(result.stdout)
        self.assertEqual(calculated["length_m"], 100.25)
        self.assertEqual(calculated["path"], [{"edge_id": "ab", "forward": True}])


if __name__ == "__main__":
    unittest.main()
