#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from collections import defaultdict
from pathlib import Path

from bomb import run_scan, safe_read


def load_first_impact(path: Path) -> dict:
    f = path / "first_impact" / "first_impact.json"
    return json.loads(safe_read(f)) if f.exists() else {}


def load_plan(path: Path) -> dict:
    f = path / "first_impact" / "resurrection_plan.json"
    return json.loads(safe_read(f)) if f.exists() else {}


def main() -> None:
    parser = argparse.ArgumentParser(description="Run data bomb on multiple paths")
    parser.add_argument("--paths", nargs="+", required=True)
    args = parser.parse_args()

    roots = [Path(p).expanduser().resolve() for p in args.paths]
    for root in roots:
        if root.exists() and root.is_dir():
            run_scan(root)

    all_components = []
    func_map: dict[str, list[str]] = defaultdict(list)
    total_scripts = 0
    total_scenes = 0
    recommendations = []

    for root in roots:
        first_impact = load_first_impact(root)
        plan = load_plan(root)
        scripts = first_impact.get("scripts", [])
        scenes = first_impact.get("scenes", [])
        total_scripts += len(scripts)
        total_scenes += len(scenes)
        all_components.extend(plan.get("usable_components", []))
        recommendations.append({"project": root.name, "suggested_branch": plan.get("suggested_branch", "")})
        for script in scripts:
            for fn in script.get("functions", []):
                func_map[fn["name"]].append(f"{root.name}/{script['file_path']}")

    cross = []
    for fn_name, appears in sorted(func_map.items()):
        if len(appears) > 1:
            cross.append({"function": fn_name, "appears_in": appears, "most_complete_version": appears[0]})

    catalogue = {
        "total_projects_scanned": len(roots),
        "total_scripts": total_scripts,
        "total_scenes": total_scenes,
        "all_components": all_components,
        "cross_project_connections": cross,
        "recommended_build_order": recommendations,
    }

    out = Path.cwd() / "master_catalogue.json"
    out.write_text(json.dumps(catalogue, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
