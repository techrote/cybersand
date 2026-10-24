#pragma once

#include <array>
#include <cstddef>
#include <cstdint>
#include <span>
#include <string>

namespace cybersand {

// FIPS 180-4 SHA-256 for construction-time identity (liquid policy hashes).
// Not used on tick paths; no allocation beyond the caller's buffers.
class Sha256 final {
public:
    using Digest = std::array<std::uint8_t, 32>;

    Sha256() noexcept { reset(); }

    void reset() noexcept {
        state_ = {0x6a09e667U, 0xbb67ae85U, 0x3c6ef372U, 0xa54ff53aU,
                  0x510e527fU, 0x9b05688cU, 0x1f83d9abU, 0x5be0cd19U};
        buffered_ = 0;
        length_ = 0;
    }

    void update(std::span<const std::uint8_t> bytes) noexcept {
        for (const auto byte : bytes) {
            buffer_[buffered_++] = byte;
            if (buffered_ == buffer_.size()) {
                compress();
                buffered_ = 0;
            }
        }
        length_ += static_cast<std::uint64_t>(bytes.size());
    }

    [[nodiscard]] Digest finish() noexcept {
        const auto bit_length = length_ * 8U;
        buffer_[buffered_++] = 0x80U;
        if (buffered_ > 56U) {
            while (buffered_ < buffer_.size()) buffer_[buffered_++] = 0U;
            compress();
            buffered_ = 0;
        }
        while (buffered_ < 56U) buffer_[buffered_++] = 0U;
        for (int shift = 56; shift >= 0; shift -= 8)
            buffer_[buffered_++] = static_cast<std::uint8_t>(bit_length >> shift);
        compress();
        Digest digest{};
        for (std::size_t i = 0; i < state_.size(); ++i) {
            for (std::size_t b = 0; b < 4U; ++b)
                digest[i * 4U + b] = static_cast<std::uint8_t>(state_[i] >> (24U - 8U * b));
        }
        reset();
        return digest;
    }

    [[nodiscard]] static Digest of(std::span<const std::uint8_t> bytes) noexcept {
        Sha256 hash;
        hash.update(bytes);
        return hash.finish();
    }

    [[nodiscard]] static std::string hex(const Digest& digest) {
        static constexpr char kDigits[] = "0123456789abcdef";
        std::string result(digest.size() * 2U, '0');
        for (std::size_t i = 0; i < digest.size(); ++i) {
            result[i * 2U] = kDigits[digest[i] >> 4U];
            result[i * 2U + 1U] = kDigits[digest[i] & 0x0fU];
        }
        return result;
    }

private:
    [[nodiscard]] static constexpr std::uint32_t rotr(std::uint32_t value, unsigned bits) noexcept {
        return (value >> bits) | (value << (32U - bits));
    }

    void compress() noexcept {
        static constexpr std::array<std::uint32_t, 64> kRound{
            0x428a2f98U, 0x71374491U, 0xb5c0fbcfU, 0xe9b5dba5U, 0x3956c25bU, 0x59f111f1U,
            0x923f82a4U, 0xab1c5ed5U, 0xd807aa98U, 0x12835b01U, 0x243185beU, 0x550c7dc3U,
            0x72be5d74U, 0x80deb1feU, 0x9bdc06a7U, 0xc19bf174U, 0xe49b69c1U, 0xefbe4786U,
            0x0fc19dc6U, 0x240ca1ccU, 0x2de92c6fU, 0x4a7484aaU, 0x5cb0a9dcU, 0x76f988daU,
            0x983e5152U, 0xa831c66dU, 0xb00327c8U, 0xbf597fc7U, 0xc6e00bf3U, 0xd5a79147U,
            0x06ca6351U, 0x14292967U, 0x27b70a85U, 0x2e1b2138U, 0x4d2c6dfcU, 0x53380d13U,
            0x650a7354U, 0x766a0abbU, 0x81c2c92eU, 0x92722c85U, 0xa2bfe8a1U, 0xa81a664bU,
            0xc24b8b70U, 0xc76c51a3U, 0xd192e819U, 0xd6990624U, 0xf40e3585U, 0x106aa070U,
            0x19a4c116U, 0x1e376c08U, 0x2748774cU, 0x34b0bcb5U, 0x391c0cb3U, 0x4ed8aa4aU,
            0x5b9cca4fU, 0x682e6ff3U, 0x748f82eeU, 0x78a5636fU, 0x84c87814U, 0x8cc70208U,
            0x90befffaU, 0xa4506cebU, 0xbef9a3f7U, 0xc67178f2U};
        std::array<std::uint32_t, 64> w{};
        for (std::size_t i = 0; i < 16U; ++i) {
            w[i] = (static_cast<std::uint32_t>(buffer_[i * 4U]) << 24U) |
                   (static_cast<std::uint32_t>(buffer_[i * 4U + 1U]) << 16U) |
                   (static_cast<std::uint32_t>(buffer_[i * 4U + 2U]) << 8U) |
                   static_cast<std::uint32_t>(buffer_[i * 4U + 3U]);
        }
        for (std::size_t i = 16; i < 64U; ++i) {
            const auto s0 = rotr(w[i - 15U], 7U) ^ rotr(w[i - 15U], 18U) ^ (w[i - 15U] >> 3U);
            const auto s1 = rotr(w[i - 2U], 17U) ^ rotr(w[i - 2U], 19U) ^ (w[i - 2U] >> 10U);
            w[i] = w[i - 16U] + s0 + w[i - 7U] + s1;
        }
        auto [a, b, c, d, e, f, g, h] = state_;
        for (std::size_t i = 0; i < 64U; ++i) {
            const auto t1 = h + (rotr(e, 6U) ^ rotr(e, 11U) ^ rotr(e, 25U)) +
                            ((e & f) ^ (~e & g)) + kRound[i] + w[i];
            const auto t2 = (rotr(a, 2U) ^ rotr(a, 13U) ^ rotr(a, 22U)) +
                            ((a & b) ^ (a & c) ^ (b & c));
            h = g; g = f; f = e; e = d + t1;
            d = c; c = b; b = a; a = t1 + t2;
        }
        state_[0] += a; state_[1] += b; state_[2] += c; state_[3] += d;
        state_[4] += e; state_[5] += f; state_[6] += g; state_[7] += h;
    }

    std::array<std::uint32_t, 8> state_{};
    std::array<std::uint8_t, 64> buffer_{};
    std::size_t buffered_ = 0;
    std::uint64_t length_ = 0;
};

}  // namespace cybersand
