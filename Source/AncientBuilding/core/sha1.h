#pragma once

#include <godot_cpp/variant/string.hpp>

namespace theone {

/// Lowercase hex SHA-1 of the UTF-8 bytes of `p_text`.
godot::String Sha1Hex(const godot::String &p_text);

} // namespace theone
