"""Private intake registration for existing Architecture and Batch qualification.

These are the producer/reopen/render groups already invoked by batch_lab/qualify.py.
This does not add cases, reducers, fallback inputs or a general dependency system.
"""

from pathlib import Path


COMPONENTS = (
    ("stages", (
        "test_architecture_stage_native", "test_architecture_stage_reopen",
        "test_architecture_module_compositions", "test_architecture_stage_render",
    ), {
        "ARCHITECTURE_EVIDENCE_DIR": "architecture/stages",
        "ARCHITECTURE_MODULE_COMPOSITIONS_DIR": "architecture/stages",
    }),
    ("catalogue", (
        "test_native_module_catalogue_native", "test_native_module_catalogue_render",
        "test_architecture_collaborative_ui",
    ), {
        "NATIVE_CATALOGUE_EVIDENCE_DIR": "architecture/collaborative/catalogue",
        "NATIVE_CATALOGUE_RENDER_DIR": "architecture/collaborative/catalogue/rendered",
        "ARCHITECTURE_MODULE_CATALOGUE_DIR": "architecture/collaborative/catalogue",
        "ARCHITECTURE_COLLABORATIVE_UI_DIR": "architecture/collaborative/ui",
    }),
    ("flagships-and-gameplay", (
        "test_architecture_flagships_native", "test_architecture_flagships_render",
        "test_architecture_gameplay", "test_architecture_gameplay_reopen",
    ), {
        "ARCHITECTURE_FLAGSHIP_DIR": "architecture/collaborative/flagships",
        "ARCHITECTURE_GAMEPLAY_MANIFEST": "architecture/collaborative/flagships/flagships-native.json",
        "ARCHITECTURE_GAMEPLAY_EVIDENCE_DIR": "architecture/collaborative/gameplay",
    }),
    ("hierarchy", (
        "test_architecture_hierarchy_native", "test_architecture_hierarchy_reopen",
        "test_architecture_hierarchy_render",
    ), {
        "ARCHITECTURE_HIERARCHY_DIR": "architecture/collaborative/hierarchy",
    }),
    ("comparison", ("test_architecture_comparison",), {
        "ARCHITECTURE_COMPARISON_DIR": "architecture/comparison",
    }),
    ("composition-comparison", ("test_architecture_composition_comparison",), {
        "M67_COMPARISON_EVIDENCE_DIR": "architecture/collaborative/comparison",
    }),
    ("detail", ("test_native_detail_jobs_native",), {
        "NATIVE_DETAIL_EVIDENCE_DIR": "architecture/collaborative/detail",
    }),
    ("batch-provider-workbench", ("test_batch_lab_provider", "test_batch_lab_workbench"), {}),
    ("batch-ui", ("test_batch_lab_ui",), {
        "BATCH_LAB_EVIDENCE_DIR": "batch/ui",
    }),
)

# The dedicated Batch driver shares a profile across provider -> mounted editor,
# while retaining the original processes' separate evidence directories.
_BATCH_PROCESS_EVIDENCE = {
    "test_batch_lab_provider": "batch/provider-protocol",
    "test_batch_lab_workbench": "batch/workbench",
}

DEPENDENCIES = {
    "test_architecture_stage_reopen": ("test_architecture_stage_native",),
    "test_architecture_stage_render": ("test_architecture_stage_native", "test_architecture_module_compositions"),
    "test_native_module_catalogue_render": ("test_native_module_catalogue_native",),
    "test_architecture_collaborative_ui": ("test_native_module_catalogue_native",),
    "test_architecture_flagships_render": ("test_architecture_flagships_native",),
    "test_architecture_gameplay": ("test_architecture_flagships_native",),
    "test_architecture_gameplay_reopen": ("test_architecture_gameplay",),
    "test_architecture_hierarchy_reopen": ("test_architecture_hierarchy_native",),
    "test_architecture_hierarchy_render": ("test_architecture_hierarchy_native",),
    "test_batch_lab_workbench": ("test_batch_lab_provider",),
}

GRAPHICAL_CASES = frozenset({
    "test_architecture_stage_render", "test_native_module_catalogue_render",
    "test_architecture_flagships_render", "test_architecture_gameplay",
    "test_architecture_gameplay_reopen", "test_architecture_collaborative_ui",
    "test_architecture_hierarchy_render",
    "test_batch_lab_ui",
    # The overlay compares ImageTexture pixels on both supported desktop renderers.
    "test_object_shard_m4_overlay_identity",
})


def windows_applicable(case) -> bool:
    """Retain the Windows scope, admitting only these existing graphical gates."""
    return not case.requires_display or case.name in GRAPHICAL_CASES


def scheduling_units(cases):
    """Keep registered components whole and in their declared process order."""
    by_name = {case.name: case for case in cases}
    registered = {}
    for _component, names, _paths in COMPONENTS:
        present = set(names) & by_name.keys()
        if present and present != set(names):
            raise RuntimeError("Incomplete Architecture context component; missing=" + str(sorted(set(names) - present)))
        for name in names:
            registered[name] = names
    units = []
    seen = set()
    for case in cases:
        if case.name in seen:
            continue
        names = registered.get(case.name, (case.name,))
        units.append([by_name[name] for name in names])
        seen.update(names)
    return units


def prepare_contexts(cases, output: Path) -> dict[str, dict[str, str]]:
    """Create fresh directories only; producers must create every input file."""
    scheduling_units(cases)  # Refuse a missing producer before creating context.
    selected = {case.name for case in cases}
    active = [(component, names, paths) for component, names, paths in COMPONENTS if selected.intersection(names)]
    if not active:
        return {}
    root = output.resolve() / "architecture-context"
    # A reused shard directory must never let a failed producer consume an old
    # successful run's manifests or authored starts.
    root.mkdir(exist_ok=False)
    contexts = {}
    for component, names, paths in active:
        profile = root / "userdata" / component
        overrides = {name: str(root / relative) for name, relative in paths.items()}
        overrides.update({"APPDATA": str(profile / "appdata"),
                          "LOCALAPPDATA": str(profile / "localappdata"),
                          "XDG_DATA_HOME": str(profile / "xdg-data")})
        for name, value in overrides.items():
            path = Path(value)
            (path.parent if name == "ARCHITECTURE_GAMEPLAY_MANIFEST" else path).mkdir(parents=True, exist_ok=True)
        for name in names:
            if name not in selected:
                continue
            contexts[name] = dict(overrides)
            if name in _BATCH_PROCESS_EVIDENCE:
                directory = root / _BATCH_PROCESS_EVIDENCE[name]
                directory.mkdir(parents=True, exist_ok=True)
                contexts[name]["BATCH_LAB_EVIDENCE_DIR"] = str(directory)
    return contexts


def failed_dependencies(name: str, results: list[dict]) -> list[str]:
    statuses = {row["name"]: row.get("status") for row in results if row.get("role") == "case"}
    return [producer for producer in DEPENDENCIES.get(name, ()) if statuses.get(producer) != "passed"]
