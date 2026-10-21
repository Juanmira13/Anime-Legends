"""Generate selene's Roblox standard library (roblox.yml) without selene's downloader.

Usage: python tools/selene_std.py

`selene generate-roblox-std` gives up when the API dump (~7 MB) downloads
slowly. This script does the same work with a long timeout: it is a port of
selene's generator (selene/src/roblox/generate_std.rs) for the selene version
pinned in rokit.toml. It writes two files at the project root, both ignored by
git:
  - roblox_base.yml: selene's hand-written Roblox base (CFrame.new, task...).
  - roblox.yml: classes, enums, Instance.new and GetService from the API dump,
    as JSON (valid YAML), with `base: roblox_base`.
"""
import json
import pathlib
import re
import time
import urllib.request

PROJECT = pathlib.Path(__file__).resolve().parent.parent
API_DUMP = "https://raw.githubusercontent.com/CloneTrooper1019/Roblox-Client-Tracker/roblox/API-Dump.json"
BASE_URL = "https://raw.githubusercontent.com/Kampfkarren/selene/{version}/selene-lib/default_std/roblox_base.yml"
CUSTOM_METHOD_TYPES = {"CFrame", "UDim", "UDim2", "Vector2", "Vector3"}


def fetch(url: str) -> bytes:
    with urllib.request.urlopen(url, timeout=600) as response:
        return response.read()


def selene_version() -> str:
    manifest = (PROJECT / "rokit.toml").read_text(encoding="utf-8")
    match = re.search(r'selene\s*=\s*"Kampfkarren/selene@([^"]+)"', manifest)
    if not match:
        raise SystemExit("selene is not pinned in rokit.toml")
    return match.group(1)


class Generator:
    def __init__(self, api: dict):
        self.classes = {cls["Name"]: cls for cls in api["Classes"]}
        self.api = api
        self.globals: dict = {}
        self.structs: dict = {}

    def write_class(self, global_name: str, class_name: str):
        self.write_class_struct(class_name)
        self.globals[global_name] = {"struct": class_name}

    def write_class_struct(self, class_name: str):
        if class_name in self.structs:
            return
        self.structs[class_name] = {}
        table = {"*": {"struct": "Instance"}}
        self.write_class_members(table, class_name)
        self.structs[class_name] = table

    def write_class_members(self, table: dict, class_name: str):
        cls = self.classes[class_name]
        for member in cls["Members"]:
            kind = member.get("MemberType")
            tags = [tag for tag in (member.get("Tags") or []) if isinstance(tag, str)]
            if kind == "Callback":
                field = {"property": "override-fields"}
            elif kind == "Event":
                field = {"struct": "Event"}
            elif kind == "Function":
                field = {
                    "args": [{"required": False, "type": "any"} for _ in member.get("Parameters", [])],
                    "method": True,
                }
            elif kind == "Property":
                field = self.property_field(member, tags)
            else:
                continue
            if field is None:
                continue
            if "Deprecated" in tags:
                field["deprecated"] = {"message": "this property is deprecated.", "replace": []}
            table[member["Name"]] = field
        if cls["Superclass"] != "<<<ROOT>>>":
            self.write_class_members(table, cls["Superclass"])

    def property_field(self, member: dict, tags: list):
        security = member.get("Security")
        if isinstance(security, dict):
            secure = security.get("Read", "None") != "None" or security.get("Write", "None") != "None"
        else:
            secure = security not in (None, "None")
        if secure:
            return None
        default = {"property": "read-only" if "ReadOnly" in tags else "override-fields"}
        value_type = member.get("ValueType") or {}
        if value_type.get("Category") == "Class":
            self.write_class_struct(value_type["Name"])
            return {"struct": value_type["Name"]}
        if value_type.get("Category") == "DataType" and value_type.get("Name") in CUSTOM_METHOD_TYPES:
            return {"any": True}
        return default

    def write_enums(self):
        for enum in self.api["Enums"]:
            name = enum["Name"]
            self.globals[f"Enum.{name}.GetEnumItems"] = {"args": [], "method": True, "must_use": True}
            self.globals[f"Enum.{name}.FromName"] = {
                "args": [{"required": False, "type": "string"}],
                "method": True,
                "must_use": True,
            }
            self.globals[f"Enum.{name}.FromValue"] = {
                "args": [{"required": False, "type": "number"}],
                "method": True,
                "must_use": True,
            }
            for item in enum["Items"]:
                self.globals[f"Enum.{name}.{item['Name']}"] = {"struct": "EnumItem"}
                for legacy in item.get("LegacyNames", []):
                    self.globals[f"Enum.{name}.{legacy}"] = {
                        "struct": "EnumItem",
                        "deprecated": {
                            "message": f"Enum.{name}.{legacy} was replaced with Enum.{name}.{item['Name']}",
                            "replace": [f"Enum.{name}.{item['Name']}"],
                        },
                    }

    def write_instance_new(self):
        creatable = [cls["Name"] for cls in self.api["Classes"] if "NotCreatable" not in (cls.get("Tags") or [])]
        self.globals["Instance.new"] = {
            "args": [
                {"type": creatable},
                {
                    "required": False,
                    "type": {"display": "Instance"},
                    "deprecated": {"message": "set the instance's parent separately", "replace": []},
                },
            ],
            "must_use": True,
        }

    def write_get_service(self):
        services = [cls["Name"] for cls in self.api["Classes"] if "Service" in (cls.get("Tags") or [])]
        self.structs["DataModel"]["GetService"] = {"args": [{"type": services}], "method": True, "must_use": True}

    def roblox_classes(self) -> dict:
        result = {}
        for cls in self.api["Classes"]:
            members = cls["Members"]
            result[cls["Name"]] = {
                "superclass": cls["Superclass"],
                "events": [m["Name"] for m in members if m.get("MemberType") == "Event"],
                "properties": [m["Name"] for m in members if m.get("MemberType") == "Property"],
            }
        return result


def main() -> int:
    version = selene_version()
    print(f"Downloading selene {version} Roblox base and the Roblox API dump...")
    base = fetch(BASE_URL.format(version=version)).decode("utf-8")
    base = re.sub(r"^name: roblox$", "name: roblox_base", base, count=1, flags=re.MULTILINE)
    api = json.loads(fetch(API_DUMP))

    generator = Generator(api)
    for global_name, class_name in (
        ("game", "DataModel"),
        ("plugin", "Plugin"),
        ("script", "Script"),
        ("workspace", "Workspace"),
    ):
        generator.write_class(global_name, class_name)
    generator.write_enums()
    generator.write_instance_new()
    generator.write_get_service()

    std = {
        "base": "roblox_base",
        "name": "roblox",
        "globals": generator.globals,
        "structs": generator.structs,
        "last_updated": int(time.time()),
        "last_selene_version": version,
        "roblox_classes": generator.roblox_classes(),
    }
    (PROJECT / "roblox_base.yml").write_text(base, encoding="utf-8")
    header = "# Generated by tools/selene_std.py (port of selene generate-roblox-std). Do not edit.\n"
    (PROJECT / "roblox.yml").write_text(header + json.dumps(std, indent=1, sort_keys=True), encoding="utf-8")
    print(f"Wrote roblox_base.yml and roblox.yml ({len(generator.globals)} globals, {len(generator.structs)} structs)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
