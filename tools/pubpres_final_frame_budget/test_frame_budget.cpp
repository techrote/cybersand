#include "cybersand_frame_budget.h"

#include <atomic>
#include <cstdlib>
#include <limits>
#include <iostream>
#include <thread>

using cybersand_pubpres::FrameBudget;

static void require(bool value, const char *message) {
	if (!value) {
		std::cerr << message << '\n';
		std::exit(1);
	}
}

int main() {
	// An empty queue, disabled owner, or exhausted producer allowance cannot
	// supply a new draw, physics callback, or an endlessly renewable skip.
	FrameBudget gate;
	require(!gate.defer_if_pending(true), "No draw may not grant deferral");
	require(gate.begin_draw() == 1, "First actual draw identity");
	for (int index = 0; index < 100; ++index) {
		require(!gate.defer_if_pending(false), "A disabled owner changed scheduling");
	}
	for (int index = 0; index < 4; ++index) {
		require(gate.defer_if_pending(true), "Outstanding actual draw lost allowance");
	}
	for (int index = 0; index < 100; ++index) {
		require(!gate.defer_if_pending(true), "Producer batch became unbounded");
	}
	gate.complete_draw(1);
	require(!gate.defer_if_pending(true), "Completed old marker renewed allowance");
	require(gate.current_budget_spent() == 4, "Completion token silently reset batch");
	require(gate.begin_draw() == 2, "Only actual next draw renews allowance");
	require(gate.defer_if_pending(true), "New actual draw did not admit producer turn");
	gate.complete_draw(2);
	require(gate.deferrals() == 5 && gate.max_budget_spent() == 4, "Ledger differs from actual admissions");

	// Arbitrary completion arrival points (including no arrival until the
	// original barrier) preserve the same hard cap across successive draws.
	for (int arrival = 0; arrival <= 8; ++arrival) {
		FrameBudget schedule;
		for (uint64_t serial = 1; serial <= 120; ++serial) {
			require(schedule.begin_draw() == serial, "Draw identity did not advance once");
			unsigned admitted = 0;
			for (int turn = 0; turn < 8; ++turn) {
				if (turn == arrival) {
					schedule.complete_draw(serial);
				}
				admitted += schedule.defer_if_pending(true) ? 1 : 0;
			}
			if (arrival == 8) {
				schedule.complete_draw(serial);
			}
			require(admitted <= 4 && schedule.completed() == serial, "Arrival schedule exceeded bound or lost real completion");
		}
	}

	// A malformed producer never hides an older/out-of-order render token by
	// accepting a new apparently plausible one. Refusal stays permanent.
	for (uint64_t bad : { uint64_t(0), uint64_t(2), uint64_t(1000) }) {
		FrameBudget broken;
		broken.begin_draw();
		broken.complete_draw(bad);
		require(broken.faulted() && !broken.defer_if_pending(true), "Malformed completion did not fail closed");
		broken.complete_draw(1);
		broken.begin_draw();
		require(!broken.defer_if_pending(true), "Later token erased permanent completion fault");
	}
	FrameBudget duplicate;
	duplicate.begin_draw();
	duplicate.complete_draw(1);
	duplicate.begin_draw();
	duplicate.complete_draw(1);
	require(duplicate.faulted() && !duplicate.defer_if_pending(true), "Duplicate old token authorized later work");

	// Four deferred opportunities conserve all elapsed rendering time. The
	// fifth Main producer turn reaches the original barrier and a real draw.
	// Completion alone does not consume shader/particle time or renew credit.
	FrameBudget timing;
	timing.begin_draw();
	double total_offered = 0.0, total_applied = 0.0;
	for (uint64_t serial = 1; serial <= 150; ++serial) {
		for (int turn = 0; turn < 4; ++turn) {
			const double delta = 0.013 + double(turn) / 1000.0;
			require(timing.defer_if_pending(true, delta), "Pending draw refused valid elapsed render time");
			total_offered += delta;
		}
		require(!timing.defer_if_pending(true, 1.0), "Exhausted opportunity consumed extra time");
		timing.complete_draw(serial);
		require(timing.pending_render_step() > 0.0, "Completion lost carried render delta");
		total_offered += 0.017;
		total_applied += timing.consume_render_step(0.017);
		require(timing.pending_render_step() == 0.0, "Actual draw did not consume render delta once");
		timing.begin_draw();
	}
	require(std::abs(total_offered - total_applied) < 1e-10, "Shader/particle elapsed time was dropped or duplicated");
	require(std::abs(timing.deferred_render_step_total() - timing.consumed_render_step_total()) < 1e-10,
			"Deferred render time ledger did not conserve elapsed time");
	for (double bad : { -1.0, std::numeric_limits<double>::infinity(), std::numeric_limits<double>::quiet_NaN() }) {
		require(!timing.defer_if_pending(true, bad), "Invalid render delta admitted deferral");
	}

	// Real cross-thread release/acquire publication: Main may inspect state
	// only after the render owner has published completion of that draw.
	FrameBudget concurrent;
	std::atomic<uint64_t> queued{ 0 };
	std::atomic<bool> stop{ false };
	uint64_t rendered_payload = 0;
	std::thread renderer([&]() {
		uint64_t next = 1;
		while (!stop.load(std::memory_order_acquire)) {
			if (queued.load(std::memory_order_acquire) == next) {
				rendered_payload = next * 17;
				concurrent.complete_draw(next);
				++next;
			} else {
				std::this_thread::yield();
			}
		}
	});
	for (uint64_t serial = 1; serial <= 4000; ++serial) {
		require(concurrent.begin_draw() == serial, "Main producer serial");
		queued.store(serial, std::memory_order_release);
		unsigned admitted = 0;
		while (concurrent.completed() != serial) {
			admitted += concurrent.defer_if_pending(true) ? 1 : 0;
			std::this_thread::yield();
		}
		require(admitted <= 4 && rendered_payload == serial * 17, "Completion did not publish its actual render-owner work");
	}
	stop.store(true, std::memory_order_release);
	renderer.join();
	require(!concurrent.faulted() && concurrent.submitted() == concurrent.completed(), "Unretired or fabricated draw at shutdown");
	std::cout << "FrameBudget: bounded Main turns, old-token refusal, forced sequence and4000 real cross-thread publications PASS; no physical or GPU credit\n";
}
