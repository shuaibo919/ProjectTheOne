#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/string.hpp>

namespace godot {

/// Minimal class that proves the ancient_building extension loaded independently.
class AncientBuildingModule : public RefCounted {
    GDCLASS(AncientBuildingModule, RefCounted)

protected:
    static void _bind_methods();

public:
    String get_version() const;
};

} // namespace godot