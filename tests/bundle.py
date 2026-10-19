"""Bundle Luau source folders and a spec into one file with a fake instance tree,
so modules that use `require(script.Parent...)` run under the standalone luau CLI.

Each root becomes a global named after it (e.g. `Shared`, `Server`). Only pure
modules can be required this way; anything that touches Roblox services at
require time will fail.
"""
import pathlib
import re

PRELUDE = """
local __loaders = {}
local __cache = {}
local function __inst(name, parent)
    local inst = { Name = name, Parent = parent, __children = {} }
    setmetatable(inst, { __index = function(_, key) error("No child '" .. tostring(key) .. "' in " .. name) end })
    if parent then rawget(parent, "__children")[name] = inst; rawset(parent, name, inst) end
    return inst
end
local function require(inst)
    if __cache[inst] == nil then
        local loader = __loaders[inst]
        if loader == nil then error("Not a module: " .. inst.Name) end
        __cache[inst] = loader(inst)
    end
    return __cache[inst]
end
"""


def instance_name(path: pathlib.Path) -> str:
    """Name Rojo gives a file: drop .luau and the .server/.client suffixes."""
    name = path.name.removesuffix(".luau")
    return name.removesuffix(".server").removesuffix(".client")


def bundle(roots: dict[str, pathlib.Path], spec: pathlib.Path, out: pathlib.Path) -> None:
    parts = [PRELUDE]
    counter = 0
    for root_name, root in roots.items():
        folders = {root: root_name}
        parts.append(f'local {root_name} = __inst("{root_name}", nil)')
        for path in sorted(root.rglob("*")):
            counter += 1
            var = f"__i{counter}"
            parent = folders[path.parent]
            if path.is_dir():
                folders[path] = var
                parts.append(f'local {var} = __inst("{path.name}", {parent})')
            elif path.suffix == ".luau":
                source = path.read_text(encoding="utf-8")
                # Type exports are only legal at the top level of a real module.
                source = re.sub(r"^export type", "type", source, flags=re.M)
                parts.append(f'local {var} = __inst("{instance_name(path)}", {parent})')
                parts.append(f"__loaders[{var}] = function(script)\n{source}\nend")
    parts.append(spec.read_text(encoding="utf-8"))
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("\n".join(parts), encoding="utf-8")
