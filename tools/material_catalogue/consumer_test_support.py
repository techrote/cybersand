"""Copy B guard inputs into disposable roots; never regenerate tracked outputs."""
from pathlib import Path

import display_contract as contract
import legacy_display_names as legacy
import presentation


def copy_b_inputs(root: Path) -> None:
    source_root = contract.ROOT
    if root.resolve() == source_root.resolve() or root.resolve().is_relative_to(source_root.resolve()):
        raise ValueError("test input copies must be outside the task source checkout")
    paths = {p.relative_to(source_root).as_posix()
             for tree in contract.EXECUTABLE_ROOTS for p in (source_root / tree).rglob("*") if p.is_file()
             and p.suffix in contract.EXECUTABLE_SUFFIXES and
             ".godot" not in p.relative_to(source_root).parts}
    paths.update((*presentation.INPUTS, *presentation.OUTPUTS, str(legacy.FIXTURE)))
    for relative in paths:
        dest = root / relative
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes((source_root / relative).read_bytes())
    # These are prospective source-contract fixtures even while the parent is
    # freezing the actual legacy runtime. They never edit the real consumer.
    old_main = legacy.git_bytes(source_root, contract.MAIN).decode("utf-8")
    main = old_main.replace("extends Control\n", "extends Control\n\n" + contract.PRELOAD, 1)
    (root / contract.MAIN).write_text(main.replace(legacy.function(old_main, "material_name"), contract.METHOD, 1), encoding="utf-8")
    identity = legacy.git_bytes(source_root, contract.IDENTITY).decode("utf-8")
    (root / contract.IDENTITY).write_text(identity.replace(contract.IDENTITY_NEEDLE, contract.IDENTITY_NEEDLE + contract.IDENTITY_ENTRY), encoding="utf-8")
