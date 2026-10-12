#!/usr/bin/env python3
"""Build a .macscript storyboard project from a small JSON spec.

The macScript file format is plain JSON: every shot can carry an image as
base64 in `imageData`, which is what the app writes when you paste a frame.
This script assembles that JSON so a storyboard can be produced from extracted
video frames without touching the UI.

Spec:
{
  "title": "AMK 2026 AW",
  "teamName": "制作团队",
  "aspect": "16:9",              // or "9:16", "4:5", or a number
  "minimumRowHeight": 116,
  "columns": [
    {"role": "order", "visible": false},
    {"role": "frameImage", "width": 280},
    {"title": "旁白", "custom": true, "width": 260}
  ],
  "shots": [
    {"shotSize": "一镜到底", "duration": "6", "content": "...",
     "note": "...", "frame": "frames/01.jpg", "custom": {"旁白": "..."}}
  ]
}

Only the columns an ordinary storyboard needs have to be listed; anything
omitted falls back to the app defaults. Paths resolve relative to the spec file.
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import re
import subprocess
import sys
import tempfile
import uuid

BUILT_IN_ORDER = ["order", "shotNumber", "frameImage", "shotSize", "duration", "content", "note"]
DEFAULT_TITLES = {
    "order": "排序",
    "shotNumber": "镜号",
    "frameImage": "画面",
    "shotSize": "景别",
    "duration": "时长(秒)",
    "content": "内容",
    "note": "备注",
}
DEFAULT_WIDTHS = {
    "order": 78,
    "shotNumber": 92,
    "frameImage": 300,
    "shotSize": 118,
    "duration": 110,
    "content": 360,
    "note": 250,
    "customText": 180,
}
DEFAULT_ASPECT = 16.0 / 9.0


def parse_aspect(value) -> float:
    if value is None:
        return DEFAULT_ASPECT
    if isinstance(value, (int, float)):
        return float(value)
    text = str(value).strip()
    match = re.fullmatch(r"\s*(\d+(?:\.\d+)?)\s*[:/]\s*(\d+(?:\.\d+)?)\s*", text)
    if not match:
        raise ValueError(f"无法解析画幅比: {value!r}（用 16:9 或 1.7778）")
    width, height = float(match.group(1)), float(match.group(2))
    if height == 0:
        raise ValueError(f"画幅比出错: {value!r}")
    return width / height


def slugify(text: str) -> str:
    slug = re.sub(r"[^0-9a-zA-Z]+", "-", text).strip("-").lower()
    return slug or "col"


def embed_image(path: str, max_width: int) -> str:
    """Downscale if needed, then return base64 bytes."""
    if not os.path.isfile(path):
        raise FileNotFoundError(path)

    source = path
    temporary = None
    if max_width > 0:
        handle, temporary = tempfile.mkstemp(suffix=os.path.splitext(path)[1] or ".jpg")
        os.close(handle)
        result = subprocess.run(
            ["sips", "--resampleWidth", str(max_width), path, "--out", temporary],
            capture_output=True,
            text=True,
        )
        # sips refuses to upscale; that is fine, keep the original.
        if result.returncode == 0 and os.path.getsize(temporary) > 0:
            source = temporary
        else:
            os.unlink(temporary)
            temporary = None

    try:
        with open(source, "rb") as handle:
            return base64.b64encode(handle.read()).decode("ascii")
    finally:
        if temporary and os.path.exists(temporary):
            os.unlink(temporary)


def build_columns(spec_columns) -> tuple[list[dict], list[dict]]:
    """Return (columns, custom_columns). Custom columns keep their spec order."""
    provided = list(spec_columns or [])
    seen_builtin = set()
    columns: list[dict] = []
    custom_columns: list[dict] = []
    custom_index = 0

    for entry in provided:
        role = entry.get("role")
        if entry.get("custom") or role in (None, "custom", "customText"):
            title = str(entry.get("title") or "新列")
            custom_index += 1
            column = {
                "id": f"custom-{slugify(title)}-{custom_index}",
                "title": title,
                "width": entry.get("width", DEFAULT_WIDTHS["customText"]),
                "isVisible": entry.get("visible", True),
                "role": "customText",
            }
            custom_columns.append(column)
            continue

        if role not in BUILT_IN_ORDER:
            raise ValueError(f"未知列 role: {role!r}")
        if role in seen_builtin:
            continue
        seen_builtin.add(role)
        columns.append(
            {
                "id": role,
                "title": entry.get("title", DEFAULT_TITLES[role]),
                "width": entry.get("width", DEFAULT_WIDTHS[role]),
                "isVisible": entry.get("visible", True),
                "role": role,
            }
        )

    if any(column["role"] == "order" and not column["isVisible"] for column in columns):
        print(
            "注意：隐藏「排序」列会连带隐藏每一行左侧的拖动 / 新增 / 删除按钮，"
            "工程文件将无法直接增删调整镜头。除非只是导出用的副本，否则保持它可见。",
            file=sys.stderr,
        )

    if custom_columns:
        print(
            "注意：只要工程里有自定义列，macScript 打开时会自动把 景别 / 时长 / 内容 / 备注 "
            "压到最小宽度（90 / 86 / 220 / 150）来给新列腾位置，正文字会被挤得很难看。"
            "优先用内置列并改标题（例如把 备注 的 title 改成 旁白），而不是加自定义列。",
            file=sys.stderr,
        )

    for role in BUILT_IN_ORDER:
        if role in seen_builtin:
            continue
        columns.append(
            {
                "id": role,
                "title": DEFAULT_TITLES[role],
                "width": DEFAULT_WIDTHS[role],
                "isVisible": True,
                "role": role,
            }
        )

    return columns, custom_columns


def build_shot(item: dict, index: int, base_dir: str, max_width: int, custom_columns: list[dict]) -> dict:
    shot = {
        "id": str(uuid.uuid4()).upper(),
        "shotNumber": index + 1,
        "shotSize": str(item.get("shotSize", "")),
        "duration": str(item.get("duration", "")),
        "content": str(item.get("content", "")),
        "note": str(item.get("note", "")),
        "customValues": {},
    }

    frame = item.get("frame")
    if frame:
        frame_path = frame if os.path.isabs(frame) else os.path.join(base_dir, frame)
        shot["imageData"] = embed_image(frame_path, max_width)

    custom_values = item.get("custom") or {}
    titles = {column["title"]: column["id"] for column in custom_columns}
    unknown = [key for key in custom_values if key not in titles]
    if unknown:
        raise ValueError(f"镜头 {index + 1} 的自定义列 {unknown} 没有对应列，检查 columns 里的 title")
    for title, value in custom_values.items():
        shot["customValues"][titles[title]] = str(value)

    return shot


def build_project(spec: dict, base_dir: str, max_width: int) -> dict:
    columns, custom_columns = build_columns(spec.get("columns"))
    shots = spec.get("shots") or []
    if not shots:
        raise ValueError("spec 里没有 shots")

    return {
        "title": spec.get("title") or "未命名脚本",
        "teamName": spec.get("teamName") or "制作团队",
        "columns": columns + custom_columns,
        "shots": [build_shot(item, index, base_dir, max_width, custom_columns) for index, item in enumerate(shots)],
        "frameAspectRatio": parse_aspect(spec.get("aspect")),
        "minimumRowHeight": spec.get("minimumRowHeight", 116),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="把 JSON 分镜规格打包成 .macscript")
    parser.add_argument("spec", help="分镜规格 JSON")
    parser.add_argument("-o", "--output", required=True, help="输出的 .macscript 路径")
    parser.add_argument("--base-dir", default=None, help="图片相对路径的基准目录，默认是 spec 所在目录")
    parser.add_argument("--max-width", type=int, default=1600, help="内嵌图片的最大宽度，0 表示不改尺寸")
    parser.add_argument(
        "--hide",
        default="",
        help="逗号分隔的列（role 或标题），在输出的工程里隐藏；导出 PDF 用的打印版通常写 --hide order",
    )
    arguments = parser.parse_args()

    spec_path = os.path.abspath(os.path.expanduser(arguments.spec))
    base_dir = arguments.base_dir or os.path.dirname(spec_path)
    with open(spec_path, "r", encoding="utf-8") as handle:
        spec = json.load(handle)

    project = build_project(spec, base_dir, arguments.max_width)

    hidden = [item.strip() for item in arguments.hide.split(",") if item.strip()]
    for column in project["columns"]:
        if column["role"] in hidden or column["title"] in hidden:
            column["isVisible"] = False

    output = os.path.abspath(os.path.expanduser(arguments.output))
    os.makedirs(os.path.dirname(output), exist_ok=True)
    with open(output, "w", encoding="utf-8") as handle:
        json.dump(project, handle, ensure_ascii=False, indent=2, sort_keys=True)
        handle.write("\n")

    table_width = sum(column["width"] for column in project["columns"] if column["isVisible"])
    frames = sum(1 for shot in project["shots"] if "imageData" in shot)
    print(
        f"{output}\n{len(project['shots'])} 个镜头，{frames} 张画面，"
        f"可见列宽合计 {table_width:.0f}，{os.path.getsize(output) / 1048576:.1f} MB"
    )
    if table_width > 1360:
        print(
            f"注意：可见列宽合计 {table_width:.0f} 超过 PDF 页面的可用宽度 1360，"
            "右边缘会被裁掉，减列或缩列宽。",
            file=sys.stderr,
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
