"""Generate the placeholder R15 rigs for every fighter and enemy as .rbxmx files.

Usage: python tools/build_rigs.py [--force | --check]

Writes one model per fighter (assets/CharacterModels/<Island>/<CharacterId>.rbxmx)
and per enemy (assets/EnemyModels/<Island>/<Rank>.rbxmx and
assets/EnemyModels/Raid/<Type>.rbxmx). Rojo syncs them into
ReplicatedStorage.CharacterModels and ServerStorage.EnemyModels.

Existing files (.rbxmx or .rbxm) are kept, so final models (Blender, or avatars
imported with tools/import_avatars.py) are never overwritten; --force
regenerates the .rbxmx placeholders only (a model with MeshParts is always
kept). --check only lists missing models and fails if there are any.

The placeholders are block R15 rigs with the same parts, joints and
proportions as the imported Roblox avatars: 5 studs tall, feet at y = 0,
HumanoidRootPart centered at y = 3, unrotated joint frames.

The lists of characters, islands, ranks and raid enemy types are read from the
Luau sources, which stay the single source of truth.
"""
import pathlib
import re
import sys
from xml.sax.saxutils import escape

PROJECT = pathlib.Path(__file__).resolve().parent.parent
MODELS = PROJECT / "models"  # imported avatars, loaded in Studio from file (not synced by Rojo)
SHARED = PROJECT / "src" / "shared"
CLIENT = PROJECT / "src" / "client"
ASSETS = PROJECT / "assets"

# Block R15 parts at scale 1: name -> (size, look). Looks: body, limb, leg, skin.
R15_PARTS = {
    "HumanoidRootPart": ((2, 2, 1), "body"),
    "LowerTorso": ((2, 0.4, 1), "body"),
    "UpperTorso": ((2, 1.6, 1), "body"),
    "Head": ((1.2, 1.2, 1.2), "skin"),
    "RightUpperArm": ((1, 1.17, 1), "limb"),
    "RightLowerArm": ((1, 1.05, 1), "limb"),
    "RightHand": ((1, 0.3, 1), "skin"),
    "LeftUpperArm": ((1, 1.17, 1), "limb"),
    "LeftLowerArm": ((1, 1.05, 1), "limb"),
    "LeftHand": ((1, 0.3, 1), "skin"),
    "RightUpperLeg": ((1, 1.217, 1), "leg"),
    "RightLowerLeg": ((1, 1.193, 1), "leg"),
    "RightFoot": ((1, 0.3, 1), "leg"),
    "LeftUpperLeg": ((1, 1.217, 1), "leg"),
    "LeftLowerLeg": ((1, 1.193, 1), "leg"),
    "LeftFoot": ((1, 0.3, 1), "leg"),
}

# Standard R15 Motor6Ds (in Part1): name, Part0, Part1, C0 position, C1 position.
# Same rig attachments as the imported Roblox avatars; frames are unrotated.
R15_JOINTS = [
    ("Root", "HumanoidRootPart", "LowerTorso", (0, -1, 0), (0, -0.2, 0)),
    ("Waist", "LowerTorso", "UpperTorso", (0, 0.2, 0), (0, -0.8, 0)),
    ("Neck", "UpperTorso", "Head", (0, 0.8, 0), (0, -0.586, 0)),
    ("RightShoulder", "UpperTorso", "RightUpperArm", (1, 0.563, 0), (-0.5, 0.394, 0)),
    ("RightElbow", "RightUpperArm", "RightLowerArm", (0, -0.334, 0), (0, 0.259, 0)),
    ("RightWrist", "RightLowerArm", "RightHand", (0, -0.501, 0), (0, 0.125, 0)),
    ("LeftShoulder", "UpperTorso", "LeftUpperArm", (-1, 0.563, 0), (0.5, 0.394, 0)),
    ("LeftElbow", "LeftUpperArm", "LeftLowerArm", (0, -0.334, 0), (0, 0.259, 0)),
    ("LeftWrist", "LeftLowerArm", "LeftHand", (0, -0.501, 0), (0, 0.125, 0)),
    ("RightHip", "LowerTorso", "RightUpperLeg", (0.5, -0.2, 0), (0, 0.421, 0)),
    ("RightKnee", "RightUpperLeg", "RightLowerLeg", (0, -0.401, 0), (0, 0.379, 0)),
    ("RightAnkle", "RightLowerLeg", "RightFoot", (0, -0.547, 0), (0, 0.102, 0)),
    ("LeftHip", "LowerTorso", "LeftUpperLeg", (-0.5, -0.2, 0), (0, 0.421, 0)),
    ("LeftKnee", "LeftUpperLeg", "LeftLowerLeg", (0, -0.401, 0), (0, 0.379, 0)),
    ("LeftAnkle", "LeftLowerLeg", "LeftFoot", (0, -0.547, 0), (0, 0.102, 0)),
]
ROOT_CENTER = (0, 3, 0)  # HumanoidRootPart; the feet end at y = 0
HIP_HEIGHT = 2

IDENTITY = (1, 0, 0, 0, 1, 0, 0, 0, 1)
SKIN = (255, 205, 148)
MATERIAL_SMOOTH_PLASTIC = 272

# Enemy looks: body color and scale (1 = 5 studs tall). Colors match the
# placeholder blocks in EnemyService.
ENEMY_LOOKS = {
    "Easy": ((110, 200, 110), 1.0),
    "Medium": ((230, 200, 80), 1.25),
    "Hard": ((230, 110, 60), 1.5),
    "Boss": ((170, 50, 200), 2.5),
    "Weak": ((110, 200, 110), 1.0),
    "MiniBoss": ((220, 60, 60), 2.0),
}
RAID_LOOKS = {"Medium": ENEMY_LOOKS["Medium"], "Strong": ENEMY_LOOKS["Hard"], "Boss": ((170, 50, 200), 3.0)}


def read(path: pathlib.Path) -> str:
    return path.read_text(encoding="utf-8")


def load_characters() -> list[tuple[str, str, str]]:
    source = read(SHARED / "Data" / "Characters.luau")
    pattern = r'\{ id = "(\w+)", displayName = "[^"]*", island = "(\w+)", rarity = "(\w+)" \}'
    return re.findall(pattern, source)


def load_islands() -> list[str]:
    return re.findall(r'\{ id = "(\w+)", displayName', read(SHARED / "Data" / "Islands.luau"))


def load_enemy_ranks() -> list[str]:
    return re.findall(r'\{ id = "(\w+)", displayName = "[^"]*", timeToKill = [\d.]+, yen = [\d.]+, respawnTime', read(SHARED / "Config" / "Balance.luau"))


def load_raid_types() -> list[str]:
    return re.findall(r'\{ id = "(\w+)", displayName = "[^"]*", timeToKill = [\d.]+, yen = [\d.]+ \}', read(SHARED / "Config" / "Raids.luau"))


def load_rarity_colors() -> dict[str, tuple[int, int, int]]:
    source = read(CLIENT / "UI" / "Theme.luau")
    block = source[source.index("Theme.RarityColors"):source.index("}", source.index("Theme.RarityColors"))]
    return {name: (int(r), int(g), int(b)) for name, r, g, b in re.findall(r"(\w+) = Color3\.fromRGB\((\d+), (\d+), (\d+)\)", block)}


def num(value: float) -> str:
    return f"{value:g}"


def cframe_xml(name: str, position, rotation) -> str:
    x, y, z = position
    rotation_xml = "".join(f"<R{i // 3}{i % 3}>{num(v)}</R{i // 3}{i % 3}>" for i, v in enumerate(rotation))
    return f'<CoordinateFrame name="{name}"><X>{num(x)}</X><Y>{num(y)}</Y><Z>{num(z)}</Z>{rotation_xml}</CoordinateFrame>'


def color_xml(color: tuple[int, int, int]) -> str:
    r, g, b = color
    return f'<Color3uint8 name="Color3uint8">{0xFF000000 | (r << 16) | (g << 8) | b}</Color3uint8>'


def darker(color: tuple[int, int, int], factor: float = 0.75) -> tuple[int, int, int]:
    return tuple(int(c * factor) for c in color)


def build_rig(name: str, body: tuple[int, int, int], scale: float) -> str:
    """Block R15 rig: only HumanoidRootPart is anchored; limbs hang from
    Motor6Ds so animations can move them."""
    refs = {part: f"RBX{index + 1}" for index, part in enumerate(R15_PARTS)}
    looks = {"body": body, "limb": darker(body), "leg": darker(body, 0.55), "skin": SKIN}
    centers = {"HumanoidRootPart": ROOT_CENTER}
    joints_by_part: dict[str, list[str]] = {}
    for joint_name, part0, part1, c0, c1 in R15_JOINTS:
        centers[part1] = tuple(centers[part0][i] + c0[i] - c1[i] for i in range(3))
        joints_by_part.setdefault(part1, []).append(
            f'<Item class="Motor6D"><Properties>'
            f'<string name="Name">{escape(joint_name)}</string>'
            f'<Ref name="Part0">{refs[part0]}</Ref><Ref name="Part1">{refs[part1]}</Ref>'
            f"{cframe_xml('C0', tuple(v * scale for v in c0), IDENTITY)}"
            f"{cframe_xml('C1', tuple(v * scale for v in c1), IDENTITY)}"
            f"</Properties></Item>"
        )

    items = []
    for part, (size, look) in R15_PARTS.items():
        is_root = part == "HumanoidRootPart"
        sx, sy, sz = (v * scale for v in size)
        position = tuple(v * scale for v in centers[part])
        items.append(
            f'<Item class="Part" referent="{refs[part]}"><Properties>'
            f'<string name="Name">{escape(part)}</string>'
            f'<bool name="Anchored">{"true" if is_root else "false"}</bool>'
            f'<bool name="CanCollide">false</bool>'
            f'<bool name="Massless">{"false" if is_root else "true"}</bool>'
            f"{cframe_xml('CFrame', position, IDENTITY)}"
            f'<Vector3 name="size"><X>{num(sx)}</X><Y>{num(sy)}</Y><Z>{num(sz)}</Z></Vector3>'
            f"{color_xml(looks[look])}"
            f'<token name="Material">{MATERIAL_SMOOTH_PLASTIC}</token>'
            f'<token name="TopSurface">0</token><token name="BottomSurface">0</token>'
            f'<float name="Transparency">{"1" if is_root else "0"}</float>'
            f"</Properties>{''.join(joints_by_part.get(part, []))}</Item>"
        )

    humanoid = (
        '<Item class="Humanoid"><Properties>'
        '<string name="Name">Humanoid</string>'
        '<token name="RigType">1</token>'  # R15
        '<token name="DisplayDistanceType">2</token>'  # None: the game draws its own labels
        '<token name="HealthDisplayType">2</token>'  # AlwaysOff
        f'<float name="HipHeight">{num(HIP_HEIGHT * scale)}</float>'
        '</Properties><Item class="Animator"><Properties><string name="Name">Animator</string></Properties></Item></Item>'
    )
    return (
        '<roblox version="4">'
        '<Item class="Model" referent="RBX0"><Properties>'
        f'<string name="Name">{escape(name)}</string>'
        f'<Ref name="PrimaryPart">{refs["HumanoidRootPart"]}</Ref>'
        f"</Properties>{''.join(items)}{humanoid}</Item>"
        "</roblox>\n"
    )


def imported(path: pathlib.Path) -> pathlib.Path:
    """Where an imported avatar for this asset path would be (models/...)."""
    return MODELS / path.relative_to(ASSETS)


def exists(path: pathlib.Path) -> bool:
    return path.exists() or path.with_suffix(".rbxm").exists() or imported(path).exists()


def is_final(path: pathlib.Path) -> bool:
    """A final model in assets/: Blender .rbxm, or a model with MeshParts. (An
    imported avatar in models/ keeps its placeholder here as the fallback the
    game uses until the avatar is inserted in Studio.)"""
    if path.with_suffix(".rbxm").exists():
        return True
    return path.exists() and 'class="MeshPart"' in path.read_text(encoding="utf-8")


def write(path: pathlib.Path, content: str, force: bool) -> bool:
    if is_final(path):
        return False  # a final model always wins over a placeholder
    if path.exists() and not force:
        return False
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8", newline="\n")
    return True


def main() -> int:
    force = "--force" in sys.argv
    check = "--check" in sys.argv
    rarity_colors = load_rarity_colors()
    created = kept = 0
    missing = []

    def emit(path: pathlib.Path, name: str, color, scale: float):
        nonlocal created, kept
        if check:
            if not exists(path):
                missing.append(path.relative_to(PROJECT).as_posix())
            return
        if write(path, build_rig(name, color, scale), force):
            created += 1
        else:
            kept += 1

    for character_id, island, rarity in load_characters():
        emit(ASSETS / "CharacterModels" / island / f"{character_id}.rbxmx", character_id, rarity_colors[rarity], 1.0)
    for island in load_islands():
        for rank in load_enemy_ranks():
            color, scale = ENEMY_LOOKS[rank]
            emit(ASSETS / "EnemyModels" / island / f"{rank}.rbxmx", rank, color, scale)
    for raid_type in load_raid_types():
        color, scale = RAID_LOOKS.get(raid_type, ENEMY_LOOKS.get(raid_type))
        emit(ASSETS / "EnemyModels" / "Raid" / f"{raid_type}.rbxmx", raid_type, color, scale)

    if check:
        for path in missing:
            print(f"Missing model: {path}")
        print("OK: every fighter and enemy has a model" if not missing else f"{len(missing)} models missing")
        return 1 if missing else 0
    print(f"Created {created}, kept {kept} existing")
    return 0


if __name__ == "__main__":
    sys.exit(main())
