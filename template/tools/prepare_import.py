"""
Get a .glb ready for Studio's File > Import 3D. Run every model through this before importing it.

    python tools/prepare_import.py <file.glb | folder> [more...]      -> Downloads/ready/<safe name>.glb

It does two things, so imports are both crisp and safe:

1. Family-friendly names. Roblox's moderation reads the name of every mesh, image and part an
   import uploads, and banned the owner's account once for names that were fine in context but
   read badly out of it. Every name inside the file (nodes, meshes, materials, images, textures)
   and the file name itself are rewritten with tools/names/renames.json (risky word -> safe word;
   no shade word next to a person/body word). Words not on tools/names/allowed.txt are listed at
   the end: review them, and add them to allowed.txt or to the rename table, before importing.
2. Crisp pixel art. The textures are 4-16 px pixel art; a file whose samplers smooth them imports
   blurry. Samplers are set to nearest-neighbour and every texture is enlarged nearest-neighbour to
   at least 512 px, so the hard pixel edges survive whatever Roblox does to it.

Needs Pillow (pip install pillow).
"""
import io
import json
import os
import re
import struct
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
CONFIG = json.load(open(os.path.join(HERE, "names", "renames.json"), encoding="utf-8"))
RENAME = CONFIG["rename"]
BODY = set(CONFIG["bodyWords"])
SHADE = set(CONFIG["shadeWords"])
ALLOWED = set()
for line in open(os.path.join(HERE, "names", "allowed.txt"), encoding="utf-8"):
    if not line.startswith("#"):
        ALLOWED.update(w.lower() for w in re.findall(r"[A-Za-z]+", line))

# Where prepared files go: Downloads/ready on a PC; an agent on the server sets READY_DIR to its own build/ready
# (a folder of its worktree, not shared with other agents).
READY = os.environ.get("READY_DIR") or os.path.join(os.path.expanduser("~"), "Downloads", "ready")
OUT_DIR = READY
MIN_SIZE, MAX_SIZE = 512, 1024
NEAREST = 9728
JSON_CHUNK, BIN_CHUNK = 0x4E4F534A, 0x004E4942


def words(name):
    out = []
    for run in re.findall(r"[A-Za-z]+", name):
        out += [p.lower() for p in re.sub(r"([a-z])([A-Z])", r"\1 \2", run).split()]
    return out


def clean(name):
    def swap(match):
        part = match.group(0)
        new = RENAME.get(part.lower())
        if not new:
            return part
        return new[0].upper() + new[1:] if part[0].isupper() else new

    out = re.sub(r"[A-Z]?[a-z]+|[A-Z]+(?![a-z])", swap, name)
    if any(w in BODY for w in words(out)):
        out = re.sub(r"[A-Za-z]+", lambda m: "" if m.group(0).lower() in SHADE else m.group(0), out)
        out = re.sub(r"__+", "_", out).strip("_")
    return out


def pad4(b, fill):
    return b + fill * ((4 - len(b) % 4) % 4)


def prepare(src, unknown):
    data = open(src, "rb").read()
    magic, version, length = struct.unpack("<III", data[:12])
    if magic != 0x46546C67:
        print(f"skipped (not a .glb): {src}")
        return
    off, chunks = 12, {}
    while off < length:
        clen, ctype = struct.unpack("<II", data[off:off + 8])
        chunks[ctype] = data[off + 8:off + 8 + clen]
        off += 8 + clen
    gltf = json.loads(chunks[JSON_CHUNK].decode("utf-8"))
    binary = chunks.get(BIN_CHUNK, b"")

    renamed = 0
    for key in ("nodes", "meshes", "materials", "images", "textures", "scenes", "animations", "skins"):
        for item in gltf.get(key, []):
            if isinstance(item, dict) and item.get("name"):
                safe = clean(item["name"])
                if safe != item["name"]:
                    item["name"] = safe or key[:-1]
                    renamed += 1
                for w in words(item["name"]):
                    if len(w) > 1 and w not in ALLOWED:
                        unknown.setdefault(w, set()).add(os.path.basename(src))

    views = gltf.get("bufferViews", [])
    image_views = {im["bufferView"] for im in gltf.get("images", []) if "bufferView" in im}
    new_bin = bytearray()
    for index, view in enumerate(views):
        start = view.get("byteOffset", 0)
        blob = binary[start:start + view["byteLength"]]
        if index in image_views:
            image = Image.open(io.BytesIO(blob)).convert("RGBA")
            w, h = image.size
            factor = max(1, min(MAX_SIZE // max(w, h), -(-MIN_SIZE // max(w, h))))
            out = io.BytesIO()
            image.resize((w * factor, h * factor), Image.NEAREST).save(out, format="PNG", optimize=True)
            blob = out.getvalue()
        while len(new_bin) % 4:
            new_bin += b"\x00"
        view["byteOffset"] = len(new_bin)
        view["byteLength"] = len(blob)
        new_bin += blob
    # A material that's only a colour (no texture: eyes, teeth, a belt) loses that colour on the way into
    # the game (only a texture survives), so each becomes a small texture of its own colour - with
    # texture coordinates added to any piece that has none (it's one colour, so all zeros will do).
    def append(blob):
        nonlocal new_bin
        while len(new_bin) % 4:
            new_bin += b"\x00"
        views.append({"buffer": 0, "byteOffset": len(new_bin), "byteLength": len(blob)})
        new_bin += blob
        return len(views) - 1

    def srgb(c):
        return round(255 * (12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055))

    plain = {}
    for index, material in enumerate(gltf.get("materials", [])):
        pbr = material.setdefault("pbrMetallicRoughness", {})
        if "baseColorTexture" in pbr:
            continue
        factor = pbr.get("baseColorFactor", [1, 1, 1, 1])
        colour = tuple(max(0, min(255, srgb(c))) for c in factor[:3])
        out = io.BytesIO()
        Image.new("RGBA", (32, 32), colour + (255,)).save(out, format="PNG")
        gltf.setdefault("images", []).append({
            "bufferView": append(out.getvalue()),
            "mimeType": "image/png",
            "name": "solid_" + (material.get("name") or "colour"),
        })
        gltf.setdefault("samplers", []).append({"magFilter": NEAREST, "minFilter": NEAREST})
        gltf.setdefault("textures", []).append({
            "source": len(gltf["images"]) - 1,
            "sampler": len(gltf["samplers"]) - 1,
        })
        pbr["baseColorTexture"] = {"index": len(gltf["textures"]) - 1}
        pbr["baseColorFactor"] = [1, 1, 1, factor[3] if len(factor) > 3 else 1]
        plain[index] = True
    for mesh in gltf.get("meshes", []):
        for prim in mesh.get("primitives", []):
            attrs = prim.get("attributes", {})
            if prim.get("material") in plain and "TEXCOORD_0" not in attrs and "POSITION" in attrs:
                count = gltf["accessors"][attrs["POSITION"]]["count"]
                gltf["accessors"].append({
                    "bufferView": append(b"\x00" * (8 * count)),
                    "componentType": 5126,
                    "count": count,
                    "type": "VEC2",
                })
                attrs["TEXCOORD_0"] = len(gltf["accessors"]) - 1
    if plain:
        print(f"  {len(plain)} plain colours made into textures")

    if gltf.get("buffers"):
        gltf["buffers"][0]["byteLength"] = len(new_bin)
    for sampler in gltf.get("samplers", []):
        sampler["magFilter"] = NEAREST
        sampler["minFilter"] = NEAREST

    base = clean(os.path.splitext(os.path.basename(src))[0])
    for w in words(base):
        if len(w) > 1 and w not in ALLOWED:
            unknown.setdefault(w, set()).add(os.path.basename(src))
    os.makedirs(OUT_DIR, exist_ok=True)
    dst = os.path.join(OUT_DIR, base + ".glb")
    json_bytes = pad4(json.dumps(gltf, separators=(",", ":")).encode("utf-8"), b" ")
    bin_bytes = pad4(bytes(new_bin), b"\x00")
    with open(dst, "wb") as f:
        f.write(struct.pack("<III", magic, version, 12 + 8 + len(json_bytes) + 8 + len(bin_bytes)))
        f.write(struct.pack("<II", len(json_bytes), JSON_CHUNK))
        f.write(json_bytes)
        f.write(struct.pack("<II", len(bin_bytes), BIN_CHUNK))
        f.write(bin_bytes)
    print(f"ready: {dst}  ({renamed} names made safe)")


def main(paths):
    if not paths:
        print(__doc__)
        sys.exit(1)
    files = []
    for p in paths:
        if os.path.isdir(p):
            files += [os.path.join(p, f) for f in sorted(os.listdir(p)) if f.lower().endswith(".glb")]
        else:
            files.append(p)
    unknown = {}
    for f in files:
        prepare(f, unknown)
    if unknown:
        print("\nNOT YET REVIEWED - check each word, then add it to tools/names/allowed.txt (or give it a")
        print("safe replacement in tools/names/renames.json) and run this again before importing:")
        for w in sorted(unknown):
            print(f"  {w}  ({', '.join(sorted(unknown[w]))})")
        sys.exit(2)
    print(f"\nAll {len(files)} files ready in {OUT_DIR}. Import them from there.")


if __name__ == "__main__":
    main(sys.argv[1:])
