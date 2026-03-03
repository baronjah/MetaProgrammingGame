#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from collections import defaultdict
from difflib import SequenceMatcher
from pathlib import Path

from bomb import run_scan, safe_read


def load_json(path: Path) -> dict:
    return json.loads(safe_read(path)) if path.exists() else {}


def first_impact_path(root: Path) -> Path:
    return root / "first_impact" / "first_impact.json"


def plan_path(root: Path) -> Path:
    return root / "first_impact" / "resurrection_plan.json"


def similarity(project_a: dict, project_b: dict) -> float:
    name_score = SequenceMatcher(None, project_a.get("project", ""), project_b.get("project", "")).ratio()
    fa = {f["name"] for s in project_a.get("scripts", []) for f in s.get("functions", [])}
    fb = {f["name"] for s in project_b.get("scripts", []) for f in s.get("functions", [])}
    overlap = (len(fa & fb) / len(fa | fb)) if (fa or fb) else 1.0
    return (name_score + overlap) / 2.0


def main() -> None:
    parser = argparse.ArgumentParser(description="Run data bomb on multiple paths")
    parser.add_argument("--paths", nargs="+", required=True)
    args = parser.parse_args()

    roots = [Path(p).expanduser().resolve() for p in args.paths]
    for root in roots:
        if root.exists() and root.is_dir():
            run_scan(root)

    impacts = {root: load_json(first_impact_path(root)) for root in roots}
    plans = {root: load_json(plan_path(root)) for root in roots}

    all_components = []
    func_map: dict[str, list[str]] = defaultdict(list)
    total_scripts = 0
    total_scenes = 0
    recommended = []

    for root in roots:
        fi = impacts[root]
        plan = plans[root]
        scripts = fi.get("scripts", [])
        scenes = fi.get("scenes", [])
        total_scripts += len(scripts)
        total_scenes += len(scenes)
        all_components.extend(plan.get("usable_components", []))
        recommended.append({"project": root.name, "suggested_branch": plan.get("suggested_branch", "")})
        for script in scripts:
            for fn in script.get("functions", []):
                func_map[fn["name"]].append(f"{root.name}/{script['file_path']}")

    cross = [{"function": fn, "appears_in": refs, "most_complete_version": refs[0]} for fn, refs in sorted(func_map.items()) if len(refs) > 1]

    duplicates = []
    roots_list = list(roots)
    for i in range(len(roots_list)):
        for j in range(i + 1, len(roots_list)):
            a = roots_list[i]
            b = roots_list[j]
            score = similarity(impacts[a], impacts[b])
            if score >= 0.7:
                duplicates.append({"a": a.name, "b": b.name, "similarity_score": score})

    for root in roots:
        fi = impacts[root]
        pairs = [d for d in duplicates if d["a"] == root.name or d["b"] == root.name]
        fi["similarity_pairs"] = pairs
        out = first_impact_path(root)
        out.write_text(json.dumps(fi, indent=2) + "\n", encoding="utf-8")

    catalogue = {
        "total_projects_scanned": len(roots),
        "total_scripts": total_scripts,
        "total_scenes": total_scenes,
        "all_components": all_components,
        "cross_project_connections": cross,
        "recommended_build_order": recommended,
        "possible_duplicates": duplicates,
    }
    (Path.cwd() / "master_catalogue.json").write_text(json.dumps(catalogue, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
