"""B3 isolated negative-control oracle: does not import the production or B3 model.

Exact structural control for a prepare/commit source witness. This is deliberately
not a worker, native or physical-hash test. Standard-library only.
"""
from dataclasses import dataclass, replace


@dataclass(frozen=True)
class Source:
    identity: str
    owner: str
    amount: int
    revision: int
    overfill: int
    velocity: tuple[int, int]
    body_id: int


def full_source(s: Source) -> tuple:
    return (s.identity, s.owner, s.amount, s.revision,
            s.overfill, tuple(s.velocity), s.body_id)


def legacy_guard(original: Source, current: Source) -> bool:
    return ((original.revision, original.owner, original.amount) ==
            (current.revision, current.owner, current.amount))


def revised_guard(prepared_source_tuple: tuple, current: Source) -> bool:
    return prepared_source_tuple == full_source(current)


def main() -> None:
    source = Source("water-0", "freemass", 256, 7, 0, (0, 0), 0)
    snapshot = full_source(source)
    assert legacy_guard(source, source) and revised_guard(snapshot, source)
    trials = 0
    for dx in range(-32, 33):
        for dy in range(-32, 33):
            if dx == dy == 0:
                continue
            current = replace(source, velocity=(dx, dy))
            assert legacy_guard(source, current)  # deliberately unsafe control
            assert not revised_guard(snapshot, current)
            trials += 1
    for body in (1, 2, 7, 64):
        current = replace(source, body_id=body)
        assert legacy_guard(source, current)
        assert not revised_guard(snapshot, current)
        trials += 1
    # A typed resource guard cannot replace World/producer authority.
    # Returning to the identical value erases evidence of intermediate writes.
    restored = replace(replace(source, velocity=(1, 0)), velocity=(0, 0))
    assert revised_guard(snapshot, restored)  # documented ABA limitation
    # A non-committing refusal leaves the source/destination record ledger unchanged.
    record_set = {source.identity: source}
    before = dict(record_set)
    altered = replace(source, velocity=(100, -20))
    if not revised_guard(snapshot, altered):
        pass  # explicit refusal path; no write
    assert record_set == before
    print(f"PASS {trials} same-revision source drift refusals; "
          "one unchanged source admission; one deliberate ABA non-detection; "
          "no state mutation")


if __name__ == "__main__":
    main()
