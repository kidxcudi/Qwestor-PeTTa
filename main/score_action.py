import re

def _clamp01(x: float) -> float:
    return max(0.0, min(1.0, float(x)))


# ACTIONS table  ─ every entry is either a plain float or a
# callable that takes cx and returns a float.

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

    for action, effects in ACTIONS.items():
        score = 0.0
        for goal, weight in weights.items():
            effect = effects.get(goal)
            if effect is None:
                continue
            rel = effect(cx) if callable(effect) else float(effect)
            score += float(weight) * float(rel)

        if action == "act_clarify":
            score += 0.90 * ambiguity - 0.35 * ux - 0.15 * u + 0.20 * threshold
            score += 0.20 * securing
            score += 0.10 * coherence - 0.08 * valence
            score += 0.22 * social - 0.06 * originality
            score += 0.08 * (1.0 - error_tolerance)
            score -= 0.55 * answerability
            score -= 0.20 * help_short
            score -= 0.15 * anti_redundant
            if ambiguity > 0.75 and (threshold_signal > 0.55 or low_confidence > 0.45):
                score += 0.18

        elif action == "act_respond":
            score += 0.35 * u + 0.25 * (1.0 - ambiguity) + 0.15 * ux - 0.20 * cx
            score += 0.20 * familiarity - 0.35 * threshold - 0.30 * failure_wariness
            score -= 0.35 * securing + 0.20 * low_confidence
            score += 0.10 * (1.0 - arousal)
            score += 0.12 * coherence + 0.10 * valence
            score += 0.14 * social - 0.06 * originality
            score -= 0.18 * risk_aversion
            score += 0.30 * help_short - 0.15 * help_long
            score += 0.45 * answerability
            score += 0.22 * error_tolerance
            score += 0.16 * help_short
            score += 0.12 * anti_redundant
            if cx >= 0.50:
                score -= 0.08 * knowledge + 0.10 * success_breakthrough

        elif action == "act_search":
            score += 0.35 * cx + 0.20 * res - 0.15 * u
            score += (0.35 * threshold + 0.35 * (1.0 - familiarity)
                      + 0.30 * failure_wariness)
            score += 0.15 * securing
            score += 0.08 * arousal
            score += 0.06 * coherence + 0.02 * valence
            score += 0.10 * originality + 0.06 * social
            score += 0.08 * (1.0 - risk_aversion)
            score += 0.10 * (1.0 - error_tolerance)
            score += 0.10 * creativity
            score += 0.06 * help_long - 0.08 * help_short
            score += 0.14 * knowledge + 0.12 * novelty + 0.08 * success_breakthrough
            score += 0.50 * needs_external_evidence
            score += 0.12 * needs_multi_source_integration
            score -= 0.08 * needs_task_plan
            score -= reflective_search_penalty * reflective_intent

        elif action == "act_verify":
            score += 0.65 * threshold + 0.75 * low_confidence + 0.35 * failure_wariness
            score += 0.15 * cx - 0.20 * u - 0.10 * ambiguity
            score += 0.30 * securing
            score += 0.14 * coherence - 0.14 * valence
            score += 0.10 * social - 0.08 * originality
            score += 0.25 * risk_aversion
            score -= 0.08 * arousal
            score += 0.55 * (1.0 - error_tolerance)
            score += 0.08 * (1.0 - creativity)
            score += 0.08 * help_long - 0.10 * help_short
            score += 0.32 * (1.0 if verify_request else 0.0)
            score += 0.05 * knowledge

        elif action == "act_decompose":
            score += 0.30 * cx + 0.30 * res + 0.10 * (1.0 - ambiguity) - 0.12 * u
            score -= 0.28 * ambiguity
            if cx >= 0.60 and ambiguity <= 0.60:
                score += 0.10
            if cx < 0.35:
                score -= 0.35
            score += 0.10 * approach
            score += 0.10 * arousal
            score += 0.10 * coherence + 0.04 * valence
            score += 0.12 * originality + 0.08 * social
            score += 0.08 * creativity
            score -= 0.08 * (1.0 - error_tolerance)
            score += 0.12 * help_long - 0.12 * help_short
            score += 0.08 * knowledge + 0.06 * novelty + 0.10 * success_breakthrough
            score += 0.24 * needs_task_plan
            score -= 0.12 * needs_external_evidence
            score += 0.02 * needs_multi_source_integration

        elif action == "act_think":
            score += 0.35 * cx + 0.25 * ambiguity + 0.35 * approach
            score += 0.10 * low_confidence + 0.10 * (1.0 - u)
            score -= 0.10 * threshold
            score += 0.20 * arousal
            score += 0.08 * coherence + 0.02 * valence
            score += 0.14 * originality + 0.04 * social
            score += 0.10 * (1.0 - risk_aversion)
            score += 0.26 * creativity
            score -= 0.14 * (1.0 - error_tolerance)
            score += 0.10 * help_long - 0.08 * help_short
            score += 0.10 * knowledge + 0.12 * novelty + 0.16 * success_breakthrough
            score += reflective_think_bonus * reflective_intent
            score -= 0.30 * anti_redundant * (0.70 + 0.30 * familiarity)
            score -= 0.16 * answerability
            if (cx >= 0.70 and approach >= 0.62 and (ambiguity >= 0.25 or low_confidence >= 0.30)):
                score += 0.07
            elif (cx >= 0.65 and approach >= 0.58 and (ambiguity >= 0.22 or low_confidence >= 0.28)):
                score += 0.03

        elif action == "act_synthesize":
            score += 0.24 * cx + 0.12 * res - 0.10 * u
            score += 0.16 * (1.0 - ambiguity) + 0.14 * (1.0 - familiarity)
            score += 0.12 * approach + 0.08 * arousal + 0.16 * creativity
            score += 0.16 * coherence + 0.08 * valence
            score += 0.22 * originality + 0.10 * social
            score += 0.06 * (1.0 - low_confidence)
            score += 0.12 * knowledge + 0.08 * novelty + 0.10 * success_breakthrough
            score += 0.14 * help_long - 0.10 * help_short
            score -= 0.12 * risk_aversion
            score -= 0.18 * threshold
            score -= 0.16 * failure_wariness
            score += 0.55 * needs_multi_source_integration
            score -= 0.12 * needs_external_evidence
            score -= 0.18 * needs_task_plan
            if cx >= 0.55 and ambiguity <= 0.60:
                score += 0.16
            if ambiguity >= 0.80:
                score -= 0.28
            if verify_request:
                score -= 0.25
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
 

def _parse_metta_pairlist(metta_str: str) -> dict:
    """
    Parse a MeTTa flat-pair list such as
      ((key1 val1) (key2 val2) ...)
    into a Python dict.  Values that look like numbers become floats;
    'true'/'false' become bools; everything else stays a string.
    """
    text = str(metta_str).strip()
    pairs = re.findall(r'\((\S+)\s+([^()]+?)\)', text)
    result = {}
    for k, v in pairs:
        v = v.strip()
        if v.lower() == 'true':
            result[k] = True
        elif v.lower() == 'false':
            result[k] = False
        else:
            try:
                result[k] = float(v)
            except ValueError:
                result[k] = v
    return result


def _parse_state_block(metta_str: str) -> dict:
    """
    Pull values out of the (state ...) atom that lives in the space list.
    Specifically extracts anti-goals and alpha constants.
    """
    text = str(metta_str)
    extra = {}

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

    ap   = _parse_metta_pairlist(str(appraisal_metta))
    wt   = _parse_metta_pairlist(str(weights_metta))
    sp   = _parse_state_block(str(space_metta))

 
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


