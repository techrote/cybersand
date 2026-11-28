#include "admission_clock.h"
#include "../pubpres_final_frame_budget/cybersand_frame_budget.h"
#include <cassert>
#include <cmath>
#include <limits>

int main() {
	using namespace cybersand_pubpres;
	AdmissionClock admission;
	FrameBudget draw;
	assert(admission.consume() == 0 && draw.submitted() == 0);
	const uint64_t first = draw.begin_draw();
	for (int i = 0; i < 4; ++i) assert(draw.defer_if_pending(true, .01));
	assert(!draw.defer_if_pending(true, .01));
	draw.complete_draw(first); // real queue barrier still required by caller
	admission.reject(.02);
	admission.reject(.03);
	assert(draw.submitted() == 1 && draw.completed() == 1);
	assert(draw.current_budget_spent() == 4); // refusal never replenishes it
	assert(std::abs(admission.pending() - .05) < 1e-12);
	assert(std::abs(draw.pending_render_step() - .04) < 1e-12);
	const double elapsed = draw.consume_render_step(.06 + admission.consume());
	assert(std::abs(elapsed - .15) < 1e-12);
	assert(admission.pending() == 0 && draw.pending_render_step() == 0);
	assert(admission.rejections() == 2);
	assert(admission.consumed_steps() == admission.rejected_steps());
	assert(draw.begin_draw() == 2 && draw.current_budget_spent() == 0);
	admission.reject(std::numeric_limits<double>::quiet_NaN());
	admission.reject(-1);
	assert(admission.pending() == 0 && admission.rejections() == 4);
}
