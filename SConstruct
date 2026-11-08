#!/usr/bin/env python
"""ProjectTheOne GDExtension build.

Each directory under Source/ (except Common) becomes its own extension library:
its own DLL, its own .gdextension descriptor and its own entry symbol.
Common/ is shared source compiled into every module.
"""
import os

custom_api_file = os.path.join("Source", "build_api", "extension_api.json")
if os.path.isfile(custom_api_file):
    ARGUMENTS.setdefault("custom_api_file", custom_api_file)
else:
    ARGUMENTS.setdefault("api_version", "4.7")

env = SConscript("EngineAdaptor/SConstruct")

# Force MSVC English output: avoids GBK mojibake in terminals.
env["ENV"]["VSLANG"] = "1033"

env = env.Clone()
env.Append(CPPPATH=["Source/"])

common_sources = Glob("Source/Common/*.cpp")
modules = [
    ("theone_core", Glob("Source/Core/*.cpp")),
    ("ancient_building", Glob("Source/AncientBuilding/*.cpp")),
]

for name, sources in modules:
    library = env.SharedLibrary(
        "Project/bin/{}{}{}".format(name, env["suffix"], env.subst("$SHLIBSUFFIX")),
        source=sources + common_sources,
    )
    Default(library)