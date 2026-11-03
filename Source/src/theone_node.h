#pragma once

#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/variant/string.hpp>

namespace godot {

/// Minimal native node used to prove the GDExtension pipeline end to end.
class TheOneNode : public Node {
    GDCLASS(TheOneNode, Node)

protected:
    static void _bind_methods();

public:
    TheOneNode() = default;
    ~TheOneNode() override = default;

    String get_build_info() const;
};

} // namespace godot