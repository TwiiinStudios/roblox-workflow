"""
Upload one file to Roblox through the Open Cloud Assets API, owned by the group that owns the game,
and wait for the result (asset id and moderation state).

    python tools/import/upload_asset.py <file> <Decal|Model|Audio> "<display name>"

The key is ROBLOX_ASSETS_KEY in the git-ignored .env (Assets read + write, created under the
TwiiinStudios group); it is read from the file and never printed. Group-owned uploads are what the
game can use: images owned by a person's account don't show in it.

Every name and picture is read by moderation out of context (the owner was banned once over asset
names): run tools/prepare_import.py on models first and look at every texture before uploading.
"""
import json
import os
import sys
import time
import urllib.error
import urllib.request
import uuid

GROUP_ID = "524204215"  # TwiiinStudios
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TYPES = {
    ".png": "image/png",
    ".jpg": "image/jpeg",
    ".fbx": "model/fbx",
    ".glb": "model/gltf-binary",
    ".gltf": "model/gltf+json",
    ".ogg": "audio/ogg",
    ".mp3": "audio/mpeg",
}


def api_key():
    for line in open(os.path.join(ROOT, ".env"), encoding="utf-8-sig"):
        if line.strip().startswith("ROBLOX_ASSETS_KEY="):
            return line.split("=", 1)[1].strip()
    sys.exit("no ROBLOX_ASSETS_KEY in .env")


def call(key, url, data=None, method="GET", content_type=None):
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("x-api-key", key)
    if content_type:
        req.add_header("Content-Type", content_type)
    try:
        with urllib.request.urlopen(req, timeout=60) as reply:  # (without one, a stalled call hung forever)
            return reply.status, json.loads(reply.read() or b"{}")
    except urllib.error.HTTPError as err:
        return err.code, err.read().decode(errors="replace")[:600]


def upload(path, kind, name):
    key = api_key()
    request = {
        "assetType": kind,
        "displayName": name,
        "description": os.path.basename(ROOT),  # the game's folder name
        "creationContext": {"creator": {"groupId": GROUP_ID}},
    }
    boundary = uuid.uuid4().hex
    mime = TYPES[os.path.splitext(path)[1].lower()]
    body = (
        (
            f'--{boundary}\r\nContent-Disposition: form-data; name="request"\r\nContent-Type: application/json\r\n\r\n'
            + json.dumps(request)
            + f'\r\n--{boundary}\r\nContent-Disposition: form-data; name="fileContent"; '
            + f'filename="{os.path.basename(path)}"\r\nContent-Type: {mime}\r\n\r\n'
        ).encode()
        + open(path, "rb").read()
        + f"\r\n--{boundary}--\r\n".encode()
    )
    status, op = call(key, "https://apis.roblox.com/assets/v1/assets", body, "POST", f"multipart/form-data; boundary={boundary}")
    if status != 200 or not isinstance(op, dict):
        sys.exit(f"upload refused: {status} {op}")
    for _ in range(60):
        if op.get("done"):
            break
        time.sleep(2)
        status, op = call(key, "https://apis.roblox.com/assets/v1/" + op["path"])
    response = op.get("response", {})
    print(json.dumps({
        "assetId": response.get("assetId"),
        "moderation": response.get("moderationResult", {}).get("moderationState"),
        "state": response.get("state"),
        "done": op.get("done"),
    }))


if __name__ == "__main__":
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    upload(*sys.argv[1:4])
