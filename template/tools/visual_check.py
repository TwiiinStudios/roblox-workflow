"""
Look for what goes wrong in a model's looks before it goes to Roblox, the way Roblox will draw it.

    python tools/visual_check.py <file.glb> [more...]        exits 1 on a problem

Run it on the file that is uploaded or imported (after tools/prepare_import.py and tools/merge_model.py), and on
the prepared, unmerged file for flicker (merging joins the pieces, so their overlaps can't be told apart after).
It checks, for every textured triangle, what Roblox will actually show:

  - stretched textures: how many texture pixels land on a stud along each of the triangle's two directions. Pixels
    drawn more than STRETCH times longer one way than the other look smeared (a hatch's collar side and its
    turned hazard stripes did, 2026-10-20). Plain-colour textures can't look stretched and are skipped.
  - settings Roblox ignores: KHR_texture_transform (a per-face repeat or turn; tools/merge_model.py bakes it in),
    and UVs outside 0..1 on a texture that doesn't repeat.
  - flicker: two surfaces of different pieces facing the same way at the same depth and overlapping. The graphics
    card can't tell which is in front and they flicker (a door wheel's hub and spokes did). Nudge one out.
  - textures that are missing or can't be read.

Needs Python with Pillow (pip install pillow).
"""
import io
import json
import math
import os
import struct
import sys

from PIL import Image

STRETCH = 2.5  # pixels this much longer one way than the other look smeared
FLICKER_GAP = 0.002  # studs: surfaces closer than this (facing the same way) fight
FLICKER_AREA = 0.0004  # square studs of overlap that count (smaller can't be seen)
MIN_AREA = 1e-6  # triangles smaller than this are ignored
SHOWN = 8  # problems listed per kind

FLOAT, UBYTE, USHORT, UINT = 5126, 5121, 5123, 5125


def load(path):
    data = open(path, "rb").read()
    magic, _, _ = struct.unpack("<III", data[:12])
    if magic != 0x46546C67:
        sys.exit(f"{path}: not a .glb")
    length, _ = struct.unpack("<II", data[12:20])
    gltf = json.loads(data[20 : 20 + length])
    binary = data[20 + length + 8 :]
    return gltf, binary


def read_accessor(gltf, binary, index):
    acc = gltf["accessors"][index]
    view = gltf["bufferViews"][acc["bufferView"]]
    width = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[acc["type"]]
    fmt = {FLOAT: "f", UBYTE: "B", USHORT: "H", UINT: "I"}[acc["componentType"]]
    size = struct.calcsize(fmt)
    stride = view.get("byteStride") or size * width
    start = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    out = []
    for i in range(acc["count"]):
        vals = struct.unpack_from("<" + fmt * width, binary, start + i * stride)
        out.append(vals if width > 1 else vals[0])
    return out


def node_matrix(node):
    if "matrix" in node:
        m = node["matrix"]
        return [[m[c * 4 + r] for c in range(4)] for r in range(4)]
    tx, ty, tz = node.get("translation", [0, 0, 0])
    x, y, z, w = node.get("rotation", [0, 0, 0, 1])
    sx, sy, sz = node.get("scale", [1, 1, 1])
    r = [
        [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
        [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
        [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
    ]
    return [[r[i][0] * sx, r[i][1] * sy, r[i][2] * sz, (tx, ty, tz)[i]] for i in range(3)] + [[0, 0, 0, 1]]


def mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(4)) for j in range(4)] for i in range(4)]


def point(m, p):
    return tuple(m[i][0] * p[0] + m[i][1] * p[1] + m[i][2] * p[2] + m[i][3] for i in range(3))


def sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def length(a):
    return math.sqrt(dot(a, a))


def images_of(gltf, binary):
    """Per image: (width, height, plain) - plain = one colour (can't look stretched) - or None if unreadable."""
    out = []
    for image in gltf.get("images", []):
        try:
            view = gltf["bufferViews"][image["bufferView"]]
            start = view.get("byteOffset", 0)
            img = Image.open(io.BytesIO(binary[start : start + view["byteLength"]])).convert("RGBA")
            colours = img.getcolors(maxcolors=2)
            out.append((img.width, img.height, colours is not None and len(colours) == 1))
        except Exception:  # (a broken or external image)
            out.append(None)
    return out


def check(path):
    gltf, binary = load(path)
    materials = gltf.get("materials", [])
    textures = gltf.get("textures", [])
    samplers = gltf.get("samplers", [])
    images = images_of(gltf, binary)
    problems = {"stretched": [], "ignored": [], "flicker": [], "missing": []}

    def texture_of(material):
        """(image size and plainness, repeats?, transform) of a material's colour texture, or None."""
        if not 0 <= material < len(materials):
            return None
        tex = materials[material].get("pbrMetallicRoughness", {}).get("baseColorTexture")
        if not tex:
            return None
        t = textures[tex["index"]] if tex["index"] < len(textures) else {}
        source = t.get("source")
        info = images[source] if source is not None and source < len(images) else None
        sampler = samplers[t["sampler"]] if "sampler" in t and t["sampler"] < len(samplers) else {}
        repeats = sampler.get("wrapS", 10497) == 10497 and sampler.get("wrapT", 10497) == 10497
        return info, repeats, tex.get("extensions", {}).get("KHR_texture_transform")

    triangles = []  # (node name, material, points, normal, area) for the flicker check
    stretched = {}  # (node, material) -> [worst ratio, area stretched, area in all]
    scene = gltf["scenes"][gltf.get("scene", 0)]

    def walk(index, parent):
        node = gltf["nodes"][index]
        world = mul(parent, node_matrix(node))
        name = node.get("name", f"node {index}")
        if "mesh" in node:
            for prim in gltf["meshes"][node["mesh"]]["primitives"]:
                if prim.get("mode", 4) != 4:
                    continue
                material = prim.get("material", -1)
                attrs = prim["attributes"]
                pos = [point(world, p) for p in read_accessor(gltf, binary, attrs["POSITION"])]
                idx = read_accessor(gltf, binary, prim["indices"]) if "indices" in prim else list(range(len(pos)))
                tex = texture_of(material)
                uv = read_accessor(gltf, binary, attrs["TEXCOORD_0"]) if "TEXCOORD_0" in attrs else None
                label = f"{name} / {materials[material].get('name', material) if 0 <= material < len(materials) else 'no material'}"
                if tex:
                    info, repeats, transform = tex
                    if info is None:
                        problems["missing"].append(f"{label}: its texture can't be read")
                    if transform:
                        problems["ignored"].append(f"{label}: a texture repeat/turn (KHR_texture_transform) Roblox ignores - run tools/merge_model.py")
                    if uv and not repeats and any(not (-0.01 <= c <= 1.01) for p in uv for c in p):
                        problems["ignored"].append(f"{label}: UVs outside 0..1 on a texture that doesn't repeat")
                for t in range(0, len(idx) - 2, 3):
                    a, b, c = idx[t], idx[t + 1], idx[t + 2]
                    pa, pb, pc = pos[a], pos[b], pos[c]
                    n = cross(sub(pb, pa), sub(pc, pa))
                    area = length(n) / 2
                    if area < MIN_AREA:
                        continue
                    normal = tuple(x / (2 * area) for x in n)
                    triangles.append((name, material, (pa, pb, pc), normal, area))
                    if not (tex and uv and tex[0] and not tex[0][2]):
                        continue
                    (w, h, _plain) = tex[0]
                    # texels per stud along the triangle's two directions: the map from its surface to the
                    # picture, whose two "stretch" factors are the singular values of this 2x2 matrix
                    e1, e2 = sub(pb, pa), sub(pc, pa)
                    x_axis = tuple(x / length(e1) for x in e1) if length(e1) > 0 else None
                    if not x_axis:
                        continue
                    y_axis = cross(normal, x_axis)
                    p1 = (dot(e1, x_axis), dot(e1, y_axis))
                    p2 = (dot(e2, x_axis), dot(e2, y_axis))
                    d1 = ((uv[b][0] - uv[a][0]) * w, (uv[b][1] - uv[a][1]) * h)
                    d2 = ((uv[c][0] - uv[a][0]) * w, (uv[c][1] - uv[a][1]) * h)
                    det = p1[0] * p2[1] - p2[0] * p1[1]
                    if abs(det) < 1e-12:
                        continue
                    # J = [d1 d2] * inverse([p1 p2])
                    inv = ((p2[1] / det, -p2[0] / det), (-p1[1] / det, p1[0] / det))
                    j = [
                        [d1[0] * inv[0][0] + d2[0] * inv[1][0], d1[0] * inv[0][1] + d2[0] * inv[1][1]],
                        [d1[1] * inv[0][0] + d2[1] * inv[1][0], d1[1] * inv[0][1] + d2[1] * inv[1][1]],
                    ]
                    aa, bb, cc, dd = j[0][0], j[0][1], j[1][0], j[1][1]
                    s = aa * aa + bb * bb + cc * cc + dd * dd
                    q = math.sqrt(max(0.0, (aa * aa + bb * bb - cc * cc - dd * dd) ** 2 + 4 * (aa * cc + bb * dd) ** 2))
                    big, small = math.sqrt((s + q) / 2), math.sqrt(max(0.0, (s - q) / 2))
                    if big < 1e-9:
                        problems["stretched"].append(f"{label}: a face shows a single pixel of its texture (no UVs spread)")
                        continue
                    ratio = big / small if small > 1e-9 else math.inf
                    entry = stretched.setdefault(label, [0.0, 0.0, 0.0])
                    entry[2] += area
                    if ratio > STRETCH:
                        entry[0] = max(entry[0], ratio)
                        entry[1] += area
        for child in node.get("children", []):
            walk(child, world)

    for root in scene["nodes"]:
        walk(root, [[1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]])

    for label, (worst, bad, total) in sorted(stretched.items(), key=lambda kv: -kv[1][1]):
        if bad > 0:
            ratio = "endless" if worst == math.inf else f"{worst:.1f}:1"
            problems["stretched"].append(f"{label}: {bad:.2f} of {total:.2f} sq studs stretched (worst {ratio})")

    # Flicker: same-facing surfaces of different pieces on the same plane, overlapping.
    planes = {}
    for tri in triangles:
        name, _material, pts, normal, _area = tri
        key = (round(normal[0], 2), round(normal[1], 2), round(normal[2], 2), round(dot(normal, pts[0]) / FLICKER_GAP))
        planes.setdefault(key, []).append(tri)
    seen = set()
    for key, tris in planes.items():
        # (a plane right at a rounding edge: look at its neighbour too)
        near = tris + planes.get(key[:3] + (key[3] + 1,), [])
        owners = {t[0] for t in near}
        if len(owners) < 2:
            continue
        for i, a in enumerate(near):
            for bt in near[i + 1 :]:
                if a[0] == bt[0] or (a[0], bt[0]) in seen or (bt[0], a[0]) in seen:
                    continue
                overlap = overlap_area(a, bt)
                if overlap > FLICKER_AREA:
                    seen.add((a[0], bt[0]))
                    at = tuple(round(sum(p[k] for p in a[2]) / 3, 2) for k in range(3))
                    problems["flicker"].append(f"{a[0]} and {bt[0]}: {overlap:.4f} sq studs at the same depth, facing the same way, near {at}")

    return problems


def overlap_area(a, b):
    """Area two triangles on (nearly) one plane share, in square studs (clipping one by the other)."""
    normal = a[3]
    x_axis = sub(a[2][1], a[2][0])
    x_axis = tuple(v / length(x_axis) for v in x_axis)
    y_axis = cross(normal, x_axis)
    origin = a[2][0]

    def flat(p):
        d = sub(p, origin)
        return (dot(d, x_axis), dot(d, y_axis))

    subject = [flat(p) for p in a[2]]
    clip = [flat(p) for p in b[2]]
    if area2(clip) < 0:
        clip.reverse()
    if area2(subject) < 0:
        subject.reverse()
    out = subject
    for i in range(len(clip)):
        c1, c2 = clip[i], clip[(i + 1) % len(clip)]
        inside = lambda p: (c2[0] - c1[0]) * (p[1] - c1[1]) - (c2[1] - c1[1]) * (p[0] - c1[0]) >= 0
        src, out = out, []
        for j in range(len(src)):
            p, q = src[j], src[(j + 1) % len(src)]
            if inside(q):
                if not inside(p):
                    out.append(cross_point(p, q, c1, c2))
                out.append(q)
            elif inside(p):
                out.append(cross_point(p, q, c1, c2))
        if not out:
            return 0.0
    return abs(area2(out)) / 2


def area2(poly):
    return sum(poly[i][0] * poly[(i + 1) % len(poly)][1] - poly[(i + 1) % len(poly)][0] * poly[i][1] for i in range(len(poly)))


def cross_point(p, q, a, b):
    x1, y1, x2, y2 = p[0], p[1], q[0], q[1]
    x3, y3, x4, y4 = a[0], a[1], b[0], b[1]
    den = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4)
    if abs(den) < 1e-12:
        return q
    t = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / den
    return (x1 + t * (x2 - x1), y1 + t * (y2 - y1))


WORDS = {
    "stretched": "Stretched textures (pixels smeared one way)",
    "ignored": "Settings Roblox ignores",
    "flicker": "Flicker (two surfaces at the same depth)",
    "missing": "Missing textures",
}

if __name__ == "__main__":
    paths = sys.argv[1:]
    if not paths:
        sys.exit(__doc__)
    bad = 0
    for path in paths:
        problems = check(path)
        count = sum(len(v) for v in problems.values())
        bad += count
        print(f"{os.path.basename(path)}: {'looks right' if not count else f'{count} problem(s)'}")
        for kind, items in problems.items():
            if items:
                print(f"  {WORDS[kind]}:")
                for item in items[:SHOWN]:
                    print(f"    - {item}")
                if len(items) > SHOWN:
                    print(f"    ... and {len(items) - SHOWN} more")
    sys.exit(1 if bad else 0)
