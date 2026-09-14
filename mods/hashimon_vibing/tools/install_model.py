#!/usr/bin/env python3
"""Install a glTF/GLB tower model into the hashimon_vibing mod as node media.

Pipeline (matches Hashimon body assets — do NOT ship the fat Meshy export):
  1. Extract base-color image → textures/hashimon_vibing_spire.jpg (≤512px)
  2. Strip embedded images via scripts/glb_for_luanti.py → models/…glb (~85KB)
  3. Park the original source under tools/asset/ (Luanti does not ship that dir)

Usage:
    python3 tools/install_model.py /path/to/new_model.glb
"""

from __future__ import annotations

import json
import shutil
import struct
import subprocess
import sys
from pathlib import Path

MOD_DIR = Path(__file__).resolve().parent.parent
REPO_ROOT = MOD_DIR.parents[2]  # …/Hashimon (mods → 3d-world → Hashimon)
GLB_TOOL = REPO_ROOT / "scripts" / "glb_for_luanti.py"
MESH_OUT = MOD_DIR / "models" / "hashimon_vibing_spire.glb"
TEX_OUT = MOD_DIR / "textures" / "hashimon_vibing_spire.jpg"
ASSET_DIR = MOD_DIR / "tools" / "asset"
MAX_TEX_PX = 512


def read_glb(path: Path):
    raw = path.read_bytes()
    if raw[:4] != b"glTF":
        raise ValueError(f"{path.name}: not a GLB")
    _, _, total = struct.unpack("<III", raw[:12])
    gltf, binary, off = None, b"", 12
    while off < min(total, len(raw)):
        length, ctype = struct.unpack("<II", raw[off:off + 8])
        payload = raw[off + 8:off + 8 + length]
        if ctype == 0x4E4F534A:
            gltf = json.loads(payload.decode("utf-8"))
        elif ctype == 0x004E4942:
            binary = payload
        off += 8 + length
    if gltf is None:
        raise ValueError(f"{path.name}: no JSON chunk")
    return gltf, binary


def base_color_image_index(gltf) -> int:
    for material in gltf.get("materials", []):
        tex = material.get("pbrMetallicRoughness", {}).get("baseColorTexture")
        if tex is not None:
            return gltf["textures"][tex["index"]]["source"]
    return 0


def extract_albedo(gltf, binary, out: Path) -> None:
    idx = base_color_image_index(gltf)
    image = gltf["images"][idx]
    if "bufferView" not in image:
        raise ValueError(f"image {idx} is not embedded; copy albedo by hand")
    view = gltf["bufferViews"][image["bufferView"]]
    start = view.get("byteOffset", 0)
    data = binary[start:start + view["byteLength"]]
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_bytes(data)
    print(f"  + textures/{out.name}  ({len(data) / 1024:.0f} KB raw)")


def downscale(path: Path) -> None:
    if shutil.which("sips"):
        subprocess.run(
            ["sips", "-Z", str(MAX_TEX_PX), str(path)],
            check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
        print(f"  resized {path.name} to <= {MAX_TEX_PX}px")
        return
    try:
        from PIL import Image
        img = Image.open(path).convert("RGB")
        img.thumbnail((MAX_TEX_PX, MAX_TEX_PX))
        img.save(path, quality=88, optimize=True)
        print(f"  resized {path.name} with Pillow to <= {MAX_TEX_PX}px")
    except Exception as exc:
        print(f"  (no sips/Pillow — left full size: {exc})")


def boost_contrast(path: Path) -> None:
    try:
        from PIL import Image, ImageEnhance, ImageOps
        img = Image.open(path).convert("RGB")
        img = ImageOps.autocontrast(img, cutoff=2)
        img = ImageEnhance.Contrast(img).enhance(1.35)
        img = ImageEnhance.Color(img).enhance(1.55)
        img = ImageEnhance.Sharpness(img).enhance(1.2)
        img.save(path, quality=88, optimize=True)
        print(f"  boosted contrast on {path.name}")
    except Exception as exc:
        print(f"  (contrast boost skipped: {exc})")


def main() -> None:
    if len(sys.argv) != 2:
        sys.exit("usage: install_model.py <source.glb>")
    src = Path(sys.argv[1]).expanduser().resolve()
    if not src.is_file():
        sys.exit(f"no such file: {src}")
    if not GLB_TOOL.is_file():
        sys.exit(f"missing {GLB_TOOL} — run from the Hashimon repo tree")

    ASSET_DIR.mkdir(parents=True, exist_ok=True)
    parked = ASSET_DIR / "Meshy_AI_Arcane_Energy_Spire_source.glb"
    shutil.copy2(src, parked)
    print(f"  parked source → tools/asset/{parked.name}")

    gltf, binary = read_glb(src)
    extract_albedo(gltf, binary, TEX_OUT)
    downscale(TEX_OUT)
    boost_contrast(TEX_OUT)
    shutil.copy2(TEX_OUT, ASSET_DIR / TEX_OUT.name)

    MESH_OUT.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        [sys.executable, str(GLB_TOOL), str(src), str(MESH_OUT), "--keep-times"],
        check=True,
    )
    size_kb = MESH_OUT.stat().st_size / 1024
    print(f"  + models/{MESH_OUT.name}  ({size_kb:.0f} KB stripped)")
    shutil.copy2(MESH_OUT, ASSET_DIR / MESH_OUT.name)

    print("\nDone. Restart Luanti so the mesh node definition reloads.")


if __name__ == "__main__":
    main()
