#!/usr/bin/env python3
"""Serve a local BMAD live board powered by filesystem artifacts."""

from __future__ import annotations

import argparse
import json
import re
from dataclasses import dataclass
from datetime import datetime, timezone
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Dict, List, Tuple
from urllib.parse import parse_qs, urlparse


SCRIPT_PATH = Path(__file__).resolve()
REPO_ROOT = SCRIPT_PATH.parents[1]
WORKSPACE_ROOT = SCRIPT_PATH.parents[2]
DEFAULT_BMAD_OUTPUT = WORKSPACE_ROOT / "_bmad-output"
DEFAULT_BMAD = WORKSPACE_ROOT / "_bmad"
HTML_PATH = REPO_ROOT / "ui-preview" / "bmad-local-dashboard.html"


EPIC_KEY_RE = re.compile(r"^epic-(\d+)$")
STORY_KEY_RE = re.compile(r"^(\d+)-(\d+)-([a-z0-9-]+)$")
EPIC_TITLE_RE = re.compile(r"^### Epic\s+(\d+):\s*(.+?)\s*$")
STORY_LINE_RE = re.compile(r"^-\s+(\d+)\.(\d+)\s+(.+?)\s*$")
STORY_FILE_TITLE_RE = re.compile(r"^# Story\s+\d+\.\d+:\s*(.+?)\s*$")
STATUS_LINE_RE = re.compile(r"^Status:\s*(.+?)\s*$")
CHECKBOX_TOTAL_RE = re.compile(r"^- \[(?: |x|X)\]", re.MULTILINE)
CHECKBOX_DONE_RE = re.compile(r"^- \[(?:x|X)\]", re.MULTILINE)


STORY_STATUS_ORDER = [
    "backlog",
    "ready-for-dev",
    "in-progress",
    "review",
    "done",
    "optional",
]
EPIC_STATUS_ORDER = ["backlog", "in-progress", "done", "optional"]


@dataclass
class ParsedStoryFile:
    title: str | None
    status: str | None
    checklist_done: int
    checklist_total: int
    updated_at: str | None


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except FileNotFoundError:
        return ""
    except OSError:
        return ""


def normalize_status(raw: str | None, fallback: str = "backlog") -> str:
    if not raw:
        return fallback
    value = raw.strip().lower()
    if value in STORY_STATUS_ORDER or value in EPIC_STATUS_ORDER:
        return value
    if value in {"ready", "ready for dev"}:
        return "ready-for-dev"
    if value in {"in progress", "doing", "wip"}:
        return "in-progress"
    return fallback


def parse_sprint_status(path: Path) -> Dict[str, str]:
    text = read_text(path)
    if not text:
        return {}

    statuses: Dict[str, str] = {}
    in_dev = False

    for raw_line in text.splitlines():
        line = raw_line.rstrip("\n")
        stripped = line.strip()

        if not in_dev:
            if stripped == "development_status:":
                in_dev = True
            continue

        if not stripped or stripped.startswith("#"):
            continue

        if not line.startswith("  "):
            break

        match = re.match(r"^\s{2}([a-z0-9-]+):\s*([a-z-]+)\s*$", line)
        if not match:
            continue
        key, value = match.group(1), match.group(2)
        statuses[key] = normalize_status(value, fallback=value)

    return statuses


def parse_epic_and_story_titles(files: List[Path]) -> Tuple[Dict[int, str], Dict[str, str]]:
    epic_titles: Dict[int, str] = {}
    story_titles: Dict[str, str] = {}
    current_epic: int | None = None

    for file_path in files:
        text = read_text(file_path)
        if not text:
            continue

        for raw_line in text.splitlines():
            line = raw_line.strip()

            epic_match = EPIC_TITLE_RE.match(line)
            if epic_match:
                current_epic = int(epic_match.group(1))
                epic_titles[current_epic] = epic_match.group(2).strip()
                continue

            story_match = STORY_LINE_RE.match(line)
            if story_match:
                epic = int(story_match.group(1))
                story = int(story_match.group(2))
                key = f"{epic}-{story}"
                story_titles[key] = story_match.group(3).strip()
                if current_epic is None:
                    current_epic = epic
                continue

    return epic_titles, story_titles


def parse_story_file(path: Path) -> ParsedStoryFile:
    text = read_text(path)
    if not text:
        return ParsedStoryFile(
            title=None,
            status=None,
            checklist_done=0,
            checklist_total=0,
            updated_at=None,
        )

    title: str | None = None
    status: str | None = None

    for raw_line in text.splitlines():
        if title is None:
            title_match = STORY_FILE_TITLE_RE.match(raw_line.strip())
            if title_match:
                title = title_match.group(1).strip()
                continue
        if status is None:
            status_match = STATUS_LINE_RE.match(raw_line.strip())
            if status_match:
                status = normalize_status(status_match.group(1), fallback="backlog")
        if title is not None and status is not None:
            break

    checklist_total = len(CHECKBOX_TOTAL_RE.findall(text))
    checklist_done = len(CHECKBOX_DONE_RE.findall(text))

    updated_at: str | None = None
    try:
        updated_at = datetime.fromtimestamp(path.stat().st_mtime, tz=timezone.utc).isoformat()
    except OSError:
        updated_at = None

    return ParsedStoryFile(
        title=title,
        status=status,
        checklist_done=checklist_done,
        checklist_total=checklist_total,
        updated_at=updated_at,
    )


def title_from_story_key(story_key: str) -> str:
    story_match = STORY_KEY_RE.match(story_key)
    if not story_match:
        return story_key
    slug = story_match.group(3)
    return slug.replace("-", " ").strip().title()


def resolve_output_path(query_output: str | None) -> Path:
    if not query_output:
        return DEFAULT_BMAD_OUTPUT
    raw = query_output.strip()
    if not raw:
        return DEFAULT_BMAD_OUTPUT
    candidate = Path(raw).expanduser()
    if not candidate.is_absolute():
        candidate = (WORKSPACE_ROOT / candidate).resolve()
    return candidate


def build_board_data(output_dir: Path) -> Dict[str, object]:
    impl_dir = output_dir / "implementation-artifacts"
    planning_dir = output_dir / "planning-artifacts"
    sprint_status_file = impl_dir / "sprint-status.yaml"
    epic_visual_file = planning_dir / "epics-stories-visualization.md"
    epics_file = planning_dir / "epics.md"

    statuses = parse_sprint_status(sprint_status_file)
    epic_titles, story_titles = parse_epic_and_story_titles([epic_visual_file, epics_file])

    epic_entries: List[Dict[str, object]] = []
    story_entries: List[Dict[str, object]] = []
    warnings: List[str] = []

    if not output_dir.exists():
        warnings.append(f"Output path does not exist: {output_dir}")
    if not sprint_status_file.exists():
        warnings.append(f"sprint-status.yaml not found: {sprint_status_file}")

    story_keys_in_status = set()
    epic_keys_in_status = set()

    for key, value in statuses.items():
        epic_match = EPIC_KEY_RE.match(key)
        if epic_match:
            epic_number = int(epic_match.group(1))
            epic_keys_in_status.add(key)
            epic_entries.append(
                {
                    "key": key,
                    "number": epic_number,
                    "title": epic_titles.get(epic_number, f"Epic {epic_number}"),
                    "status": normalize_status(value, fallback="backlog"),
                }
            )
            continue

        story_match = STORY_KEY_RE.match(key)
        if not story_match:
            continue

        epic_number = int(story_match.group(1))
        story_number = int(story_match.group(2))
        compact_story_key = f"{epic_number}-{story_number}"
        story_file = impl_dir / f"{key}.md"
        parsed = parse_story_file(story_file)

        mapped_status = normalize_status(value, fallback="backlog")
        effective_status = mapped_status
        file_status = parsed.status
        status_mismatch = bool(file_status and file_status != mapped_status)

        if key not in story_keys_in_status:
            story_keys_in_status.add(key)

        title = story_titles.get(compact_story_key) or parsed.title or title_from_story_key(key)

        story_entries.append(
            {
                "key": key,
                "epic_number": epic_number,
                "story_number": story_number,
                "display_number": f"{epic_number}.{story_number}",
                "title": title,
                "status": effective_status,
                "status_from_sprint": mapped_status,
                "status_from_file": file_status,
                "status_mismatch": status_mismatch,
                "file_path": str(story_file),
                "file_exists": story_file.exists(),
                "updated_at": parsed.updated_at,
                "checklist_done": parsed.checklist_done,
                "checklist_total": parsed.checklist_total,
            }
        )

    # Include story files that are present but missing in sprint-status
    if impl_dir.exists():
        for file_path in sorted(impl_dir.glob("*.md")):
            story_key = file_path.stem
            match = STORY_KEY_RE.match(story_key)
            if not match or story_key in story_keys_in_status:
                continue

            epic_number = int(match.group(1))
            story_number = int(match.group(2))
            compact_story_key = f"{epic_number}-{story_number}"
            parsed = parse_story_file(file_path)
            fallback_status = parsed.status or "backlog"
            title = story_titles.get(compact_story_key) or parsed.title or title_from_story_key(story_key)

            story_entries.append(
                {
                    "key": story_key,
                    "epic_number": epic_number,
                    "story_number": story_number,
                    "display_number": f"{epic_number}.{story_number}",
                    "title": title,
                    "status": normalize_status(fallback_status, fallback="backlog"),
                    "status_from_sprint": None,
                    "status_from_file": parsed.status,
                    "status_mismatch": False,
                    "file_path": str(file_path),
                    "file_exists": True,
                    "updated_at": parsed.updated_at,
                    "checklist_done": parsed.checklist_done,
                    "checklist_total": parsed.checklist_total,
                }
            )

    epic_map: Dict[int, Dict[str, object]] = {}
    for epic in epic_entries:
        epic_map[int(epic["number"])] = dict(epic)

    for story in story_entries:
        number = int(story["epic_number"])
        if number not in epic_map:
            epic_map[number] = {
                "key": f"epic-{number}",
                "number": number,
                "title": epic_titles.get(number, f"Epic {number}"),
                "status": "backlog",
            }

    epic_progress: List[Dict[str, object]] = []
    for epic_number in sorted(epic_map.keys()):
        epic = epic_map[epic_number]
        stories = [s for s in story_entries if int(s["epic_number"]) == epic_number]
        total = len(stories)
        done = sum(1 for s in stories if s["status"] == "done")
        in_progress = sum(1 for s in stories if s["status"] == "in-progress")
        review = sum(1 for s in stories if s["status"] == "review")
        backlog = sum(1 for s in stories if s["status"] in {"backlog", "ready-for-dev"})
        progress = int((done / total) * 100) if total else 0

        epic_progress.append(
            {
                "key": epic["key"],
                "number": epic_number,
                "title": epic["title"],
                "status": epic["status"],
                "story_total": total,
                "story_done": done,
                "story_in_progress": in_progress,
                "story_review": review,
                "story_backlog": backlog,
                "progress_percent": progress,
            }
        )

    story_entries.sort(key=lambda s: (int(s["epic_number"]), int(s["story_number"])))
    epic_progress.sort(key=lambda e: int(e["number"]))

    stories_by_status: Dict[str, int] = {status: 0 for status in STORY_STATUS_ORDER}
    for story in story_entries:
        status = str(story["status"])
        stories_by_status[status] = stories_by_status.get(status, 0) + 1

    status_mismatch_count = sum(1 for s in story_entries if s["status_mismatch"])
    missing_file_count = sum(1 for s in story_entries if not s["file_exists"])

    return {
        "generated_at": now_iso(),
        "workspace_root": str(WORKSPACE_ROOT),
        "bmad_root": str(DEFAULT_BMAD),
        "bmad_output": str(output_dir),
        "sprint_status_file": str(sprint_status_file),
        "story_count": len(story_entries),
        "epic_count": len(epic_progress),
        "stories_by_status": stories_by_status,
        "status_mismatch_count": status_mismatch_count,
        "missing_file_count": missing_file_count,
        "warnings": warnings,
        "epics": epic_progress,
        "stories": story_entries,
    }


class BMADLiveBoardHandler(BaseHTTPRequestHandler):
    def _send_json(self, payload: Dict[str, object], status: int = HTTPStatus.OK) -> None:
        content = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(content)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(content)

    def _send_html(self, html: str, status: int = HTTPStatus.OK) -> None:
        content = html.encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(content)))
        self.end_headers()
        self.wfile.write(content)

    def _send_not_found(self) -> None:
        self._send_json({"error": "Not found"}, status=HTTPStatus.NOT_FOUND)

    def do_GET(self) -> None:  # noqa: N802
        parsed = urlparse(self.path)

        if parsed.path in {"/", "/index.html", "/bmad-local-dashboard.html"}:
            html = read_text(HTML_PATH)
            if not html:
                self._send_html("<h1>Dashboard file not found</h1>", status=HTTPStatus.NOT_FOUND)
                return
            self._send_html(html)
            return

        if parsed.path == "/api/board":
            params = parse_qs(parsed.query)
            output_dir = resolve_output_path(params.get("output", [None])[0])
            data = build_board_data(output_dir)
            self._send_json(data)
            return

        self._send_not_found()

    def log_message(self, format: str, *args: object) -> None:  # noqa: A003
        return


def run_server(host: str, port: int) -> None:
    server = ThreadingHTTPServer((host, port), BMADLiveBoardHandler)
    print(f"BMAD live board running at http://{host}:{port}")
    print(f"Dashboard URL: http://{host}:{port}/bmad-local-dashboard.html")
    print(f"Default BMAD output path: {DEFAULT_BMAD_OUTPUT}")
    print("Press Ctrl+C to stop.")
    server.serve_forever()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Serve BMAD local live board.")
    parser.add_argument("--host", default="127.0.0.1", help="Host to bind (default: 127.0.0.1)")
    parser.add_argument("--port", type=int, default=4173, help="Port to bind (default: 4173)")
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    run_server(args.host, args.port)
