"""Bundle Luau source folders and a spec into one file with a fake instance tree,
so modules that use `require(script.Parent...)` run under the standalone luau CLI.

Each root becomes a variable named after it (e.g. `Shared`, `Server`, `Client`) and is
placed in its service, so `game:GetService("ReplicatedStorage"):WaitForChild("Shared")`
also works. Only pure modules can be required this way; anything that uses
other Roblox APIs at require time will fail.
"""
import pathlib
import re

PRELUDE = """
local __loaders = {}
local __cache = {}
local __I = {}
local function __inst(name, parent)
    local inst = { Name = name, Parent = parent, __children = {} }
    function inst:WaitForChild(childName)
        return rawget(self, "__children")[childName] or error("No child '" .. childName .. "' in " .. name)
    end
    function inst:FindFirstChild(childName)
        return rawget(self, "__children")[childName]
    end
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
-- Only the services that hold the source roots exist in tests.
local __services = {
    ReplicatedStorage = __inst("ReplicatedStorage", nil),
    ServerScriptService = __inst("ServerScriptService", nil),
}
local game = {
    GetService = function(_, serviceName)
        return __services[serviceName] or error("Service not available in tests: " .. serviceName)
    end,
}
"""

# Service each root lives in, matching default.project.json. Roots without a
# service (Client) are only reachable through their variable.
ROOT_SERVICES = {
    "Shared": "ReplicatedStorage",
    "Server": "ServerScriptService",
}


def instance_name(path: pathlib.Path) -> str:
    """Name Rojo gives a file: drop .luau and the .server/.client suffixes."""
    name = path.name.removesuffix(".luau")
    return name.removesuffix(".server").removesuffix(".client")


def bundle(roots: dict[str, pathlib.Path], spec: pathlib.Path, out: pathlib.Path) -> None:
    parts = [PRELUDE]
    counter = 0
    for root_name, root in roots.items():
        folders = {root: root_name}
        service = ROOT_SERVICES.get(root_name)
        parent_expr = f'__services["{service}"]' if service else "nil"
        parts.append(f'local {root_name} = __inst("{root_name}", {parent_expr})')
        for path in sorted(root.rglob("*")):
            counter += 1
            var = f"__I[{counter}]"
            parent = folders[path.parent]
            if path.is_dir():
                folders[path] = var
                parts.append(f'{var} = __inst("{path.name}", {parent})')
            elif path.suffix == ".luau":
                source = path.read_text(encoding="utf-8")
                # Type exports are only legal at the top level of a real module.
                source = re.sub(r"^export type", "type", source, flags=re.M)
                parts.append(f'{var} = __inst("{instance_name(path)}", {parent})')
                parts.append(f"__loaders[{var}] = function(script)\n{source}\nend")
    parts.append(spec.read_text(encoding="utf-8"))
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("\n".join(parts), encoding="utf-8")
