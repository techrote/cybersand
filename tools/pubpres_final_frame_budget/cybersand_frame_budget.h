#pragma once

#include <atomic>
#include <cstdint>
#include <cmath>

// Experimental Main/render-owner rendezvous, not a physics or GPU clock.
// One Main producer owns every field except the explicitly atomic completion
// token/fault flag. The render owner publishes a token only AFTER its actual
// draw function returns. No old token can retire commands appended behind it:
// the caller must execute the original queue barrier before another draw.
namespace cybersand_pubpres {

class FrameBudget {
public:
	static constexpr uint32_t MAX_DEFERRED_TURNS = 4;

private:
	std::atomic<uint64_t> completed_serial{ 0 };
	std::atomic<bool> completion_fault{ false };
	uint64_t submitted_serial = 0;
	uint64_t deferred_total = 0;
	uint32_t deferred_since_draw = 0;
	uint32_t maximum_deferred_since_draw = 0;
	double deferred_render_step = 0.0;
	double total_deferred_render_step = 0.0;
	double total_consumed_render_step = 0.0;

public:
	// Main only. This does not consume or produce any physical-step credit,
	// reset the budget when a token arrives, or enqueue another rendering job.
	bool defer_if_pending(bool p_allowed, double p_render_step = 0.0) {
		if (!p_allowed || !std::isfinite(p_render_step) || p_render_step < 0.0 ||
				completion_fault.load(std::memory_order_acquire) ||
				submitted_serial == 0 ||
				completed_serial.load(std::memory_order_acquire) >= submitted_serial ||
				deferred_since_draw >= MAX_DEFERRED_TURNS) {
			return false;
		}
		deferred_render_step += p_render_step;
		total_deferred_render_step += p_render_step;
		++deferred_since_draw;
		++deferred_total;
		if (deferred_since_draw > maximum_deferred_since_draw) {
			maximum_deferred_since_draw = deferred_since_draw;
		}
		return true;
	}

	// Main only, immediately before a real draw admission. The rasterizer uses
	// frame_step for shader/particle time; skipped opportunities must not erase
	// elapsed render time. This never changes any physical-step clock.
	double consume_render_step(double p_current_step) {
		const double carried = deferred_render_step;
		deferred_render_step = 0.0;
		total_consumed_render_step += carried;
		return p_current_step + carried;
	}

	// Main only, at an actual draw admission after the existing queue barrier.
	// RenderingServer's manual/forced-draw entry must drain too when the arm is
	// active. Only that actual draw replenishes the bounded producer allowance.
	uint64_t begin_draw() {
		++submitted_serial;
		deferred_since_draw = 0;
		return submitted_serial;
	}

	// Render-owner only, after the corresponding _draw has actually returned.
	// An unexpected/out-of-order/duplicate token permanently refuses further
	// deferral. The caller still performs the original synchronization path.
	void complete_draw(uint64_t p_serial) {
		const uint64_t previous = completed_serial.load(std::memory_order_relaxed);
		if (p_serial == 0 || p_serial != previous + 1) {
			completion_fault.store(true, std::memory_order_release);
			return;
		}
		completed_serial.store(p_serial, std::memory_order_release);
	}

	// Main observations only. A token is render-owner CPU completion, not a
	// fence proving GPU completion or a physical monitor's presentation time.
	uint64_t submitted() const { return submitted_serial; }
	uint64_t completed() const { return completed_serial.load(std::memory_order_acquire); }
	uint64_t deferrals() const { return deferred_total; }
	uint32_t current_budget_spent() const { return deferred_since_draw; }
	uint32_t max_budget_spent() const { return maximum_deferred_since_draw; }
	double pending_render_step() const { return deferred_render_step; }
	double deferred_render_step_total() const { return total_deferred_render_step; }
	double consumed_render_step_total() const { return total_consumed_render_step; }
	bool faulted() const { return completion_fault.load(std::memory_order_acquire); }
};

} // namespace cybersand_pubpres
