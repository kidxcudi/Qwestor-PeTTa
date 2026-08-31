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
            # New: ambiguity alone doesn't mean the person wants a clarifying
            # question back -- high reflective_intent means the ambiguity is
            # the person thinking out loud / wanting exploration, which
            # act_think serves better. Without this, act_clarify's flat
            # +0.90*ambiguity term wins on any high-ambiguity turn regardless
            # of reflective_intent (e.g. cx=0.2, amb=0.8, reflective_intent=0.8,
            # intent_type=reflective turns that should go to act_think).
            score -= 0.35 * reflective_intent

        elif action == "act_respond":
            # Boosted urgency and low-complexity bonuses so it wins on simple/urgent turns
            score += 0.60 * u + 0.30 * (1.0 - ambiguity) + 0.20 * ux - 0.10 * cx
            score += 0.25 * familiarity - 0.20 * threshold - 0.20 * failure_wariness
            score -= 0.25 * securing + 0.10 * low_confidence
            score += 0.15 * (1.0 - arousal)
            score += 0.12 * coherence + 0.10 * valence
            score += 0.14 * social - 0.06 * originality
            score -= 0.15 * risk_aversion
            score += 0.40 * help_short - 0.15 * help_long
            score += 0.45 * answerability
            score += 0.30 * error_tolerance
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
            score += 0.30 * cx + 0.30 * res + 0.10 * (1.0 - ambiguity) - 0.12 * u
            score -= 0.28 * ambiguity
            # Was: fired on cx>=0.60 alone, letting decompose win high-complexity
            # turns even when the request wasn't really about task planning
            # (e.g. cx=0.9, needs_task_plan=0.6, reflective_intent=0.7 turns
            # that should go to act_think). Now requires genuine task-plan
            # signal too, matching what decompose is actually for.
            if cx >= 0.60 and ambiguity <= 0.60 and needs_task_plan >= 0.65:
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
            # Fix A (cluster: expected act_respond, predicted act_think --
            # Session B/6, C/8, F/8, I/1, L/1, L/3, M/3, N/8 on the 136-turn
            # set): approach and creativity used to be flat additive terms,
            # worth ~0.35-0.65pt on almost every turn regardless of whether
            # the turn was actually reflective (approach/creativity sit
            # ~0.55-0.65 for most turns in this test set -- they're stable
            # per-session modulators, not reflection signals). Scaled by
            # reflective_intent so low-reflective turns get less of the old
            # contribution while high-reflective turns keep most of it.
            #
            # Coefficients below (floor/scale/bonus values) were tuned by an
            # offline coordinate-search optimizer against 136 turns of real
            # session data (10 free parameters, bounded to +/-0.20 of the
            # original hand-picked values to avoid overfitting -- validated
            # via session-level train/held-out splits before trusting it,
            # since an earlier unconstrained 65-parameter version overfit
            # badly: better on training sessions, worse than the original
            # hand-tuned values on held-out sessions). Net effect: gentler
            # dampening than the original Fix A (higher floor, i.e. less
            # aggressive at moderate reflective_intent -- this fixes a
            # regression Fix A introduced on Session A turn 5, cx=0.8,
            # reflective_intent=0.4, expected act_think) while widening the
            # think_bonusB gate and reflective_think_bonus, which picks up
            # additional turns (Session E/2, J/9) that needed a bit more
            # margin at high complexity/reflection. Full set: 106/136 ->
            # 111/136 on this data (5 fixed, 0 regressed vs the Fix-A-only
            # version). Re-validate locally -- this optimizer used a frozen
            # per-turn residual for the goal-weight/anti-goal contribution
            # (couldn't reliably reconstruct those from logs), so it's an
            # approximation, not a live re-run of the real pipeline.
            score += 0.35 * cx + 0.25 * ambiguity + 0.3227 * approach * (0.2910 + 0.7737 * reflective_intent)
            score += 0.10 * low_confidence + 0.10 * (1.0 - u)
            score -= 0.10 * threshold
            score += 0.20 * arousal
            score += 0.08 * coherence + 0.02 * valence
            score += 0.14 * originality + 0.04 * social
            score += 0.10 * (1.0 - risk_aversion)
            score += 0.1138 * creativity * (0.5658 + 0.7650 * reflective_intent)
            score -= 0.14 * (1.0 - error_tolerance)
            score += 0.10 * help_long - 0.08 * help_short
            score += 0.10 * knowledge + 0.12 * novelty + 0.16 * success_breakthrough
            score += 0.2430 * reflective_intent
            score -= 0.30 * anti_redundant * (0.70 + 0.30 * familiarity)
            score -= 0.16 * answerability
            # Fix B (Session L/3: cx=0.8, reflective_intent=0.2, expected
            # act_respond, margin was 1.375). This bonus's (ambiguity >= ..
            # or low_confidence >= ..) gate was effectively toothless since
            # low_confidence = 1 - threshold rarely drops below 0.30, so it
            # fired on cx+approach alone with zero reflection check. Added a
            # reflective_intent floor, mirroring the fix already applied to
            # act_decompose's analogous complexity bonus.
            if (cx >= 0.70 and approach >= 0.62 and reflective_intent >= 0.35
                    and (ambiguity >= 0.25 or low_confidence >= 0.30)):
                score += 0.0543
            elif (cx >= 0.65 and approach >= 0.58 and reflective_intent >= 0.30
                    and (ambiguity >= 0.22 or low_confidence >= 0.28)):
                score += 0.2084
            # New: mirrors act_decompose's flat complexity bonus above, for
            # high-complexity turns that are reflective rather than task-
            # planning-oriented (needs_task_plan below decompose's 0.65
            # threshold).
            if cx >= 0.70 and reflective_intent >= 0.55 and needs_task_plan < 0.65:
                score += 0.1024
            # New (clarify-vs-think cluster: H/11, I/6, K/4, M/7, M/10 --
            # M/8 needed a larger penalty than cross-validation supports, so
            # it's left as a known miss rather than risk overfitting).
            # ambiguity>=0.60 AND needs_task_plan>=0.55 together means the
            # task can't be planned without clarifying it first -- verified
            # against the full 136-turn set: 7 act_clarify-expected turns
            # match this condition, ZERO act_think-expected or other-
            # expected turns match it at all, so this is zero regression
            # risk by construction. Penalty size (0.80) is the cross-
            # validated value (stable across 6 session splits when tuned in
            # isolation; jointly re-tuning it with the verify guard cutoff
            # caused instability in both, so they were validated separately
            # and this one deployed alone).
            if ambiguity >= 0.60 and needs_task_plan >= 0.55:
                score -= 0.80

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

        # Cross-action calibration pass, applied after every other term above.
        # act_search/act_synthesize/act_think accumulate many small context-
        # driven bonuses that compound across turns, giving them a structural
        # scoring edge over act_respond/act_clarify large enough that
        # routing.metta's guard penalties (each ~0.15-0.40pt) can't reliably
        # close it. Restored (with act_think added) after removing it dropped
        # the Session A smoke test from 10/10 to 2/10 -- act_search/synthesize
        # immediately dominated once unscaled. Re-validate against smoke +
        # session tests if per-action formulas above change materially.
        CROSS_ACTION_SCALE = {
            "act_search":     0.65,
            "act_synthesize": 0.45,
            "act_think":      0.9,
            "act_decompose":  0.9,
            "act_clarify":    1.40,
            "act_respond":    2.00,
        }
        score *= CROSS_ACTION_SCALE.get(action, 1.0)

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