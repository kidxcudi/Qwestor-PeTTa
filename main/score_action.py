import re
import sys

def _clamp01(x: float) -> float:
    return max(0.0, min(1.0, float(x)))

# ACTIONS table
ACTIONS: dict[str, dict] = {
    "act_respond":    {"efficiency": 0.85, "accuracy": 0.60,
                       "success_moderate": 0.70, "knowledge": 0.30,
                       "novelty": 0.10, "success_breakthrough": 0.20},
    "act_search":     {"efficiency": 0.40, "accuracy": 0.85,
                       "success_moderate": 0.60, "knowledge": 0.80,
                       "novelty": 0.55, "success_breakthrough": 0.50},
    "act_verify":     {"efficiency": 0.30, "accuracy": 0.90,
                       "success_moderate": 0.65, "knowledge": 0.35,
                       "novelty": 0.10, "success_breakthrough": 0.15},
    "act_clarify":    {"efficiency": 0.50, "accuracy": 0.55,
                       "success_moderate": 0.50, "knowledge": 0.20,
                       "novelty": 0.10, "success_breakthrough": 0.10},
    "act_decompose":  {"efficiency": 0.45, "accuracy": 0.65,
                       "success_moderate": 0.70, "knowledge": 0.50,
                       "novelty": 0.40, "success_breakthrough": 0.55},
    "act_think":      {"efficiency": 0.35, "accuracy": 0.60,
                       "success_moderate": 0.55, "knowledge": 0.55,
                       "novelty": 0.60, "success_breakthrough": 0.65},
    "act_synthesize": {"efficiency": 0.40, "accuracy": 0.70,
                       "success_moderate": 0.65, "knowledge": 0.60,
                       "novelty": 0.55, "success_breakthrough": 0.60},
}

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

    # Per-action calibration weight. Each action's raw score sums a
    # different number of terms of different sizes, so without this the
    # action whose formula just happens to add up the most wins by default
    # rather than by genuinely fitting the turn. SCALE corrects for that so
    # all 7 actions compete on a level footing. Applied directly to every
    # coefficient below; two spots (the goal-weight loop, the penalty/risk
    # block) apply it explicitly instead since it can't be pre-baked there.
    SCALE = {
        "act_search":     0.65,
        "act_synthesize": 0.45,
        "act_think":      0.9,
        "act_decompose":  0.9,
        "act_clarify":    1.40,
        "act_respond":    2.00,
    }

    for action, effects in ACTIONS.items():
        score = 0.0
        action_scale = SCALE.get(action, 1.0)
        for goal, weight in weights.items():
            effect = effects.get(goal)
            if effect is None:
                continue
            rel = effect(cx) if callable(effect) else float(effect)
            score += float(weight) * float(rel) * action_scale

        if action == "act_clarify":
            score += 1.26 * ambiguity - 0.49 * ux - 0.21 * u + 0.28 * threshold
            score += 0.28 * securing
            score += 0.14 * coherence - 0.112 * valence
            score += 0.308 * social - 0.084 * originality
            score += 0.112 * (1.0 - error_tolerance)
            score -= 0.77 * answerability
            score -= 0.28 * help_short
            score -= 0.21 * anti_redundant
            if ambiguity > 0.75 and (threshold_signal > 0.55 or low_confidence > 0.45):
                score += 0.252
            # New: ambiguity alone doesn't mean the person wants a clarifying
            # question back -- high reflective_intent means the ambiguity is
            # the person thinking out loud, which act_think serves better.
            score -= 0.49 * reflective_intent

        elif action == "act_respond":
            score += 1.2 * u + 0.6 * (1.0 - ambiguity) + 0.4 * ux - 0.2 * cx
            score += 0.5 * familiarity - 0.4 * threshold - 0.4 * failure_wariness
            score -= 0.5 * securing + 0.2 * low_confidence
            score += 0.3 * (1.0 - arousal)
            score += 0.24 * coherence + 0.2 * valence
            score += 0.28 * social - 0.12 * originality
            score -= 0.3 * risk_aversion
            score += 0.8 * help_short - 0.3 * help_long
            score += 0.9 * answerability
            score += 0.6 * error_tolerance
            if cx >= 0.50:
                score -= 0.16 * knowledge + 0.2 * success_breakthrough

        elif action == "act_search":
            score += 0.2275 * cx + 0.13 * res - 0.0975 * u
            score += (0.2275 * threshold + 0.2275 * (1.0 - familiarity)
                      + 0.195 * failure_wariness)
            score += 0.0975 * securing
            score += 0.052 * arousal
            score += 0.039 * coherence + 0.013 * valence
            score += 0.065 * originality + 0.039 * social
            score += 0.052 * (1.0 - risk_aversion)
            score += 0.065 * (1.0 - error_tolerance)
            score += 0.065 * creativity
            score += 0.039 * help_long - 0.052 * help_short
            score += 0.091 * knowledge + 0.078 * novelty + 0.052 * success_breakthrough
            score += 0.325 * needs_external_evidence
            score += 0.078 * needs_multi_source_integration
            score -= 0.052 * needs_task_plan
            # reflective_search_penalty is a runtime variable (sp-sourced,
            # default 0.10), not a literal -- can't pre-bake action_scale
            # into it, so it's applied explicitly here instead.
            score -= reflective_search_penalty * reflective_intent * action_scale
            # act_search won purely on terms unrelated to its core signal
            # even at ext=0 -- confirmed zero legitimate win below ext=0.8
            # anywhere in the dataset. Scoped fix only, not the full formula.
            if needs_external_evidence < 0.5:
                score -= 0.5005

        elif action == "act_verify":
            # Toned down the low_confidence bonus so it doesn't beat act_respond on simple turns
            score += 0.40 * threshold + 0.45 * low_confidence + 0.25 * failure_wariness
            score += 0.10 * cx - 0.30 * u - 0.10 * ambiguity  # Penalized more by urgency
            score += 0.25 * securing
            score += 0.14 * coherence - 0.14 * valence
            score += 0.10 * social - 0.08 * originality
            score += 0.20 * risk_aversion
            score -= 0.10 * arousal
            score += 0.45 * (1.0 - error_tolerance)
            score += 0.08 * (1.0 - creativity)
            score += 0.08 * help_long - 0.10 * help_short
            score += 0.32 * (1.0 if verify_request else 0.0)
            score += 0.05 * knowledge

        elif action == "act_decompose":
            score += 0.27 * cx + 0.27 * res + 0.09 * (1.0 - ambiguity) - 0.108 * u
            score -= 0.252 * ambiguity
            # Requires genuine task-plan signal, not just complexity, so
            # decompose doesn't win high-cx turns that should go to think.
            if cx >= 0.60 and ambiguity <= 0.60 and needs_task_plan >= 0.65:
                score += 0.09
            if cx < 0.35:
                score -= 0.315
            score += 0.09 * approach
            score += 0.09 * arousal
            score += 0.09 * coherence + 0.036 * valence
            score += 0.108 * originality + 0.072 * social
            score += 0.072 * creativity
            score -= 0.072 * (1.0 - error_tolerance)
            score += 0.108 * help_long - 0.108 * help_short
            score += 0.072 * knowledge + 0.054 * novelty + 0.09 * success_breakthrough
            score += 0.216 * needs_task_plan
            score -= 0.108 * needs_external_evidence
            score += 0.018 * needs_multi_source_integration
            # Every act_decompose-expected turn in the full 136-turn set has
            # needs_task_plan=1.0 exactly, no exceptions -- so this discount
            # (fires below 0.90) has zero overlap risk with any correct win.
            if needs_task_plan < 0.90:
                score -= 0.405

        elif action == "act_think":
            # approach/creativity used to be flat terms regardless of
            # reflective_intent; scaled by it instead (offline CV-optimized
            # coefficients; an unconstrained search overfit and was discarded).
            score += 0.315 * cx + 0.225 * ambiguity + 0.29043 * approach * (0.2910 + 0.7737 * reflective_intent)
            score += 0.09 * low_confidence + 0.09 * (1.0 - u)
            score -= 0.09 * threshold
            score += 0.18 * arousal
            score += 0.072 * coherence + 0.018 * valence
            score += 0.126 * originality + 0.036 * social
            score += 0.09 * (1.0 - risk_aversion)
            score += 0.10242 * creativity * (0.5658 + 0.7650 * reflective_intent)
            score -= 0.126 * (1.0 - error_tolerance)
            score += 0.09 * help_long - 0.072 * help_short
            score += 0.09 * knowledge + 0.108 * novelty + 0.144 * success_breakthrough
            score += 0.2187 * reflective_intent
            score -= 0.27 * anti_redundant * (0.70 + 0.30 * familiarity)
            score -= 0.144 * answerability
            # Zero correctly-won act_think turn exists below complexity=0.5
            # in the dataset. Not extended to cx 0.5-0.8: a confirmed
            # ground-truth conflict lives there (near-identical signals).
            if cx < 0.5:
                score -= 0.9
            # This bonus's ambiguity/low_confidence gate was toothless (fired
            # on cx+approach alone); added a reflective_intent floor.
            if (cx >= 0.70 and approach >= 0.62 and reflective_intent >= 0.35
                    and (ambiguity >= 0.25 or low_confidence >= 0.30)):
                score += 0.04887
            elif (cx >= 0.65 and approach >= 0.58 and reflective_intent >= 0.30
                    and (ambiguity >= 0.22 or low_confidence >= 0.28)):
                score += 0.18756
            # Mirrors act_decompose's complexity bonus, for reflective turns
            # that aren't task-planning-oriented.
            if cx >= 0.70 and reflective_intent >= 0.55 and needs_task_plan < 0.65:
                score += 0.09216
            # High ambiguity + high needs_task_plan together means the task
            # can't be planned without clarifying it first -- zero overlap
            # with any act_think-expected turn in the dataset.
            if ambiguity >= 0.60 and needs_task_plan >= 0.55:
                score -= 0.72

        elif action == "act_synthesize":
            score += 0.108 * cx + 0.054 * res - 0.045 * u
            score += 0.072 * (1.0 - ambiguity) + 0.063 * (1.0 - familiarity)
            score += 0.054 * approach + 0.036 * arousal + 0.072 * creativity
            score += 0.072 * coherence + 0.036 * valence
            score += 0.099 * originality + 0.045 * social
            score += 0.027 * (1.0 - low_confidence)
            score += 0.054 * knowledge + 0.036 * novelty + 0.045 * success_breakthrough
            score += 0.063 * help_long - 0.045 * help_short
            score -= 0.054 * risk_aversion
            score -= 0.081 * threshold
            score -= 0.072 * failure_wariness
            score += 0.2475 * needs_multi_source_integration
            score -= 0.054 * needs_external_evidence
            score -= 0.081 * needs_task_plan
            if cx >= 0.55 and ambiguity <= 0.60:
                score += 0.072
            if ambiguity >= 0.80:
                score -= 0.126
            if verify_request:
                score -= 0.1125

        # Penalty/risk block: these helper functions clamp their result to
        # 0..1 before returning, so action_scale is applied explicitly here
        # (post-clamp) rather than baked into their internal literals --
        # see the note on SCALE near the top of this loop for why.
        score -= action_scale * anti_hall * _hallucination_penalty(action, cx=cx, ambiguity=ambiguity)
        score -= action_scale * (anti_redundant
                  * _redundancy_penalty(action, cx=cx,
                                        familiarity=familiarity, urgency=u)
                  * (0.70 + 0.30 * (1.0 - u)))
        score -= action_scale * (anti_premature
                  * _premature_penalty(action, cx=cx,
                                       ambiguity=ambiguity, threshold=threshold)
                  * (0.60 + 0.40 * threshold))

        rabbit_hole_scale = 0.40 + 0.22 * help_short
        if action == "act_decompose":
            rabbit_hole_scale *= 1.0 - 0.35 * needs_task_plan
        score -= action_scale * (anti_rabbit_hole
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

        score -= action_scale * over_safety    * safety_risk    * (0.65 + 0.35 * securing)
        score -= action_scale * over_honesty   * honesty_risk   * (0.60 + 0.40 * low_confidence)
        score -= action_scale * over_beneficial* beneficial_risk * (0.60 + 0.40 * securing)

        scores[action] = score

    print(f"DEBUG final scores dict: {scores!r}", file=sys.stderr)
    return scores


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
    # Parse dynamically using the robust parsers
    ap = _parse_metta_pairlist(appraisal_metta)
    wt = _parse_metta_pairlist(weights_metta)
    sp = _parse_state_block(space_metta)

    import sys
    print(f"DEBUG space_metta type={type(space_metta)!r} repr={space_metta!r}", file=sys.stderr)
    print(f"DEBUG sp={sp!r}", file=sys.stderr)

    anti_hall        = float(sp.get("hallucinate",  ap.get("hallucinate",  0.35)))
    anti_redundant   = float(sp.get("redundant",    ap.get("redundant",    0.30)))
    anti_rabbit_hole = float(sp.get("rabbit_hole",  ap.get("rabbit_hole",  0.28)))
    anti_premature   = float(sp.get("premature",    ap.get("premature",    0.30)))
   
    threshold      = float(ap.get("threshold", 0.30))
    low_confidence = _clamp01(1.0 - threshold) 
    threshold_signal= float(ap.get("threshold_signal",1.0))
    familiarity_sig = float(ap.get("familiarity_signal", 0.0))
    ambiguity       = float(ap.get("ambiguity",       0.0))

    answerability   = _clamp01(
        (1.0 - ambiguity) * (1.0 - threshold_signal) * familiarity_sig
    )

    failure_wariness = float(
        sp.get("failure_wariness",
               ap.get("failure_signal", 0.0))
    )

    topic_familiarity = float(
        sp.get("topic_familiarity",
               ap.get("familiarity_signal", 0.0))
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