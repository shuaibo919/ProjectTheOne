#!/usr/bin/env python
"""ProjectTheOne GDExtension build.

Prefers the API dumped from our own engine fork (Source/build_api/extension_api.json,
regenerate with `godot --headless --dump-extension-api`). Falls back to godot-cpp's
bundled 4.7 snapshot when the dump is absent.
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
env.Append(CPPPATH=["Source/src/"])

sources = Glob("Source/src/*.cpp")

library = env.SharedLibrary(
    "Project/bin/theone{}{}".format(env["suffix"], env.subst("$SHLIBSUFFIX")),
    source=sources,
)

Default(library)