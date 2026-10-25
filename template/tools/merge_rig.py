"""
Merge an imported character (a rig from Claude Design: an NPC, a creature) into a few meshes per body part, keeping
its joints, before Import 3D.

    python tools/merge_rig.py <prepared.glb>      -> Downloads/ready/rig/<name>.glb

Why: a detailed character comes as hundreds of tiny pieces (fingers, nails, every lump and cap), and each
distinct mesh is a separate download for every new player (src/shared/PerfBudget.luau). Unlike
tools/merge_model.py (one mesh per texture for the whole model), a rig has to keep moving: every
`joint_*` node stays, with its transform, and the pieces under it (but not under a deeper joint) are
merged into one mesh per texture in that joint's space. The six main limb pieces (Torso, Head, Left
Arm, Right Arm, Left Leg, Right Leg) stay as they are, so their boxes stay exact (the hitboxes).

Run it on files already through tools/prepare_import.py (safe names, crisp textures).
"""
import json
import os
import struct
import sys

from merge_model import (
    BIN_CHUNK,
    FLOAT,
    JSON_CHUNK,
    UINT,
    direction,
    identity,
    load,
    mirrored,
    mul,
    node_matrix,
    point,
    read_accessor,
)

# Where prepared files go: Downloads/ready on a PC; an agent on the server sets READY_DIR to its own build/ready
# (a folder of its worktree, not shared with other agents).
READY = os.environ.get("READY_DIR") or os.path.join(os.path.expanduser("~"), "Downloads", "ready")
OUT_DIR = os.path.join(READY, "rig")
LIMBS = {"Torso", "Head", "Left Arm", "Right Arm", "Left Leg", "Right Leg"}


def prims_of(gltf, binary, node, m):
    """The node's triangle lists with `m` baked in: (material, positions, normals, uvs, indices)."""
    out = []
    flip = mirrored(m)
    for prim in gltf["meshes"][node["mesh"]]["primitives"]:
        if prim.get("mode", 4) != 4:
            continue
        attrs = prim["attributes"]
        pos = [point(m, p) for p in read_accessor(gltf, binary, attrs["POSITION"])]
        nrm = (
            [direction(m, v) for v in read_accessor(gltf, binary, attrs["NORMAL"])]
            if "NORMAL" in attrs
            else [(0, 1, 0)] * len(pos)
        )
        uv = read_accessor(gltf, binary, attrs["TEXCOORD_0"]) if "TEXCOORD_0" in attrs else [(0, 0)] * len(pos)
        idx = read_accessor(gltf, binary, prim["indices"]) if "indices" in prim else list(range(len(pos)))
        if flip:
            idx = [idx[i + j] for i in range(0, len(idx), 3) for j in (0, 2, 1)]
        out.append((prim.get("material", -1), pos, nrm, uv, idx))
    return out


def merge(src):
    gltf, binary = load(src)
    materials = gltf.get("materials", [])
    out_bin = bytearray()
    views, accessors, meshes, nodes = [], [], [], []

    def add_view(data, target=None):
        while len(out_bin) % 4:
            out_bin.append(0)
        view = {"buffer": 0, "byteOffset": len(out_bin), "byteLength": len(data)}
        if target:
            view["target"] = target
        out_bin.extend(data)
        views.append(view)
        return len(views) - 1

    def add_mesh(name, prims):
        """One mesh from prims (all one material, or several primitives)."""
        out_prims = []
        by_material = {}
        for material, pos, nrm, uv, idx in prims:
            by_material.setdefault(material, []).append((pos, nrm, uv, idx))
        for material, parts in by_material.items():
            pos, nrm, uv, idx = [], [], [], []
            for p, nm, u, ix in parts:
                offset = len(pos)
                pos += p
                nrm += nm
                uv += u
                idx += [i + offset for i in ix]
            a_pos = add_view(struct.pack("<" + "f" * (3 * len(pos)), *[c for p in pos for c in p]), 34962)
            a_nrm = add_view(struct.pack("<" + "f" * (3 * len(nrm)), *[c for v in nrm for c in v]), 34962)
            a_uv = add_view(struct.pack("<" + "f" * (2 * len(uv)), *[c for v in uv for c in v]), 34962)
            a_idx = add_view(struct.pack("<" + "I" * len(idx), *idx), 34963)
            first = len(accessors)
            accessors.extend([
                {
                    "bufferView": a_pos, "componentType": FLOAT, "count": len(pos), "type": "VEC3",
                    "min": [min(p[k] for p in pos) for k in range(3)],
                    "max": [max(p[k] for p in pos) for k in range(3)],
                },
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
            out_prims.append(prim)
        meshes.append({"name": name, "primitives": out_prims})
        return len(meshes) - 1

    before = 0

    def gather(index, m, extras):
        """Pieces under a joint (not under a deeper joint), baked into the joint's space by `m`."""
        nonlocal before
        node = gltf["nodes"][index]
        if node.get("name", "").startswith("joint_"):
            return [index]  # a deeper joint: kept, handled on its own
        local = mul(m, node_matrix(node))
        if "mesh" in node:
            before += 1
            extras.extend(prims_of(gltf, binary, node, local))
        deeper = []
        for child in node.get("children", []):
            deeper += gather(child, local, extras)
        return deeper

    def emit(index):
        """Copy a structural node; a joint gets its limb and its merged details as children."""
        nonlocal before
        node = gltf["nodes"][index]
        name = node.get("name", "")
        out = {"name": name}
        for key in ("translation", "rotation", "scale", "matrix"):
            if key in node:
                out[key] = node[key]
        children = []
        if name.startswith("joint_"):
            extras, deeper = [], []
            for child in node.get("children", []):
                c = gltf["nodes"][child]
                if c.get("name") in LIMBS and "mesh" in c and not c.get("children"):
                    # the limb itself: its own transform and mesh, untouched
                    before += 1
                    limb = {"name": c["name"], "mesh": add_mesh(c["name"], prims_of(gltf, binary, c, identity()))}
                    for key in ("translation", "rotation", "scale", "matrix"):
                        if key in c:
                            limb[key] = c[key]
                    nodes.append(limb)
                    children.append(len(nodes) - 1)
                else:
                    deeper += gather(child, identity(), extras)
            by_material = {}
            for prim in extras:
                by_material.setdefault(prim[0], []).append(prim)
            for material, prims in by_material.items():
                base = materials[material].get("name", "part") if material >= 0 else "part"
                nodes.append({"name": base, "mesh": add_mesh(base, prims)})
                children.append(len(nodes) - 1)
            for d in deeper:
                children.append(emit(d))
        else:
            if "mesh" in node:
                raise SystemExit(f"a mesh outside any joint: {name}")
            for child in node.get("children", []):
                children.append(emit(child))
        if children:
            out["children"] = children
        nodes.append(out)
        return len(nodes) - 1

    scene = gltf["scenes"][gltf.get("scene", 0)]
    roots = [emit(r) for r in scene["nodes"]]

    images = []
    for image in gltf.get("images", []):
        view = gltf["bufferViews"][image["bufferView"]]
        start = view.get("byteOffset", 0)
        copy = dict(image)
        copy["bufferView"] = add_view(binary[start : start + view["byteLength"]])
        images.append(copy)

    out = {
        "asset": {"version": "2.0", "generator": "merge_rig.py"},
        "scene": 0,
        "scenes": [{"nodes": roots}],
        "nodes": nodes,
        "meshes": meshes,
        "accessors": accessors,
        "bufferViews": views,
        "buffers": [{"byteLength": len(out_bin)}],
    }
    for key in ("materials", "textures", "samplers", "extensionsUsed", "extensionsRequired"):
        if key in gltf:
            out[key] = gltf[key]
    if images:
        out["images"] = images

    os.makedirs(OUT_DIR, exist_ok=True)
    dest = os.path.join(OUT_DIR, os.path.basename(src))
    js = json.dumps(out, separators=(",", ":")).encode()
    js += b" " * (-len(js) % 4)
    out_bin.extend(b"\0" * (-len(out_bin) % 4))
    with open(dest, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(out_bin)))
        f.write(struct.pack("<II", len(js), JSON_CHUNK) + js)
        f.write(struct.pack("<II", len(out_bin), BIN_CHUNK) + out_bin)
    print(f"{os.path.basename(src)}: {before} pieces -> {len(meshes)} meshes -> {dest}")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    for path in sys.argv[1:]:
        merge(path)
