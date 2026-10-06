"""Looks over a folder of 3D model files before they are imported into Roblox Studio.

For every .glb/.gltf/.fbx/.obj file it works out which of the game's models the file is (by
its name), and for glTF files also reads what Roblox cares about: triangles per mesh (Roblox
takes at most 20,000 in one mesh), texture sizes (anything above 1024 px is shrunk), the
model's proportions (is it standing up, does a kunai lie along one axis) and whether it has a
rig. Then it lists what is missing and which files should be renamed, so that the importer,
which names a model after its file, gives every model the name the game looks for.

    python scripts/check-models.py <folder>            look only, change nothing
    python scripts/check-models.py <folder> --rename   also rename the files it is sure about

The names it expects are read from the game's own config, so the list never goes stale.
Needs nothing but Python.
"""

import base64
import difflib
import json
import math
import re
import struct
import sys
from pathlib import Path

CONFIG = Path(__file__).resolve().parent.parent / "src" / "shared" / "Config"
MODEL_FILES = {".glb", ".gltf", ".fbx", ".obj"}

# Roblox refuses a single mesh with more triangles than this.
MESH_LIMIT = 20_000
# Above these a model is worth making lighter: there can be over a hundred shinobi in view.
HEAVY = {"shinobi": 12_000, "enemy": 20_000, "kunai": 3_000}
# Roblox shrinks textures to this many pixels a side.
TEXTURE_LIMIT = 1024
# The same rules the game applies at start-up (server World/Showroom).
LYING = 1.7
SLENDER = 1.8
# A kunai thinner than this share of its length all but vanishes seen end-on.
FLAT = 0.05

# Words in a file name that say nothing about who the model is.
NOISE = {"chibi", "model", "final", "lowpoly", "low", "poly", "mesh", "textured", "texture",
         "3d", "glb", "gltf", "fbx", "obj", "new", "fixed", "export", "roblox"}


def plain(text):
    """A name as lowercase words joined by underscores."""
    return re.sub(r"[^a-z0-9]+", "_", text.lower()).strip("_")


def without_brackets(name):
    return re.sub(r"\([^)]*\)", " ", name)


def inside_brackets(name):
    return " ".join(re.findall(r"\(([^)]*)\)", name))


def expected_models():
    """model name -> (kind, display name), in the game's order."""
    models = {}
    characters = (CONFIG / "Characters.luau").read_text(encoding="utf-8")
    for match in re.finditer(r'\{\s*id = "([a-z0-9_]+)",\s*name = "([^"]+)",\s*rank', characters):
        models[match.group(1)] = ("shinobi", match.group(2))
    zones = (CONFIG / "Zones.luau").read_text(encoding="utf-8")
    zone_ids = re.findall(r'\bid = "([a-z0-9_]+)"', zones)
    enemies = re.findall(r'enemy = \{ name = "([^"]+)"', zones)
    for zone, enemy in zip(zone_ids, enemies):
        models["enemy_" + zone] = ("enemy", enemy)
    kunai = (CONFIG / "Kunai.luau").read_text(encoding="utf-8")
    for match in re.finditer(r'kunai\(\s*"([a-z0-9_]+)",\s*"([^"]+)"', kunai):
        models["kunai_" + match.group(1)] = ("kunai", match.group(2))
    return models


def alias_table(models):
    """Every way a file may be named -> the model it means. Surer ways come first; a way
    that two models could claim alike belongs to neither."""
    tiers = [{}, {}, {}]

    def claim(tier, alias, model):
        alias = plain(alias)
        if alias:
            tiers[tier].setdefault(alias, set()).add(model)

    for model, (kind, name) in models.items():
        claim(0, model, model)
        claim(1, name, model)
        short = without_brackets(name)
        claim(2, short, model)
        if kind == "enemy":
            claim(1, "enemy " + name, model)
            claim(1, "boss " + name, model)
            claim(2, "enemy " + short, model)
            claim(2, "boss " + short, model)
            claim(2, inside_brackets(name), model)
            claim(2, short.split()[0] if short.split() else "", model)
        elif kind == "kunai":
            bare = model[len("kunai_"):]
            claim(1, bare + " kunai", model)
            claim(2, bare, model)

    table = {}
    for tier in tiers:
        for alias, claimed in tier.items():
            if alias not in table and len(claimed) == 1:
                table[alias] = next(iter(claimed))
    return table


def recognize(stem, table):
    """(model name or None, how sure: "exact", "cleaned" or "guess")."""
    name = plain(stem)
    if name in table:
        return table[name], "exact"
    words = [w for w in name.split("_") if w not in NOISE and not w.isdigit()]
    cleaned = "_".join(words)
    if cleaned in table:
        return table[cleaned], "cleaned"
    close = difflib.get_close_matches(cleaned or name, list(table), n=1, cutoff=0.82)
    if close:
        return table[close[0]], "guess"
    return None, "unknown"


# --- Reading glTF -------------------------------------------------------------------------


def read_gltf(path):
    """The glTF document and its binary chunk (None for a .gltf with outside buffers)."""
    if path.suffix.lower() == ".glb":
        data = path.read_bytes()
        magic, _, length = struct.unpack_from("<4sII", data, 0)
        if magic != b"glTF":
            raise ValueError("not a GLB file")
        document, binary, offset = None, None, 12
        while offset + 8 <= min(length, len(data)):
            size, kind = struct.unpack_from("<II", data, offset)
            chunk = data[offset + 8 : offset + 8 + size]
            if kind == 0x4E4F534A:
                document = json.loads(chunk.decode("utf-8"))
            elif kind == 0x004E4942 and binary is None:
                binary = chunk
            offset += 8 + size
        if document is None:
            raise ValueError("GLB without a JSON chunk")
        return document, binary
    return json.loads(path.read_text(encoding="utf-8")), None


def multiply(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(4)) for j in range(4)] for i in range(4)]


def node_matrix(node):
    if "matrix" in node:
        m = node["matrix"]  # column-major
        return [[m[column * 4 + row] for column in range(4)] for row in range(4)]
    tx, ty, tz = node.get("translation", (0, 0, 0))
    x, y, z, w = node.get("rotation", (0, 0, 0, 1))
    sx, sy, sz = node.get("scale", (1, 1, 1))
    rotation = [
        [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
        [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
        [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
    ]
    scale = (sx, sy, sz)
    matrix = [[rotation[i][j] * scale[j] for j in range(3)] + [(tx, ty, tz)[i]] for i in range(3)]
    return matrix + [[0, 0, 0, 1]]


def image_size(data):
    """(width, height) of a PNG or JPEG from its first bytes, or None."""
    if data[:8] == b"\x89PNG\r\n\x1a\n" and len(data) >= 24:
        return struct.unpack(">II", data[16:24])
    if data[:2] == b"\xff\xd8":
        at = 2
        while at + 9 < len(data):
            if data[at] != 0xFF:
                at += 1
                continue
            marker = data[at + 1]
            if marker in (0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, 0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF):
                height, width = struct.unpack(">HH", data[at + 5 : at + 9])
                return width, height
            if marker in (0xD8, 0x01) or 0xD0 <= marker <= 0xD7:
                at += 2
                continue
            at += 2 + struct.unpack(">H", data[at + 2 : at + 4])[0]
    return None


def image_bytes(document, binary, image, folder):
    if "bufferView" in image and binary is not None:
        view = document["bufferViews"][image["bufferView"]]
        start = view.get("byteOffset", 0)
        return binary[start : start + view["byteLength"]]
    uri = image.get("uri", "")
    if uri.startswith("data:"):
        return base64.b64decode(uri.split(",", 1)[1])
    if uri:
        target = folder / uri
        if target.is_file():
            with target.open("rb") as handle:
                return handle.read(1 << 16)
        return None
    return None


def measure(path):
    """What a glTF file holds: triangles, meshes, textures, size."""
    document, binary = read_gltf(path)
    accessors = document.get("accessors", [])
    meshes = document.get("meshes", [])

    def triangles(primitive):
        if "indices" in primitive:
            count = accessors[primitive["indices"]]["count"]
        else:
            count = accessors[primitive["attributes"]["POSITION"]]["count"]
        mode = primitive.get("mode", 4)
        if mode == 4:
            return count // 3
        return max(count - 2, 0) if mode in (5, 6) else 0

    per_mesh = [sum(triangles(p) for p in mesh.get("primitives", [])) for mesh in meshes]

    # Walk the scene so that every placed mesh is counted where it stands.
    nodes = document.get("nodes", [])
    scenes = document.get("scenes", [])
    roots = scenes[document.get("scene", 0)]["nodes"] if scenes else list(range(len(nodes)))
    low, high = [math.inf] * 3, [-math.inf] * 3
    total, placed, biggest = 0, 0, 0
    identity = [[1 if i == j else 0 for j in range(4)] for i in range(4)]
    stack = [(index, identity) for index in roots]
    while stack:
        index, parent = stack.pop()
        node = nodes[index]
        world = multiply(parent, node_matrix(node))
        if "mesh" in node:
            placed += 1
            total += per_mesh[node["mesh"]]
            biggest = max(biggest, per_mesh[node["mesh"]])
            for primitive in meshes[node["mesh"]].get("primitives", []):
                position = accessors[primitive["attributes"]["POSITION"]]
                if "min" not in position or "max" not in position:
                    continue
                for corner in range(8):
                    point = [
                        (position["max"] if corner >> axis & 1 else position["min"])[axis]
                        for axis in range(3)
                    ] + [1]
                    for axis in range(3):
                        value = sum(world[axis][k] * point[k] for k in range(4))
                        low[axis] = min(low[axis], value)
                        high[axis] = max(high[axis], value)
        stack.extend((child, world) for child in node.get("children", []))

    textures = []
    for image in document.get("images", []):
        data = image_bytes(document, binary, image, path.parent)
        textures.append(image_size(data) if data else None)

    return {
        "triangles": total,
        "biggest": biggest,
        "meshes": placed,
        "textures": textures,
        "size": [high[i] - low[i] for i in range(3)] if placed and low[0] != math.inf else None,
        "rigged": bool(document.get("skins")),
        "animated": bool(document.get("animations")),
    }


def remarks(kind, facts):
    """What to do about a file, worst first. Returns (problems, notes)."""
    problems, notes = [], []
    if facts["biggest"] > MESH_LIMIT:
        problems.append(
            f"{facts['biggest']:,} triangles in one mesh: Roblox takes at most {MESH_LIMIT:,}, make it lighter"
        )
    elif kind in HEAVY and facts["triangles"] > HEAVY[kind]:
        notes.append(f"heavy: {facts['triangles']:,} triangles, lighter is better")
    if facts["meshes"] == 0:
        problems.append("no mesh in the file")
    size = facts["size"]
    if size and kind == "shinobi":
        x, y, z = size
        if max(x, z) > y * LYING:
            up = "Z" if z > x else "X"
            problems.append(f"lies down (longest along {up}, should stand along Y)")
    if size and kind == "kunai":
        sides = sorted(size)
        if sides[2] < sides[1] * SLENDER:
            problems.append("not long and thin along one axis: a kunai must not lie diagonally")
        elif sides[0] < sides[2] * FLAT:
            notes.append(
                "nearly flat: the flight camera looks from behind, where a flat kunai is a line; "
                "about a tenth of its length is a good thickness"
            )
    known = [t for t in facts["textures"] if t]
    if not facts["textures"]:
        notes.append("no texture inside: it will come in one flat color")
    elif any(max(t) > TEXTURE_LIMIT for t in known):
        notes.append(f"texture above {TEXTURE_LIMIT} px: Roblox shrinks it, nothing to do")
    if facts["rigged"] or facts["animated"]:
        notes.append("has a rig or animation: import with Rig Type = No Rig")
    if facts["meshes"] > 12:
        notes.append(f"{facts['meshes']} separate meshes: consider Merge Meshes in the importer")
    return problems, notes


def candidates(stem, models):
    """Models a name that fits several of them could mean."""
    words = [w for w in plain(stem).split("_") if w not in NOISE and not w.isdigit()]
    if not words:
        return []
    return [
        model
        for model, (_, name) in models.items()
        if all(word in plain(model + " " + name).split("_") for word in words)
    ][:6]


def main():
    # A console that cannot show a file's name should not stop the check.
    sys.stdout.reconfigure(errors="replace")
    arguments = [a for a in sys.argv[1:] if not a.startswith("--")]
    rename = "--rename" in sys.argv
    if len(arguments) != 1:
        print(__doc__)
        return 2
    folder = Path(arguments[0])
    if not folder.is_dir():
        print(f"not a folder: {folder}")
        return 2

    models = expected_models()
    table = alias_table(models)
    files = sorted(p for p in folder.rglob("*") if p.is_file() and p.suffix.lower() in MODEL_FILES)
    # A file that already carries a model's name gets it ahead of a differently named copy.
    files.sort(key=lambda p: (p.stem not in models, str(p).lower()))
    print(f"{len(files)} model files in {folder}")
    print(f"the game looks for {len(models)} models\n")

    taken = {}  # model name -> the file that got it
    renames, guesses, unknown, broken = [], [], [], 0
    for path in files:
        model, sure = recognize(path.stem, table)
        kind = models[model][0] if model else None
        line = f"{path.name}"
        if model and sure != "guess":
            if model in taken:
                print(f"{line}\n    PROBLEM: a second file for {model} (the first is {taken[model].name})")
                broken += 1
                continue
            taken[model] = path
            line += f"  ->  {model}"
            if path.stem != model:
                renames.append((path, path.with_name(model + path.suffix.lower())))
        elif model:
            guesses.append((path, model))
            line += f"  ->  ? (perhaps {model})"
        else:
            unknown.append(path)
            could = candidates(path.stem, models)
            line += "  ->  ? (name not recognized"
            line += f"; could be {', '.join(could)})" if could else ")"

        details, problems, notes = "", [], []
        if path.suffix.lower() in (".glb", ".gltf"):
            try:
                facts = measure(path)
                problems, notes = remarks(kind, facts)
                sizes = ", ".join(f"{t[0]}x{t[1]}" if t else "?" for t in facts["textures"]) or "none"
                shape = "x".join(f"{v:.2f}" for v in facts["size"]) if facts["size"] else "?"
                details = (
                    f"{facts['triangles']:,} triangles in {facts['meshes']} mesh(es), "
                    f"textures: {sizes}, size {shape}"
                )
            except Exception as error:  # a file this script cannot read may still import
                details = f"could not read it ({error})"
        else:
            details = "not a glTF file: only its name is checked"
        print(line)
        print(f"    {details}")
        for problem in problems:
            print(f"    PROBLEM: {problem}")
        for note in notes:
            print(f"    note: {note}")
        broken += len(problems)

    print("\nSUMMARY")
    for kind, title in (("shinobi", "shinobi"), ("enemy", "enemies"), ("kunai", "kunai")):
        wanted = [m for m, (k, _) in models.items() if k == kind]
        missing = [m for m in wanted if m not in taken]
        print(f"  {title}: {len(wanted) - len(missing)}/{len(wanted)}")
        if missing:
            print(f"    no file for: {', '.join(missing)}")
    if guesses:
        print("  not sure about (rename by hand if the guess is right):")
        for path, model in guesses:
            print(f"    {path.name}  ->  {model}{path.suffix.lower()}")
    if unknown:
        print("  names not recognized:")
        for path in unknown:
            print(f"    {path.name}")
    print(f"  problems to fix before importing: {broken}")

    if renames:
        print("\nRENAMES" + ("" if rename else " (nothing is changed; add --rename to do them)"))
        for old, new in renames:
            if not rename:
                print(f"  {old.name}  ->  {new.name}")
            elif new.exists() and not new.samefile(old):
                # On Windows a name that differs only in capitals is the same file, and that
                # one does need renaming: Roblox tells "Haku" from "haku".
                print(f"  skipped {old.name}: {new.name} already exists")
            else:
                old.rename(new)
                print(f"  renamed {old.name}  ->  {new.name}")
    else:
        print("\nEvery recognized file already has the name the game looks for.")
    return 1 if broken else 0


if __name__ == "__main__":
    sys.exit(main())
