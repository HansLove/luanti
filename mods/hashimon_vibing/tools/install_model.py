#!/usr/bin/env python3
"""Install a glTF/GLB tower model into the hashimon_vibing mod as node media.

This is the deploy step for the Vibing tower's 3D asset. Luanti ships a mod's
`models/` and `textures/` to every client automatically when the mod loads, so
once this has run and the files are committed, deploying the mod is all it takes
for the spire to reach Luanti — there is no separate runtime upload.

What it does, and why:
  * Copies the mesh to `models/hashimon_vibing_spire.glb` (Luanti reads glTF
    geometry directly; embedded images are ignored by the engine).
  * Extracts the material's BASE COLOR image to
    `textures/hashimon_vibing_spire.jpg` — Luanti cannot read glTF embedded
    images, so the tile must be a separate file. Metallic/roughness and normal
    maps are dropped by the engine, so only the albedo is pulled out.
  * If `sips` (macOS) is present it downscales that texture to <=1024px in place;
    otherwise it is left full-size (still valid, just heavier).

Stdlib only (plus optional `sips`), so it runs anywhere Python 3 does. The node
registration in init.lua references the fixed filenames above, so re-running this
with a new export updates the model in place without any Lua change.

Usage:
    tools/install_model.py <source.glb>
"""

import json
import shutil
import struct
import subprocess
import sys
from pathlib import Path

MOD_DIR = Path(__file__).resolve().parent.parent
MESH_OUT = MOD_DIR / "models" / "hashimon_vibing_spire.glb"
TEX_OUT = MOD_DIR / "textures" / "hashimon_vibing_spire.jpg"
MAX_TEX_PX = 1024


def read_glb(path: Path):
    """Return (gltf_json, binary_chunk) for a .glb (or .gltf with no binary)."""
    raw = path.read_bytes()
    if raw[:4] != b"glTF":
        return json.loads(raw.decode("utf-8")), b""
    _, _, total = struct.unpack("<III", raw[:12])
    gltf, binary, off = None, b"", 12
    while off < min(total, len(raw)):
        length, ctype = struct.unpack("<II", raw[off:off + 8])
        payload = raw[off + 8:off + 8 + length]
        if ctype == 0x4E4F534A:      # 'JSON'
            gltf = json.loads(payload.decode("utf-8"))
        elif ctype == 0x004E4942:    # 'BIN'
            binary = payload
        off += 8 + length
    if gltf is None:
        raise ValueError(f"{path.name}: no JSON chunk (corrupt glb?)")
    return gltf, binary


def base_color_image_index(gltf) -> int:
    """The image index the first material paints its base color from (default 0)."""
    for material in gltf.get("materials", []):
        tex = material.get("pbrMetallicRoughness", {}).get("baseColorTexture")
        if tex is not None:
            return gltf["textures"][tex["index"]]["source"]
    return 0


def extract_image(gltf, binary, index: int, out: Path) -> str:
    """Write image `index` (a bufferView-backed embedded image) to `out`."""
    image = gltf["images"][index]
    if "bufferView" not in image:
        raise ValueError(f"image {index} is not embedded (uri={image.get('uri')!r}); "
                         "copy it into textures/ by hand")
    view = gltf["bufferViews"][image["bufferView"]]
    start = view.get("byteOffset", 0)
    data = binary[start:start + view["byteLength"]]
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_bytes(data)
    return image.get("mimeType", "image/jpeg")


def downscale(path: Path) -> None:
    """Best-effort resize to <=MAX_TEX_PX with macOS `sips`; a no-op elsewhere."""
    if not shutil.which("sips"):
        print(f"  (sips not found — {path.name} left at full size)")
        return
    subprocess.run(
        ["sips", "-Z", str(MAX_TEX_PX), str(path)],
        check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )
    print(f"  resized {path.name} to <= {MAX_TEX_PX}px")


def main() -> None:
    if len(sys.argv) != 2:
        sys.exit("usage: install_model.py <source.glb>")
    src = Path(sys.argv[1]).expanduser()
    if not src.is_file():
        sys.exit(f"no such file: {src}")

    gltf, binary = read_glb(src)

    MESH_OUT.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, MESH_OUT)
    size_mb = MESH_OUT.stat().st_size / 1_048_576
    print(f"  + models/{MESH_OUT.name}  ({size_mb:.1f} MB)")
    if size_mb > 16:
        print("  ! over Luanti's ~16MB media limit — Luanti will refuse to load it")

    idx = base_color_image_index(gltf)
    mime = extract_image(gltf, binary, idx, TEX_OUT)
    print(f"  + textures/{TEX_OUT.name}  (base color, image {idx}, {mime})")
    downscale(TEX_OUT)

    print("\nDone. Commit models/ and textures/ and deploy the mod — Luanti ships "
          "mod media to clients on load. init.lua already references these names.")


if __name__ == "__main__":
    main()
