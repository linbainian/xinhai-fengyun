"""Normalize built-in ImageGen portraits and record their provenance without altering world art."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageOps

GAME = Path(__file__).resolve().parents[1]
CATALOG = GAME / "data/portraits/characters.json"
CANVAS = (768, 1152)


def resource_path(value: str) -> Path:
    if not value.startswith("res://"):
        raise ValueError("Expected a project resource path: " + value)
    path = (GAME / value[6:]).resolve()
    if not path.is_relative_to(GAME.resolve()):
        raise ValueError("Portrait path escapes the project")
    return path


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def normalize(entry: dict) -> dict:
    source = resource_path(entry["source"])
    if not source.is_file():
        raise FileNotFoundError(source)
    with Image.open(source) as opened:
        if "A" not in opened.getbands():
            raise ValueError("ImageGen output has no alpha: " + source.name)
        image = opened.convert("RGBA")
    alpha = image.getchannel("A")
    low, high = alpha.getextrema()
    transparent = sum(alpha.histogram()[:8]) / (image.width * image.height)
    if low != 0 or high < 200 or transparent < 0.05:
        raise ValueError("Portrait must have usable native transparency: " + source.name)
    # Preserve generated alpha. Only fit and resample to a common UI canvas.
    fitted = ImageOps.contain(image, CANVAS, Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    offset = ((CANVAS[0] - fitted.width) // 2, CANVAS[1] - fitted.height)
    canvas.paste(fitted, offset)
    output = resource_path(entry["texture"])
    output.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(output, optimize=True)
    solid = canvas.getchannel("A").point(lambda value: 255 if value >= 128 else 0)
    bounds = solid.getbbox()
    if bounds is None:
        raise ValueError("Portrait contains no readable opaque subject: " + source.name)
    return {
        "status": "generated",
        "provenance": {
            "tool": "OpenAI built-in image_gen",
            "source_sha256": sha256(source),
            "runtime_sha256": sha256(output),
            "source_size": list(image.size),
            "runtime_size": list(CANVAS),
            "alpha_range": list(canvas.getchannel("A").getextrema()),
            "transparent_fraction": round(transparent, 5),
            "subject_bbox_alpha_128": list(bounds),
            "processing": "native RGBA retained; proportional Lanczos fit; bottom-center anchor",
        },
    }


def contact_sheet(characters: dict, output: Path) -> None:
    selected = [(key, entry) for key, entry in characters.items()
                if resource_path(entry["texture"]).is_file()]
    columns = 6
    cell_w, cell_h = 220, 350
    rows = (len(selected) + columns - 1) // columns
    sheet = Image.new("RGB", (columns * cell_w, rows * cell_h), "#26363b")
    draw = ImageDraw.Draw(sheet)
    font_path = Path("C:/Windows/Fonts/msyh.ttc")
    font = ImageFont.truetype(str(font_path), 18) if font_path.is_file() else ImageFont.load_default()
    for index, (key, entry) in enumerate(selected):
        x, y = (index % columns) * cell_w, (index // columns) * cell_h
        for xx in range(0, cell_w, 16):
            for yy in range(0, cell_h - 34, 16):
                color = "#314247" if (xx // 16 + yy // 16) % 2 else "#27373c"
                draw.rectangle((x + xx, y + yy, x + xx + 15, y + yy + 15), fill=color)
        with Image.open(resource_path(entry["texture"])) as opened:
            thumb = ImageOps.contain(opened.convert("RGBA"), (cell_w - 12, cell_h - 40),
                                    Image.Resampling.LANCZOS)
        sheet.paste(thumb, (x + (cell_w - thumb.width) // 2, y + cell_h - 38 - thumb.height), thumb)
        draw.text((x + 12, y + cell_h - 30), entry["name"], font=font, fill="#ece4cc")
    output.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ids", nargs="*", help="Only normalize these ready character IDs")
    parser.add_argument("--preview", action="store_true")
    args = parser.parse_args()
    catalog = json.loads(CATALOG.read_text(encoding="utf-8-sig"))
    characters = catalog["characters"]
    selected = args.ids if args.ids else list(characters)
    for key in selected:
        entry = characters[key]
        entry.update(normalize(entry))
        print(key + " -> " + entry["texture"], flush=True)
    CATALOG.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    if args.preview:
        contact_sheet(characters, GAME / "docs/previews/portraits-2026-10-18/portrait-contact-sheet.png")
    print(json.dumps({"normalized": len(selected), "total": len(characters)}, ensure_ascii=False))


if __name__ == "__main__":
    main()
