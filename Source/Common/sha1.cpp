#include "Common/sha1.h"

#include <cstdint>
#include <vector>

namespace theone {
namespace {

inline uint32_t RotateLeft(uint32_t p_value, int p_bits) {
    return (p_value << p_bits) | (p_value >> (32 - p_bits));
}

void ProcessBlock(const uint8_t *p_block, uint32_t p_state[5]) {
    uint32_t w[80];
    for (int i = 0; i < 16; ++i) {
        w[i] = (static_cast<uint32_t>(p_block[i * 4]) << 24) |
                (static_cast<uint32_t>(p_block[i * 4 + 1]) << 16) |
                (static_cast<uint32_t>(p_block[i * 4 + 2]) << 8) |
                static_cast<uint32_t>(p_block[i * 4 + 3]);
    }
    for (int i = 16; i < 80; ++i) {
        w[i] = RotateLeft(w[i - 3] ^ w[i - 8] ^ w[i - 14] ^ w[i - 16], 1);
    }

    uint32_t a = p_state[0];
    uint32_t b = p_state[1];
    uint32_t c = p_state[2];
    uint32_t d = p_state[3];
    uint32_t e = p_state[4];

    for (int i = 0; i < 80; ++i) {
        uint32_t f = 0;
        uint32_t k = 0;
        if (i < 20) {
            f = (b & c) | ((~b) & d);
            k = 0x5A827999u;
        } else if (i < 40) {
            f = b ^ c ^ d;
            k = 0x6ED9EBA1u;
        } else if (i < 60) {
            f = (b & c) | (b & d) | (c & d);
            k = 0x8F1BBCDCu;
        } else {
            f = b ^ c ^ d;
            k = 0xCA62C1D6u;
        }
        const uint32_t temp = RotateLeft(a, 5) + f + e + k + w[i];
        e = d;
        d = c;
        c = RotateLeft(b, 30);
        b = a;
        a = temp;
    }

    p_state[0] += a;
    p_state[1] += b;
    p_state[2] += c;
    p_state[3] += d;
    p_state[4] += e;
}

} // namespace

godot::String Sha1Hex(const godot::String &p_text) {
    const godot::CharString utf8 = p_text.utf8();
    const uint8_t *data = reinterpret_cast<const uint8_t *>(utf8.get_data());
    const size_t length = static_cast<size_t>(utf8.length());

    std::vector<uint8_t> message(data, data + length);
    const uint64_t bit_length = static_cast<uint64_t>(length) * 8u;

    message.push_back(0x80);
    while (message.size() % 64 != 56) {
        message.push_back(0x00);
    }
    for (int i = 7; i >= 0; --i) {
        message.push_back(static_cast<uint8_t>((bit_length >> (i * 8)) & 0xFF));
    }

    uint32_t state[5] = {
        0x67452301u,
        0xEFCDAB89u,
        0x98BADCFEu,
        0x10325476u,
        0xC3D2E1F0u,
    };

    for (size_t offset = 0; offset < message.size(); offset += 64) {
        ProcessBlock(message.data() + offset, state);
    }

    godot::String out;
    for (uint32_t word : state) {
        godot::String hex = godot::String::num_int64(static_cast<int64_t>(word), 16, false);
        // NOTE: String::pad_zeros() is unreliable for hex strings ("a9993e36" -> 9 chars).
        while (hex.length() < 8) {
            hex = godot::String("0") + hex;
        }
        out += hex;
    }
    return out;
}

} // namespace theone
