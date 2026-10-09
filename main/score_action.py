import re
import sys

def _clamp01(x: float) -> float:
    return max(0.0, min(1.0, float(x)))


# ACTIONS table

ACTIONS: dict[str, dict] = {
    "act_respond": {
        "efficiency": 1.00,
        "accuracy": lambda cx: _clamp01(1.00 - 1.10 * cx),
        "success_moderate": lambda cx: _clamp01(0.80 - 0.20 * cx),
        "knowledge": lambda cx: _clamp01(0.28 + 0.18 * cx),
        "novelty": lambda cx: _clamp01(0.18 + 0.10 * cx),
        "success_breakthrough": lambda cx: _clamp01(0.18 + 0.12 * cx),
        "coherence": lambda cx: _clamp01(0.72 - 0.10 * cx),
        "originality": lambda cx: _clamp01(0.16 + 0.10 * cx),
        "social": lambda cx: _clamp01(0.74 + 0.08 * (1.0 - cx)),
        "help_short": lambda cx: _clamp01(0.95 - 0.20 * cx),
        "help_long": lambda cx: _clamp01(0.25 + 0.20 * cx),
        "over_beneficial": lambda cx: _clamp01(0.45 - 0.15 * cx),
        "over_safety": lambda cx: _clamp01(0.45 - 0.20 * cx),
        "over_honesty": 0.60,
    },
    "act_clarify": {
        "efficiency": 0.65,
        "accuracy": lambda cx: _clamp01(0.55 + 0.25 * cx),
        "success_moderate": 0.72,
        "knowledge": lambda cx: _clamp01(0.45 + 0.20 * cx),
        "novelty": lambda cx: _clamp01(0.28 + 0.12 * cx),
        "success_breakthrough": lambda cx: _clamp01(0.28 + 0.12 * cx),
        "coherence": 0.82,
        "originality": lambda cx: _clamp01(0.18 + 0.10 * cx),
        "social": 0.95,
        "help_short": lambda cx: _clamp01(0.55 + 0.10 * (1.0 - cx)),
        "help_long": lambda cx: _clamp01(0.40 + 0.20 * cx),
        "over_beneficial": 0.85,
        "over_safety": 0.90,
        "over_honesty": 0.95,
    },
    "act_search": {
        "efficiency": 0.25,
        "accuracy": lambda cx: _clamp01(0.30 + 0.90 * cx),
        "success_moderate": lambda cx: _clamp01(0.55 + 0.20 * cx),
        "knowledge": lambda cx: _clamp01(0.68 + 0.22 * cx),
        "novelty": lambda cx: _clamp01(0.58 + 0.18 * cx),
        "success_breakthrough": lambda cx: _clamp01(0.45 + 0.18 * cx),
        "coherence": 0.58,
        "originality": lambda cx: _clamp01(0.48 + 0.16 * cx),
        "social": lambda cx: _clamp01(0.42 + 0.12 * (1.0 - cx)),
        "help_short": lambda cx: _clamp01(0.35 + 0.10 * (1.0 - cx)),
        "help_long": lambda cx: _clamp01(0.55 + 0.35 * cx),
        "over_beneficial": 0.72,
        "over_safety": 0.78,
        "over_honesty": 0.82,
    },
    "act_verify": {
        "efficiency": 0.35,
        "accuracy": lambda cx: _clamp01(0.75 + 0.20 * cx),
        "success_moderate": 0.90,
        "knowledge": lambda cx: _clamp01(0.62 + 0.15 * cx),
        "novelty": lambda cx: _clamp01(0.25 + 0.08 * cx),
        "success_breakthrough": lambda cx: _clamp01(0.38 + 0.10 * cx),
        "coherence": 0.86,
        "originality": lambda cx: _clamp01(0.24 + 0.08 * cx),
        "social": 0.88,
        "help_short": lambda cx: _clamp01(0.40 + 0.10 * (1.0 - cx)),
        "help_long": lambda cx: _clamp01(0.50 + 0.20 * cx),
        "over_beneficial": 0.96,
        "over_safety": 0.97,
        "over_honesty": 0.97,
    },
    "act_decompose": {
        "efficiency": 0.45,
        "accuracy": lambda cx: _clamp01(0.55 + 0.35 * cx),
        "success_moderate": lambda cx: _clamp01(0.65 + 0.15 * cx),
        "knowledge": lambda cx: _clamp01(0.72 + 0.20 * cx),
        "novelty": lambda cx: _clamp01(0.62 + 0.18 * cx),
        "success_breakthrough": lambda cx: _clamp01(0.62 + 0.22 * cx),
        "coherence": 0.80,
        "originality": lambda cx: _clamp01(0.66 + 0.18 * cx),
        "social": 0.72,
        "help_short": lambda cx: _clamp01(0.30 + 0.05 * (1.0 - cx)),
        "help_long": lambda cx: _clamp01(0.70 + 0.25 * cx),
        "over_beneficial": 0.70,
        "over_safety": 0.76,
        "over_honesty": 0.80,
    },
    "act_think": {
        "efficiency": 0.40,
        "accuracy": lambda cx: _clamp01(0.60 + 0.25 * cx),
        "success_moderate": lambda cx: _clamp01(0.45 + 0.20 * cx),
        "knowledge": lambda cx: _clamp01(0.66 + 0.18 * cx),
        "novelty": lambda cx: _clamp01(0.70 + 0.18 * cx),
        "success_breakthrough": lambda cx: _clamp01(0.68 + 0.20 * cx),
        "coherence": 0.74,
        "originality": lambda cx: _clamp01(0.74 + 0.16 * cx),
        "social": 0.58,
        "help_short": lambda cx: _clamp01(0.35 + 0.10 * (1.0 - cx)),
        "help_long": lambda cx: _clamp01(0.60 + 0.25 * cx),
        "over_beneficial": 0.78,
        "over_safety": 0.84,
        "over_honesty": 0.90,
    },
    "act_synthesize": {
        "efficiency": 0.30,
        "accuracy": lambda cx: _clamp01(0.74 + 0.12 * cx),
        "success_moderate": 0.82,
        "knowledge": lambda cx: _clamp01(0.78 + 0.16 * cx),
        "novelty": lambda cx: _clamp01(0.56 + 0.12 * cx),
        "success_breakthrough": lambda cx: _clamp01(0.54 + 0.14 * cx),
        "coherence": 0.84,
        "originality": lambda cx: _clamp01(0.82 + 0.12 * cx),
        "social": 0.68,
        "help_short": lambda cx: _clamp01(0.42 + 0.08 * (1.0 - cx)),
        "help_long": lambda cx: _clamp01(0.72 + 0.18 * cx),
        "over_beneficial": 0.90,
        "over_safety": 0.92,
        "over_honesty": 0.95,
    },
}

# penalty functions, corresponds to penalties.py

def _hallucination_penalty(action: str, cx: float, ambiguity: float) -> float:
    base = {
        "act_respond":    0.90,
        "act_search":     0.30,
        "act_verify":     0.12,
        "act_clarify":    0.15,
        "act_decompose":  0.40,
        "act_think":      0.22,
        "act_synthesize": 0.20,
    }.get(action, 0.50)
    if action == "act_respond":
        base += 0.25 * cx + 0.20 * ambiguity
    elif action == "act_search":
        base += 0.10 * ambiguity
    elif action == "act_decompose":
        base += 0.10 * cx
    return _clamp01(base)


def _redundancy_penalty(action: str, cx: float,
                         familiarity: float, urgency: float) -> float:
    if action == "act_respond":
        return _clamp01(
            0.45 + 0.25 * (1.0 - cx) + 0.15 * familiarity + 0.10 * (1.0 - urgency)
        )
    return {
        "act_search":     0.42,
        "act_verify":     0.30,
        "act_clarify":    0.18,
        "act_decompose":  0.72,
        "act_think":      0.82,
        "act_synthesize": 0.26,
    }.get(action, 0.35)


def _premature_penalty(action: str, cx: float,
                        ambiguity: float, threshold: float) -> float:
    if action == "act_respond":
        return _clamp01(0.40 + 0.35 * cx + 0.25 * ambiguity + 0.20 * threshold)
    return {
        "act_search":     0.20,
        "act_verify":     0.08,
        "act_clarify":    0.12,
        "act_decompose":  0.10,
        "act_think":      0.15,
        "act_synthesize": 0.06,
    }.get(action, 0.20)


def _rabbit_hole_penalty(action: str, cx: float, ambiguity: float) -> float:
    if action == "act_think":
        return _clamp01(0.36 + 0.16 * (1.0 - cx) + 0.14 * (1.0 - ambiguity))
    if action == "act_decompose":
        return _clamp01(0.48 + 0.18 * (1.0 - cx) + 0.18 * (1.0 - ambiguity))
    if action == "act_search":
        return _clamp01(0.35 + 0.15 * (1.0 - cx) + 0.15 * (1.0 - ambiguity))
    return {
        "act_respond":    0.10,
        "act_verify":     0.18,
        "act_clarify":    0.14,
        "act_synthesize": 0.22,
    }.get(action, 0.20)


# Rows of ACTIONS hand out different total credit (respond's 14 numbers sum to ~7, synthesize's to ~10).
# Each relevance is shifted by a per-action constant, computed from the table at load time, so all rows
# have the same average total over cx.
_CX_GRID = [i / 20 for i in range(21)]


def _row_total(effects: dict, cx: float) -> float:
    return sum(e(cx) if callable(e) else float(e) for e in effects.values())


_ROW_AVG = {a: sum(_row_total(e, cx) for cx in _CX_GRID) / len(_CX_GRID) for a, e in ACTIONS.items()}
_ROW_TARGET = sum(_ROW_AVG.values()) / len(_ROW_AVG)
_ROW_SHIFT = {a: (_ROW_TARGET - _ROW_AVG[a]) / len(ACTIONS[a]) for a in ACTIONS}

# With the rows level, only search and synthesize still over-win, so they carry a fitted penalty.
# Moving either by 0.3 changes accuracy by only a turn or two.
_ACTION_PENALTY = {"act_search": -1.19, "act_synthesize": -1.64}


# core scoring engine, corresponds to adjustments.py file

def _score_actions(
    *,
    cx, ambiguity, ux, u, res, threshold, threshold_signal,
    familiarity, familiarity_signal, failure_wariness, failure_signal,
    securing, approach, arousal, risk_aversion, error_tolerance,
    creativity, valence, low_confidence, answerability,
    needs_external_evidence, needs_task_plan, needs_multi_source_integration,
    reflective_intent, verify_request,
    anti_hall, anti_redundant, anti_rabbit_hole, anti_premature,
    coherence, originality, social, help_short, help_long,
    over_beneficial, over_safety, over_honesty,
    knowledge, novelty, success_breakthrough,
    reflective_think_bonus, reflective_search_penalty,
    weights,
) -> dict[str, float]:
    scores: dict[str, float] = {}

    # The formulas below were fit on 1 - threshold; the appraisal's low_confidence still drives the risk terms.
    lowconf = _clamp01(1.0 - threshold)

    for action, effects in ACTIONS.items():
        score = 0.0
        for goal, weight in weights.items():
            effect = effects.get(goal)
            if effect is None:
                continue
            rel = effect(cx) if callable(effect) else float(effect)
            score += float(weight) * (float(rel) + _ROW_SHIFT[action])

        # Per-action formulas: coefficients fitted on the tuning sessions, rounded to 2 decimals.
        if action == "act_clarify":
            score += 0.76 * ambiguity - 0.34 * ux - 0.07 * u + 0.18 * threshold
            score += 0.21 * securing
            score += 0.1 * coherence - 0.04 * valence
            score += 0.22 * social - 0.06 * originality
            score += 0.13 * (1.0 - error_tolerance)
            score -= 0.58 * answerability
            score -= 0.20 * help_short
            score -= 0.15 * anti_redundant
            # very ambiguous and unsure -> ask
            if ambiguity > 0.75 and (threshold_signal > 0.55 or lowconf > 0.45):
                score += 0.32
            score -= 0.18 * reflective_intent
        elif action == "act_respond":
            score += 0.78 * u + 0.33 * (1.0 - ambiguity) + 0.21 * ux - 0.05 * cx
            score += 0.25 * familiarity - 0.2 * threshold - 0.2 * failure_wariness
            score += 0.08 * lowconf - 0.35 * securing
            score += 0.13 * (1.0 - arousal)
            score += 0.12 * coherence - 0.07 * valence
            score += 0.14 * social - 0.06 * originality
            score -= 0.04 * risk_aversion
            score += 0.4 * help_short - 0.15 * help_long
            score += 0.45 * answerability
            score += 0.38 * error_tolerance
            if cx >= 0.5:
                score -= 0.08 * knowledge + 0.1 * success_breakthrough
        elif action == "act_search":
            score += 0.34 * cx + 0.02 * res - 0.21 * u
            score += 0.26 * threshold + 0.35 * (1.0 - familiarity) + 0.3 * failure_wariness
            score -= 0.03 * securing
            score += 0.16 * arousal
            score += 0.06 * coherence + 0.1 * valence
            score += 0.1 * originality + 0.06 * social
            score += 0.2 * (1.0 - risk_aversion)
            score += 0.18 * (1.0 - error_tolerance)
            score += 0.16 * creativity
            score += 0.06 * help_long - 0.08 * help_short
            score += 0.14 * knowledge + 0.12 * novelty + 0.08 * success_breakthrough
            score += 0.58 * needs_external_evidence
            score += 0.31 * needs_multi_source_integration
            score -= 0.2 * needs_task_plan
            score += 0.05 * reflective_intent
            # no real need for outside evidence
            if needs_external_evidence < 0.5:
                score -= 0.77
        elif action == "act_verify":
            score += 0.4 * threshold + 0.45 * lowconf + 0.25 * failure_wariness
            score += 0.1 * cx - 0.3 * u - 0.1 * ambiguity
            score += 0.25 * securing
            score += 0.14 * coherence - 0.14 * valence
            score += 0.1 * social - 0.08 * originality
            score += 0.2 * risk_aversion
            score -= 0.1 * arousal
            score += 0.45 * (1.0 - error_tolerance)
            score += 0.08 * (1.0 - creativity)
            score += 0.08 * help_long - 0.1 * help_short
            if verify_request:
                score += 0.32
            score += 0.05 * knowledge
        elif action == "act_decompose":
            score += 0.19 * cx + 0.46 * res + 0.14 * (1.0 - ambiguity) - 0.19 * u
            score -= 0.44 * ambiguity
            # complex, unambiguous, plan-shaped request
            if cx >= 0.6 and ambiguity <= 0.6 and needs_task_plan >= 0.65:
                score -= 0.09
            # trivial turn: don't break it down
            if cx < 0.35:
                score -= 0.29
            score += 0.17 * approach
            score += 0.02 * arousal
            score += 0.1 * coherence + 0.04 * valence
            score += 0.12 * originality + 0.08 * social
            score += 0.08 * creativity
            score -= 0.21 * (1.0 - error_tolerance)
            score += 0.12 * help_long - 0.12 * help_short
            score += 0.08 * knowledge + 0.06 * novelty + 0.1 * success_breakthrough
            score += 0.18 * needs_task_plan
            score -= 0.09 * needs_external_evidence
            score += 0.05 * needs_multi_source_integration
            # not clearly a multi-step task
            if needs_task_plan < 0.9:
                score -= 0.45
        elif action == "act_think":
            rscale = 0.09 + 0.75 * reflective_intent
            cscale = 0.72 + 0.71 * reflective_intent
            score += 0.19 * cx + 0.13 * ambiguity + 0.29 * approach * rscale
            score += 0.12 * lowconf + 0.23 * (1.0 - u)
            score += 0.38 * arousal
            score += 0.08 * coherence + 0.02 * valence
            score += 0.14 * originality + 0.04 * social
            score -= 0.06 * (1.0 - risk_aversion)
            score += 0.31 * creativity * cscale
            score -= 0.27 * (1.0 - error_tolerance)
            score += 0.1 * help_long - 0.08 * help_short
            score += 0.1 * knowledge + 0.12 * novelty + 0.16 * success_breakthrough
            score += 0.1 * reflective_intent
            score -= 0.3 * anti_redundant * (0.7 + 0.3 * familiarity)
            score += 0.03 * answerability
            # low-complexity turns rarely need deliberate thinking
            if cx < 0.5:
                score -= 1.0
            if (cx >= 0.7 and approach >= 0.62 and reflective_intent >= 0.35
                    and (ambiguity >= 0.25 or lowconf >= 0.3)):
                score += 0.01
            elif (cx >= 0.65 and approach >= 0.58 and reflective_intent >= 0.3
                    and (ambiguity >= 0.22 or lowconf >= 0.28)):
                score += 0.05
            if cx >= 0.7 and reflective_intent >= 0.55 and needs_task_plan < 0.65:
                score += 0.14
            # ambiguous multi-step requests are clarify cases, not think cases
            if ambiguity >= 0.6 and needs_task_plan >= 0.55:
                score -= 0.99
        elif action == "act_synthesize":
            score += 0.24 * cx + 0.12 * res - 0.1 * u
            score += 0.16 * (1.0 - ambiguity) + 0.14 * (1.0 - familiarity)
            score += 0.12 * approach + 0.08 * arousal + 0.16 * creativity
            score += 0.16 * coherence + 0.08 * valence
            score += 0.22 * originality + 0.1 * social
            score += 0.06 * (1.0 - lowconf)
            score += 0.12 * knowledge + 0.08 * novelty + 0.1 * success_breakthrough
            score += 0.14 * help_long - 0.1 * help_short
            score -= 0.12 * risk_aversion
            score -= 0.18 * threshold
            score -= 0.16 * failure_wariness
            score += 0.55 * needs_multi_source_integration
            score -= 0.12 * needs_external_evidence
            score -= 0.18 * needs_task_plan
            if cx >= 0.55 and ambiguity <= 0.6:
                score += 0.16
            if ambiguity >= 0.8:
                score -= 0.28
            if verify_request:
                score -= 0.25

        score += _ACTION_PENALTY.get(action, 0.0)

        # this corresponds to penalities.py file
        # ── penalty deductions ──────────────────────────────────
        score -= anti_hall * _hallucination_penalty(action, cx=cx, ambiguity=ambiguity)
        score -= (anti_redundant
                  * _redundancy_penalty(action, cx=cx,
                                        familiarity=familiarity, urgency=u)
                  * (0.70 + 0.30 * (1.0 - u)))
        score -= (anti_premature
                  * _premature_penalty(action, cx=cx,
                                       ambiguity=ambiguity, threshold=threshold)
                  * (0.60 + 0.40 * threshold))

        rabbit_hole_scale = 0.40 + 0.22 * help_short
        if action == "act_decompose":
            rabbit_hole_scale *= 1.0 - 0.35 * needs_task_plan
        score -= (anti_rabbit_hole
                  * _rabbit_hole_penalty(action, cx=cx, ambiguity=ambiguity)
                  * rabbit_hole_scale)

        safety_risk = {
            "act_respond":   _clamp01(0.55 + 0.20 * cx + 0.25 * threshold
                                      + 0.20 * ambiguity),
            "act_search":    _clamp01(0.35 + 0.20 * threshold),
            "act_verify":    0.08,
            "act_clarify":   0.10,
            "act_decompose": 0.25,
            "act_synthesize":0.12,
        }.get(action, 0.30)

        honesty_risk = {
            "act_respond":   _clamp01(0.40 + 0.30 * low_confidence
                                      + 0.15 * ambiguity),
            "act_search":    0.18,
            "act_verify":    0.05,
            "act_clarify":   0.10,
            "act_decompose": 0.16,
            "act_synthesize":0.08,
        }.get(action, 0.20)

        beneficial_risk = {
            "act_respond":   _clamp01(0.50 + 0.20 * cx + 0.20 * threshold
                                      + 0.20 * low_confidence),
            "act_search":    0.22,
            "act_verify":    0.06,
            "act_clarify":   0.10,
            "act_decompose": 0.18,
            "act_synthesize":0.10,
        }.get(action, 0.20)

        score -= over_safety    * safety_risk    * (0.65 + 0.35 * securing)
        score -= over_honesty   * honesty_risk   * (0.60 + 0.40 * low_confidence)
        score -= over_beneficial* beneficial_risk * (0.60 + 0.40 * securing)

        scores[action] = score

    return scores


# metta list parsers


def _parse_metta_pairlist(data) -> dict:
    """
    Robust parser for MeTTa pair lists.
    Handles Python lists/tuples (e.g., [['key', val], ...]) and MeTTa strings (e.g., "(key val) ...")
    """
    result = {}
    
    def process_val(v):
        if isinstance(v, bool):
            return v
        if isinstance(v, (int, float)):
            return float(v)
        v_str = str(v).strip()
        if v_str.lower() == 'true':
            return True
        if v_str.lower() == 'false':
            return False
        try:
            return float(v_str)
        except ValueError:
            return v_str

    # 1. Handle Python list/tuple format
    if isinstance(data, (list, tuple)):
        for item in data:
            if isinstance(item, (list, tuple)) and len(item) >= 2:
                k = str(item[0])
                result[k] = process_val(item[1])
        return result

    # 2. Handle string format
    text = str(data).strip()
    # Normalize Python list syntax to MeTTa syntax just in case it's stringified
    text = text.replace("[", "(").replace("]", ")").replace(",", "")
    
    pairs = re.findall(r'\((\S+)\s+([^()]+?)\)', text)
    for k, v in pairs:
        result[k] = process_val(v)
        
    return result


def _parse_state_block(data) -> dict:
    """
    Pull values out of the (state ...) atom that lives in the space list.
    Specifically extracts anti-goals and alpha constants.
    Handles both lists and strings.
    """
    extra = {}
    
    def process_val(v):
        if isinstance(v, bool):
            return v
        if isinstance(v, (int, float)):
            return float(v)
        try:
            return float(str(v).strip())
        except ValueError:
            return 0.0

    # 1. Handle Python list/tuple format
    if isinstance(data, (list, tuple)):
        for item in data:
            if isinstance(item, (list, tuple)) and len(item) >= 2:
                k = str(item[0]).replace("(", "").replace(")", "").strip()
                if k in ("hallucinate", "redundant", "rabbit_hole", "premature", 
                         "reflective_think_bonus", "reflective_search_penalty", 
                         "topic_familiarity", "failure_wariness", "m_failure_wariness"):
                    extra[k] = process_val(item[1])

    # 2. Handle string format via regex
    text = str(data)
    text = text.replace("[", "(").replace("]", ")").replace(",", "").replace("'", "").replace('"', "")
    
    for name in ("hallucinate", "redundant", "rabbit_hole", "premature"):
        m = re.search(rf'\({name}\s+([0-9.]+)\)', text)
        if m:
            extra[name] = float(m.group(1))

    for name in ("reflective_think_bonus", "reflective_search_penalty",
                 "topic_familiarity", "failure_wariness"):
        m = re.search(rf'\({name}\s+([0-9.]+)\)', text)
        if m:
            extra[name] = float(m.group(1))

    m = re.search(r'\(m_failure_wariness\s+([0-9.]+)\)', text)
    if m:
        extra.setdefault("failure_wariness", float(m.group(1)))

    return extra


def compute_scores(appraisal_metta, weights_metta, space_metta) -> str:

    ap   = _parse_metta_pairlist(appraisal_metta)
    wt   = _parse_metta_pairlist(weights_metta)
    sp   = _parse_state_block(space_metta)

    if not ap or not wt:
        print(f"[score_action] WARNING: empty parse (ap={len(ap)}, wt={len(wt)}) -> scores will be "
              f"constant defaults", file=sys.stderr)


    anti_hall        = float(sp.get("hallucinate",  ap.get("hallucinate",  0.35)))
    anti_redundant   = float(sp.get("redundant",    ap.get("redundant",    0.30)))
    anti_rabbit_hole = float(sp.get("rabbit_hole",  ap.get("rabbit_hole",  0.28)))
    anti_premature   = float(sp.get("premature",    ap.get("premature",    0.30)))


    threshold      = float(ap.get("threshold", 0.30))
    low_confidence = _clamp01(float(ap.get("low_confidence", 1.0 - threshold)))
    threshold_signal= float(ap.get("threshold_signal",1.0))
    familiarity_sig = float(ap.get("familiarity_signal", 0.0))
    ambiguity       = float(ap.get("ambiguity",       0.0))

    answerability   = _clamp01(
        (1.0 - ambiguity) * (1.0 - threshold_signal) * familiarity_sig
    )

    failure_wariness = float(
        ap.get("failure_wariness",
               sp.get("failure_wariness", ap.get("failure_signal", 0.0)))
    )

    topic_familiarity = float(
        ap.get("familiarity",
               sp.get("topic_familiarity", ap.get("familiarity_signal", 0.0)))
    )

    reflective_think_bonus   = float(sp.get("reflective_think_bonus",   0.14))
    reflective_search_penalty= float(sp.get("reflective_search_penalty",0.10))

    vr_raw = ap.get("verify_request", 0)
    verify_request = bool(vr_raw) if isinstance(vr_raw, bool) else (int(vr_raw) != 0)

    scoring_weight_keys = {
        "efficiency", "accuracy", "success_moderate", "knowledge",
        "novelty", "success_breakthrough", "coherence", "originality",
        "social", "help_short", "help_long",
        "over_beneficial", "over_safety", "over_honesty",
    }
    weights_clean = {k: float(v) for k, v in wt.items()
                     if k in scoring_weight_keys}

    # call the engine
    raw_scores = _score_actions(
        cx                        = float(ap.get("complexity",                 0.0)),
        ambiguity                 = ambiguity,
        ux                        = float(ap.get("user_expertise",             0.0)),
        u                         = float(ap.get("urgency",                    0.0)),
        res                       = float(ap.get("resolution",                 0.0)),
        threshold                 = threshold,
        threshold_signal          = threshold_signal,
        familiarity               = topic_familiarity,
        familiarity_signal        = familiarity_sig,
        failure_wariness          = failure_wariness,
        failure_signal            = float(ap.get("failure_signal",            0.0)),
        securing                  = float(ap.get("securing",                  0.0)),
        approach                  = float(ap.get("approach",                  0.0)),
        arousal                   = float(ap.get("arousal",                   0.0)),
        risk_aversion             = float(ap.get("risk_aversion",             0.0)),
        error_tolerance           = float(ap.get("error_tolerance",           0.35)),
        creativity                = float(ap.get("creativity",                0.5)),
        valence                   = float(ap.get("valence",                   0.0)),
        low_confidence            = low_confidence,
        answerability             = answerability,
        needs_external_evidence   = float(ap.get("needs_external_evidence",   0.0)),
        needs_task_plan           = float(ap.get("needs_task_plan",           0.0)),
        needs_multi_source_integration=float(ap.get("needs_multi_source_integration",0.0)),
        reflective_intent         = float(ap.get("reflective_intent",         0.0)),
        verify_request            = verify_request,
        anti_hall                 = anti_hall,
        anti_redundant            = anti_redundant,
        anti_rabbit_hole          = anti_rabbit_hole,
        anti_premature            = anti_premature,
        coherence                 = float(wt.get("coherence",                 0.0)),
        originality               = float(wt.get("originality",               0.0)),
        social                    = float(wt.get("social",                    0.0)),
        help_short                = float(wt.get("help_short",                0.0)),
        help_long                 = float(wt.get("help_long",                 0.0)),
        over_beneficial           = float(wt.get("over_beneficial",           0.0)),
        over_safety               = float(wt.get("over_safety",               0.0)),
        over_honesty              = float(wt.get("over_honesty",              0.0)),
        knowledge                 = float(wt.get("knowledge",                 0.0)),
        novelty                   = float(wt.get("novelty",                   0.0)),
        success_breakthrough      = float(wt.get("success_breakthrough",      0.0)),
        reflective_think_bonus    = reflective_think_bonus,
        reflective_search_penalty = reflective_search_penalty,
        weights                   = weights_clean,
    )


    order = ["act_respond", "act_search", "act_verify",
             "act_clarify", "act_decompose", "act_think", "act_synthesize"]

    parts = []
    for act in order:
        val = raw_scores.get(act, 0.0)
        parts.append(f"({act} {round(val, 6)})")

    return "(" + " ".join(parts) + ")"


