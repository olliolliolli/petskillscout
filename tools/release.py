"""Upload a built zip to CurseForge (Upload API).

  python -I tools/release.py versions [filter]         list game versions (token check)
  python -I tools/release.py upload <zip> <changelog.md> <game version id,...> [beta|release|alpha]

The token is read from the file named by PSS_CF_TOKEN_FILE (or A:/Obsidian/API/petskillscout.txt)
and is never printed.
"""
import json, os, sys, urllib.request, uuid

PROJECT = 1743280
API = "https://wow.curseforge.com/api"
TOKEN_FILE = os.environ.get("PSS_CF_TOKEN_FILE", "A:/Obsidian/API/petskillscout.txt")


def token():
    with open(TOKEN_FILE, encoding="utf-8-sig") as f:
        return f.read().strip()


def versions(needle=""):
    req = urllib.request.Request(API + "/game/versions", headers={"X-Api-Token": token(), "User-Agent": "pss-release"})
    with urllib.request.urlopen(req, timeout=60) as r:
        data = json.load(r)
    print(len(data), "versions")
    for v in data:
        if needle.lower() in (v.get("name", "") + " " + v.get("slug", "")).lower():
            print(v["id"], v.get("gameVersionTypeID"), v.get("name"))


def upload(path, changelog, ids, kind="beta"):
    assert kind in ("alpha", "beta", "release")
    with open(changelog, encoding="utf-8") as f:
        text = f.read()
    meta = {"changelog": text, "changelogType": "markdown", "releaseType": kind,
            "gameVersions": [int(x) for x in ids.split(",")], "displayName": os.path.basename(path)[:-4]}
    b = uuid.uuid4().hex
    with open(path, "rb") as f:
        blob = f.read()
    body = (f'--{b}\r\nContent-Disposition: form-data; name="metadata"\r\n\r\n{json.dumps(meta)}\r\n'
            f'--{b}\r\nContent-Disposition: form-data; name="file"; filename="{os.path.basename(path)}"\r\n'
            'Content-Type: application/zip\r\n\r\n').encode() + blob + f"\r\n--{b}--\r\n".encode()
    req = urllib.request.Request(f"{API}/projects/{PROJECT}/upload-file", data=body, method="POST", headers={
        "X-Api-Token": token(), "Content-Type": f"multipart/form-data; boundary={b}", "User-Agent": "pss-release"})
    with urllib.request.urlopen(req, timeout=300) as r:
        print(r.status, r.read().decode()[:300])


if __name__ == "__main__":
    if sys.argv[1] == "versions":
        versions(sys.argv[2] if len(sys.argv) > 2 else "")
    elif sys.argv[1] == "upload":
        upload(*sys.argv[2:])
