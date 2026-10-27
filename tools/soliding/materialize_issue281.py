"""One-shot, exact-source patch assembly on the isolated #281 branch.

The final branch contains ordinary source changes, not a runtime patch loader.
This script refuses source drift, never pushes main, and removes itself and the
assembly-only workflow before its reviewed source changes are committed.
"""
from pathlib import Path
import re
import subprocess

BASE = "c9ebe39c6cab086b7f7207ee3d80a6de2cb21f59"
ROOT = Path(__file__).resolve().parents[2]


def source(path: str) -> str:
    current = (ROOT / path).read_text(encoding="utf-8")
    frozen = subprocess.check_output(["git", "show", f"{BASE}:{path}"], cwd=ROOT).decode()
    if current != frozen:
        raise RuntimeError(f"Refusing unreviewed source drift: {path}")
    return current


def once(text: str, old: str, new: str) -> str:
    if text.count(old) != 1:
        raise RuntimeError(f"Expected one exact patch anchor: {old[:100]!r}")
    return text.replace(old, new, 1)


def guard(text: str, method: str, code: str) -> str:
    pattern = r"\bWorld::" + re.escape(method) + r"\([^)]*\)(?:\s*(?:const|noexcept))*\s*\{"
    matches = list(re.finditer(pattern, text, flags=re.S))
    if len(matches) != 1:
        raise RuntimeError(f"Expected one method definition for {method}, got {len(matches)}")
    at = matches[0].end()
    return text[:at] + "\n    " + code + text[at:]


header = source("native/include/cybersand/world.hpp")
header = once(header, "#pragma once", '#pragma once\n\n#include "cybersand/solid_detachment.hpp"')
public = '''    // SOL-DETACH-001/A1: experimental one-aggregate native ownership kernel.
    // Exclusive owner only. Main-thread physics must remain separately fenced
    // until a source/geometry-bound contact receipt has been finalized.
    [[nodiscard]] soliding::SolidOutcome configure_solid_detachment(soliding::SolidLimits limits = {});
    [[nodiscard]] soliding::SolidOutcome prepare_solid_detachment(const soliding::SolidRequest& request);
    [[nodiscard]] soliding::SolidOutcome acknowledge_solid_detachment(const soliding::SolidBodyReservation& body);
    [[nodiscard]] soliding::SolidOutcome commit_solid_detachment(soliding::SolidToken token);
    [[nodiscard]] soliding::SolidOutcome finalize_solid_detachment(const soliding::SolidCollisionReceipt& receipt);
    [[nodiscard]] soliding::SolidOutcome cancel_solid_detachment(soliding::SolidToken token);
    [[nodiscard]] soliding::SolidOutcome rollback_solid_detachment(soliding::SolidToken token);
    [[nodiscard]] soliding::SolidOutcome complete_solid_rollback(const soliding::SolidCollisionReceipt& receipt);
    [[nodiscard]] bool solid_detachment_fenced() const noexcept;
    [[nodiscard]] soliding::SolidSnapshot inspect_solid_detachment() const noexcept;
    [[nodiscard]] std::size_t solid_detachment_storage_bytes() const noexcept;
    [[nodiscard]] std::size_t copy_solid_detachment_members(std::span<soliding::SolidMember> output) const noexcept;
    [[nodiscard]] std::size_t copy_solid_detachment_shapes(std::span<soliding::SolidShape> output) const noexcept;

'''
header = once(header, "    [[nodiscard]] TickStats tick();", public + "    [[nodiscard]] TickStats tick();")
header = once(header, "    WorldConfig config_;", '''    std::unique_ptr<soliding::SolidStore> solid_detachment_;
    void require_solid_mutation_allowed() const;
    WorldConfig config_;''')

cpp = source("native/src/world.cpp")
# Fail BEFORE existing writes/allocation. Getters/render extraction remain usable
# while staged: the bridge needs the post-commit terrain to repair collision.
for method in ("set_with_quantity_kind", "set_temperature", "paint_disc", "reserve_region",
               "reserve_temperature_region", "set_simulation_region", "configure_transient_obstacles",
               "clear_transient_obstacles", "tick", "install_generated_chunk"):
    cpp = guard(cpp, method, "require_solid_mutation_allowed();")
for method in ("set_cell_state", "set_transient_obstacle", "relocate_stored_cell", "queue_explosion"):
    cpp = guard(cpp, method, "if (solid_detachment_fenced()) return false;")
cpp = guard(cpp, "apply_player_material_field", "if (solid_detachment_fenced()) return {};")
cpp = guard(cpp, "set_liquid_surface_adhesion_enabled", "if (solid_detachment_fenced()) return;")
# Explicit whole-World reset is allowed; old token/body epochs must be retired by
# the owning host. An attempted clear during an executing tick still refuses.
cpp = once(cpp,
    '    if (tick_in_progress_) throw std::logic_error("cannot clear during a world tick");',
    '    if (tick_in_progress_) throw std::logic_error("cannot clear during a world tick");\n    solid_detachment_.reset();')
cpp = once(cpp, "}  // namespace cybersand", '#include "world_solid_detachment.inc"\n\n}  // namespace cybersand')

pressure = source("native/src/world_pressure.inc")
# No unversioned aggregate omission from a claimed complete physical state.
for method in ("save_physical_state", "physical_state_hash_impl"):
    pressure = guard(pressure, method, '''if (solid_detachment_ && solid_detachment_->snapshot.phase != soliding::SolidPhase::Idle)
        throw std::logic_error("solid aggregate/transaction is not serializable in CYPS2/3");''')

makefile = source("Makefile")
makefile += '''
# SOL-DETACH-001 experimental native ownership (real World, not the Stage-2 model).
.PHONY: solid-detachment-test solid-detachment-sanitize
$(BUILD_DIR)/test_solid_detachment: $(CORE_SOURCES) $(CORE_HEADERS) native/tests/test_solid_detachment.cpp | $(BUILD_DIR)
\t$(CXX) $(COMMON_FLAGS) $(DEBUG_FLAGS) -pthread $(CORE_SOURCES) native/tests/test_solid_detachment.cpp -o $@
solid-detachment-test: $(BUILD_DIR)/test_solid_detachment
\t./$(BUILD_DIR)/test_solid_detachment
$(BUILD_DIR)/test_solid_detachment_sanitized: $(CORE_SOURCES) $(CORE_HEADERS) native/tests/test_solid_detachment.cpp | $(BUILD_DIR)
\t$(CXX) $(COMMON_FLAGS) -O1 -g -fno-omit-frame-pointer -fsanitize=address,undefined -pthread $(CORE_SOURCES) native/tests/test_solid_detachment.cpp -o $@
solid-detachment-sanitize: $(BUILD_DIR)/test_solid_detachment_sanitized
\tASAN_OPTIONS=detect_leaks=0 UBSAN_OPTIONS=halt_on_error=1 ./$(BUILD_DIR)/test_solid_detachment_sanitized
'''
# Integrate the executable into ordinary native regression without inventing a
# pass for the substantially larger sanitizer/Godot publication matrix.
makefile = once(makefile, "\nsoliding-test: ", "\nsoliding-test: $(BUILD_DIR)/test_solid_detachment ")
makefile = once(makefile, "\n\t./$(BUILD_DIR)/test_soliding_lifecycle\n", "\n\t./$(BUILD_DIR)/test_solid_detachment\n\t./$(BUILD_DIR)/test_soliding_lifecycle\n")

for path, text in {
    "native/include/cybersand/world.hpp": header,
    "native/src/world.cpp": cpp,
    "native/src/world_pressure.inc": pressure,
    "Makefile": makefile,
}.items():
    (ROOT / path).write_text(text, encoding="utf-8")
    print("assembled", path)
# The source assembler is a one-shot branch tool, not shipped runtime behavior.
(ROOT / ".github/workflows/sol281-assemble.yml").unlink()
Path(__file__).unlink()
