#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/variant.hpp>

namespace godot {

/// Stable module identity for the AncientBuilding pipeline.
/// Static methods are bound so both GDScript hosts and tests share one implementation.
class ModuleKey : public RefCounted {
    GDCLASS(ModuleKey, RefCounted)

protected:
    static void _bind_methods();

public:
    /// Lowercase hex SHA-1 of the UTF-8 text (exposed for fixed-vector tests).
    static String sha1_hex(const String &p_text);

    /// Canonical JSON of a variant; floats are rejected by design.
    static String canonicalize(const Variant &p_value);

    /// "ab1_" + first 16 hex chars of sha1(canonical(payload)).
    static String make_key(const Variant &p_payload);
};

} // namespace godot
