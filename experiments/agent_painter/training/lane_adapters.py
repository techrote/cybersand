"""Fixed, reviewed model adapters. Importing this module does not import Torch.

No profile can select an arbitrary Python module or execute downloaded code.
Model-specific framing and trainable boundaries are part of checkpoint identity.
"""
from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

from common import ROOT, SHA256, read_json, sha256_file


SUPPORTED = {
    "smol": ("HuggingFaceTB/SmolLM2-135M-Instruct", "LlamaForCausalLM", "AutoModelForCausalLM"),
    "void": ("dotlabs/void.1", "Qwen3ForCausalLM", "Qwen3ForCausalLM"),
    "sprocket": ("kandivault/sprocket-500m", "LlamaForCausalLM", "AutoModelForCausalLM"),
    "lfm25_vl": ("LiquidAI/LFM2.5-VL-450M", "Lfm2VlForConditionalGeneration", "Lfm2VlForConditionalGeneration"),
}
HOOKS = ("load_base", "encode_row", "encode_prompt", "validate_trainable", "set_training_mode")


def validate_profile(name, selected):
    expected = SUPPORTED.get(name)
    actual = tuple(selected.get(key) for key in ("model_id", "architecture", "loader"))
    if expected is None or actual != expected or selected.get("trust_remote_code") is not False:
        raise ValueError(f"{name}: reviewed model adapter required; no generic loader fallback")
    hashes = selected.get("required_hashes", {})
    if not hashes or any(not isinstance(value, str) or not SHA256.fullmatch(value)
                         or Path(key).name != key or key in (".", "..")
                         for key, value in hashes.items()):
        raise ValueError("every required root model file needs a reviewed SHA-256")
    targets = selected.get("lora_targets")
    if not isinstance(targets, (list, str)) or not targets:
        raise ValueError("model-specific LoRA targets are required")
    if name != "smol":
        owned = ROOT / "lanes" / name / "profile.json"
        if not owned.is_file() or read_json(owned) != selected:
            raise ValueError("shared and lane-owned model profiles differ")


def lane_name(selected):
    matches = [name for name, values in SUPPORTED.items() if selected.get("model_id") == values[0]]
    if len(matches) != 1:
        raise ValueError("unregistered model adapter")
    validate_profile(matches[0], selected)
    return matches[0]


def adapter_for(selected):
    name = lane_name(selected)
    if name == "smol":
        return None
    module_name = "_cybersand_painter_" + name
    if module_name not in sys.modules:
        directory = ROOT / "lanes" / name
        spec = importlib.util.spec_from_file_location(
            module_name, directory / "adapter.py", submodule_search_locations=[str(directory)])
        module = importlib.util.module_from_spec(spec)
        sys.modules[module_name] = module
        try:
            spec.loader.exec_module(module)
            if not all(callable(getattr(module, hook, None)) for hook in HOOKS):
                raise ValueError("reviewed adapter does not implement the complete protocol")
        except BaseException:
            sys.modules.pop(module_name, None)
            raise
    return sys.modules[module_name]


def adapter_identity(selected):
    name = lane_name(selected)
    files = {"training/lane_adapters.py": sha256_file(__file__)}
    if name != "smol":
        directory = ROOT / "lanes" / name
        for path in sorted(directory.rglob("*")):
            if path.is_file() and (path.suffix == ".py" or path.name == "profile.json"):
                files[path.relative_to(ROOT).as_posix()] = sha256_file(path)
    return {"schema_version": 1, "lane": name, "source_files": files,
            "framing": selected.get("framing", "upstream-chat-template")}


def encode_prompt(tokenizer, prompt, system, selected):
    adapter = adapter_for(selected)
    if adapter:
        return adapter.encode_prompt(tokenizer, prompt, system)
    messages = [{"role": "system", "content": system}, {"role": "user", "content": prompt}]
    prefix = tokenizer.apply_chat_template(messages, tokenize=False, add_generation_prompt=True)
    return tokenizer.encode(prefix, add_special_tokens=False)
