#include "Core/theone_node.h"

#include <godot_cpp/core/class_db.hpp>

namespace godot {

void TheOneNode::_bind_methods() {
    ClassDB::bind_method(D_METHOD("get_build_info"), &TheOneNode::get_build_info);
}

String TheOneNode::get_build_info() const {
    return String("TheOne native extension");
}

} // namespace godot
