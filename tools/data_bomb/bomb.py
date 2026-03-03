#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
from collections import Counter
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


FUNC_RE = re.compile(r"^\s*func\s+(\w+)\s*\(([^)]*)\)")
CLASS_RE = re.compile(r"^\s*class_name\s+(\w+)")
EXTENDS_RE = re.compile(r"^\s*extends\s+([\w\.]+)")
SIGNAL_RE = re.compile(r"^\s*signal\s+(\w+)")
VAR_RE = re.compile(r"^\s*var\s+(\w+)(?:\s*:\s*([^=]+))?")
LOCAL_VAR_RE = re.compile(r"\bvar\s+(\w+)(?:\s*:\s*([A-Za-z0-9_\.]+))?")


@dataclass
class ScanState:
    scripts: list[dict[str, Any]]
    scenes: list[dict[str, Any]]
    python_files: list[str]
    markdown_files: list[str]


def safe_read(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return path.read_text(encoding="latin-1", errors="ignore")


def to_res(path: Path, root: Path) -> str:
    rel = path.relative_to(root).as_posix()
    return f"res://{rel}"


def list_files(root: Path, pattern: str) -> list[Path]:
    return sorted(p for p in root.rglob(pattern) if p.is_file())


def detect(root: Path) -> dict[str, Any]:
    gd = list_files(root, "*.gd")
    cs = list_files(root, "*.cs")
    tscn = list_files(root, "*.tscn")
    tres = list_files(root, "*.tres")
    py = list_files(root, "*.py")
    md = list_files(root, "*.md")
    json_files = list_files(root, "*.json")
    req = list_files(root, "requirements.txt")
    return {
        "path": str(root),
        "is_godot_project": (root / "project.godot").exists(),
        "languages": {
            "gdscript": bool(gd),
            "csharp": bool(cs),
            "python": bool(py),
        },
        "counts": {
            "gd_files": len(gd),
            "cs_files": len(cs),
            "scene_files": len(tscn),
            "resource_files": len(tres),
            "json_files": len(json_files),
            "python_files": len(py),
            "markdown_files": len(md),
        },
        "has_requirements_txt": bool(req),
    }




def has_paired_tscn(file_path: Path) -> bool:
    return file_path.with_suffix(".tscn").exists()


def detect_script_type(file_path: Path, content: str, project_autoloads: set[str]) -> str:
    res_path = f"res://{file_path.as_posix()}"
    if res_path in project_autoloads or "/autoload/" in res_path.lower():
        return "autoload"
    if "extends EditorPlugin" in content or "/addons/" in res_path.lower():
        return "addon"
    if "class_name" in content and "@tool" in content:
        return "tool_script"
    if "class_name" in content:
        return "class_named"
    if has_paired_tscn(file_path):
        return "scene_script"
    return "orphan"


def parse_project_autoloads(root: Path) -> set[str]:
    project = root / "project.godot"
    if not project.exists():
        return set()
    result = set()
    for line in safe_read(project).splitlines():
        if '=' in line and '.gd' in line and '*' in line:
            right = line.split('=', 1)[1].strip().strip('"')
            if right.startswith("res://"):
                result.add(right)
    return result

def parse_gd(path: Path, root: Path, project_autoloads: set[str]) -> dict[str, Any]:
    text = safe_read(path)
    lines = text.splitlines()
    class_name = ""
    extends = ""
    signals: list[str] = []
    variables: list[dict[str, str]] = []
    functions: list[dict[str, Any]] = []
    known_names: list[str] = []

    for i, line in enumerate(lines, start=1):
        if m := CLASS_RE.match(line):
            class_name = m.group(1)
        if m := EXTENDS_RE.match(line):
            extends = m.group(1)
        if m := SIGNAL_RE.match(line):
            signals.append(m.group(1))
        if m := VAR_RE.match(line):
            variables.append({"name": m.group(1), "type": (m.group(2) or "").strip(), "scope": "global"})
        if m := FUNC_RE.match(line):
            name = m.group(1)
            params = [p.strip() for p in m.group(2).split(",") if p.strip()]
            known_names.append(name)
            functions.append({
                "name": name,
                "params": params,
                "line_start": i,
                "line_end": i,
                "calls_external": [],
                "suspected_duality_pair": None,
                "missing_polar_opposite": False,
            })

    for idx, fn in enumerate(functions):
        start = fn["line_start"] - 1
        end = len(lines)
        if idx + 1 < len(functions):
            end = functions[idx + 1]["line_start"] - 1
        fn["line_end"] = end
        body = "\n".join(lines[start:end])
        calls = sorted(set(re.findall(r"\b([A-Z][A-Za-z0-9_]+)\.", body)))
        fn["calls_external"] = calls
        fn["var_legend"] = build_var_legend_stub(fn["params"], body)
        fn["dna"] = {"type": classify_dna(body), "classified_by": "data_bomb"}

    for fn in functions:
        name = fn["name"]
        pair = None
        if name.startswith("apply_"):
            for prefix in ("remove_", "reverse_"):
                candidate = prefix + name[len("apply_"):]
                if candidate in known_names:
                    pair = candidate
                    break
        elif name.startswith("spawn_"):
            candidate = name.replace("spawn_", "despawn_", 1)
            if candidate in known_names:
                pair = candidate
        fn["suspected_duality_pair"] = pair
        fn["missing_polar_opposite"] = pair is None

    script_type = detect_script_type(path.relative_to(root), text, project_autoloads)
    return {
        "file_path": to_res(path, root),
        "script_type": script_type,
        "recommended_registry_type": script_type,
        "class_name": class_name,
        "extends": extends,
        "is_autoload": "autoload" in [p.lower() for p in path.parts],
        "functions": functions,
        "signals": signals,
        "variables": variables,
        "connection_points": sorted({c for f in functions for c in f["calls_external"]}),
        "raw_line_count": len(lines),
        "needs_split": len(lines) > 400,
    }




def build_var_legend_stub(params: list[str], body: str) -> dict[str, dict[str, str | list[str] | bool]]:
    legend: dict[str, dict[str, str | list[str] | bool]] = {}
    for param in params:
        name = param.split(":", 1)[0].strip()
        ptype = param.split(":", 1)[1].strip() if ":" in param else "Variant"
        if name:
            legend[name] = {
                "type": ptype,
                "role": "unknown",
                "passed_from": "unknown",
                "previous_names": [],
                "current_name": name,
                "needs_annotation": True,
            }
    for m in LOCAL_VAR_RE.finditer(body):
        name = m.group(1)
        ptype = m.group(2) or "Variant"
        if name not in legend:
            legend[name] = {
                "type": ptype,
                "role": "unknown",
                "passed_from": "local",
                "previous_names": [],
                "current_name": name,
                "needs_annotation": True,
            }
    return legend



def classify_dna(func_source: str) -> str:
    if any(k in func_source for k in ["add_child", "remove_child", "reparent", "free()"]):
        return "TREE_STRUCTURE"
    if "FileAccess.open" in func_source:
        if "WRITE" in func_source or "READ_WRITE" in func_source:
            return "WRITE_RESOURCE"
        return "READ_FILE"
    if "Scriptura." in func_source or "ScriptRegistry." in func_source:
        if any(k in func_source for k in ["set_", "register_", "push_", "= "]):
            return "MUTATE_GLOBAL"
        if ".duplicate()" in func_source:
            return "COPY_GLOBAL"
        return "QUERY_GLOBAL"
    if any(k in func_source for k in [".position", ".visible", "set_script", ".scale"]):
        return "MUTATE_NODE"
    if any(k in func_source for k in ["get_path()", "is_inside_tree"]):
        return "QUERY_NODE"
    if "return " in func_source:
        return "RETURN_VALUE"
    return "UNKNOWN"

def parse_tscn(path: Path, root: Path) -> dict[str, Any]:
    text = safe_read(path)
    nodes = re.findall(r'^\[node name="([^"]+)" type="([^"]+)"(?: parent="([^"]*)")?\]$', text, flags=re.MULTILINE)
    root_node_type = nodes[0][1] if nodes else "Unknown"
    child_nodes = [n[0] for n in nodes[1:]]
    script_match = re.search(r'^script = ExtResource\("(\d+)"\)$', text, flags=re.MULTILINE)
    ext_map = {m.group(2): m.group(1) for m in re.finditer(r'^\[ext_resource type="Script" path="([^"]+)" id="([^"]+)"\]$', text, flags=re.MULTILINE)}
    script_path = ext_map.get(script_match.group(1), "") if script_match else ""
    purpose = "menu or world container" if any(x in path.name.lower() for x in ["menu", "world"]) else "scene"
    return {
        "scene_path": to_res(path, root),
        "root_node_type": root_node_type,
        "node_count": len(nodes),
        "script_attached": script_path,
        "child_nodes": child_nodes,
        "suspected_purpose": purpose,
    }


def categorize(gd_data: list[dict[str, Any]], scenes: list[dict[str, Any]], root: Path) -> dict[str, list[str]]:
    cats: dict[str, list[str]] = {k: [] for k in ["autoload", "ui_mesh", "system", "scene_world", "tool_script", "orphan", "python_companion", "documentation"]}
    scene_scripts = {s["script_attached"] for s in scenes if s.get("script_attached")}
    for gd in gd_data:
        p = gd["file_path"]
        low = p.lower()
        if "/autoload/" in low:
            cats["autoload"].append(p)
        if "/systems/" in low:
            cats["system"].append(p)
        if "/ui/" in low or "panel" in low or "menu" in low:
            cats["ui_mesh"].append(p)
        if "/tools/" in low:
            cats["tool_script"].append(p)
        if p not in scene_scripts and p not in cats["autoload"] and p not in cats["system"]:
            cats["orphan"].append(p)
    for s in scenes:
        cats["scene_world"].append(s["scene_path"])
    for p in list_files(root, "*.py"):
        cats["python_companion"].append(p.relative_to(root).as_posix())
    for p in list_files(root, "*.md"):
        cats["documentation"].append(p.relative_to(root).as_posix())
    return cats




def python_path_strategy(script_type: str, target_name: str) -> dict[str, str | bool | None]:
    if target_name in {"Scriptura", "ScriptRegistry", "PathResolver", "ConsciousnessBridge"}:
        return {"strategy": "autoload_direct", "snippet": target_name, "target_scene": None, "needs_scene_load": False}
    if script_type == "class_named":
        return {"strategy": "inject_dependency", "snippet": "pass as param", "target_scene": None, "needs_scene_load": False}
    if script_type == "scene_script":
        return {"strategy": "cross_scene", "snippet": f"get_node('/root/{target_name}')", "target_scene": None, "needs_scene_load": True}
    return {"strategy": "root_climb", "snippet": "get_tree().root", "target_scene": None, "needs_scene_load": True}

def resurrection_plan(root: Path, data: ScanState) -> dict[str, Any]:
    missing = []
    over = []
    components = []
    for script in data.scripts:
        if script["needs_split"]:
            over.append(script["file_path"])
        for fn in script["functions"]:
            if fn["missing_polar_opposite"]:
                missing.append(f"{script['file_path']}::{fn['name']}")
            path_info = {c: python_path_strategy(script.get("script_type", "orphan"), c) for c in fn["calls_external"]}
            components.append({
                "component_id": f"{fn['name']}_v1",
                "source_file": script["file_path"],
                "function": fn["name"],
                "duality_complete": not fn["missing_polar_opposite"],
                "recommendation": "extract/add polar opposite" if fn["missing_polar_opposite"] else "keep and wire to Scriptura",
                "path_strategies": path_info,
            })
    return {
        "project_name": root.name,
        "original_path": str(root),
        "first_impact_version": "1.0",
        "date_scanned": datetime.now(timezone.utc).isoformat(),
        "health": {
            "orphan_scripts": len([s for s in data.scripts if s["is_autoload"] is False and not s["file_path"].startswith("res://systems/")]),
            "missing_duality_pairs": len(missing),
            "files_over_400_lines": len(over),
            "autoloads_detected": len([s for s in data.scripts if s["is_autoload"]]),
        },
        "usable_components": components,
        "missing_polar_opposites": missing,
        "suggested_branch": "feature/duality-functions",
        "suggested_merge_target": "MetaProgrammingGame",
    }


def scavenge_notes(root: Path, data: ScanState, plan: dict[str, Any]) -> str:
    autoloads = [s["class_name"] or s["file_path"] for s in data.scripts if s["is_autoload"]]
    missing = plan["missing_polar_opposites"]
    over = [s["file_path"] for s in data.scripts if s["needs_split"]]
    orphan = [s["file_path"] for s in data.scripts if not s["is_autoload"] and not s["file_path"].startswith("res://systems/")]
    complete = sum(1 for s in data.scripts for f in s["functions"] if not f["missing_polar_opposite"])
    return f"""# SCAVENGE REPORT — {root.name}
Scanned: {datetime.now(timezone.utc).date().isoformat()}

## What I Found
- {len(data.scripts)} scripts, {len(data.scenes)} scenes, {len(orphan)} orphans
- Autoloads: {', '.join(autoloads) if autoloads else 'none'}
- Python companions: {', '.join(data.python_files) if data.python_files else 'none'}

## Duality Health
- Complete pairs: {complete}
- Missing polar opposites: {', '.join(missing) if missing else 'none'}

## Resurrection Priority
1. Scriptura core and law bindings
2. Missing duality pairs in systems
3. Orphan classification and integration

## Danger Zones
- Files over 400 lines: {', '.join(over) if over else 'none'}
- Orphan scripts with no clear purpose: {', '.join(orphan) if orphan else 'none'}

## Notes
Generated by tools/data_bomb/bomb.py.
UNKNOWN DNA functions need human classification.
"""


def run_scan(root: Path) -> None:
    out = root / "first_impact"
    out.mkdir(exist_ok=True)

    detection = detect(root)
    project_autoloads = parse_project_autoloads(root)
    scripts = [parse_gd(p, root, project_autoloads) for p in list_files(root, "*.gd")]
    scenes = [parse_tscn(p, root) for p in list_files(root, "*.tscn")]
    py = [p.relative_to(root).as_posix() for p in list_files(root, "*.py")]
    md = [p.relative_to(root).as_posix() for p in list_files(root, "*.md")]
    categories = categorize(scripts, scenes, root)
    state = ScanState(scripts=scripts, scenes=scenes, python_files=py, markdown_files=md)
    plan = resurrection_plan(root, state)

    first_impact = {
        "project": root.name,
        "scripts": scripts,
        "scenes": scenes,
        "categories": categories,
        "duality_summary": dict(Counter([f["missing_polar_opposite"] for s in scripts for f in s["functions"]])),
    }

    (out / "detection_report.json").write_text(json.dumps(detection, indent=2) + "\n", encoding="utf-8")
    (out / "first_impact.json").write_text(json.dumps(first_impact, indent=2) + "\n", encoding="utf-8")
    (out / "resurrection_plan.json").write_text(json.dumps(plan, indent=2) + "\n", encoding="utf-8")
    (out / "SCAVENGE_NOTES.md").write_text(scavenge_notes(root, state, plan), encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description="Data Bomb scanner")
    parser.add_argument("--path", required=True, help="Path to scan")
    args = parser.parse_args()
    target = Path(args.path).expanduser().resolve()
    if not target.exists() or not target.is_dir():
        raise SystemExit(f"Invalid path: {target}")
    run_scan(target)


if __name__ == "__main__":
    main()
