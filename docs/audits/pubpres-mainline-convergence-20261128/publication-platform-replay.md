# Cross-platform original publication-reader repair

## Preserved failed publication preflight

[Publication attempt P1, run 46143088429](https://github.com/techrote/cybersand/actions/runs/46143088429), attempt 1, ran on source `a303299e59228363a229ae80bfce6746cbbfd771`. Its admission executed all 33 then-current Python tests successfully and the original local-evidence custody job independently reassembled the unchanged three archives. Publisher job 140973443808 stopped at 12:09:34 UTC on 28 November 2026 with `ValueError: Multipart native or Rapier bytes differ`.

The original stack passes through `replay_summary` into the unchanged `tools/pubpres_final_recovery/run_qualification.py` multipart reader. That reader selects its two library filenames using its module's `os.name`. Running the offline reader on Ubuntu while verifying a Windows artifact therefore selects the host's Linux filenames. The actual Windows application campaign had executed its reader on Windows.

The failed preflight occurred before all repository/native writes, LFS uploads and branch updates in the publisher. Independent API inspection confirmed the principal head remained `a303299e59228363a229ae80bfce6746cbbfd771`. Its [original failure artifact 15262511886](https://github.com/techrote/cybersand/actions/runs/46143088429/artifacts/15262511886) is 10,352 bytes, SHA-256 `8cd7944dc6351a5968bb6c0c4dccf6678707cee871c0f9f6d50e99c7be458204`. The failed attempt remains failed. The source ordering alone is not relabelled as a directly replayed observation of which previous platform loop completed.

## Narrow evidence-platform binding

The corrected publisher validates the authenticated target platform and temporarily replaces only the isolated imported legacy reader module's `os` lookup with a facade. Its `name` is the explicit target; all other attributes delegate to the previous binding. A `finally` block restores that exact previous binding, including nested or rejected replays. Global `os.name`, `pathlib`, host process behavior, original reader bytes and application/qualification fixtures are unchanged.

The native and Rapier digest comparisons still execute. No filename, expected digest, semantic assertion, source identity, artifact identity or qualification outcome is waived. The publisher now emits one bounded platform/focus/source/run/attempt progress record before each original graphical replay to make any subsequent refusal identifiable without losing the original report.

## Independent review and execution requirement

Specialist C authored the repair; the principal and presentation specialist independently compared it with the reviewed publisher. Three additional tests call the real original multipart reader against distinct Linux and Windows native/Rapier files. Correct target bytes must reach the unchanged refusal for the deliberately missing 72 observations; wrong native or Rapier digests must still refuse at the byte boundary. The synthetic unit fixture does not claim graphical or native execution. Nested exceptions and unknown target platforms test restoration of the module and global host state.

The new admission population is 36 tests and must execute before the retry can reach the writer. The original 26 required Q4 application jobs all completed successfully on `ff7a9e87b5d37fde66d4d932c9fa84cc0b3a4dae`; their source, receipts and outcomes are unchanged. Only the guarded publisher, its tests and dated audit documentation change. A successful retry still requires complete original native/application replay, exactly four published runtime paths, a leased ordinary fast-forward and fresh remote LFS retrieval. Final published-source Windows packaging and extracted execution remain separate requirements, and physical acceptance and mainline promotion remain HOLD.
