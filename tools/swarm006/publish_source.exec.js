// @exec: {"yield_time_ms": 1000, "max_output_tokens": 2000}
// Run through functions.exec after the coordinator declares the native tree
// frozen. This is an operator helper, not browser or Node application code.
// Set both values explicitly; merely reading this file publishes nothing.
const manifestPath = "/ABSOLUTE/PUBLICATION/DIRECTORY/manifest.json";
const frozenTreeApprovedForPublication = false;
if (!frozenTreeApprovedForPublication) throw new Error("Freeze coordination is required before publication");

const quote = value => "'" + String(value).replace(/'/g, "'\\''") + "'";
async function localJSON(code, args) {
  const result = await tools.exec_command({
    cmd: "python3 -c " + quote(code) + " " + args.map(quote).join(" "),
    max_output_tokens: 10000, yield_time_ms: 10000
  });
  if (result.exit_code !== 0) throw new Error("Local publication object read/write failed: " + result.output);
  return result.output.trim() ? JSON.parse(result.output) : null;
}
async function readASCII(path) {
  const size = await localJSON("import json,pathlib,sys;print(json.dumps(pathlib.Path(sys.argv[1]).stat().st_size))", [path]);
  if (!Number.isSafeInteger(size) || size < 0 || size > 12 * 1024 * 1024) throw new Error("Unbounded publication input");
  let value = "";
  for (let offset = 0; offset < size; offset += 8192) {
    value += await localJSON("import json,sys\nwith open(sys.argv[1],'rb') as stream:\n stream.seek(int(sys.argv[2]));print(json.dumps(stream.read(8192).decode('ascii')))", [path, offset]);
  }
  return value;
}
function payload(result) {
  if (result.isError) throw new Error(JSON.stringify(result.structuredContent || result.content));
  let value = result.structuredContent;
  if (value && typeof value.content === "string") value = JSON.parse(value.content);
  if (!value) {
    const content = (result.content || []).find(item => item.type === "text");
    if (!content) throw new Error("Missing GitHub result payload");
    value = JSON.parse(content.text);
  }
  return value;
}
const manifest = JSON.parse(await readASCII(manifestPath));
if (manifest.schema !== 1 || manifest.programme !== "GENTEK-SWARM-006" || manifest.draft_hold !== true ||
    manifest.repository_full_name !== "techrote/cybersand" ||
    !/^experiment\/gentek-swarm-006-(native|workbench)-recovery$/.test(manifest.branch)) {
  throw new Error("Unrecognized publication manifest or branch");
}
const repository = manifest.repository_full_name;
const api = "https://api.github.com/repos/" + repository;
const get = async suffix => payload(await tools.mcp__codex_apps__github_fetch({url: api + suffix}));
const firstParent = await get("/git/commits/" + manifest.first_parent_sha);
if (firstParent.tree.sha !== manifest.first_parent_tree_sha) throw new Error("Verified first-parent tree differs remotely");
for (const sha of manifest.additional_parent_shas) {
  const parent = await get("/git/commits/" + sha);
  if (parent.sha !== sha) throw new Error("Frozen native additional parent is unavailable");
}
const refs = await get("/git/matching-refs/heads/" + manifest.branch);
const existing = refs.find(ref => ref.ref === "refs/heads/" + manifest.branch);
if (existing ? existing.object.sha !== manifest.expected_remote_head : manifest.expected_remote_head !== null) {
  throw new Error("Remote branch differs from the manifest lease; inspect without overwriting it");
}
if (manifest.expected_remote_head !== null && manifest.first_parent_sha !== manifest.expected_remote_head) {
  throw new Error("Existing SWARM006 branch must advance from its leased first parent");
}
// Only changed blobs are sent. Independent uploads are bounded to four at a
// time; every response is checked against Git's original exact blob identity.
for (let offset = 0; offset < manifest.blobs.length; offset += 4) {
  const batch = manifest.blobs.slice(offset, offset + 4);
  const outcomes = await Promise.allSettled(batch.map(async blob => {
    const content = await readASCII(blob.base64_file);
    if (content.length !== blob.base64_chars) throw new Error("Local blob encoding length changed");
    const uploaded = payload(await tools.mcp__codex_apps__github_create_blob({repository_full_name: repository, encoding: "base64", content}));
    if (uploaded.sha !== blob.sha) throw new Error("Uploaded source blob differs: " + blob.sha);
    return blob.sha;
  }));
  const errors = outcomes.filter(result => result.status === "rejected");
  if (errors.length) throw new Error(errors.map(result => String(result.reason)).join("\n"));
  notify({stage: "verified_changed_blobs", completed: Math.min(offset + 4, manifest.blobs.length), total: manifest.blobs.length});
}
const elements = manifest.changed_paths.map(entry => ({path: entry.path, mode: entry.mode, type: entry.type, sha: entry.sha}));
const tree = payload(await tools.mcp__codex_apps__github_create_tree({repository_full_name: repository,
  base_tree_sha: manifest.first_parent_tree_sha, tree_elements: elements}));
if (tree.sha !== manifest.expected_tree_sha) throw new Error("Remote source tree differs from frozen local tree; no ref was changed");
const created = payload(await tools.mcp__codex_apps__github_create_commit({repository_full_name: repository,
  parent_sha: manifest.first_parent_sha, additional_parent_shas: manifest.additional_parent_shas,
  tree_sha: tree.sha, message: manifest.message}));
const remote = await get("/git/commits/" + created.sha);
const expectedParents = [manifest.first_parent_sha, ...manifest.additional_parent_shas];
if (remote.tree.sha !== manifest.expected_tree_sha || JSON.stringify(remote.parents.map(p => p.sha)) !== JSON.stringify(expectedParents)) {
  throw new Error("Remote commit does not retain exact source tree and ordered ancestry; no ref was changed");
}
const receipt = {schema: 1, programme: manifest.programme, draft_hold: true, branch: manifest.branch,
  local_preparation_commit: manifest.local_target_commit, published_commit: remote.sha,
  exact_tree: remote.tree.sha, ordered_parents: expectedParents, ref_published: false,
  qualification: "pending on returned remote SHA"};
const receiptPath = manifestPath.replace(/manifest\.json$/, "publication-receipt.json");
async function saveReceipt() {
  store("swarm006-publication-" + manifest.lane, receipt);
  await localJSON("import json,pathlib,sys;pathlib.Path(sys.argv[1]).write_text(json.dumps(json.loads(sys.argv[2]),indent=2)+'\\n')", [receiptPath, JSON.stringify(receipt)]);
}
await saveReceipt();
notify({stage: "exact_remote_commit_created", ...receipt});
if (!existing) {
  payload(await tools.mcp__codex_apps__github_create_branch({repository_full_name: repository,
    branch_name: manifest.branch, sha: manifest.first_parent_sha}));
}
payload(await tools.mcp__codex_apps__github_update_ref({repository_full_name: repository,
  branch_name: manifest.branch, sha: remote.sha, force: false,
  expected_sha: manifest.expected_remote_head || manifest.first_parent_sha}));
const finalRefs = await get("/git/matching-refs/heads/" + manifest.branch);
const finalRef = finalRefs.find(ref => ref.ref === "refs/heads/" + manifest.branch);
if (!finalRef || finalRef.object.sha !== remote.sha) throw new Error("Ref publication was not observed; inspect before any retry");
receipt.ref_published = true;
await saveReceipt();
text(receipt);
