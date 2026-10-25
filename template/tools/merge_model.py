"""
Merge a big imported model (a building, a camp) into a few large meshes before Import 3D.

    python tools/merge_model.py <prepared.glb> [more...]      -> Downloads/ready/merged/<name>.glb

Why: the buildings came as one mesh per wall, shelf, book and can (500-2,000 each). Roblox fetches every
distinct mesh separately the first time a player sees it, and a town of ~13 building types was ~10,000
fetches: Roblox's servers refused most of them and the loading screen stalled for minutes. Merged, a
building is one mesh per texture (~50), split where a mesh would pass MAX_TRIANGLES.

Every node's transform is baked into its vertices, so the merged model lines up exactly with the
original (same bounding box). Collision can't come from the merged meshes (one mesh per texture spans
the whole building, and its hull would wall up the doorways), so next to the .glb it writes
<name>.colliders.json: one box per solid piece of the original (walls, floors, furniture; not doors,
which all hang open, and not loose bits under CLUTTER_SIZE), in the model's own space with its
bounding-box centre at the origin. A piece that is itself a closed box gets an opaque box just inside
its faces ("solid": the camera stops at it as at a wall, and it can't be seen); any other shape gets
an invisible box. Studio turns these into Parts when the merged model is captured.

    python tools/merge_model.py <file.glb> --skip name1,name2   leaves those nodes (and their children) out
    python tools/merge_model.py <file.glb> --skip-in x0,y0,z0,x1,y1,z1
        also leaves out every piece whose centre is in that box (file coordinates, metres from the
        model's bounding-box centre; for pieces with no name of their own, like a rifle on a bench)
    python tools/merge_model.py <file.glb> --doors
        keeps every walk-in door (a group named like "front_door", "office_door_open"; not a fridge,
        cabinet, safe or garage door, nor one lying fallen) as a group of its own, merged per texture,
        so the game can swing it open and shut (World/Doors), and writes <name>.doors.json: per door,
        its hinge, its slab and the turns that shut and open it (worked out from where its handle is
        and from the walls round its doorway)
    python tools/merge_model.py <file.glb> --keep lid:hatch_lid,door:blast_door+door_wheel
        keeps those nodes (and their children) as groups of their own, named as given (each group
        merged per texture, no collider), for pieces the game moves itself, like a hatch's lid
    python tools/merge_model.py <file.glb> --clutter 0
        keeps a box for every piece, however small (for props modelled in metres and scaled up in
        the game: the capture step decides which are clutter at the size they're shown)

Run it on files already through tools/prepare_import.py (safe names, crisp textures). Needs nothing
but Python.
"""
import json
import math
import os
import re
import struct
import sys

OUT_DIR = os.path.join(os.path.expanduser("~"), "Downloads", "ready", "merged")
MAX_TRIANGLES = 9000
# Two pieces whose faces lie on the same plane, facing the same way, flicker where they overlap
# (z-fighting: a door frame flush with the wall around it). The smaller face is nudged this far out
# of the plane (file units), so it's drawn cleanly on top; far too little to see.
NUDGE = 0.02
# Images Roblox moderation blocked, drawn instead with another material's image (material -> material).
REPLACE_IMAGES = {}  # e.g. {"canvas_worn": "canvas"}
CLUTTER_SIZE = 1.5  # a piece no longer than this (studs) never collided in the game, so gets no box
# Doors hang open (the game places them open): no box for these.
# A group of these names is a door you walk through (unless it's one of NOT_A_DOOR); its handle pieces.
DOOR_GROUP = re.compile(r"door", re.I)
NOT_A_DOOR = re.compile(r"fridge|cabinet|safe|garage|locker|freezer|cold|oven|stall|wardrobe|fallen", re.I)
HANDLE = re.compile(r"handle|knob")  # (a push bar runs across the door: no clue to its hinge)
WALK_THROUGH = re.compile(r"^(door_glass|split_tape|door_leaf|door_panel|door_rail|door_stile|door_handle|door_knob|door\d*$)")
JSON_CHUNK, BIN_CHUNK = 0x4E4F534A, 0x004E4942
FLOAT, USHORT, UINT, UBYTE = 5126, 5123, 5125, 5121
COMPONENTS = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}
FORMATS = {FLOAT: "f", USHORT: "H", UINT: "I", UBYTE: "B"}


def load(path):
    data = open(path, "rb").read()
    offset, gltf, binary = 12, None, b""
    while offset < len(data):
        length, kind = struct.unpack_from("<II", data, offset)
        chunk = data[offset + 8 : offset + 8 + length]
        if kind == JSON_CHUNK:
            gltf = json.loads(chunk)
        elif kind == BIN_CHUNK:
            binary = chunk
        offset += 8 + length
    return gltf, binary


def read_accessor(gltf, binary, index):
    acc = gltf["accessors"][index]
    view = gltf["bufferViews"][acc["bufferView"]]
    n = COMPONENTS[acc["type"]]
    fmt = FORMATS[acc["componentType"]]
    size = struct.calcsize(fmt)
    stride = view.get("byteStride", size * n)
    start = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    out = []
    for i in range(acc["count"]):
        values = struct.unpack_from("<" + fmt * n, binary, start + i * stride)
        out.append(values if n > 1 else values[0])
    return out


def identity():
    return [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]


def node_matrix(node):
    """Column-major 4x4 of a glTF node."""
    if "matrix" in node:
        return list(node["matrix"])
    t = node.get("translation", [0, 0, 0])
    x, y, z, w = node.get("rotation", [0, 0, 0, 1])
    s = node.get("scale", [1, 1, 1])
    r = [
        1 - 2 * (y * y + z * z), 2 * (x * y + z * w), 2 * (x * z - y * w),
        2 * (x * y - z * w), 1 - 2 * (x * x + z * z), 2 * (y * z + x * w),
        2 * (x * z + y * w), 2 * (y * z - x * w), 1 - 2 * (x * x + y * y),
    ]
    return [
        r[0] * s[0], r[1] * s[0], r[2] * s[0], 0,
        r[3] * s[1], r[4] * s[1], r[5] * s[1], 0,
        r[6] * s[2], r[7] * s[2], r[8] * s[2], 0,
        t[0], t[1], t[2], 1,
    ]


def mul(a, b):
    """a * b, both column-major."""
    out = [0.0] * 16
    for col in range(4):
        for row in range(4):
            out[col * 4 + row] = sum(a[k * 4 + row] * b[col * 4 + k] for k in range(4))
    return out


def point(m, p):
    return tuple(m[row] * p[0] + m[4 + row] * p[1] + m[8 + row] * p[2] + m[12 + row] for row in range(3))


def direction(m, v):
    d = [m[row] * v[0] + m[4 + row] * v[1] + m[8 + row] * v[2] for row in range(3)]
    length = (d[0] ** 2 + d[1] ** 2 + d[2] ** 2) ** 0.5 or 1
    return tuple(c / length for c in d)


def mirrored(m):
    det = (
        m[0] * (m[5] * m[10] - m[9] * m[6])
        - m[4] * (m[1] * m[10] - m[9] * m[2])
        + m[8] * (m[1] * m[6] - m[5] * m[2])
    )
    return det < 0


def collider(name, world, local_pos, see_through, triangles):
    """A box around one piece: centre and axes in model space, size, and whether it's a closed box."""
    lo = [min(p[k] for p in local_pos) for k in range(3)]
    hi = [max(p[k] for p in local_pos) for k in range(3)]
    axes = [[world[c * 4 + r] for r in range(3)] for c in range(3)]
    scales = [sum(v * v for v in axis) ** 0.5 or 1 for axis in axes]
    size = [(hi[k] - lo[k]) * scales[k] for k in range(3)]
    corners = {tuple(round(c, 4) for c in p) for p in local_pos}
    closed = (
        len(corners) == 8
        and triangles >= 12  # all six faces (a box missing one would show its collider through the gap)
        and all(len({c[k] for c in corners}) == 2 for k in range(3))
    )
    return {
        "name": name,
        "centre": point(world, [(lo[k] + hi[k]) / 2 for k in range(3)]),
        "axes": [[v / scales[c] for v in axes[c]] for c in range(3)],
        "size": size,
        "solid": closed and not see_through,
    }


def bounds(gltf, binary):
    """The model's bounding box (all pieces, transforms applied)."""
    lo, hi = [1e9] * 3, [-1e9] * 3

    def walk(index, parent):
        node = gltf["nodes"][index]
        world = mul(parent, node_matrix(node))
        if "mesh" in node:
            for prim in gltf["meshes"][node["mesh"]]["primitives"]:
                for p in read_accessor(gltf, binary, prim["attributes"]["POSITION"]):
                    q = point(world, p)
                    for k in range(3):
                        lo[k], hi[k] = min(lo[k], q[k]), max(hi[k], q[k])
        for child in node.get("children", []):
            walk(child, world)

    for root in gltf["scenes"][gltf.get("scene", 0)]["nodes"]:
        walk(root, identity())
    return lo, hi


def unflicker(pieces):
    """Nudge the smaller of every two flush, same-facing, overlapping box faces out of the plane."""
    faces = {}
    for i, piece in enumerate(pieces):
        for axis in range(3):
            others = [k for k in range(3) if k != axis]
            rect = [(piece["lo"][k], piece["hi"][k]) for k in others]
            area = (rect[0][1] - rect[0][0]) * (rect[1][1] - rect[1][0])
            for sign, plane in ((-1, piece["lo"][axis]), (1, piece["hi"][axis])):
                faces.setdefault((axis, sign, round(plane, 3)), []).append((i, rect, area, plane))
    moved = set()
    for (axis, sign, _), group in faces.items():
        for a in range(len(group)):
            for b in range(a + 1, len(group)):
                (i, ra, aa, plane), (j, rb, ab, _) = group[a], group[b]
                if i == j:
                    continue
                if all(min(ra[k][1], rb[k][1]) - max(ra[k][0], rb[k][0]) > 0.001 for k in range(2)):
                    small, small_plane = (i, plane) if aa <= ab else (j, plane)
                    key = (small, axis, sign)
                    if key in moved:
                        continue
                    moved.add(key)
                    for pos in pieces[small]["lists"]:
                        for n, q in enumerate(pos):
                            if abs(q[axis] - small_plane) < 0.001:
                                q = list(q)
                                q[axis] += sign * NUDGE
                                pos[n] = tuple(q)
    return len(moved)


# ---------- Looks: square pixels, nothing at the same depth (tools/visual_check.py checks the result) ----------

STRETCH = 2.5  # a face whose texture pixels come out more than this much longer one way than the other is re-spread
FLICKER_GAP = 0.002  # faces of two pieces closer than this, facing the same way, fight (flicker)


def sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def length(a):
    return math.sqrt(dot(a, a))


def image_size(gltf, binary, material):
    """(width, height) of a material's colour texture when it's a PNG, else None."""
    mats = gltf.get("materials", [])
    if not 0 <= material < len(mats):
        return None
    tex = mats[material].get("pbrMetallicRoughness", {}).get("baseColorTexture")
    if not tex:
        return None
    t = gltf.get("textures", [])[tex["index"]]
    image = gltf.get("images", [])[t["source"]] if "source" in t else None
    if not image or "bufferView" not in image:
        return None
    view = gltf["bufferViews"][image["bufferView"]]
    data = binary[view.get("byteOffset", 0) : view.get("byteOffset", 0) + view["byteLength"]]
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        return None
    if plain_picture(data):
        return None  # (one colour: it can't look stretched, so its faces are left alone)
    return struct.unpack(">II", data[16:24])


def plain_picture(png):
    """Is a PNG one colour all over (prepare_import.py makes plain colours into small textures)? Needs Pillow; without
    it every picture counts as patterned."""
    try:
        import io
        from PIL import Image
    except ImportError:
        return False
    colours = Image.open(io.BytesIO(png)).convert("RGBA").getcolors(maxcolors=2)
    return colours is not None and len(colours) == 1


def texel_map(p, t, size):
    """For one triangle (3 points, 3 UVs) and its texture's size: the two densities (texture pixels per stud) along
    its surface's two principal directions, big first, with the texture-space direction of each; None if degenerate."""
    w, h = size
    e1, e2 = sub(p[1], p[0]), sub(p[2], p[0])
    n = cross(e1, e2)
    if length(n) < 1e-12 or length(e1) < 1e-12:
        return None
    x_axis = tuple(v / length(e1) for v in e1)
    y_axis = cross(tuple(v / length(n) for v in n), x_axis)
    p1, p2 = (dot(e1, x_axis), dot(e1, y_axis)), (dot(e2, x_axis), dot(e2, y_axis))
    d1 = ((t[1][0] - t[0][0]) * w, (t[1][1] - t[0][1]) * h)
    d2 = ((t[2][0] - t[0][0]) * w, (t[2][1] - t[0][1]) * h)
    det = p1[0] * p2[1] - p2[0] * p1[1]
    if abs(det) < 1e-12:
        return None
    # J (texels per stud) = [d1 d2] * inverse([p1 p2]); its singular values are the two densities
    a = (d1[0] * p2[1] - d2[0] * p1[1]) / det
    b = (-d1[0] * p2[0] + d2[0] * p1[0]) / det
    c = (d1[1] * p2[1] - d2[1] * p1[1]) / det
    d = (-d1[1] * p2[0] + d2[1] * p1[0]) / det
    # J J^T = [[pp, pq], [pq, qq]]: its eigenvalues are the densities squared, its eigenvectors their directions
    pp, pq, qq = a * a + b * b, a * c + b * d, c * c + d * d
    mid, gap = (pp + qq) / 2, math.sqrt(max(0.0, ((pp - qq) / 2) ** 2 + pq * pq))
    big, small = math.sqrt(max(0.0, mid + gap)), math.sqrt(max(0.0, mid - gap))
    if abs(pq) > 1e-12:
        u1 = (pq, big * big - pp)
    else:
        u1 = (1.0, 0.0) if pp >= qq else (0.0, 1.0)
    ln = math.hypot(*u1)
    u1 = (u1[0] / ln, u1[1] / ln)
    return big, small, u1, (-u1[1], u1[0])


def square_pixels(pos, nrm, uv, idx, size, usual):
    """Faces whose texture would be squashed or stretched more than STRETCH:1 (Roblox draws the UVs as they are) get
    it re-spread so its pixels are square, at whichever of the face's two densities is nearer the texture's `usual`
    one on the model's well-shaped faces. A changed face gets its own vertices. Returns the lists and how many faces."""
    if not size or not usual:
        return pos, nrm, uv, idx, 0
    w, h = size
    faces = {}
    for t in range(0, len(idx) - 2, 3):
        a, b, c = idx[t], idx[t + 1], idx[t + 2]
        n = cross(sub(pos[b], pos[a]), sub(pos[c], pos[a]))
        if length(n) < 1e-12:
            continue
        n = tuple(v / length(n) for v in n)
        faces.setdefault((round(n[0], 2), round(n[1], 2), round(n[2], 2), round(dot(n, pos[a]), 3)), []).append(t)
    out_pos, out_nrm, out_uv, out_idx = list(pos), list(nrm), list(uv), list(idx)
    fixed = 0
    for tris in faces.values():
        area = lambda t: length(cross(sub(pos[idx[t + 1]], pos[idx[t]]), sub(pos[idx[t + 2]], pos[idx[t]])))
        t = max(tris, key=area)
        found = texel_map([pos[idx[t + i]] for i in range(3)], [uv[idx[t + i]] for i in range(3)], size)
        if not found:
            continue
        big, small, u_big, u_small = found
        if small < 1e-9 or big / small <= STRETCH:
            continue
        # keep the density nearer the usual one; spread the other direction to match it
        if abs(math.log(big / usual)) <= abs(math.log(small / usual)):
            direction, factor = u_small, big / small
        else:
            direction, factor = u_big, small / big
        verts = sorted({idx[tt + i] for tt in tris for i in range(3)})
        ox, oy = uv[verts[0]][0] * w, uv[verts[0]][1] * h
        remap = {}
        for v in verts:
            tx, ty = uv[v][0] * w - ox, uv[v][1] * h - oy
            along = (factor - 1) * (tx * direction[0] + ty * direction[1])
            remap[v] = len(out_pos)
            out_pos.append(pos[v])
            out_nrm.append(nrm[v])
            out_uv.append(((ox + tx + along * direction[0]) / w, (oy + ty + along * direction[1]) / h))
        for tt in tris:
            for i in range(3):
                out_idx[tt + i] = remap[idx[tt + i]]
        fixed += 1
    return out_pos, out_nrm, out_uv, out_idx, fixed


def overlap_area(a, b):
    """Area two triangles (3 points each) on (nearly) one plane share, in square studs."""
    e = sub(a[1], a[0])
    x_axis = tuple(v / length(e) for v in e)
    n = cross(sub(a[1], a[0]), sub(a[2], a[0]))
    y_axis = cross(tuple(v / length(n) for v in n), x_axis)

    def flat(p):
        d = sub(p, a[0])
        return (dot(d, x_axis), dot(d, y_axis))

    def area2(poly):
        return sum(poly[i][0] * poly[(i + 1) % len(poly)][1] - poly[(i + 1) % len(poly)][0] * poly[i][1] for i in range(len(poly)))

    def meet(p, q, c1, c2):
        den = (p[0] - q[0]) * (c1[1] - c2[1]) - (p[1] - q[1]) * (c1[0] - c2[0])
        if abs(den) < 1e-12:
            return q
        s = ((p[0] - c1[0]) * (c1[1] - c2[1]) - (p[1] - c1[1]) * (c1[0] - c2[0])) / den
        return (p[0] + s * (q[0] - p[0]), p[1] + s * (q[1] - p[1]))

    out, clip = [flat(p) for p in a], [flat(p) for p in b]
    if area2(out) < 0:
        out.reverse()
    if area2(clip) < 0:
        clip.reverse()
    for i in range(len(clip)):
        c1, c2 = clip[i], clip[(i + 1) % len(clip)]
        inside = lambda p: (c2[0] - c1[0]) * (p[1] - c1[1]) - (c2[1] - c1[1]) * (p[0] - c1[0]) >= -1e-12
        src, out = out, []
        for j in range(len(src)):
            p, q = src[j], src[(j + 1) % len(src)]
            if inside(q):
                if not inside(p):
                    out.append(meet(p, q, c1, c2))
                out.append(q)
            elif inside(p):
                out.append(meet(p, q, c1, c2))
        if not out:
            return 0.0
    return abs(area2(out)) / 2


def flush_faces(owners):
    """Pairs of pieces with faces flush on one plane, facing the same way and overlapping: (piece, other piece,
    normal, area). `owners`: per piece, {"parts": [(vertex list, indices)], "area": ...}."""
    planes = {}
    for o, owner in enumerate(owners):
        tris = [(pos[idx[t]], pos[idx[t + 1]], pos[idx[t + 2]]) for pos, idx in owner["parts"] for t in range(0, len(idx) - 2, 3)]
        for tri in tris:
            n = cross(sub(tri[1], tri[0]), sub(tri[2], tri[0]))
            if length(n) < 2e-6:
                continue
            n = tuple(v / length(n) for v in n)
            key = (round(n[0], 2), round(n[1], 2), round(n[2], 2), round(dot(n, tri[0]) / FLICKER_GAP))
            planes.setdefault(key, []).append((o, tri, n))
    found = {}
    for key, tris in planes.items():
        near = tris + planes.get(key[:3] + (key[3] + 1,), [])
        if len({t[0] for t in near}) < 2:
            continue
        for i, x in enumerate(near):
            for y in near[i + 1 :]:
                if x[0] == y[0] or (min(x[0], y[0]), max(x[0], y[0]), key[:3]) in found:
                    continue
                shared = overlap_area(x[1], y[1])
                if shared > 1e-4:
                    found[(min(x[0], y[0]), max(x[0], y[0]), key[:3])] = (x[0], y[0], x[2], shared)
    return list(found.values())


def unflicker_any(owners):
    """Every two pieces flush, facing the same way and overlapping (any shape, door and kept groups too): the smaller
    piece moves NUDGE out along that face's normal, in front. Returns how many moves."""
    moves = 0
    for a, b, n, _ in flush_faces(owners):
        small = a if owners[a]["area"] <= owners[b]["area"] else b
        for pos, _ in owners[small]["parts"]:
            pos[:] = [(p[0] + n[0] * NUDGE, p[1] + n[1] * NUDGE, p[2] + n[2] * NUDGE) for p in pos]
        moves += 1
    return moves


def inside(box, p, grow=0.0):
    """Is point p inside collider `box` (grown by `grow` on every side)?"""
    d = [p[k] - box["centre"][k] for k in range(3)]
    return all(abs(sum(d[k] * box["axes"][a][k] for k in range(3))) <= box["size"][a] / 2 + grow for a in range(3))


def plan_door(door, boxes, middle):
    """Where a door's hinge is and how far it turns to shut and to open (radians about +Y, from the
    pose it was modelled in), from its slab's shape, its handle and the colliders round it."""
    pts, grips = door["points"], door["grips"]
    n = len(pts)
    mx, mz = sum(p[0] for p in pts) / n, sum(p[2] for p in pts) / n
    cxx = sum((p[0] - mx) ** 2 for p in pts) / n
    czz = sum((p[2] - mz) ** 2 for p in pts) / n
    cxz = sum((p[0] - mx) * (p[2] - mz) for p in pts) / n
    phi = 0.5 * math.atan2(2 * cxz, cxx - czz)
    u, v = (math.cos(phi), math.sin(phi)), (-math.sin(phi), math.cos(phi))
    pu = [(p[0] - mx) * u[0] + (p[2] - mz) * u[1] for p in pts]
    pv = [(p[0] - mx) * v[0] + (p[2] - mz) * v[1] for p in pts]
    ylo, yhi = min(p[1] for p in pts), max(p[1] for p in pts)
    width, thick = max(pu) - min(pu), max(0.1, max(pv) - min(pv))
    mid_v = (max(pv) + min(pv)) / 2
    ends = [
        (mx + u[0] * e + v[0] * mid_v, mz + u[1] * e + v[1] * mid_v) for e in (max(pu), min(pu))
    ]
    y_mid = (ylo + yhi) / 2
    height = yhi - ylo

    def hits(hinge, a, s_from=0.15, s_to=0.85):
        """How many points of the slab, swung to angle a about the hinge, are in a wall (the walls
        grown a little: a door can hang a little off its wall's line)."""
        d = (math.cos(a), math.sin(a))
        count = 0
        for i in range(5):
            s_ = width * (s_from + (s_to - s_from) * i / 4)
            for y in (ylo + 0.25 * height, y_mid, ylo + 0.75 * height):
                p = (hinge[0] + d[0] * s_, y, hinge[1] + d[1] * s_)
                if any(inside(b, p, 0.3) for b in boxes):
                    count += 1
        return count

    def touches(hinge, a, s_):
        """Is there a wall, frame or the other half of a double door at distance s_ along angle a?"""
        d = (math.cos(a), math.sin(a))
        for across in (0, 0.5, -0.5, 1.0, -1.0):
            p = (hinge[0] + d[0] * s_ - d[1] * across, y_mid, hinge[1] + d[1] * s_ + d[0] * across)
            if any(inside(b, p, 0.25) for b in boxes):
                return True
        return False

    def wrap(a):
        return (a + math.pi) % (2 * math.pi) - math.pi

    # which end is the hinge: the one away from the handle (both are tried if it has none)
    if grips:
        gx, gz = sum(p[0] for p in grips) / len(grips), sum(p[2] for p in grips) / len(grips)
        far = max(ends, key=lambda e: (e[0] - gx) ** 2 + (e[1] - gz) ** 2)
        hinges = [far]
    else:
        # no handle: the hinge is the end against a wall or frame (if only one is)
        def walled(e):
            return any(inside(b, (e[0], y_mid, e[1]), 0.6) for b in boxes)

        hinges = [e for e in ends if walled(e)] if sum(1 for e in ends if walled(e)) == 1 else ends
    name = door["name"].lower()
    best = None
    for hinge in hinges:
        free = ends[1] if hinge == ends[0] else ends[0]
        a0 = math.atan2(free[1] - hinge[1], free[0] - hinge[0])
        aligned = min(abs(wrap(a0 - k * math.pi / 2)) for k in range(4)) < math.radians(6)
        modelled_shut = aligned and thick < width * 0.25 and not re.search(r"open|ajar", name)
        if modelled_shut:
            shut, score = a0, 0
        else:
            # shut: lined up with a wall (a quarter turn), filling the doorway - no wall in the slab,
            # a frame or wall at both its ends
            # (a quarter turn at most from how it hangs: a door doesn't swing through its own wall)
            options = []
            for k in range(4):
                a = k * math.pi / 2
                if abs(wrap(a - a0)) > math.radians(125):
                    continue
                sc = 3 * hits(hinge, a) + (0 if touches(hinge, a, width + 0.35) else 2)
                sc += (0 if touches(hinge, a, -0.35) else 1) + 0.01 * abs(wrap(a - a0))
                options.append((sc, a))
            score, shut = min(options)
        # open: a quarter turn from shut, into the building if both ways are clear
        inward = (middle[0] - hinge[0], middle[2] - hinge[1])
        opens = []
        for sign in (1, -1):
            a = shut + sign * math.pi / 2
            sweep = sum(hits(hinge, shut + sign * math.pi / 2 * f) for f in (0.33, 0.66, 1.0))
            into = math.cos(a) * inward[0] + math.sin(a) * inward[1] > 0
            opens.append((3 * sweep + (0 if into else 0.5), a))
        open_score, opened = min(opens)
        if not modelled_shut:
            opened = a0  # it was modelled open: that's its open pose
        total = score + open_score * 0.1
        if best is None or total < best[0]:
            best = (total, hinge, a0, shut, opened, modelled_shut)
    _, hinge, a0, shut, opened, modelled_shut = best
    d0 = (math.cos(a0), math.sin(a0))
    # a turn about +Y by t moves a direction's angle (atan2 z, x) by -t
    return {
        "name": door["name"],
        "hinge": [hinge[0], y_mid, hinge[1]],
        "leaf": {
            "centre": [hinge[0] + d0[0] * width / 2, y_mid, hinge[1] + d0[1] * width / 2],
            "along": [d0[0], 0, d0[1]],
            "size": [width, height, max(thick, 0.3)],
        },
        "shutTurn": -wrap(shut - a0),
        "openTurn": -wrap(opened - a0),
        "startsOpen": not modelled_shut,
    }


def merge(src, skip=(), skip_in=None, clutter=CLUTTER_SIZE, with_doors=False, keep=None):
    gltf, binary = load(src)
    scene = gltf["scenes"][gltf.get("scene", 0)]
    if skip_in:
        blo, bhi = bounds(gltf, binary)
        mid = [(blo[k] + bhi[k]) / 2 for k in range(3)]
        skip_in = [skip_in[k] + mid[k % 3] for k in range(6)]
    groups = {}  # material index -> list of (positions, normals, uvs, indices)
    boxes = []
    pieces = []  # closed boxes lined up with the model's axes: {lo, hi, positions (lists, shared with groups)}
    lo, hi = [1e9] * 3, [-1e9] * 3
    materials = gltf.get("materials", [])

    def see_through(material):
        m = materials[material] if 0 <= material < len(materials) else {}
        alpha = m.get("pbrMetallicRoughness", {}).get("baseColorFactor", [1, 1, 1, 1])[3]
        return m.get("alphaMode", "OPAQUE") != "OPAQUE" or alpha < 1 or "glass" in m.get("name", "")

    doors = []  # with_doors: each walk-in door's pieces, merged on their own

    # A texture repeated, turned or shifted on a face (glTF's KHR_texture_transform: an exporter keeps
    # pixels square that way, e.g. repeat 3.5x along a long side) is baked into the UVs: Roblox ignores the
    # setting and stretched the whole picture across each face (squashed pixels, streaks on thin edges).
    # Its textures repeat beyond 0..1, so the repeat still shows.
    from_three = "THREE" in gltf.get("asset", {}).get("generator", "")

    def baked_uv(material, uvs):
        m = materials[material] if 0 <= material < len(materials) else {}
        t = m.get("pbrMetallicRoughness", {}).get("baseColorTexture", {}).get("extensions", {}).get("KHR_texture_transform")
        if not t:
            return uvs
        sx, sy = t.get("scale", [1, 1])
        ox, oy = t.get("offset", [0, 0])
        c, s_ = math.cos(t.get("rotation", 0)), math.sin(t.get("rotation", 0))
        if from_three:
            # three.js (its exporter writes its own texture settings as they are) turns first and repeats
            # after - the other way round from the spec; with a turn, the spec's order put the repeat on
            # the wrong axis (a hatch's turned hazard stripes came out as long lines)
            return [(sx * (c * u + s_ * v) + ox, sy * (-s_ * u + c * v) + oy) for u, v in uvs]
        # (the spec's matrix: translation * rotation * scale, on [u, v, 1])
        return [(c * sx * u + s_ * sy * v + ox, -s_ * sx * u + c * sy * v + oy) for u, v in uvs]

    # Each texture's usual pixel size (texels per stud) on the model's well-shaped faces, the size square_pixels
    # re-spreads squashed faces to (as Roblox draws them: after baked_uv).
    def usual_densities():
        found = {}

        def visit(index, parent):
            node = gltf["nodes"][index]
            world = mul(parent, node_matrix(node))
            for prim in gltf["meshes"][node["mesh"]]["primitives"] if "mesh" in node else []:
                material = prim.get("material", -1)
                size = image_size(gltf, binary, material)
                if prim.get("mode", 4) != 4 or not size or "TEXCOORD_0" not in prim["attributes"]:
                    continue
                pos = [point(world, q) for q in read_accessor(gltf, binary, prim["attributes"]["POSITION"])]
                uv = baked_uv(material, read_accessor(gltf, binary, prim["attributes"]["TEXCOORD_0"]))
                idx = read_accessor(gltf, binary, prim["indices"]) if "indices" in prim else list(range(len(pos)))
                for t in range(0, len(idx) - 2, 3):
                    tri = [pos[idx[t + i]] for i in range(3)]
                    m = texel_map(tri, [uv[idx[t + i]] for i in range(3)], size)
                    if m and m[1] > 1e-9:
                        area = length(cross(sub(tri[1], tri[0]), sub(tri[2], tri[0]))) / 2
                        found.setdefault(material, []).append((m[0] / m[1], math.sqrt(m[0] * m[1]), area))
            for child in node.get("children", []):
                visit(child, world)

        for root in scene["nodes"]:
            visit(root, identity())
        usual = {}
        for material, faces in found.items():
            good = [f for f in faces if f[0] <= 1.5] or faces
            good.sort(key=lambda f: f[1])
            half, run = sum(f[2] for f in good) / 2, 0.0
            for f in good:  # (the area-weighted median)
                run += f[2]
                if run >= half:
                    usual[material] = f[1]
                    break
        return usual

    usual = usual_densities()
    owners = []  # per piece (a node with a mesh): its vertex lists, triangles and area, for unflicker_any
    respread = [0]  # faces square_pixels fixed

    def own(pos, idx):
        owner = owners[-1]
        owner["parts"].append((pos, idx))
        for t in range(0, len(idx) - 2, 3):
            owner["area"] += length(cross(sub(pos[idx[t + 1]], pos[idx[t]]), sub(pos[idx[t + 2]], pos[idx[t]]))) / 2

    # Materials that look the same (same picture, colour and transparency; exporters often make one per
    # face, "collar", "collar_0", ...) share one mesh: each distinct mesh is a download for every player.
    textures_ = gltf.get("textures", [])
    first_like = {}

    def look(material):
        if not 0 <= material < len(materials):
            return material
        m = materials[material]
        pbr = m.get("pbrMetallicRoughness", {})
        tex = pbr.get("baseColorTexture", {}).get("index")
        key = (
            textures_[tex].get("source") if tex is not None and tex < len(textures_) else None,
            tuple(pbr.get("baseColorFactor", [1, 1, 1, 1])),
            m.get("alphaMode", "OPAQUE"),
            bool(m.get("doubleSided")),
        )
        return first_like.setdefault(key, material)

    def walk(index, parent, door=None):
        node = gltf["nodes"][index]
        name = node.get("name", "")
        if name in skip:
            return
        world = mul(parent, node_matrix(node))
        if door is None and keep and name in keep:
            # --keep: a moving piece, kept whole as a named group (gathered like a door's pieces, no plan)
            door = next((d for d in doors if d["name"] == keep[name]), None)
            if door is None:
                door = {"name": keep[name], "groups": {}, "points": [], "grips": [], "kept": True}
                doors.append(door)
        if (
            with_doors
            and door is None
            and node.get("children")
            and DOOR_GROUP.search(name)
            and not NOT_A_DOOR.search(name)
        ):
            door = {"name": name, "groups": {}, "points": [], "grips": []}
            doors.append(door)
        if door is not None and "mesh" in node:
            # a door's piece: its own meshes, no collider (the game gives the door one)
            flip = mirrored(world)
            grip = bool(HANDLE.search(name))
            owners.append({"parts": [], "area": 0.0})
            for prim in gltf["meshes"][node["mesh"]]["primitives"]:
                if prim.get("mode", 4) != 4:
                    continue
                attrs = prim["attributes"]
                pos = [point(world, p) for p in read_accessor(gltf, binary, attrs["POSITION"])]
                nrm = (
                    [direction(world, v) for v in read_accessor(gltf, binary, attrs["NORMAL"])]
                    if "NORMAL" in attrs
                    else [(0, 1, 0)] * len(pos)
                )
                uv = baked_uv(prim.get("material", -1), read_accessor(gltf, binary, attrs["TEXCOORD_0"])) if "TEXCOORD_0" in attrs else [(0, 0)] * len(pos)
                idx = read_accessor(gltf, binary, prim["indices"]) if "indices" in prim else list(range(len(pos)))
                if flip:
                    idx = [idx[i + j] for i in range(0, len(idx), 3) for j in (0, 2, 1)]
                for p in pos:
                    for k in range(3):
                        lo[k], hi[k] = min(lo[k], p[k]), max(hi[k], p[k])
                material = prim.get("material", -1)
                pos, nrm, uv, idx, n_fixed = square_pixels(pos, nrm, uv, idx, image_size(gltf, binary, material), usual.get(material))
                respread[0] += n_fixed
                own(pos, idx)
                key = ("handle" if grip else "", look(material))
                door["groups"].setdefault(key, []).append((pos, nrm, uv, idx))
                (door["grips"] if grip else door["points"]).extend(pos)
            for child in node.get("children", []):
                walk(child, world, door)
            return
        if door is not None:
            for child in node.get("children", []):
                walk(child, world, door)
            return
        if "mesh" in node and skip_in:
            raw = []
            for prim in gltf["meshes"][node["mesh"]]["primitives"]:
                raw += read_accessor(gltf, binary, prim["attributes"]["POSITION"])
            c = point(world, [(min(p[k] for p in raw) + max(p[k] for p in raw)) / 2 for k in range(3)])
            if all(skip_in[k] <= c[k] <= skip_in[k + 3] for k in range(3)):
                return
        if "mesh" in node:
            flip = mirrored(world)
            local_pos, clear, triangles, world_lists = [], False, 0, []
            owners.append({"parts": [], "area": 0.0})
            for prim in gltf["meshes"][node["mesh"]]["primitives"]:
                if prim.get("mode", 4) != 4:
                    continue
                attrs = prim["attributes"]
                raw = read_accessor(gltf, binary, attrs["POSITION"])
                local_pos += raw
                clear = clear or see_through(prim.get("material", -1))
                pos = [point(world, p) for p in raw]
                nrm = (
                    [direction(world, v) for v in read_accessor(gltf, binary, attrs["NORMAL"])]
                    if "NORMAL" in attrs
                    else [(0, 1, 0)] * len(pos)
                )
                uv = baked_uv(prim.get("material", -1), read_accessor(gltf, binary, attrs["TEXCOORD_0"])) if "TEXCOORD_0" in attrs else [(0, 0)] * len(pos)
                idx = read_accessor(gltf, binary, prim["indices"]) if "indices" in prim else list(range(len(pos)))
                triangles += len(idx) // 3
                if flip:
                    idx = [idx[i + j] for i in range(0, len(idx), 3) for j in (0, 2, 1)]
                for p in pos:
                    for k in range(3):
                        lo[k], hi[k] = min(lo[k], p[k]), max(hi[k], p[k])
                material = prim.get("material", -1)
                pos, nrm, uv, idx, n_fixed = square_pixels(pos, nrm, uv, idx, image_size(gltf, binary, material), usual.get(material))
                respread[0] += n_fixed
                own(pos, idx)
                groups.setdefault(look(material), []).append((pos, nrm, uv, idx))
                world_lists.append(pos)
            corners = {tuple(round(c, 4) for c in q) for pos in world_lists for q in pos}
            if (
                len(corners) == 8
                and triangles >= 12
                and all(len({c[k] for c in corners}) == 2 for k in range(3))
            ):
                pieces.append({
                    "lo": [min(c[k] for c in corners) for k in range(3)],
                    "hi": [max(c[k] for c in corners) for k in range(3)],
                    "lists": world_lists,
                })
            if local_pos and not WALK_THROUGH.search(name):
                box = collider(name, world, local_pos, clear, triangles)
                if max(box["size"]) > clutter:
                    boxes.append(box)
        for child in node.get("children", []):
            walk(child, world)

    for root in scene["nodes"]:
        walk(root, identity())
    nudged = unflicker(pieces)
    for _ in range(3):  # (moving one piece can line it up with a third: again until nothing is flush)
        moved = unflicker_any(owners)
        nudged += moved
        if not moved:
            break

    for bad, good in REPLACE_IMAGES.items():
        by_name = {m.get("name"): m for m in materials}
        if bad in by_name and good in by_name:
            tex = by_name[good].get("pbrMetallicRoughness", {}).get("baseColorTexture")
            bad_tex = by_name[bad].get("pbrMetallicRoughness", {}).get("baseColorTexture")
            if tex and bad_tex:
                textures = gltf["textures"]
                # the blocked image's slot gets the good image's bytes (so it's never uploaded)
                gltf["images"][textures[bad_tex["index"]]["source"]]["bufferView"] = gltf["images"][
                    textures[tex["index"]]["source"]
                ]["bufferView"]

    out_bin = bytearray()
    views, accessors = [], []

    def add_view(data, target=None):
        while len(out_bin) % 4:
            out_bin.append(0)
        view = {"buffer": 0, "byteOffset": len(out_bin), "byteLength": len(data)}
        if target:
            view["target"] = target
        out_bin.extend(data)
        views.append(view)
        return len(views) - 1

    # images carried over as they are
    images = []
    for image in gltf.get("images", []):
        view = gltf["bufferViews"][image["bufferView"]]
        start = view.get("byteOffset", 0)
        copy = dict(image)
        copy["bufferView"] = add_view(binary[start : start + view["byteLength"]])
        images.append(copy)

    meshes, nodes = [], []

    def emit(material, prims, base):
        """One node per chunk of `prims` (one material), returning their indices."""
        made = []
        chunks, current, tris = [], [], 0
        for prim in prims:
            count = len(prim[3]) // 3
            if current and tris + count > MAX_TRIANGLES:
                chunks.append(current)
                current, tris = [], 0
            current.append(prim)
            tris += count
        if current:
            chunks.append(current)
        for n, chunk in enumerate(chunks):
            pos, nrm, uv, idx = [], [], [], []
            for p, nm, u, ix in chunk:
                offset = len(pos)
                pos += p
                nrm += nm
                uv += u
                idx += [i + offset for i in ix]
            plo = [min(p[k] for p in pos) for k in range(3)]
            phi = [max(p[k] for p in pos) for k in range(3)]
            a_pos = add_view(struct.pack("<" + "f" * (3 * len(pos)), *[c for p in pos for c in p]), 34962)
            a_nrm = add_view(struct.pack("<" + "f" * (3 * len(nrm)), *[c for v in nrm for c in v]), 34962)
            a_uv = add_view(struct.pack("<" + "f" * (2 * len(uv)), *[c for v in uv for c in v]), 34962)
            a_idx = add_view(struct.pack("<" + "I" * len(idx), *idx), 34963)
            first = len(accessors)
            accessors.extend([
                {"bufferView": a_pos, "componentType": FLOAT, "count": len(pos), "type": "VEC3", "min": plo, "max": phi},
                {"bufferView": a_nrm, "componentType": FLOAT, "count": len(nrm), "type": "VEC3"},
                {"bufferView": a_uv, "componentType": FLOAT, "count": len(uv), "type": "VEC2"},
                {"bufferView": a_idx, "componentType": UINT, "count": len(idx), "type": "SCALAR"},
            ])
            prim = {
                "attributes": {"POSITION": first, "NORMAL": first + 1, "TEXCOORD_0": first + 2},
                "indices": first + 3,
                "mode": 4,
            }
            if material >= 0:
                prim["material"] = material
            name = base if len(chunks) == 1 else f"{base}_{n + 1}"
            meshes.append({"name": name, "primitives": [prim]})
            nodes.append({"name": name, "mesh": len(meshes) - 1})
            made.append(len(nodes) - 1)
        return made

    for material, prims in groups.items():
        emit(material, prims, materials[material]["name"] if material >= 0 and "name" in materials[material] else "part")
    tops = list(range(len(nodes)))
    plans = []
    middle = [(lo[k] + hi[k]) / 2 for k in range(3)]
    def slab_box(plan):
        leaf = plan["leaf"]
        al = leaf["along"]
        return {
            "centre": leaf["centre"],
            "axes": [[al[0], 0, al[2]], [0, 1, 0], [-al[2], 0, al[0]]],
            "size": leaf["size"],
        }

    order = sorted(range(len(doors)), key=lambda i: 0 if re.search(r"closed|broken|taped", doors[i]["name"]) else 1)
    walls = list(boxes)
    planned = {}
    for i in order:
        if doors[i]["points"] and not doors[i].get("kept"):
            planned[i] = plan_door(doors[i], walls, middle)
            if not planned[i]["startsOpen"]:
                walls.append(slab_box(planned[i]))
    for n, door in enumerate(doors):
        if not door["points"]:
            continue
        kids = []
        for (role, material), prims in door["groups"].items():
            base = role or (materials[material]["name"] if material >= 0 and "name" in materials[material] else "part")
            kids += emit(material, prims, base)
        nodes.append({"name": door["name"] if door.get("kept") else f"door_{n + 1}", "children": kids})
        tops.append(len(nodes) - 1)
        if door.get("kept"):
            continue
        plan = planned[n]
        plan["group"] = f"door_{n + 1}"
        plans.append(plan)

    root_name = gltf["nodes"][scene["nodes"][0]].get("name", "model")
    nodes.append({"name": root_name, "children": tops})
    out = {
        "asset": {"version": "2.0", "generator": "merge_model.py"},
        "scene": 0,
        "scenes": [{"nodes": [len(nodes) - 1]}],
        "nodes": nodes,
        "meshes": meshes,
        "accessors": accessors,
        "bufferViews": views,
        "buffers": [{"byteLength": len(out_bin)}],
    }
    for key in ("materials", "textures", "samplers", "extensionsUsed", "extensionsRequired"):
        if key in gltf:
            out[key] = json.loads(json.dumps(gltf[key]))
    # (the texture transforms are in the UVs now: drop them, so nothing applies them twice)
    for m in out.get("materials", []):
        m.get("pbrMetallicRoughness", {}).get("baseColorTexture", {}).get("extensions", {}).pop("KHR_texture_transform", None)
    for key in ("extensionsUsed", "extensionsRequired"):
        if key in out:
            out[key] = [e for e in out[key] if e != "KHR_texture_transform"]
            if not out[key]:
                del out[key]
    if images:
        out["images"] = images

    os.makedirs(OUT_DIR, exist_ok=True)
    dest = os.path.join(OUT_DIR, os.path.basename(src))
    js = json.dumps(out, separators=(",", ":")).encode()
    js += b" " * (-len(js) % 4)
    out_bin.extend(b"\0" * (-len(out_bin) % 4))
    with open(dest, "wb") as f:
        total = 12 + 8 + len(js) + 8 + len(out_bin)
        f.write(struct.pack("<III", 0x46546C67, 2, total))
        f.write(struct.pack("<II", len(js), JSON_CHUNK) + js)
        f.write(struct.pack("<II", len(out_bin), BIN_CHUNK) + out_bin)
    centre = [(lo[k] + hi[k]) / 2 for k in range(3)]
    for box in boxes:
        box["centre"] = [round(box["centre"][k] - centre[k], 4) for k in range(3)]
        box["size"] = [round(v, 4) for v in box["size"]]
        box["axes"] = [[round(v, 5) for v in axis] for axis in box["axes"]]
    if with_doors:
        for plan in plans:
            plan["hinge"] = [round(plan["hinge"][k] - centre[k], 4) for k in range(3)]
            plan["leaf"]["centre"] = [round(plan["leaf"]["centre"][k] - centre[k], 4) for k in range(3)]
        with open(dest[: -len(".glb")] + ".doors.json", "w", encoding="utf-8") as f:
            json.dump(plans, f, indent=1)
    with open(dest[: -len(".glb")] + ".colliders.json", "w", encoding="utf-8") as f:
        json.dump({"size": [hi[k] - lo[k] for k in range(3)], "boxes": boxes}, f, separators=(",", ":"))
    size = [round(hi[k] - lo[k], 2) for k in range(3)]
    before = sum(len(m["primitives"]) for m in gltf["meshes"])
    solid = sum(1 for b in boxes if b["solid"])
    print(
        f"{os.path.basename(src)}: {before} pieces -> {len(meshes)} meshes, size {size}, "
        f"{len(boxes)} colliders ({solid} solid), {nudged} flush faces nudged, {respread[0]} squashed faces re-spread -> {dest}"
    )


if __name__ == "__main__":
    args = sys.argv[1:]
    skip, skip_in, clutter = (), None, CLUTTER_SIZE
    with_doors = "--doors" in args
    if with_doors:
        args.remove("--doors")
    if "--clutter" in args:
        at = args.index("--clutter")
        clutter = float(args[at + 1])
        del args[at : at + 2]
    keep = {}
    if "--keep" in args:
        at = args.index("--keep")
        for spec in args[at + 1].split(","):
            group, names = spec.split(":", 1)
            keep.update({name: group for name in names.split("+")})
        del args[at : at + 2]
    if "--skip" in args:
        at = args.index("--skip")
        skip = set(args[at + 1].split(","))
        del args[at : at + 2]
    if "--skip-in" in args:
        at = args.index("--skip-in")
        skip_in = [float(v) for v in args[at + 1].split(",")]
        del args[at : at + 2]
    if not args:
        sys.exit(__doc__)
    for path in args:
        merge(path, skip, skip_in, clutter, with_doors, keep)
