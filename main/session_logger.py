"""
Writes the same log/eval file set as MetaMo-Prototype's runner.py +
run_logger.py, driven from MeTTa turn records passed in via py-call.

Ported fields (verified against a real MetaMo run_20260812_132800):
    logs/{run_id}/run_meta.json
    logs/{run_id}/turns.json
    logs/{run_id}/turns.csv
    logs/{run_id}/eval/strict_per_turn.json
    logs/{run_id}/eval/strict_per_session.json
    logs/{run_id}/eval/strict_overall.json
    logs/{run_id}/eval/evaluation_results.json

Fields with no MeTTa-side source yet (operators/homeostasis.metta has no
trigger_count/trigger_keys/mode logic, and full-step does not generate a
free-text answer) are emitted as null/empty placeholders to keep the JSON
shape identical to MetaMo's output, per explicit instruction.

evaluation_results.json's schema (turn_count/strict_accuracy/soft_accuracy/
top3_hit_rate/average_decision_margin/predicted_action_counts/
expected_action_counts/confusion_matrix/sessions/turns) is ported directly
from usecase/metrics/qwestor_eval.py's _metrics_for/_build_evaluation.
write_logs calls plot_evaluation_results.save_figures() directly on that
same dict at the end of every run (best-effort, never fails the run itself),
so logs/{run_id}/eval/plots/*.png are produced automatically -- no separate
manual `python plot_evaluation_results.py` step needed.
"""

from __future__ import annotations

import csv
import json
from collections import Counter, defaultdict
from datetime import datetime
from pathlib import Path
import sys
from typing import Any

SOFT_CREDIT = 0.8

GOAL_NAMES = [
    "efficiency", "accuracy", "success_moderate", "knowledge", "novelty",
    "success_breakthrough", "coherence", "originality", "social",
    "help_short", "help_long", "over_beneficial", "over_safety",
    "over_honesty",
]

MODULATOR_NAMES = [
    "urgency", "resolution", "user_expertise", "threshold",
    "topic_familiarity", "failure_wariness", "securing", "approach",
    "arousal", "risk_aversion", "error_tolerance", "creativity", "valence",
]

ANTI_GOAL_NAMES = ["hallucinate", "redundant", "rabbit_hole", "premature"]

CONTEXT_KEYS = [
    "complexity", "threshold", "ambiguity", "urgent", "intent_type",
    "expertise", "topic_familiarity", "failure_signal", "verify_request",
    "reflective_intent", "needs_external_evidence", "needs_task_plan",
    "needs_multi_source_integration", "valence",
]

CSV_FIELDS = [
    "run_id", "timestamp", "session", "turn", "query", "action",
    "style_modifier", "intent_type", "complexity", "ambiguity", "threshold",
    "arousal", "risk_aversion", "resolution", "topic_familiarity",
    "confidence", "low_confidence", "over_beneficial", "over_safety",
    "over_honesty", "hallucinate", "redundant", "rabbit_hole", "premature",
    "homeo_mode", "homeo_trigger_count", "homeo_trigger_keys",
    "context_memory_enabled", "context_window_turns", "score_top3",
    "answer",
]


def _flatten_metta_list(data: Any) -> list:
    """Flattens a MeTTa (Cons h t) list or nested tuple into a flat Python 
    list of 15-element records. Bypasses the string 'Cons' which causes 
    unpacking errors."""
    out = []
    if not isinstance(data, (list, tuple)):
        return out
        
    if len(data) == 3 and data[0] == "Cons":
        out.extend(_flatten_metta_list(data[1]))
        out.extend(_flatten_metta_list(data[2]))
    elif len(data) == 15:
        out.append(data)
    else:
        for item in data:
            if item == "Cons" or item == [] or item == ():
                continue
            if isinstance(item, (list, tuple)):
                if len(item) == 15:
                    out.append(item)
                else:
                    out.extend(_flatten_metta_list(item))
    return out

def _flatten_scalar_list(data: Any) -> list:
    """Flattens a MeTTa (Cons head tail) list of scalar strings into a flat
    Python list. Mirrors _flatten_metta_list's Cons-walking logic but for
    leaf scalars (e.g. acceptable_actions) instead of 15-element records."""
    if data is None:
        return []
    if isinstance(data, str):
        return [] if data == "Cons" else [data]
    if not isinstance(data, (list, tuple)):
        return []
    if len(data) == 3 and data[0] == "Cons":
        out = []
        head, tail = data[1], data[2]
        out.extend(_flatten_scalar_list(head))
        out.extend(_flatten_scalar_list(tail))
        return out
    out = []
    for item in data:
        if item == "Cons" or item == [] or item == ():
            continue
        out.extend(_flatten_scalar_list(item))
    return out


def _safe_float(val):
    """Safely converts a value to float, returning 0.0 if it's an unevaluated list/expression."""
    try:
        return float(val)
    except (TypeError, ValueError):
        return 0.0

def _pairs_to_dict(pairs: Any, strip_prefix: str = "") -> dict:
    """MeTTa association lists arrive as nested lists/tuples of
    [key, value] (mirroring context_parser.wrap_parser's own return
    convention). Normalize whatever shape py-call hands us into a dict.
    Modulator keys carry an m_ prefix on the MeTTa side (m_urgency) but
    the real turns.json sample uses unprefixed names (urgency) - strip
    it here so the ported output matches MetaMo's field names exactly.
    """
    out: dict = {}
    if not pairs:
        return out
    for item in pairs:
        try:
            k, v = item[0], item[1]
        except (TypeError, IndexError, KeyError):
            continue
        key = str(k)
        if strip_prefix and key.startswith(strip_prefix):
            key = key[len(strip_prefix):]
        out[key] = v
    return out


def _floatify(d: dict, keys: list[str]) -> dict:
    result = {}
    for k in keys:
        v = d.get(k, 0.0)
        try:
            result[k] = float(v)
        except (TypeError, ValueError):
            result[k] = v
    return result


def _score_top3_from_sorted(sorted_scores: Any) -> list[list]:
    """Normalizes and re-sorts entries into the top 3 [action_name, score]
    pairs, highest score first.

    operators/decision.metta's sort_scores (line 758) builds
    ($score act_name) pairs -- score first, name second -- the reverse of
    the (name, score) convention this function originally assumed. That
    mismatch meant float(score) always raised trying to convert the action
    name string, got swallowed by the except below, and every entry was
    silently dropped: score_top3 (and downstream decision_margin /
    top3_hit_rate) have been empty in every run so far, going back to at
    least run_20260820_014750. Detecting orientation per-entry fixes the
    immediate bug; explicitly re-sorting here (rather than trusting
    incoming order) also sidesteps needing to confirm which direction
    MeTTa's `sort` builtin orders ascending vs descending.
    """
    parsed: list[tuple[str, float]] = []
    if not sorted_scores:
        return []
    for entry in sorted_scores:
        try:
            a, b = entry[0], entry[1]
        except (TypeError, IndexError):
            continue
        try:
            score, name = float(a), b
        except (TypeError, ValueError):
            try:
                score, name = float(b), a
            except (TypeError, ValueError):
                continue
        parsed.append((str(name), score))
    parsed.sort(key=lambda item: item[1], reverse=True)
    return [[name, score] for name, score in parsed[:3]]


def _format_score_top3_text(score_top3: list[list]) -> str:
    parts = []
    for name, score in score_top3:
        try:
            parts.append(f"{name}={float(score):.3f}")
        except (TypeError, ValueError):
            continue
    return " | ".join(parts)


def _decision_margin(score_top3: list[list]) -> float | None:
    """Top-1 minus top-2 score, the same quantity manually eyeballed in
    debug notes ('search 2.97 vs think 2.81'). None when fewer than two
    candidates were scored."""
    if len(score_top3) < 2:
        return None
    try:
        return round(float(score_top3[0][1]) - float(score_top3[1][1]), 6)
    except (TypeError, ValueError, IndexError):
        return None


def _metrics_for(turns: list[dict]) -> dict[str, Any]:
    """Aggregate metrics for a list of enriched turn records. Ported from
    usecase/metrics/qwestor_eval.py's _metrics_for so the output here is
    schema-compatible with usecase/plot_evaluation_results.py."""
    labeled = [t for t in turns if t.get("expected_action")]
    strict_total = sum(int(t.get("strict_correct") or 0) for t in labeled)
    soft_total = sum(float(t.get("soft_score") or 0.0) for t in labeled)
    margins = [
        float(t["decision_margin"]) for t in labeled
        if t.get("decision_margin") is not None
    ]
    turn_count = len(labeled)

    predicted_counts = Counter(
        str(t.get("predicted_action", "")) for t in labeled if t.get("predicted_action")
    )
    expected_counts = Counter(
        str(t.get("expected_action", "")) for t in labeled if t.get("expected_action")
    )
    top3_hits = sum(1 for t in labeled if t.get("top3_hit"))

    confusion: dict[str, Counter] = defaultdict(Counter)
    for t in labeled:
        expected = str(t.get("expected_action", ""))
        predicted = str(t.get("predicted_action", ""))
        if expected and predicted:
            confusion[expected][predicted] += 1

    return {
        "turn_count": turn_count,
        "strict_correct": strict_total,
        "strict_accuracy": round(strict_total / turn_count, 6) if turn_count else None,
        "soft_accuracy": round(soft_total / turn_count, 6) if turn_count else None,
        "top3_hit_rate": round(top3_hits / turn_count, 6) if turn_count else None,
        "average_decision_margin": (
            round(sum(margins) / len(margins), 6) if margins else None
        ),
        "predicted_action_counts": dict(sorted(predicted_counts.items())),
        "expected_action_counts": dict(sorted(expected_counts.items())),
        "confusion_matrix": {
            expected: dict(sorted(predicted.items()))
            for expected, predicted in sorted(confusion.items())
        },
    }


def write_logs(run_records: Any, base_dir_str: str) -> list:
    """
    run_records: a MeTTa list of turn records, each shaped as
        (session_name turn_index query expected_action acceptable_actions
         predicted_action pre_goals pre_mods pre_anti pre_context
         post_goals post_mods post_anti sorted_scores style_modifier)

    where each of pre_goals/pre_mods/... is itself a list of [key value]
    pairs (association-list convention, matching wrap_parser's output).

    Returns the run_id as a string so the MeTTa side can log/println it.
    """
    base_dir = Path(__file__).resolve().parent.parent
    run_timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    run_id = f"run_{run_timestamp}"
    logs_dir = base_dir / "logs" / run_id
    eval_dir = logs_dir / "eval"
    logs_dir.mkdir(parents=True, exist_ok=True)
    eval_dir.mkdir(parents=True, exist_ok=True)

    # Flatten the MeTTa Cons list into a normal Python list of 15-element records
    flat_records = _flatten_metta_list(run_records)

    turn_json_records: list[dict] = []
    strict_turn_records: list[dict] = []
    session_names_seen: list[str] = []

    per_session: dict[str, dict] = {}

    csv_path = logs_dir / "turns.csv"
    with csv_path.open("w", newline="", encoding="utf-8") as csv_file:
        csv_writer = csv.DictWriter(csv_file, fieldnames=CSV_FIELDS)
        csv_writer.writeheader()

        for rec in flat_records:
            (
                session_name, turn_index, query, expected_action,
                acceptable_actions, predicted_action,
                pre_goals_raw, pre_mods_raw, pre_anti_raw, context_raw,
                post_goals_raw, post_mods_raw, post_anti_raw,
                sorted_scores_raw, style_modifier,
            ) = rec

            session_name = str(session_name)
            turn_index = int(turn_index)
            query = str(query)
            expected_action = str(expected_action)
            predicted_action = str(predicted_action)
            acceptable_list = [str(a) for a in _flatten_scalar_list(acceptable_actions)]
            style_modifier = (
                "" if style_modifier in (None, "no-style") else str(style_modifier)
            )

            if session_name not in session_names_seen:
                session_names_seen.append(session_name)
                per_session[session_name] = {
                    "strict_correct": 0, "turn_count": 0, "soft_score_sum": 0.0,
                }

            pre_goals = _floatify(_pairs_to_dict(pre_goals_raw), GOAL_NAMES)
            pre_mods = _floatify(_pairs_to_dict(pre_mods_raw, "m_"), MODULATOR_NAMES)
            pre_anti = _floatify(_pairs_to_dict(pre_anti_raw), ANTI_GOAL_NAMES)
            post_goals = _floatify(_pairs_to_dict(post_goals_raw), GOAL_NAMES)
            post_mods = _floatify(_pairs_to_dict(post_mods_raw, "m_"), MODULATOR_NAMES)
            post_anti = _floatify(_pairs_to_dict(post_anti_raw), ANTI_GOAL_NAMES)
            context = _pairs_to_dict(context_raw)
            context = {k: context.get(k) for k in CONTEXT_KEYS if k in context}
            # No MeTTa-side calibration logging exists yet; keep the shape
            # identical to MetaMo's output with an explicit empty marker.
            context["parser_calibration"] = {
                "enabled": False, "raw": {}, "output": {},
            }

            score_top3 = _score_top3_from_sorted(sorted_scores_raw)
            decision_margin = _decision_margin(score_top3)
            top3_hit = expected_action in {name for name, _ in score_top3}

            strict_correct = int(predicted_action == expected_action)
            acceptable_hit = int(
                predicted_action in acceptable_list and not strict_correct
            )
            soft_score = (
                1.0 if strict_correct else (SOFT_CREDIT if acceptable_hit else 0.0)
            )

            per_session[session_name]["strict_correct"] += strict_correct
            per_session[session_name]["turn_count"] += 1
            per_session[session_name]["soft_score_sum"] += soft_score

            turn_timestamp = datetime.now().isoformat(timespec="seconds")

            turn_json_records.append({
                "run_id": run_id,
                "timestamp": turn_timestamp,
                "session": session_name,
                "turn": turn_index,
                "query": query,
                "context": context,
                "decision": {
                    "action": predicted_action,
                    "style_modifier": style_modifier or None,
                    "reason": None,
                    "score_top3": score_top3,
                },
                "pre_update": {
                    "cold_weight": None,
                    "modulators": pre_mods,
                    "goals": pre_goals,
                    "anti_goals": pre_anti,
                },
                "post_update": {
                    "modulators": post_mods,
                    "goals": post_goals,
                    "anti_goals": post_anti,
                },
                "homeostasis": {
                    "mode": None,
                    "trigger_count": None,
                    "trigger_keys": [],
                },
                "context_memory": {
                    "enabled": None,
                    "window_turns": None,
                },
                "answer": "",
            })

            strict_turn_records.append({
                "session": session_name,
                "turn": turn_index,
                "query": query,
                "expected_action": expected_action,
                "acceptable_actions": acceptable_list,
                "predicted_action": predicted_action,
                "strict_correct": strict_correct,
                "acceptable_hit": acceptable_hit,
                "soft_score": soft_score,
                "decision_margin": decision_margin,
                "top3_hit": top3_hit,
            })

            score_top3_text = _format_score_top3_text(score_top3)
            csv_writer.writerow({
                "run_id": run_id,
                "timestamp": turn_timestamp,
                "session": session_name,
                "turn": turn_index,
                "query": query,
                "action": predicted_action,
                "style_modifier": style_modifier,
                "intent_type": context.get("intent_type", ""),
                "complexity": f"{_safe_float(context.get('complexity')):.4f}",
                "ambiguity": f"{_safe_float(context.get('ambiguity')):.4f}",
                "threshold": f"{_safe_float(context.get('threshold')):.4f}",
                "arousal": f"{_safe_float(post_mods.get('arousal', 0.0)):.4f}",
                "risk_aversion": f"{_safe_float(post_mods.get('risk_aversion', 0.0)):.4f}",
                "resolution": f"{_safe_float(post_mods.get('resolution', 0.0)):.4f}",
                "topic_familiarity": f"{_safe_float(post_mods.get('topic_familiarity', 0.0)):.4f}",
                "confidence": "",
                "low_confidence": f"{max(0.0, min(1.0, 1.0 - _safe_float(context.get('threshold')))):.4f}",
                "over_beneficial": f"{_safe_float(post_goals.get('over_beneficial', 0.0)):.4f}",
                "over_safety": f"{_safe_float(post_goals.get('over_safety', 0.0)):.4f}",
                "over_honesty": f"{_safe_float(post_goals.get('over_honesty', 0.0)):.4f}",
                "hallucinate": f"{_safe_float(post_anti.get('hallucinate', 0.0)):.4f}",
                "redundant": f"{_safe_float(post_anti.get('redundant', 0.0)):.4f}",
                "rabbit_hole": f"{_safe_float(post_anti.get('rabbit_hole', 0.0)):.4f}",
                "premature": f"{_safe_float(post_anti.get('premature', 0.0)):.4f}",
                "homeo_mode": "",
                "homeo_trigger_count": "",
                "homeo_trigger_keys": "",
                "context_memory_enabled": "",
                "context_window_turns": "",
                "score_top3": score_top3_text,
                "answer": "",
            })

    with (logs_dir / "turns.json").open("w", encoding="utf-8") as f:
        json.dump(turn_json_records, f, ensure_ascii=True, indent=2)

    with (logs_dir / "run_meta.json").open("w", encoding="utf-8") as f:
        json.dump({
            "run_id": run_id,
            "created_at": datetime.now().isoformat(timespec="seconds"),
            "sessions": session_names_seen,
            "run_config": {"session_set": "short", "session_file": "session.py"},
        }, f, ensure_ascii=True, indent=2)

    strict_session_records = []
    total_correct = 0
    total_turns = 0
    soft_total_score = 0.0
    for name in session_names_seen:
        s = per_session[name]
        accuracy = (
            float(s["strict_correct"]) / float(s["turn_count"])
            if s["turn_count"] else 0.0
        )
        strict_session_records.append({
            "session": name,
            "strict_correct": s["strict_correct"],
            "turn_count": s["turn_count"],
            "strict_accuracy": accuracy,
            "soft_score_sum": s["soft_score_sum"],
            "soft_accuracy": (
                float(s["soft_score_sum"]) / float(s["turn_count"])
                if s["turn_count"] else 0.0
            ),
        })
        total_correct += s["strict_correct"]
        total_turns += s["turn_count"]
        soft_total_score += s["soft_score_sum"]

    overall_accuracy = (
        float(total_correct) / float(total_turns) if total_turns else 0.0
    )
    strict_overall = {
        "strict_correct": total_correct,
        "turn_count": total_turns,
        "strict_accuracy": overall_accuracy,
        "soft_score_sum": soft_total_score,
        "soft_accuracy": (
            float(soft_total_score) / float(total_turns) if total_turns else 0.0
        ),
        "soft_credit_for_~": SOFT_CREDIT,
        "session_set": "short",
    }

    # decision_margin / confusion_matrix / top3_hit_rate, computed over the
    # same strict_turn_records (now carrying decision_margin + top3_hit per
    # turn) via the qwestor_eval.py-ported _metrics_for helper.
    overall_metrics = _metrics_for(strict_turn_records)
    sessions_metrics = {
        name: _metrics_for([t for t in strict_turn_records if t["session"] == name])
        for name in session_names_seen
    }

    strict_overall.update({
        "top3_hit_rate": overall_metrics["top3_hit_rate"],
        "average_decision_margin": overall_metrics["average_decision_margin"],
        "predicted_action_counts": overall_metrics["predicted_action_counts"],
        "expected_action_counts": overall_metrics["expected_action_counts"],
        "confusion_matrix": overall_metrics["confusion_matrix"],
    })
    for rec in strict_session_records:
        rec.update({
            k: v for k, v in sessions_metrics[rec["session"]].items()
            if k not in ("turn_count", "strict_correct", "strict_accuracy", "soft_accuracy")
        })

    evaluation_results = {
        "generated_at": datetime.now().isoformat(timespec="seconds"),
        "source_run_id": run_id,
        **overall_metrics,
        "unlabeled_turn_count": total_turns - overall_metrics["turn_count"],
        "sessions": sessions_metrics,
        "turns": strict_turn_records,
    }

    with (eval_dir / "strict_per_turn.json").open("w", encoding="utf-8") as f:
        json.dump(strict_turn_records, f, ensure_ascii=True, indent=2)
    with (eval_dir / "strict_per_session.json").open("w", encoding="utf-8") as f:
        json.dump(strict_session_records, f, ensure_ascii=True, indent=2)
    with (eval_dir / "strict_overall.json").open("w", encoding="utf-8") as f:
        json.dump(strict_overall, f, ensure_ascii=True, indent=2)
    with (eval_dir / "evaluation_results.json").open("w", encoding="utf-8") as f:
        json.dump(evaluation_results, f, ensure_ascii=True, indent=2)

    print(f"Strict accuracy: {total_correct}/{total_turns} = {overall_accuracy:.3f}")
    print(
        f"Soft accuracy: {soft_total_score:.1f}/{total_turns} = "
        f"{strict_overall['soft_accuracy']:.3f}"
    )
    print(
        f"Top-3 hit rate: {overall_metrics['top3_hit_rate']}, "
        f"avg decision margin: {overall_metrics['average_decision_margin']}"
    )
    print(f"Saved eval files to {eval_dir}")
    print(f"Saved logs to {logs_dir}")

    # Auto-plot: fires every time this function runs, regardless of whether
    # it's invoked via run-tests.sh, a raw `petta` call, or anything else,
    # since it's a direct in-process call rather than something that needs
    # separate shell wiring. save_figures() takes the evaluation_results
    # dict we already built above -- no need to re-read the JSON we just
    # wrote. Wrapped defensively: a plotting failure (missing matplotlib,
    # unexpected data shape, etc.) must never take down the actual eval run
    # that produced the numbers in the first place.
    try:
        import sys as _sys
        _main_dir = str(Path(__file__).resolve().parent)
        if _main_dir not in _sys.path:
            _sys.path.insert(0, _main_dir)
        from plot_evaluation_results import save_figures
        plot_dir = eval_dir / "plots"
        session_png, overall_png = save_figures(evaluation_results, plot_dir, dpi=180)
        print(f"Saved plots to {plot_dir}")
    except Exception as exc:  # noqa: BLE001 - plotting is best-effort
        print(f"(plot generation skipped: {exc})")
    sys._exit(0)
    # Returned as a plain list (not a dict) since py-call results cross
    # back into MeTTa most predictably as an ordered pair list here,
    # matching the [key, value] convention used elsewhere in this repo.
    return [run_id, total_correct, total_turns]