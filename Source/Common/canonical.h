#pragma once

#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/variant.hpp>

namespace theone {

/// Canonical JSON: object keys sorted, no whitespace, floats rejected.
/// Returns an empty string and fills `r_error` when the value cannot be canonicalized.
godot::String Canonicalize(const godot::Variant &p_value, godot::String *r_error = nullptr);

} // namespace theone
