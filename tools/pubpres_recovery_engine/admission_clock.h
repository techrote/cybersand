#pragma once

#include <cmath>
#include <cstdint>

namespace cybersand_pubpres {

// Main only. A refused application transaction is not a draw and cannot earn
// render-owner completion credit. Keep its elapsed rendering time as a scalar;
// queued canvas/resource commands are still drained by the real sync barrier.
class AdmissionClock {
	double pending_step = 0.0;
	double rejected_total_step = 0.0;
	double consumed_total_step = 0.0;
	uint64_t rejected_count = 0;

public:
	void reject(double p_step) {
		if (std::isfinite(p_step) && p_step >= 0.0) {
			pending_step += p_step;
			rejected_total_step += p_step;
		}
		++rejected_count;
	}
	double consume() {
		const double result = pending_step;
		pending_step = 0.0;
		consumed_total_step += result;
		return result;
	}
	double pending() const { return pending_step; }
	double rejected_steps() const { return rejected_total_step; }
	double consumed_steps() const { return consumed_total_step; }
	uint64_t rejections() const { return rejected_count; }
};

} // namespace cybersand_pubpres
