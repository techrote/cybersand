// Exercises the exact private pressure-column relay. The World pool itself is
// private; real jthreads test transport/drain ordering, healthy World head parity
// tests exercise its pool, and existing World capacity failures test quarantine.
void test_pressure_column_failure_relay() {
    using Failure = cybersand::pressure_column_detail::PressureColumnFailure;
    static_assert(std::is_trivially_copyable_v<Failure>);
    static_assert(noexcept(std::declval<Failure&>().capture([] {})));
    static_assert(Failure::kMessageBytes == 192U);
    Failure failure;
    failure.raise_if_present();

    const auto check_message = [&]<class Error>(Error error, Failure::Kind kind) {
        failure.capture([&] { throw error; });
        require(failure.kind == kind && !failure.truncated, "column failure retains its standard category");
        bool matched = false;
        try { failure.raise_if_present(); }
        catch (const Error& observed) {
            matched = std::string(observed.what()) == error.what();
        }
        require(matched, "owner reconstructs the standard column failure category and message");
    };
    check_message(std::length_error("column capacity"), Failure::Kind::Length);
    check_message(std::out_of_range("column index"), Failure::Kind::OutOfRange);
    check_message(std::invalid_argument("column input"), Failure::Kind::InvalidArgument);
    check_message(std::logic_error("column invariant"), Failure::Kind::Logic);
    check_message(std::runtime_error("column worker"), Failure::Kind::Runtime);
    failure.capture([] { throw std::bad_alloc{}; });
    bool allocation = false;
    try { failure.raise_if_present(); }
    catch (const std::bad_alloc&) { allocation = true; }
    require(allocation && failure.kind == Failure::Kind::BadAlloc, "bad_alloc is not converted to a runtime error");

    const std::string long_message(Failure::kMessageBytes + 32U, 'x');
    failure.capture([&] { throw std::runtime_error(long_message); });
    require(failure.truncated && failure.message.back() == '\0' &&
                std::string(failure.message.data()).size() == Failure::kMessageBytes - 1U &&
                std::string(failure.message.data()).ends_with(" [truncated]"),
            "long worker diagnostics are bounded, terminated and explicitly marked");
    struct CustomStandard : std::exception {
        const char* what() const noexcept override { return "custom standard failure"; }
    };
    failure.capture([] { throw CustomStandard{}; });
    require(failure.kind == Failure::Kind::Standard &&
                std::string(failure.message.data()) == "custom standard failure",
            "an otherwise unknown standard exception retains its diagnostic");
    bool standard = false;
    try { failure.raise_if_present(); }
    catch (const std::runtime_error& error) {
        standard = std::string(error.what()) == "custom standard failure";
    }
    require(standard, "unknown standard exception diagnostics reach the owner");
    failure.capture([] { throw 17; });
    bool unknown = false;
    try { failure.raise_if_present(); }
    catch (const std::runtime_error& error) {
        unknown = std::string(error.what()) == "Unknown exception in pressure column worker";
    }
    require(unknown && failure.kind == Failure::Kind::Unknown, "non-standard failures get a stable owner exception");
    failure.capture([] {});
    failure.raise_if_present();
    require(failure.kind == Failure::Kind::None && !failure.truncated && failure.message[0] == '\0',
            "a successful capture cannot replay an earlier failure");

    std::array<Failure, 4> tasks;
    std::atomic<unsigned> completed{0};
    const auto owner = std::this_thread::get_id();
    std::array<std::jthread, 2> workers;
    for (std::size_t worker = 0; worker < workers.size(); ++worker) {
        workers[worker] = std::jthread([&, worker] {
            for (std::size_t index = worker; index < tasks.size(); index += workers.size()) {
                tasks[index].capture([&] {
                    if (index == 0U) throw std::length_error("worker column capacity");
                });
                completed.fetch_add(1U, std::memory_order_relaxed);
            }
        });
    }
    for (auto& worker : workers) worker.join();
    bool owner_raised = false;
    try {
        for (const auto& task : tasks) task.raise_if_present();
    } catch (const std::length_error& error) {
        owner_raised = std::this_thread::get_id() == owner && completed.load() == tasks.size() &&
            std::string(error.what()) == "worker column capacity";
    }
    require(owner_raised, "a worker failure is raised by the owner only after every task drains");
}
