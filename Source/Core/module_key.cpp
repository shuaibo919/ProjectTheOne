#include "Core/module_key.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/error_macros.hpp>

#include "Common/canonical.h"
#include "Common/sha1.h"

using namespace godot;

void ModuleKey::_bind_methods() {
    ClassDB::bind_static_method("ModuleKey", D_METHOD("sha1_hex", "text"), &ModuleKey::sha1_hex);
    ClassDB::bind_static_method("ModuleKey", D_METHOD("canonicalize", "value"), &ModuleKey::canonicalize);
    ClassDB::bind_static_method("ModuleKey", D_METHOD("make_key", "payload"), &ModuleKey::make_key);
}

String ModuleKey::sha1_hex(const String &p_text) {
    return theone::Sha1Hex(p_text);
}

String ModuleKey::canonicalize(const Variant &p_value) {
    String error;
    const String out = theone::Canonicalize(p_value, &error);
    if (!error.is_empty()) {
        ERR_PRINT(error);
    }
    return out;
}

String ModuleKey::make_key(const Variant &p_payload) {
    const String canonical = canonicalize(p_payload);
    if (canonical.is_empty()) {
        return String();
    }
    return String("ab1_") + theone::Sha1Hex(canonical).substr(0, 16);
}
