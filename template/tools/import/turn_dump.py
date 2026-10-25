"""
Turn and size a Studio dump (tools/import/studio_dump.luau) before tools/import/dump2rbxm.luau builds the
.rbxm, so a model made another way fits the game's convention for props: modelled in metres (the builder that
places them scales props by METRE, 2.78 studs), length along Z with the front at -Z.

    python tools/import/turn_dump.py <dump.json> --turn 90 --scale 0.288 [--out other.json]

--turn: degrees about +Y (Roblox's CFrame.Angles(0, turn, 0)); 90 turns a front at +X to -Z.
--scale: multiply every position and size (the mesh is stretched to its new size).
Rewrites the dump in place unless --out is given.

Claude Design's cars come front +X, ~16 units long for a sedan: --turn 90 --scale 0.288 makes a sedan
12.7 studs long once it is scaled by METRE (2.78).
"""
import argparse
import json
import math

ap = argparse.ArgumentParser()
ap.add_argument("dump")
ap.add_argument("--turn", type=float, default=0.0)
ap.add_argument("--scale", type=float, default=1.0)
ap.add_argument("--out")
args = ap.parse_args()

a = math.radians(args.turn)
c, s = math.cos(a), math.sin(a)
R = [[c, 0, s], [0, 1, 0], [-s, 0, c]]  # CFrame.Angles(0, a, 0)


def mul(A, B):
    return [[sum(A[i][k] * B[k][j] for k in range(3)) for j in range(3)] for i in range(3)]


rows = json.load(open(args.dump, encoding="utf-8"))
for row in rows:
    cf = row[2]
    p = cf[0:3]
    rot = [cf[3:6], cf[6:9], cf[9:12]]
    p2 = [args.scale * sum(R[i][k] * p[k] for k in range(3)) for i in range(3)]
    rot2 = mul(R, rot)
    row[2] = p2 + rot2[0] + rot2[1] + rot2[2]
    row[3] = [v * args.scale for v in row[3]]
json.dump(rows, open(args.out or args.dump, "w", encoding="utf-8"))
print(f"[turn_dump] {len(rows)} pieces turned {args.turn:g} degrees, scaled {args.scale:g} -> {args.out or args.dump}")
