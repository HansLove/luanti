#!/usr/bin/env python3
"""Prepare a glTF/GLB asset for Luanti's dynamic media directory.

Luanti cannot read glTF embedded images, so the texture has to be split out into
its own file. It also renders glTF at a fixed 10 mesh units = 1 node, so the
model's bounding box decides the visual_size it needs. Both facts are easy to
forget and fail quietly, which is why this script handles them together.

Standard library only, on purpose: no pip, no npm, no gltf-transform.

Usage:
    prepare_asset.py <model.glb> <world_media_dir> [--slug NAME] [--height 1.2]
"""

import argparse
import hashlib
import json
import shutil
import struct
import sys
from pathlib import Path

MIME_EXTENSIONS = {"image/jpeg": ".jpg", "image/png": ".png"}


def read_glb(path):
    """Return (gltf_json, binary_chunk). Also accepts plain .gltf (no binary)."""
    raw = path.read_bytes()
    if raw[:4] != b"glTF":
        return json.loads(raw.decode("utf-8")), b""

    _, _, total = struct.unpack("<III", raw[:12])
    gltf, binary = None, b""
    offset = 12
    while offset < min(total, len(raw)):
        length, chunk_type = struct.unpack("<II", raw[offset:offset + 8])
        payload = raw[offset + 8:offset + 8 + length]
        if chunk_type == 0x4E4F534A:      # 'JSON'
            gltf = json.loads(payload.decode("utf-8"))
        elif chunk_type == 0x004E4942:    # 'BIN'
            binary = payload
        offset += 8 + length

    if gltf is None:
        raise ValueError(f"{path.name}: no JSON chunk found; file may be corrupt")
    return gltf, binary


def bounding_box(gltf):
    """Min/max across every POSITION accessor, in mesh units."""
    lo = [float("inf")] * 3
    hi = [float("-inf")] * 3
    for mesh in gltf.get("meshes", []):
        for primitive in mesh.get("primitives", []):
            index = primitive.get("attributes", {}).get("POSITION")
            if index is None:
                continue
            accessor = gltf["accessors"][index]
            if "min" not in accessor or "max" not in accessor:
                continue
            for axis in range(3):
                lo[axis] = min(lo[axis], accessor["min"][axis])
                hi[axis] = max(hi[axis], accessor["max"][axis])
    if any(v == float("inf") for v in lo):
        return None
    return lo, hi


def extract_images(gltf, binary, destination, slug):
    """Write each embedded image to its own file. Returns the filenames."""
    written = []
    for position, image in enumerate(gltf.get("images", [])):
        mime = image.get("mimeType", "image/png")
        suffix = MIME_EXTENSIONS.get(mime)
        if suffix is None:
            print(f"  ! skipping image {position}: unsupported type {mime}")
            continue

        if "bufferView" in image:
            view = gltf["bufferViews"][image["bufferView"]]
            start = view.get("byteOffset", 0)
            data = binary[start:start + view["byteLength"]]
        elif "uri" in image and not image["uri"].startswith("data:"):
            print(f"  - image {position} is already external ({image['uri']}), copy it yourself")
            continue
        else:
            print(f"  ! skipping image {position}: no bufferView and no file URI")
            continue

        suffix_n = "" if len(gltf.get("images", [])) == 1 else f"_{position}"
        name = f"{slug}{suffix_n}{suffix}"
        (destination / name).write_bytes(data)
        written.append(name)
        print(f"  + {name}  ({len(data):,} bytes, {mime})")
    return written


def report_material_risks(gltf):
    """Warn about material features Luanti silently drops."""
    for material in gltf.get("materials", []):
        pbr = material.get("pbrMetallicRoughness", {})
        name = material.get("name", "unnamed")
        if pbr.get("metallicFactor", 1.0) > 0.0:
            print(f"  ! material '{name}': metallicFactor > 0 — Luanti keeps base color"
                  f" only, so the metallic look will be lost unless it is painted in")
        if "metallicRoughnessTexture" in pbr:
            print(f"  ! material '{name}': has a metallic/roughness map, which Luanti ignores")
        if material.get("doubleSided"):
            print(f"  ! material '{name}': doubleSided is not supported; watch for"
                  f" backface artifacts on thin geometry")


def report_animations(gltf):
    """Animation tracks and their real length.

    The number that matters is seconds, not Blender frames: glTF stores keyframe
    times in seconds and Luanti uses those seconds directly as frame numbers
    (doc/lua_api.md: "glTF files should use timestamps in seconds as animation
    frame numbers"). A Blender range of 1-15 at 24fps is 0.583s here, not 1..15.
    """
    animations = gltf.get("animations", [])
    skins = gltf.get("skins", [])

    if not animations:
        print("  ! no animation track — renders as a static pose")
        if skins:
            print("    it has an armature, so the action was probably not exported;")
            print("    in Blender check 'Animation' is enabled in the glTF exporter")
        return

    for i, anim in enumerate(animations):
        name = anim.get("name") or ""
        duration = 0.0
        for sampler in anim.get("samplers", []):
            accessor = gltf["accessors"][sampler["input"]]
            # glTF requires min/max on animation input accessors, so the length
            # is readable without decoding the binary chunk.
            if accessor.get("max"):
                duration = max(duration, float(accessor["max"][0]))
        label = f'"{name}"' if name else "(unnamed)"
        print(f"  track {i + 1} {label}: {duration:.3f}s")

        unsupported = {
            s.get("interpolation", "LINEAR") for s in anim.get("samplers", [])
        } - {"LINEAR", "STEP"}
        if unsupported:
            print(f"    ! {', '.join(sorted(unsupported))} interpolation — "
                  "Luanti loads LINEAR and STEP only")

        if any(c.get("target", {}).get("path") == "weights"
               for c in anim.get("channels", [])):
            print("    ! morph-target (shape key) animation — the glTF loader "
                  "raises on this and the WHOLE MESH fails to load")

    joints = sum(len(s.get("joints", [])) for s in skins)
    if skins:
        print(f"  {len(skins)} skin(s), {joints} joint(s) — skeletal deformation")
    else:
        print("  ! no skin — rigid node motion only, the mesh will not deform")


def next_version(destination, slug):
    """Pick a filename that has not been registered yet.

    dynamic_add_media refuses to register the same filename twice, so iterating
    on a model means a new name rather than an overwrite.
    """
    version = 1
    while (destination / f"{slug}_v{version}.glb").exists():
        version += 1
    return version


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("model", type=Path, help="source .glb or .gltf")
    parser.add_argument("media_dir", type=Path,
                        help="<worldpath>/hashimon_media")
    parser.add_argument("--slug", help="base filename (default: derived from the model)")
    parser.add_argument("--height", type=float, default=1.2,
                        help="target height in nodes (default: 1.2)")
    parser.add_argument("--dna", help="64-hex key (default: derived from the slug)")
    args = parser.parse_args()

    if not args.model.is_file():
        sys.exit(f"No such file: {args.model}")
    args.media_dir.mkdir(parents=True, exist_ok=True)

    slug = args.slug or args.model.stem.replace("-", "_").replace(" ", "_").lower()
    gltf, binary = read_glb(args.model)

    triangles = sum(
        gltf["accessors"][p["indices"]]["count"] // 3
        for mesh in gltf.get("meshes", [])
        for p in mesh.get("primitives", [])
        if "indices" in p
    )
    animations = len(gltf.get("animations", []))
    size_mb = args.model.stat().st_size / 1_048_576

    print(f"\n{args.model.name}")
    print(f"  {triangles:,} triangles, {animations} animation(s), {size_mb:.1f} MB")
    if size_mb > 16:
        print("  ! over Luanti's ~16MB media limit — this will not load")
    elif size_mb > 5:
        print("  ! large: every client downloads this in full on spawn")

    report_material_risks(gltf)
    report_animations(gltf)

    version = next_version(args.media_dir, slug)
    mesh_name = f"{slug}_v{version}.glb"
    print(f"\nWriting to {args.media_dir}/")
    shutil.copy2(args.model, args.media_dir / mesh_name)
    print(f"  + {mesh_name}")
    textures = extract_images(gltf, binary, args.media_dir, f"{slug}_v{version}")

    if not textures:
        print("  ! no texture written — the model will render untextured")

    visual_size = None
    box = bounding_box(gltf)
    if box:
        lo, hi = box
        extent = [hi[i] - lo[i] for i in range(3)]
        print(f"\nBounding box: {extent[0]:.2f} x {extent[1]:.2f} x {extent[2]:.2f} mesh units")
        if extent[1] > 0:
            # glTF in Luanti is fixed at 10 mesh units per node.
            visual_size = round(args.height * 10 / extent[1], 1)
            print(f"  visual_size {visual_size} puts it at ~{args.height} nodes tall")

    dna = args.dna or hashlib.sha256(slug.encode()).hexdigest()
    entry = {"mesh": mesh_name, "textures": textures}
    if visual_size:
        entry["visual_size"] = visual_size

    print("\nManifest entry for hashimons.json:")
    print(json.dumps({dna: entry}, indent=2))
    print(f"\nSpawn with:  /hashadd {slug}")


if __name__ == "__main__":
    main()
