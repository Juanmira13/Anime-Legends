"""Turns Roblox avatars (R15, exported from Studio) into the game's R15 rigs.

Usage:
    python tools/import_avatars.py "import/Modelos Nameku.rbxm" --island Nameku
        [--alias vegita=Vegeta ...] [--boss Freezer]

The input is a folder saved from Studio ("Save to File"), .rbxm or .rbxmx
(a .rbxm is converted with rojo first; a single saved model keeps its file
name). Each avatar model is matched to a character of the island by its
display name (case-insensitive; --alias for names that differ) and written to
models/CharacterModels/<Island>/<Id>.rbxmx; --boss also writes that character
as the island's boss, models/EnemyModels/<Island>/Boss.rbxmx, at the boss scale.

Then it rebuilds the two files to load in Studio, with every avatar imported
so far, by island: models/ImportedCharacters.rbxm (a folder ImportedCharacters
with one folder per island) and models/ImportedEnemies.rbxm (ImportedEnemies).
Rojo cannot sync them (live sync cannot set a MeshPart's mesh: Roblox does not
let plugins write MeshId), so in Studio: delete the old ImportedCharacters in
ReplicatedStorage and the old ImportedEnemies in ServerStorage, right-click
ReplicatedStorage -> Insert from File... -> models/ImportedCharacters.rbxm,
right-click ServerStorage -> Insert from File... -> models/ImportedEnemies.rbxm,
and save the place. Rojo never touches those folders, and the game looks there
first (Shared.ModelLookup); the Rojo placeholders in assets/ stay as fallback.

The avatar is kept whole (its 15 body meshes, head with dynamic face, classic
and layered clothing, accessories), as a standard R15 rig the game animates:
- each joint (AnimationConstraint between two rig attachments) becomes the
  classic R15 Motor6D of the same name (Root, Waist, Neck, RightShoulder,
  RightElbow, RightWrist, LeftShoulder, ..., RightHip, RightKnee,
  RightAnkle, ...), in the child part, with C0/C1 from the attachments;
- the ball sockets and no-collision constraints of the physics joints go;
- only HumanoidRootPart is anchored; the model is moved to the origin, facing
  -Z, with its feet at y = 0;
- the Animate script and the HumanoidDescription are dropped; the Humanoid
  shows no name or health (the game draws its own labels).
"""

import argparse
import copy
import json
import pathlib
import re
import subprocess
import sys
import tempfile
import uuid
import xml.etree.ElementTree as ET

PROJECT = pathlib.Path(__file__).resolve().parent.parent
CHARACTERS = PROJECT / "src" / "shared" / "Data" / "Characters.luau"
MODELS = PROJECT / "models"
ASSETS = PROJECT / "assets"
BOSS_SCALE = 2.5  # same as the Boss look in tools/build_rigs.py
IDENTITY = (1, 0, 0, 0, 1, 0, 0, 0, 1)
# Shared strings of the source file (mesh data that parts point to by hash);
# every written file must carry the ones its parts use, or Studio reports it
# as damaged.
SHARED_STRINGS = {}
DROPPED_PART_CHILDREN = {"AnimationConstraint", "BallSocketConstraint", "NoCollisionConstraint"}
DROPPED_MODEL_CHILDREN = {"LocalScript", "Script"}
CFRAME_PROPERTIES = {
    "Part": ("CFrame",),
    "MeshPart": ("CFrame",),
    "Attachment": ("CFrame",),
    "Motor6D": ("C0", "C1"),
    "Weld": ("C0", "C1"),
}


# --- CFrame math (position + row-major 3x3 rotation) ------------------------------------------


def cf_mul(a, b):
    (ap, ar), (bp, br) = a, b
    rot = tuple(sum(ar[r * 3 + k] * br[k * 3 + c] for k in range(3)) for r in range(3) for c in range(3))
    pos = tuple(ap[r] + sum(ar[r * 3 + k] * bp[k] for k in range(3)) for r in range(3))
    return pos, rot


def cf_inv(a):
    p, r = a
    rt = (r[0], r[3], r[6], r[1], r[4], r[7], r[2], r[5], r[8])
    pos = tuple(-sum(rt[row * 3 + k] * p[k] for k in range(3)) for row in range(3))
    return pos, rt


# --- XML helpers ------------------------------------------------------------------------------


def props(item):
    node = item.find("Properties")
    return node if node is not None else ET.SubElement(item, "Properties")


def prop(item, name):
    for child in props(item):
        if child.get("name") == name:
            return child
    return None


def name_of(item):
    node = prop(item, "Name")
    return node.text if node is not None else ""


def children(item, cls=None):
    return [c for c in item.findall("Item") if cls is None or c.get("class") == cls]


def read_cframe(item, name="CFrame"):
    node = prop(item, name)
    if node is None:
        return (0, 0, 0), IDENTITY

    def get(tag, default):
        value = node.find(tag)
        return float(value.text) if value is not None else default

    pos = (get("X", 0), get("Y", 0), get("Z", 0))
    rot = tuple(get(f"R{i // 3}{i % 3}", 1.0 if i in (0, 4, 8) else 0.0) for i in range(9))
    return pos, rot


def set_cframe(item, cframe, name="CFrame"):
    node = prop(item, name)
    if node is not None:
        props(item).remove(node)
    node = ET.SubElement(props(item), "CoordinateFrame", name=name)
    (x, y, z), rot = cframe
    for tag, value in zip(("X", "Y", "Z"), (x, y, z)):
        ET.SubElement(node, tag).text = f"{value:.6g}"
    for i, value in enumerate(rot):
        ET.SubElement(node, f"R{i // 3}{i % 3}").text = f"{value:.6g}"


def set_value(item, kind, name, text):
    node = prop(item, name)
    if node is not None:
        props(item).remove(node)
    ET.SubElement(props(item), kind, name=name).text = text


def read_vector(item, name):
    node = prop(item, name)
    return tuple(float(node.find(axis).text) for axis in ("X", "Y", "Z"))


def set_vector(item, name, vector):
    node = prop(item, name)
    if node is not None:
        props(item).remove(node)
    node = ET.SubElement(props(item), "Vector3", name=name)
    for axis, value in zip(("X", "Y", "Z"), vector):
        ET.SubElement(node, axis).text = f"{value:.6g}"


def new_item(cls, name):
    item = ET.Element("Item", {"class": cls})
    ET.SubElement(item, "Properties")
    set_value(item, "string", "Name", name)
    return item


def is_part(item):
    return item.get("class") in ("Part", "MeshPart")


# --- Conversion -------------------------------------------------------------------------------


def convert(avatar, character_id):
    model = copy.deepcopy(avatar)
    set_value(model, "string", "Name", character_id)
    by_ref = {item.get("referent"): item for item in model.iter("Item") if item.get("referent")}
    parent_of = {child: parent for parent in model.iter("Item") for child in children(parent)}

    for child in children(model):
        if child.get("class") in DROPPED_MODEL_CHILDREN:
            model.remove(child)

    root = next(p for p in children(model) if is_part(p) and name_of(p) == "HumanoidRootPart")
    set_value(model, "Ref", "PrimaryPart", root.get("referent"))
    body = [p for p in children(model) if is_part(p)]

    # Physics joints -> classic R15 Motor6Ds (in the child part, named like the joint).
    joints = 0
    for part in body:
        for constraint in children(part):
            if constraint.get("class") == "AnimationConstraint":
                attachment0 = by_ref.get(prop(constraint, "Attachment0").text)
                attachment1 = by_ref.get(prop(constraint, "Attachment1").text)
                if attachment0 is None or attachment1 is None:
                    continue
                joint = new_item("Motor6D", name_of(constraint))
                ET.SubElement(props(joint), "Ref", name="Part0").text = parent_of[attachment0].get("referent")
                ET.SubElement(props(joint), "Ref", name="Part1").text = parent_of[attachment1].get("referent")
                set_cframe(joint, read_cframe(attachment0), "C0")
                set_cframe(joint, read_cframe(attachment1), "C1")
                parent_of[attachment1].append(joint)
                joints += 1
            if constraint.get("class") in DROPPED_PART_CHILDREN:
                part.remove(constraint)
        anchored = part is root
        set_value(part, "bool", "Anchored", "true" if anchored else "false")
        set_value(part, "bool", "CanCollide", "false")
        set_value(part, "bool", "Massless", "false" if anchored else "true")

    for humanoid in children(model, "Humanoid"):
        for child in children(humanoid):
            if child.get("class") == "HumanoidDescription":
                humanoid.remove(child)
        set_value(humanoid, "token", "DisplayDistanceType", "2")  # None: the game draws its own labels
        set_value(humanoid, "token", "HealthDisplayType", "2")  # AlwaysOff
        if not children(humanoid, "Animator"):
            humanoid.append(new_item("Animator", "Animator"))

    # Move to the origin facing -Z, then stand the feet on y = 0.
    to_origin = cf_inv(read_cframe(root))
    for part in model.iter("Item"):
        if is_part(part):
            set_cframe(part, cf_mul(to_origin, read_cframe(part)))
    lowest = min(read_cframe(p)[0][1] - read_vector(p, "size")[1] / 2 for p in body if p is not root)
    for part in model.iter("Item"):
        if is_part(part):
            (x, y, z), rot = read_cframe(part)
            set_cframe(part, ((x, y - lowest, z), rot))
    return model, joints


def scale_model(model, factor):
    """Scales every part, attachment and joint offset (for bosses)."""
    for item in model.iter("Item"):
        cls = item.get("class")
        if is_part(item):
            set_vector(item, "size", tuple(v * factor for v in read_vector(item, "size")))
            for key in ("PhysicsData", "PhysicalConfigData"):
                node = prop(item, key)
                if node is not None:
                    props(item).remove(node)
        for key in CFRAME_PROPERTIES.get(cls, ()):
            if prop(item, key) is not None:
                pos, rot = read_cframe(item, key)
                set_cframe(item, (tuple(v * factor for v in pos), rot), key)
        if cls == "Humanoid":
            hip = prop(item, "HipHeight")
            if hip is not None:
                hip.text = f"{float(hip.text) * factor:.6g}"


def renumber(item):
    """Gives every Item a new unique referent and points every Ref at the new
    ones (unknown refs become null). Models from different exports reuse the
    same referents, and Studio rejects a file with repeated or dangling ones."""
    new_ids = {}
    for node in item.iter("Item"):
        new_id = "RBX" + uuid.uuid4().hex.upper()
        old = node.get("referent")
        if old:
            new_ids[old] = new_id
        node.set("referent", new_id)
    for ref in item.iter("Ref"):
        ref.text = new_ids.get((ref.text or "").strip(), "null")


def write(model, path):
    root = ET.Element("roblox", version="4")
    model = copy.deepcopy(model)
    renumber(model)
    root.append(model)
    used = sorted({(node.text or "").strip() for node in model.iter("SharedString")} - {""})
    missing = [key for key in used if key not in SHARED_STRINGS]
    if missing:
        raise SystemExit(f"{path.name}: shared strings missing from the source: {missing}")
    if used:
        table = ET.SubElement(root, "SharedStrings")
        for key in used:
            table.append(copy.deepcopy(SHARED_STRINGS[key]))
    ET.indent(root, space="\t")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(ET.tostring(root, encoding="unicode") + "\n", encoding="utf-8", newline="\n")


def build_bundle(kind, folder_name):
    """models/<folder_name>.rbxm: every model in models/<kind>/<Island>/, by
    island, in a folder named folder_name. Written in Roblox's binary format by
    rojo, so Studio reads exactly what Rojo validated."""
    root_folder = new_item("Folder", folder_name)
    for island_dir in sorted(p for p in (MODELS / kind).glob("*") if p.is_dir()):
        island_folder = new_item("Folder", island_dir.name)
        for path in sorted(island_dir.glob("*.rbxmx")):
            file_root = ET.parse(path).getroot()
            model = file_root.find("Item")
            renumber(model)  # each export numbers its referents from scratch
            island_folder.append(model)
            table = file_root.find("SharedStrings")
            for entry in table if table is not None else []:
                SHARED_STRINGS.setdefault(entry.get("md5"), entry)
        if len(island_folder.findall("Item")):
            root_folder.append(island_folder)
    path = MODELS / f"{folder_name}.rbxm"
    with tempfile.TemporaryDirectory() as tmp:
        tmp = pathlib.Path(tmp)
        write(root_folder, tmp / "bundle.rbxmx")
        # Rojo names the root after the project: the folder keeps folder_name.
        (tmp / "bundle.project.json").write_text(json.dumps({"name": folder_name, "tree": {"$path": "bundle.rbxmx"}}))
        subprocess.run(["rojo", "build", str(tmp / "bundle.project.json"), "-o", str(path)], check=True)
    (MODELS / f"{folder_name}.rbxmx").unlink(missing_ok=True)
    return path


# --- Input ------------------------------------------------------------------------------------


def load_xml(source):
    if source.suffix.lower() == ".rbxmx":
        return ET.parse(source).getroot()
    with tempfile.TemporaryDirectory() as tmp:
        tmp = pathlib.Path(tmp)
        (tmp / "input.rbxm").write_bytes(source.read_bytes())
        # Rojo names a project's root after the project, so the file goes one
        # level down under its own name: a single saved model keeps its name.
        project = {"name": "Import", "tree": {"$className": "Folder", source.stem: {"$path": "input.rbxm"}}}
        (tmp / "convert.project.json").write_text(json.dumps(project))
        subprocess.run(["rojo", "build", str(tmp / "convert.project.json"), "-o", str(tmp / "out.rbxmx")], check=True)
        return ET.parse(tmp / "out.rbxmx").getroot()


def island_characters(island):
    text = CHARACTERS.read_text(encoding="utf-8")
    found = {}
    for character_id, display, island_id in re.findall(
        r'id = "([^"]+)", displayName = "([^"]+)", island = "([^"]+)"', text
    ):
        if island_id == island:
            found[display.lower()] = character_id
            found[character_id.lower()] = character_id
    return found


def avatars_in(root):
    found = []

    def walk(item):
        if item.get("class") == "Model" and children(item, "Humanoid"):
            found.append(item)
        else:
            for child in children(item):
                walk(child)

    for item in root.findall("Item"):
        walk(item)
    return found


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("source", type=pathlib.Path)
    parser.add_argument("--island", required=True)
    parser.add_argument("--alias", action="append", default=[], help="avatar name=character id")
    parser.add_argument("--boss", help="character id whose model is also the island's boss")
    args = parser.parse_args()

    source = load_xml(args.source)
    table = source.find("SharedStrings")
    for entry in table if table is not None else []:
        SHARED_STRINGS[entry.get("md5")] = entry
    names = island_characters(args.island)
    for alias in args.alias:
        avatar_name, character_id = alias.split("=", 1)
        names[avatar_name.strip().lower()] = character_id.strip()
    converted = {}
    for avatar in avatars_in(source):
        avatar_name = name_of(avatar)
        character_id = names.get(avatar_name.strip().lower())
        if character_id is None:
            print(f"SKIP {avatar_name!r}: no {args.island} character with that name (use --alias)")
            continue
        model, joints = convert(avatar, character_id)
        path = MODELS / "CharacterModels" / args.island / f"{character_id}.rbxmx"
        write(model, path)
        converted[character_id] = model
        print(f"OK   {avatar_name!r} -> {path.relative_to(PROJECT).as_posix()} ({joints} Motor6D)")
    if args.boss:
        if args.boss not in converted:
            print(f"FAIL boss {args.boss}: not among the converted avatars")
            return 1
        boss = copy.deepcopy(converted[args.boss])
        set_value(boss, "string", "Name", "Boss")
        scale_model(boss, BOSS_SCALE)
        path = MODELS / "EnemyModels" / args.island / "Boss.rbxmx"
        write(boss, path)
        print(f"OK   boss {args.boss} x{BOSS_SCALE} -> {path.relative_to(PROJECT).as_posix()}")
    for character_id in sorted(set(names.values()) - set(converted)):
        print(f"NOTE {character_id}: no avatar given, keeps its current model")
    characters = build_bundle("CharacterModels", "ImportedCharacters")
    enemies = build_bundle("EnemyModels", "ImportedEnemies")
    print("DO   in Studio (delete the old folders first, then save the place):")
    print(f"       ReplicatedStorage -> Insert from File... -> {characters.relative_to(PROJECT).as_posix()}")
    print(f"       ServerStorage -> Insert from File... -> {enemies.relative_to(PROJECT).as_posix()}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
