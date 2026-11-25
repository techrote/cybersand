# Independent review: retained first corrected-delivery Windows failure

The first corrected-delivery campaign failed. Source `3a0ec3659f23d8e997e6721aa754d5a8ebe48512`, tree `99394ad1133b4796efa0b95eb31dfa5c7bdbbaaf`, ran in [45553413100](https://github.com/techrote/cybersand/actions/runs/45553413100). Its source-decision and Linux jobs passed; Windows job `138999860117` failed the retained displayed native gate. The nine new Windows cases, package construction and pristine extracted launcher were skipped. No corrected Windows evaluator was produced by this attempt.

## Exact observed failure

The unchanged native test reported **151 checks, one failure**. Its first sparse-polygon progress was **2187 ms**, independently violating the strict `first_progress_ms < 2000` term. The full assertion is `art.active and first_progress_ms < 2000`; the log does not separately print `art.active` at that instant. Both the earlier acknowledged-native-receipt check and first displayed sparse-pixel check passed. This observation is a retained performance failure, not proof that all native work failed.

The original native stdout is 7,679 bytes, SHA-256 `6bc12fa1a4630bdcd610211a7288f587b8ce5a279577e4cd57b5723ba56df4a0`. Original stderr is 357 bytes, SHA-256 `e1a1b666c3696e58abfdb7aaaf105827d335243ab758f4d00a3f6e9df8edbc16`.

## Independent custody and comparison

The original [Windows evidence artifact 14995049040](https://github.com/techrote/cybersand/actions/runs/45553413100/artifacts/14995049040) was independently rehashed and fully CRC-checked: **4,393,990 bytes**, SHA-256 `195829a172f0fb91f7b92cad1efe6618e33daf397c2df52b7d9cbdd23d4a1f94`. The decoded job-log API text was also retained locally and hashed separately.

The reducer read the actual earlier Windows evidence archives. e536 recorded **1693 ms / 151 checks / zero failures**; bcc recorded **1363 ms / 151 checks / zero failures**. These are separate hosted observations, not randomized matched trials or a reproducibility-rate estimate. Exact Git comparison confirms bcc-to-3a equality for the failed Godot test, raster plan, native executor and workflow. The delivery correction did change its packaging unit tests; no claim of equality for every repository test is made.

This review neither changes the two-second gate nor attributes a cause. A later pass would be a separate exact-source qualification result and would not erase this negative or establish a universal latency guarantee.

Only the derived [identity/counter record](3a-first-attempt-independent-review.json) and [read-only reducer](3a-first-attempt-independent-reducer.py) are published here. Raw downloaded artifacts and decoded logs remain local; no new raw aggregate is uploaded or rerouted. The original Actions artifact above remains the authoritative external evidence.
