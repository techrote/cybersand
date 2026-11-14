"""Model-free adversarial regression for versioned SMOL terminal-EOS supervision.

Genuine pinned-upstream tokenizer / full TRAIN census remains a separate hosted
qualification gate; this mock does not claim that evidence.
"""
import sys
from pathlib import Path
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import SMOL_SUPERVISION_POLICY_V2, encode_row


class TemplateTokenizer:
    eos_token_id = 2
    eos_token = "<|im_end|>"

    def __init__(self, suffix="<|im_end|>\n", lf_id=198, prefix_drift=False,
                 retokenize_drift=False):
        self.suffix = suffix
        self.lf_id = lf_id
        self.prefix_drift = prefix_drift
        self.retokenize_drift = retokenize_drift

    def apply_chat_template(self, messages, tokenize=False, add_generation_prompt=False):
        prefix = "<|im_start|>system\n" + messages[0]["content"]
        prefix += "<|im_end|>\n<|im_start|>user\n" + messages[1]["content"]
        prefix += "<|im_end|>\n<|im_start|>assistant\n"
        if add_generation_prompt:
            return prefix
        if self.prefix_drift:
            prefix = prefix.replace("assistant", "changed-assistant")
        return prefix + messages[-1]["content"] + self.suffix

    def encode(self, text, add_special_tokens=False):
        assert not add_special_tokens
        ids = []
        i = 0
        while i < len(text):
            if text.startswith("<|im_end|>", i):
                ids.append(self.eos_token_id)
                i += len("<|im_end|>")
            elif text[i] == "\n":
                ids.append(self.lf_id)
                i += 1
            else:
                ids.append(ord(text[i]) + 500)
                i += 1
        if self.retokenize_drift and text.endswith("<|im_end|>"):
            ids[-2] += 1
        return ids


ROW = {"id": "g-1", "prompt": "Add greebles", "completion": '{"family":"greebles"}'}
SYSTEM = "Return only JSON."


class SmolEOSPolicyTests(unittest.TestCase):
    def render(self, tokenizer=None, row=None, max_length=4096, **kwargs):
        return encode_row(tokenizer or TemplateTokenizer(), row or ROW, SYSTEM, max_length,
                          supervision_policy=SMOL_SUPERVISION_POLICY_V2, **kwargs)

    def test_pinned_upstream_tail_exactly_excluded_and_masked_prefix_preserved(self):
        tok = TemplateTokenizer()
        result = self.render(tok)
        prefix = tok.apply_chat_template([{"role": "system", "content": SYSTEM},
                                          {"role": "user", "content": ROW["prompt"]}],
                                         add_generation_prompt=True)
        self.assertEqual(result["input_ids"][-1], 2)
        self.assertEqual(result["input_ids"][result["boundary"]:].count(2), 1)
        self.assertIn(2, result["input_ids"][:result["boundary"]])
        self.assertEqual(result["prefix_ids"], tok.encode(prefix))
        self.assertEqual(result["labels"][:result["boundary"]], [-100] * result["boundary"])
        self.assertEqual(result["labels"][result["boundary"]:], result["input_ids"][result["boundary"]:])
        self.assertEqual(result["supervision_policy"], SMOL_SUPERVISION_POLICY_V2)
        self.assertTrue(result["supervised_eos_terminal"])
        self.assertEqual(result["completion_bytes"], len(ROW["completion"].encode()))

    def test_legacy_custody_not_rewritten(self):
        row = encode_row(TemplateTokenizer(), ROW, SYSTEM, 4096)
        self.assertEqual(row["input_ids"][-2:], [2, 198])
        self.assertFalse(row["supervised_eos_terminal"])
        self.assertEqual(row["supervision_policy"], "legacy-eos-presence-v1")

    def test_fail_closed_for_other_template_tail(self):
        for suffix in ("<|im_end|>", "<|im_end|>\n\n",
                       "<|im_end|>extra\n", " [EOS]\n", "<|im_end|> \n"):
            with self.subTest(suffix=suffix), self.assertRaises(ValueError):
                self.render(TemplateTokenizer(suffix=suffix))

    def test_fail_closed_for_changed_lf_id_or_eos_identity(self):
        with self.assertRaises(ValueError):
            self.render(TemplateTokenizer(lf_id=201))
        tok = TemplateTokenizer()
        tok.eos_token_id = 99
        with self.assertRaises(ValueError):
            self.render(tok)

    def test_reject_extra_supervised_eos(self):
        with self.assertRaises(ValueError):
            self.render(row={**ROW, "completion": ROW["completion"] + "<|im_end|>"})

    def test_reject_prefix_and_retokenization_drift(self):
        for tok in (TemplateTokenizer(prefix_drift=True),
                    TemplateTokenizer(retokenize_drift=True)):
            with self.subTest(tok=type(tok).__name__), self.assertRaises(ValueError):
                self.render(tok)

    def test_no_truncation_or_implicit_policy(self):
        with self.assertRaises(ValueError):
            self.render(max_length=8)
        with self.assertRaises(ValueError):
            encode_row(TemplateTokenizer(), ROW, SYSTEM, 4096,
                       supervision_policy="unrecognized-policy")


if __name__ == "__main__":
    unittest.main()
