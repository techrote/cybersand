// Private to pressure preparation and its native regression. Included after the
// standard array/new/exception headers; contains no exception ownership or heap
// storage. One value lives in each already-reserved HeadColumnTask.
namespace pressure_column_detail {
struct PressureColumnFailure {
    enum class Kind : std::uint8_t {
        None, BadAlloc, Length, OutOfRange, InvalidArgument, Logic, Runtime, Standard, Unknown
    };
    static constexpr std::size_t kMessageBytes = 192;
    Kind kind = Kind::None;
    bool truncated = false;
    std::array<char, kMessageBytes> message{};

    void record(Kind category, const char* text) noexcept {
        kind = category;
        if (text == nullptr) text = "Pressure column worker exception without a message";
        std::size_t count = 0;
        while (count + 1U < message.size() && text[count] != '\0') {
            message[count] = text[count];
            ++count;
        }
        message[count] = '\0';
        truncated = text[count] != '\0';
        if (truncated) {
            constexpr char marker[] = " [truncated]";
            const auto start = message.size() - sizeof(marker);
            for (std::size_t i = 0; i < sizeof(marker); ++i) message[start + i] = marker[i];
        }
    }

    template<class Prepare>
    void capture(Prepare&& prepare) noexcept {
        kind = Kind::None;
        truncated = false;
        message[0] = '\0';
        try { prepare(); }
        catch (const std::bad_alloc& error) { record(Kind::BadAlloc, error.what()); }
        catch (const std::length_error& error) { record(Kind::Length, error.what()); }
        catch (const std::out_of_range& error) { record(Kind::OutOfRange, error.what()); }
        catch (const std::invalid_argument& error) { record(Kind::InvalidArgument, error.what()); }
        catch (const std::logic_error& error) { record(Kind::Logic, error.what()); }
        catch (const std::runtime_error& error) { record(Kind::Runtime, error.what()); }
        catch (const std::exception& error) { record(Kind::Standard, error.what()); }
        catch (...) { record(Kind::Unknown, "Unknown exception in pressure column worker"); }
    }

    // Owner-only, after the pool's full dispatch barrier. Exception construction
    // may allocate here; never in the noexcept relay. bad_alloc retains its
    // category; a custom bad_alloc subclass's what() is not reconstructed.
    void raise_if_present() const {
        switch (kind) {
            case Kind::None: return;
            case Kind::BadAlloc: throw std::bad_alloc{};
            case Kind::Length: throw std::length_error(message.data());
            case Kind::OutOfRange: throw std::out_of_range(message.data());
            case Kind::InvalidArgument: throw std::invalid_argument(message.data());
            case Kind::Logic: throw std::logic_error(message.data());
            case Kind::Runtime: throw std::runtime_error(message.data());
            case Kind::Standard: throw std::runtime_error(message.data());
            case Kind::Unknown: throw std::runtime_error(message.data());
        }
        throw std::runtime_error("Invalid pressure column worker failure category");
    }
};
} // namespace pressure_column_detail
