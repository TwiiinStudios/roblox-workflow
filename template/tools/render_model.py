"""
Draw a model the way Roblox will, so an agent (or anyone) can look at it without Studio.

    python tools/render_model.py <file.glb> [more...] [--out <folder>]     exits 1 if it finds flicker

For every file it writes one picture sheet, <out>/<name>.png (default out: build/render), and prints its path.
Look at the sheet (an agent: Read the .png) before the model is uploaded or imported. The views:

  - the four sides from above at an angle, the four sides straight on at eye height, straight down, far away
  - close up to every named piece (a lid, a door: the groups tools/merge_model.py --keep makes)
  - cut in half both ways, looking at the inside of the far half: shafts, rooms, doors down inside

Drawn like Roblox draws a MeshPart: texture pixels crisp (nearest pixel, never blurred), texture repeat/clamp as
the file says, KHR_texture_transform ignored (Roblox ignores it), back faces not drawn (a face turned the wrong way
is a hole, as in the game), MASK/BLEND alpha cut at half. The lighting is plain (sun + sky), not Roblox's, so judge
textures and shapes here and the mood in Studio.

Flicker is found while drawing: where two different, front-facing, almost parallel surfaces are at the same depth on
a pixel and show different colours, the graphics card can't tell which is in front. Those pixels are painted bright
pink and counted; any at all fails the run. tools/merge_model.py separates such faces.

What to look for on the sheet: smeared or stretched pixels, a texture that's wrong, missing (flat grey or white) or
turned, holes and see-through faces, gaps between pieces, floating pieces, pink flicker.

Needs Python with numpy and Pillow (pip install numpy pillow).
"""
import io
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from visual_check import load, mul, node_matrix, read_accessor  # noqa: E402

VIEW = 400  # pixels per view on the sheet
SUPER = 2  # drawn this many times bigger, then shrunk (smooth edges, crisp textures)
COLUMNS = 4
FOV = math.radians(50)
NEAR = 0.05
SKY = (196, 214, 230)
FLICKER_COLOUR = (255, 0, 200)
FLICKER_GAP = 0.004  # studs between two surfaces' depths on a pixel that still fight
FLICKER_PARALLEL = 0.985  # cos of the angle between two surfaces that fight
FLICKER_SHADE = 24  # colour difference (0-255, summed) that can be seen flickering
FLICKER_MIN = 16  # pink pixels (at drawing size) before a view counts as flickering
MAX_CLOSE_UPS = 6
SUN = np.array([0.45, 0.8, 0.35]) / np.linalg.norm([0.45, 0.8, 0.35])


def textures_of(gltf, binary):
    images = []
    for image in gltf.get("images", []):
        try:
            view = gltf["bufferViews"][image["bufferView"]]
            start = view.get("byteOffset", 0)
            img = Image.open(io.BytesIO(binary[start : start + view["byteLength"]])).convert("RGBA")
            images.append(np.asarray(img, dtype=np.float32) / 255)
        except Exception:  # (unreadable: drawn white, like a missing texture in Roblox)
            images.append(None)
    out = []
    samplers = gltf.get("samplers", [])
    for t in gltf.get("textures", []):
        sampler = samplers[t["sampler"]] if "sampler" in t and t["sampler"] < len(samplers) else {}
        source = t.get("source")
        out.append(
            (
                images[source] if source is not None and source < len(images) else None,
                sampler.get("wrapS", 10497) == 10497,
                sampler.get("wrapT", 10497) == 10497,
            )
        )
    return out


def gather(path):
    """Every triangle of the model: positions (n,3,3), uvs (n,3,2), material index (n), piece index (n), pieces."""
    gltf, binary = load(path)
    pos, uvs, mats, owners = [], [], [], []
    pieces = []  # (name, first triangle, last triangle) per top-level child of the scene
    scene = gltf["scenes"][gltf.get("scene", 0)]

    def walk(index, parent, piece):
        node = gltf["nodes"][index]
        world = mul(parent, node_matrix(node))
        if "mesh" in node:
            m = np.array(world)
            for prim in gltf["meshes"][node["mesh"]]["primitives"]:
                if prim.get("mode", 4) != 4:
                    continue
                attrs = prim["attributes"]
                p = np.array(read_accessor(gltf, binary, attrs["POSITION"]), dtype=np.float64)
                p = p @ m[:3, :3].T + m[:3, 3]
                uv = (
                    np.array(read_accessor(gltf, binary, attrs["TEXCOORD_0"]), dtype=np.float64)
                    if "TEXCOORD_0" in attrs
                    else np.zeros((len(p), 2))
                )
                idx = (
                    np.array(read_accessor(gltf, binary, prim["indices"]), dtype=np.int64)
                    if "indices" in prim
                    else np.arange(len(p))
                )
                idx = idx[: len(idx) // 3 * 3].reshape(-1, 3)
                if np.linalg.det(m[:3, :3]) < 0:  # a mirrored node turns its faces around
                    idx = idx[:, ::-1]
                pos.append(p[idx])
                uvs.append(uv[idx])
                mats.append(np.full(len(idx), prim.get("material", -1)))
                owners.append(np.full(len(idx), piece))
        for child in node.get("children", []):
            walk(child, world, piece)

    identity = [[1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]]
    roots = scene["nodes"]
    # wrappers holding everything (the usual export): the children inside are the pieces
    top, children = identity, roots
    while len(children) == 1 and "mesh" not in gltf["nodes"][children[0]] and gltf["nodes"][children[0]].get("children"):
        top = mul(top, node_matrix(gltf["nodes"][children[0]]))
        children = gltf["nodes"][children[0]]["children"]
    for i, child in enumerate(children):
        before = sum(len(x) for x in pos)
        walk(child, top, i)
        pieces.append((gltf["nodes"][child].get("name", f"piece {i}"), before, sum(len(x) for x in pos)))
    if not pos:
        sys.exit(f"{path}: no triangles")
    return gltf, binary, np.concatenate(pos), np.concatenate(uvs), np.concatenate(mats), np.concatenate(owners), pieces


def look_at(eye, target):
    forward = target - eye
    forward = forward / np.linalg.norm(forward)
    up = np.array([0.0, 1.0, 0.0])
    if abs(forward @ up) > 0.99:
        up = np.array([0.0, 0.0, -1.0])
    right = np.cross(forward, up)
    right /= np.linalg.norm(right)
    up = np.cross(right, forward)
    return np.stack([right, up, forward])  # rows: camera x (right), y (up), z (forward)


def clip_near(cam, uv):
    """Triangles in camera space cut at the near plane: lists of (3,3) points and (3,2) uvs (up to two each)."""
    inside = cam[:, 2] >= NEAR
    if inside.all():
        return [(cam, uv)]
    if not inside.any():
        return []
    poly_p, poly_uv = [], []
    for i in range(3):
        j = (i + 1) % 3
        if inside[i]:
            poly_p.append(cam[i])
            poly_uv.append(uv[i])
        if inside[i] != inside[j]:
            t = (NEAR - cam[i, 2]) / (cam[j, 2] - cam[i, 2])
            poly_p.append(cam[i] + t * (cam[j] - cam[i]))
            poly_uv.append(uv[i] + t * (uv[j] - uv[i]))
    out = []
    for k in range(1, len(poly_p) - 1):
        out.append((np.array([poly_p[0], poly_p[k], poly_p[k + 1]]), np.array([poly_uv[0], poly_uv[k], poly_uv[k + 1]])))
    return out


def render(model, eye, target, cut=None, size=VIEW * SUPER):
    """One view: the picture (VIEW x VIEW), the number of flicker pixels, and the triangle in front on each pixel.
    cut = (axis, at, sign): only what lies on the sign side of that plane is drawn (the model cut open there)."""
    gltf, textures, pos, uvs, mats, owners = model
    eye = np.asarray(eye, float)
    rot = look_at(eye, np.asarray(target, float))
    focal = (size / 2) / math.tan(FOV / 2)

    colour = np.empty((size, size, 3), np.float32)
    colour[:] = np.array(SKY, np.float32) / 255
    depth = np.full((size, size), np.inf)
    who = np.full((size, size), -1, np.int64)  # triangle in front on each pixel
    depth2 = np.full((size, size), np.inf)  # the nearest other surface behind it (for flicker)
    colour2 = np.zeros((size, size, 3), np.float32)
    who2 = np.full((size, size), -1, np.int64)

    materials = gltf.get("materials", [])
    normals = np.cross(pos[:, 1] - pos[:, 0], pos[:, 2] - pos[:, 0])
    lengths = np.linalg.norm(normals, axis=1)
    ok = lengths > 1e-12
    normals[ok] /= lengths[ok, None]
    shade = 0.62 + 0.38 * np.clip(normals @ SUN, 0, 1) - 0.08 * (normals[:, 1] < -0.5)
    cam_all = (pos - eye) @ rot.T

    if cut is not None:
        axis, at, sign = cut
        ok = ok & ((sign * (pos[:, :, axis] - at)).max(axis=1) > 0)
    # all at once, before the slow loop: drop triangles behind the camera, off the picture, or facing away
    z = cam_all[:, :, 2]
    ok &= z.max(axis=1) >= NEAR
    whole = z.min(axis=1) >= NEAR  # (triangles crossing the near plane are cut in the loop instead)
    with np.errstate(divide="ignore", invalid="ignore"):
        sx_all = size / 2 + focal * cam_all[:, :, 0] / z
        sy_all = size / 2 - focal * cam_all[:, :, 1] / z
    facing = (sx_all[:, 1] - sx_all[:, 0]) * (sy_all[:, 2] - sy_all[:, 0]) - (sx_all[:, 2] - sx_all[:, 0]) * (sy_all[:, 1] - sy_all[:, 0])
    off = (sx_all.max(axis=1) < 0) | (sx_all.min(axis=1) > size) | (sy_all.max(axis=1) < 0) | (sy_all.min(axis=1) > size)
    ok &= ~(whole & ((facing >= 0) | off))
    for t in np.nonzero(ok)[0]:
        for cam, uv in clip_near(cam_all[t], uvs[t]):
            sx = size / 2 + focal * cam[:, 0] / cam[:, 2]
            sy = size / 2 - focal * cam[:, 1] / cam[:, 2]
            area = (sx[1] - sx[0]) * (sy[2] - sy[0]) - (sx[2] - sx[0]) * (sy[1] - sy[0])
            if area >= 0:  # facing away (or edge on): Roblox doesn't draw back faces
                continue
            x0, x1 = max(int(math.floor(sx.min())), 0), min(int(math.ceil(sx.max())), size - 1)
            y0, y1 = max(int(math.floor(sy.min())), 0), min(int(math.ceil(sy.max())), size - 1)
            if x0 > x1 or y0 > y1:
                continue
            px, py = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
            # edge functions (positive inside); a pixel exactly on an edge two triangles share belongs to one of
            # them only, by the edge's direction (they run along it opposite ways), or it would look like flicker
            w, inside = [], np.ones(px.shape, bool)
            for i in range(3):
                a, b = (i + 1) % 3, (i + 2) % 3
                ex, ey = sx[b] - sx[a], sy[b] - sy[a]
                e = (px - sx[a]) * ey - (py - sy[a]) * ex
                inside &= (e > 0) | ((e == 0) & (ey > 0 or (ey == 0 and ex > 0)))
                w.append(e)
            if not inside.any():
                continue
            l0, l1, l2 = (e[inside] / -area for e in w)
            inv_z = l0 / cam[0, 2] + l1 / cam[1, 2] + l2 / cam[2, 2]
            z = 1 / inv_z
            yy, xx = np.nonzero(inside)
            yy, xx = yy + y0, xx + x0
            if cut is not None:
                p = (np.outer(l0, cam[0] / cam[0, 2]) + np.outer(l1, cam[1] / cam[1, 2]) + np.outer(l2, cam[2] / cam[2, 2])) * z[:, None]
                beyond = sign * (eye[axis] + p @ rot[:, axis] - at) > 0
                l0, l1, l2, z, yy, xx = l0[beyond], l1[beyond], l2[beyond], z[beyond], yy[beyond], xx[beyond]
                if not len(z):
                    continue

            # texture (perspective-correct, nearest pixel)
            mat = mats[t]
            m = materials[mat] if 0 <= mat < len(materials) else {}
            pbr = m.get("pbrMetallicRoughness", {})
            factor = np.array(pbr.get("baseColorFactor", [1, 1, 1, 1]), np.float32)
            rgba = np.tile(factor, (len(z), 1))
            tex = pbr.get("baseColorTexture")
            if tex is not None and tex["index"] < len(textures):
                image, wrap_s, wrap_t = textures[tex["index"]]
                if image is not None:
                    u = (l0 * uv[0, 0] / cam[0, 2] + l1 * uv[1, 0] / cam[1, 2] + l2 * uv[2, 0] / cam[2, 2]) * z
                    v = (l0 * uv[0, 1] / cam[0, 2] + l1 * uv[1, 1] / cam[1, 2] + l2 * uv[2, 1] / cam[2, 2]) * z
                    h, wdt = image.shape[:2]
                    u = u - np.floor(u) if wrap_s else np.clip(u, 0, 0.999999)
                    v = v - np.floor(v) if wrap_t else np.clip(v, 0, 0.999999)
                    rgba = rgba * image[(v * h).astype(np.int64) % h, (u * wdt).astype(np.int64) % wdt]
            if m.get("alphaMode", "OPAQUE") != "OPAQUE":
                solid = rgba[:, 3] >= m.get("alphaCutoff", 0.5)
                yy, xx, z, rgba = yy[solid], xx[solid], z[solid], rgba[solid]
            rgb = np.clip(rgba[:, :3] * shade[t], 0, 1)

            # depth test, keeping the nearest other surface for the flicker check
            front = z < depth[yy, xx]
            old_who = who[yy, xx]
            moved = front & (old_who >= 0)
            my, mx = yy[moved], xx[moved]
            depth2[my, mx] = depth[my, mx]
            colour2[my, mx] = colour[my, mx]
            who2[my, mx] = old_who[moved]
            fy, fx = yy[front], xx[front]
            depth[fy, fx] = z[front]
            colour[fy, fx] = rgb[front]
            who[fy, fx] = t
            behind = ~front & (z < depth2[yy, xx])
            by, bx = yy[behind], xx[behind]
            depth2[by, bx] = z[behind]
            colour2[by, bx] = rgb[behind]
            who2[by, bx] = t

    # flicker: two different, parallel, front-facing surfaces at the same depth, showing different colours
    with np.errstate(invalid="ignore"):
        both = (who >= 0) & (who2 >= 0) & ((depth2 - depth) < FLICKER_GAP)
    fy, fx = np.nonzero(both)
    a, b = who[fy, fx], who2[fy, fx]
    parallel = np.einsum("ij,ij->i", normals[a], normals[b]) > FLICKER_PARALLEL
    differs = np.abs(colour[fy, fx] - colour2[fy, fx]).sum(axis=1) * 255 > FLICKER_SHADE
    hit = parallel & differs & (a != b)
    flicker = int(hit.sum())
    if flicker >= FLICKER_MIN:
        colour[fy[hit], fx[hit]] = np.array(FLICKER_COLOUR, np.float32) / 255
    else:
        flicker = 0
    img = Image.fromarray((colour * 255).astype(np.uint8)).resize((VIEW, VIEW), Image.BOX)
    if flicker:  # a ring around each spot, so a small one can't be missed
        draw = ImageDraw.Draw(img)
        for x, y in {(int(x) // (SUPER * 12), int(y) // (SUPER * 12)) for x, y in zip(fx[hit], fy[hit])}:
            cx, cy = x * 12 + 6, y * 12 + 6
            draw.ellipse((cx - 11, cy - 11, cx + 11, cy + 11), outline=FLICKER_COLOUR, width=2)
    return img, flicker, who


def directions():
    """Ways to look at something: around it at three heights, and from straight above."""
    out = [np.array([0.05, 1.0, 0.03])]
    for up in (0.35, 0.9, -0.3):
        for a in range(0, 360, 45):
            out.append(np.array([math.cos(math.radians(a)), up, math.sin(math.radians(a))]))
    return [d / np.linalg.norm(d) for d in out]


def seen_from(eye, points, pos):
    """How many of the points the eye can see: lines to them that no triangle (of pos) crosses (Moller-Trumbore)."""
    a = pos[:, 0]
    e1, e2 = pos[:, 1] - a, pos[:, 2] - a
    count = 0
    for p in points:
        d = p - eye
        h = np.cross(d, e2)
        det = np.einsum("ij,ij->i", e1, h)
        with np.errstate(divide="ignore", invalid="ignore"):
            f = 1 / det
            s = eye - a
            u = f * np.einsum("ij,ij->i", s, h)
            q = np.cross(s, e1)
            v = f * (q @ d)
            t = f * np.einsum("ij,ij->i", e2, q)
            blocked = (np.abs(det) > 1e-12) & (u >= 0) & (v >= 0) & (u + v <= 1) & (t > 1e-4) & (t < 0.995)
        count += not blocked.any()
    return count


def close_up(model, piece, pc, pr):
    """The spot near a piece from which the most of it can be seen (a door down a shaft: from inside the shaft)."""
    pos, owners = model[2], model[5]
    mine = owners == piece
    centres = pos[mine].mean(axis=1)
    points = centres[np.random.default_rng(1).choice(len(centres), min(10, len(centres)), replace=False)]
    others = pos[~mine]
    best, best_seen = None, 0
    for distance in (pr * 2.4, pr * 1.5):
        for d in directions():
            eye = pc + d * distance
            seen = seen_from(eye, points, others)
            if seen > best_seen:
                best, best_seen = eye, seen
        if best_seen >= len(points) * 0.7:  # a good view from further away: keep it
            break
    return best


def views(model, pieces):
    pos = model[2]
    lo, hi = pos.reshape(-1, 3).min(axis=0), pos.reshape(-1, 3).max(axis=0)
    centre, reach = (lo + hi) / 2, float(np.linalg.norm(hi - lo))
    corners = np.array([[x, y, z] for x in (lo[0], hi[0]) for y in (lo[1], hi[1]) for z in (lo[2], hi[2])]) - centre

    def framed(direction, part=None):
        """The camera spot along a direction from the middle where the model (or a half of it) just fills the view."""
        d = np.asarray(direction, float)
        d = d / np.linalg.norm(d)
        rot = look_at(centre + d, centre)
        pts = corners if part is None else corners[part(corners)]
        fit = math.tan(FOV / 2) * 0.9
        x, y, z = pts @ rot[0], pts @ rot[1], pts @ rot[2]
        return centre + d * float(max((np.abs(x) / fit - z).max(), (np.abs(y) / fit - z).max(), NEAR * 4))

    out = []
    for i, side in enumerate(["north", "east", "south", "west"]):
        a = math.radians(i * 90 + 45)
        out.append((f"{side} side", framed([math.cos(a), 0.75, math.sin(a)]), centre, None))
    for i, side in enumerate(["front", "right", "back", "left"]):
        a = math.radians(i * 90 + 90)
        out.append((f"{side}, straight on", framed([math.cos(a), 0.08, math.sin(a)]), centre, None))
    out.append(("from above", framed([0.001, 1, 0]), centre, None))
    out.append(("far away", centre + np.array([reach * 3.2, reach * 0.7, reach * 2.4]), centre, None))
    # cut open through the middle, looking into the far half, from all four sides
    for axis, sign, name in ((0, 1, "east"), (0, -1, "west"), (2, 1, "south"), (2, -1, "north")):
        d = np.zeros(3)
        d[axis] = -sign
        d[1] = 0.2
        part = (lambda c, axis=axis, sign=sign: sign * c[:, axis] >= 0)
        out.append((f"cut open: inside of the {name} half", framed(d, part), centre, (axis, centre[axis], sign)))
    # close up to the most detailed pieces smaller than the whole (a lid, a door, a wheel: where flicker and odd
    # textures hide), one per name, each from where it shows best
    named, names = [], set()
    for i, (name, first, last) in enumerate(pieces):
        if last <= first:
            continue
        plo, phi = pos[first:last].reshape(-1, 3).min(axis=0), pos[first:last].reshape(-1, 3).max(axis=0)
        size = float(np.linalg.norm(phi - plo))
        if size < reach * 0.6 and name not in names:
            names.add(name)
            named.append((last - first, i, name, (plo + phi) / 2, max(size, reach * 0.1)))
    for _, i, name, pc, pr in sorted(named, key=lambda n: -n[0])[:MAX_CLOSE_UPS]:
        eye = close_up(model, i, pc, pr)
        if eye is not None:
            out.append((f"close up: {name}", eye, pc, None))
    return out


def sheet(path, out_dir):
    gltf, binary, pos, uvs, mats, owners, pieces = gather(path)
    model = (gltf, textures_of(gltf, binary), pos, uvs, mats, owners)
    shots = views(model, pieces)
    rows = math.ceil(len(shots) / COLUMNS)
    label_h = 22
    board = Image.new("RGB", (COLUMNS * VIEW, rows * (VIEW + label_h)), (40, 40, 40))
    draw = ImageDraw.Draw(board)
    flickers = []
    for i, (name, eye, target, cut) in enumerate(shots):
        img, flicker, _ = render(model, eye, target, cut)
        x, y = (i % COLUMNS) * VIEW, (i // COLUMNS) * (VIEW + label_h)
        board.paste(img, (x, y + label_h))
        text = name + (f"  -  FLICKER: {flicker} px (pink)" if flicker else "")
        draw.text((x + 6, y + 5), text, fill=(255, 120, 220) if flicker else (235, 235, 235))
        if flicker:
            flickers.append(f"{name}: {flicker} px")
    os.makedirs(out_dir, exist_ok=True)
    target = os.path.join(out_dir, os.path.splitext(os.path.basename(path))[0] + ".png")
    board.save(target)
    return target, len(pos), flickers


if __name__ == "__main__":
    args = sys.argv[1:]
    out_dir = os.path.join("build", "render")
    if "--out" in args:
        at = args.index("--out")
        out_dir = args[at + 1]
        del args[at : at + 2]
    if not args:
        sys.exit(__doc__)
    bad = 0
    for path in args:
        target, count, flickers = sheet(path, out_dir)
        print(f"{os.path.basename(path)}: {count} triangles drawn -> {target}")
        if flickers:
            bad += 1
            print("  Flicker (pink on the sheet; tools/merge_model.py separates such faces):")
            for f in flickers:
                print(f"    - {f}")
    print("Now look at every view on the sheet: stretched or smeared pixels, wrong/missing textures, holes, gaps, floating pieces.")
    sys.exit(1 if bad else 0)
