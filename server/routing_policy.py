"""Compact Jev contract: model, effort, lease and mandatory-frontier policy."""
import math

POLICY_VERSION = "split-v17-gpt6-luna-sol-astra"
LUNA, SOL, ASTRA = "gpt-6-luna", "gpt-6.1-sol", "gpt-6-astra"
# Compatibility alias: the retired Terra tier resolves to the current Sol.
TERRA = SOL
TIERS = (LUNA, SOL, ASTRA)
PREVIOUS_SOL = "gpt-6-sol"
NATIVE_MODELS = (*TIERS, PREVIOUS_SOL)
EFFORTS = ["low", "medium", "high", "xhigh", "max"]
LEASES = ("one_call", "tool_chain", "user_turn")

MODEL_IDS = {"luna": LUNA, "sol": SOL, "astra": ASTRA}
ASTRA_POLICY = {
    "astra": (
        "Remaining work is project architecture, independent final code review, or "
        "risk-focused review of security, auth/permissions, concurrency, migrations, "
        "public API compatibility or material performance risks. "
        "A good checkpoint score never waives a required final/risk review."
    ),
    "normal": (
        "Implementation, tests, routine in-progress quality checkpoints, score comparison, "
        "fixing established findings, administration or reporting. "
        "No remaining final/risk review or architecture. Review wording alone is insufficient."
    ),
}
MODEL_PROFILES = {
    "luna": (
        "GPT-6 Luna: focused low-risk work: mechanical edits in one or "
        "several files, known-pattern bug fixes, simple checks/tests, provided-information "
        "explanations, short summaries or formatting. New diagnosis or unresolved "
        "trade-offs need Sol; clear acceptance is not a known fix."
    ),
    "sol": (
        "GPT-6.1 Sol: near-Astra capability for complex coding, refactors, multi-step tool work, "
        "new diagnosis, complex tests and substantial research/synthesis. Prefer when "
        "sufficient outside mandatory Astra policy. "
        "File count alone does not require Sol."
    ),
    "astra": (
        "GPT-6 Astra: Intermittent or concurrency failures with material risk, distributed "
        "consistency, production safety review, hardest ambiguous investigations or unresolved "
        "substantive Sol fixes after verifying inputs/access."
    ),
}
DEPTH_PROFILES = {
    "low": "Known mechanical action; no unresolved interpretation or investigation.",
    "medium": "Bounded interpretation, several considerations or normal implementation.",
    "high": "Substantial debugging, safety analysis, architecture or trade-offs.",
    "xhigh": "Extended difficult investigation or broad synthesis.",
    "max": "Rare hardest case needing exhaustive reasoning.",
}
LEASE_PROFILES = {
    "one_call": (
        "Re-evaluate after this response; the next action may change capability, risk or depth."
    ),
    "tool_chain": (
        "Reuse only for clean continuations of the same tool. Another tool, error, compaction "
        "or user turn ends it."
    ),
    "user_turn": (
        "This user turn is predictably uniform; reuse across clean tool continuations. "
        "Errors, compaction or a new user turn end it."
    ),
}

# Jev is deliberately given small, literal decisions rather than cross-product
# options. System One evaluates independent questions over the same state in one
# request; code combines the typed answers afterwards.
QUESTIONS = {
    "astra_policy": {
        "type": "choice",
        "instructions": (
            "Classify work still required for this call using task and latest intent/results. "
            "Do not inherit a completed phase's category or classify quoted evidence."
        ),
        "criteria": ASTRA_POLICY,
    },
    "model": {
        "type": "choice",
        "instructions": (
            "For remaining work, minimize total cost incl corrections/clarification; choose the "
            "least costly sufficient tier. Cache is secondary after capability fit: "
            "prefer a recent prefix-compatible hot model only when saved input is material "
            "and cost is close; a hot prior tier alone cannot justify keeping it. "
            "Warming has no read; stale_prefix is ineligible. "
            "Cache cannot cap capability. Use `recent_route_failure`: transport reason is not "
            "capability proof; count is same-turn attempts. Repeated substantive fixes may "
            "need a stronger tier; missing access/info requires repair. Effort cannot replace capability."
        ),
        "criteria": MODEL_PROFILES,
    },
    "effort": {
        "type": "choice",
        "instructions": (
            "Independently of model, choose sufficient reasoning depth; stronger models need not use higher effort."
        ),
        "criteria": DEPTH_PROFILES,
    },
    "lease": {
        "type": "choice",
        "instructions": (
            "Choose the longest safe lease for uniform work; re-evaluate likely phase changes."
        ),
        "criteria": LEASE_PROFILES,
    },
}


def route_choice(model, effort, astra_required=False, lease="one_call"):
    """Typed fixture/caller answer for a known route."""
    model_choice = next((key for key, value in MODEL_IDS.items() if value == model), None)
    if model_choice is None or effort not in EFFORTS or lease not in LEASES:
        raise ValueError("invalid model/effort/lease route")
    return {
        "astra_policy": "astra" if astra_required else "normal",
        "model": model_choice,
        "effort": effort,
        "lease": lease,
    }


def route(tier, depth, conf=None, step=None):
    """Apply a valid Jev pair verbatim; confidence and step type are observations."""
    if tier not in TIERS or depth not in EFFORTS:
        raise ValueError("invalid model/effort pair")
    return tier, depth, "default", "apply"


def _validated_choice(answers, name, choices):
    """Validate one Choice answer and its optional probability distribution."""
    answer = answers.get(name) if isinstance(answers, dict) else None
    if not isinstance(answer, dict):
        raise ValueError(f"missing {name} decision")
    choice = answer.get("choice")
    if not isinstance(choice, str) or choice not in choices:
        raise ValueError(f"unknown {name} choice")
    probabilities = answer.get("probabilities")
    if probabilities is not None:
        if not isinstance(probabilities, dict) or set(probabilities) != set(choices):
            raise ValueError(f"incomplete {name} distribution")
        values = list(probabilities.values())
        if any(
            isinstance(p, bool)
            or not isinstance(p, (int, float))
            or not math.isfinite(p)
            or not 0 <= p <= 1
            for p in values
        ):
            raise ValueError(f"invalid {name} probabilities")
        if abs(sum(values) - 1) > 0.02 or probabilities[choice] < max(values) - 1e-6:
            raise ValueError(f"inconsistent {name} distribution")
    confidence = answer.get("confidence")
    if (
        isinstance(confidence, bool)
        or not isinstance(confidence, (int, float))
        or not math.isfinite(confidence)
        or not 0 <= confidence <= 1
    ):
        confidence = None
    return choice, probabilities, confidence


def decision_from_answers(answers):
    """Validate Jev's decisions and enforce mandatory Astra categories."""
    astra_policy, astra_probs, astra_conf = _validated_choice(
        answers, "astra_policy", ASTRA_POLICY
    )
    model_choice, model_probs, model_conf = _validated_choice(
        answers, "model", MODEL_IDS
    )
    effort, effort_probs, effort_conf = _validated_choice(
        answers, "effort", EFFORTS
    )
    lease, lease_probs, lease_conf = _validated_choice(
        answers, "lease", LEASE_PROFILES
    )
    confidences = [
        value for value in (astra_conf, model_conf, effort_conf, lease_conf)
        if value is not None
    ]
    chosen_probabilities = [
        probabilities[choice]
        for probabilities, choice in (
            (astra_probs, astra_policy),
            (model_probs, model_choice),
            (effort_probs, effort),
            (lease_probs, lease),
        )
        if probabilities is not None
    ]
    selected_model = ASTRA if astra_policy == "astra" else MODEL_IDS[model_choice]
    return {
        "model": selected_model,
        "base_model": MODEL_IDS[model_choice],
        "astra_policy": astra_policy,
        "effort": effort,
        "lease": lease,
        "speed": "default",
        "gate": "astra_policy" if astra_policy == "astra" else "apply",
        # Conservative diagnostics: the weakest independent judgment.
        "confidence": min(confidences) if confidences else None,
        "probabilities": {
            "astra_policy": astra_probs,
            "model": model_probs,
            "effort": effort_probs,
            "lease": lease_probs,
        },
        "chosen_probability": min(chosen_probabilities) if chosen_probabilities else None,
        "policy_version": POLICY_VERSION,
    }
