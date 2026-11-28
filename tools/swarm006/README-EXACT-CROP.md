# SWARM-006 exact-crop comparison (Draft/HOLD)

This read-only Windows PowerShell tool performs a **paired native preview-only comparison** from the author's saved Workbench v2 setup. It never changes, uploads or applies the user's original JSON or native World.

The owner file contains 1,646 five-field rectangle stamps confined to x=4..606, y=4..235. The fixed target crop x=800, y=400, width=192, height=112 is entirely blank in that saved authored setup. Replaying the rectangles into the crop and comparing both native requests ensures exactly the same source material and masks; using a different crop reconstructs authored materials in stamp order.

Run this on the user's Windows machine with their extracted, SHA-verified SWARM-006 owner candidate (commit 4e8ff0b01043d9e1bed336559b17e37283094add):

    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\compare_saved_setup.ps1 -Setup "$HOME\Downloads\setup-swarm-006-smoketest.json"

The script locates the exact SWARM006 owner generator under Downloads, verifies its compiled SHA256, and runs 3 expressions × 2 SWARM005 switch combinations × 2 recovery settings = **12 actual native requests**, producing six matched pairs. To compare only the two SWARM005 switches OFF, specify "-Swarm005Options off".

All native request fields other than versioned recovery controls are identical *within each pair*: origin, 192×112, seed605, 2 rounds, FRAME left / MOSAIC right, border4, reach13, shared ownership ON, optional negotiation ON, orientation Balanced, 0 decorations and destruction, one activation point at crop local (96,56), identical source native material IDs and independent expression profiles.

Output directory: paired-results.csv, all-cases.csv, comparison-manifest.json, same-source-native-crop.le16 and all native request/response files/logs. Exhausted results are not falsely classified as zero unresolved obligations. No native proposal is applied.

**Important limitation:** this is a strict native-input comparison of the saved *authored* setup. It is not a pixel capture of the transient live World and is not new preregistered science or physical owner NVIDIA acceptance. GitHub CI independently uses an empty synthetic setup, not the private uploaded file. No user data is uploaded.
