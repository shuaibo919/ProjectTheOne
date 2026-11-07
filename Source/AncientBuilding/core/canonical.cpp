#include "AncientBuilding/core/canonical.h"

#include <algorithm>
#include <utility>
#include <vector>

#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>

namespace theone {
namespace {

godot::String Quote(const godot::String &p_text) {
    godot::String out = "\"";
    for (int i = 0; i < p_text.length(); ++i) {
        const char32_t c = p_text[i];
        switch (c) {
            case '"':
                out += "\\\"";
                break;
            case '\\':
                out += "\\\\";
                break;
            case '\b':
                out += "\\b";
                break;
            case '\f':
                out += "\\f";
                break;
            case '\n':
                out += "\\n";
                break;
            case '\r':
                out += "\\r";
                break;
            case '\t':
                out += "\\t";
                break;
            default:
                if (c < 0x20) {
                    godot::String escape = godot::String::num_int64(static_cast<int64_t>(c), 16, false);
                    while (escape.length() < 4) {
                        escape = godot::String("0") + escape;
                    }
                    out += godot::String("\\u") + escape;
                } else {
                    out += godot::String::chr(static_cast<int32_t>(c));
                }
                break;
        }
    }
    out += "\"";
    return out;
}

void Fail(godot::String *r_error, const godot::String &p_message) {
    if (r_error != nullptr && r_error->is_empty()) {
        *r_error = p_message;
    }
}

} // namespace

godot::String Canonicalize(const godot::Variant &p_value, godot::String *r_error) {
    switch (p_value.get_type()) {
        case godot::Variant::NIL:
            return "null";
        case godot::Variant::BOOL:
            return static_cast<bool>(p_value) ? "true" : "false";
        case godot::Variant::INT:
            return godot::String::num_int64(static_cast<int64_t>(p_value));
        case godot::Variant::FLOAT:
            Fail(r_error, "float values must be quantized to int before hashing");
            return godot::String();
        case godot::Variant::STRING:
        case godot::Variant::STRING_NAME:
            return Quote(godot::String(p_value));
        case godot::Variant::ARRAY: {
            const godot::Array array = p_value;
            godot::String out = "[";
            for (int i = 0; i < array.size(); ++i) {
                if (i > 0) {
                    out += ",";
                }
                out += Canonicalize(array[i], r_error);
                if (r_error != nullptr && !r_error->is_empty()) {
                    return godot::String();
                }
            }
            out += "]";
            return out;
        }
        case godot::Variant::DICTIONARY: {
            const godot::Dictionary dict = p_value;
            const godot::Array keys = dict.keys();
            std::vector<std::pair<godot::String, godot::Variant>> items;
            items.reserve(static_cast<size_t>(keys.size()));
            for (int i = 0; i < keys.size(); ++i) {
                items.emplace_back(godot::String(keys[i]), keys[i]);
            }
            std::sort(items.begin(), items.end(),
                    [](const std::pair<godot::String, godot::Variant> &a,
                            const std::pair<godot::String, godot::Variant> &b) {
                        return a.first < b.first;
                    });
            godot::String out = "{";
            for (size_t i = 0; i < items.size(); ++i) {
                if (i > 0) {
                    out += ",";
                }
                out += Quote(items[i].first);
                out += ":";
                out += Canonicalize(dict[items[i].second], r_error);
                if (r_error != nullptr && !r_error->is_empty()) {
                    return godot::String();
                }
            }
            out += "}";
            return out;
        }
        default:
            Fail(r_error, godot::String("unsupported variant type in canonical form: ") +
                            godot::String::num_int64(static_cast<int64_t>(p_value.get_type())));
            return godot::String();
    }
}

} // namespace theone
