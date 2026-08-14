from pathlib import Path
import importlib.util


def _load_session_module():
    sessions_file = Path(__file__).parent / "session.py"
    spec = importlib.util.spec_from_file_location("_sessions", sessions_file)
    if spec is None or spec.loader is None:
        raise ImportError(f"Could not load session module from {sessions_file}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return getattr(module, "SESSIONS", [])


def _to_metta_list(atoms):
    result = "()"
    for atom in reversed(atoms):
        result = f"(Cons {atom} {result})"
    return result


def load_queries():
    sessions = _load_session_module()

    result = []
    for session in sessions:
        query_atoms = []
        for q in session["queries"]:
            escaped = q.replace('"', '\\"')
            query_atoms.append(f'"{escaped}"')
        result.append(_to_metta_list(query_atoms))

    return _to_metta_list(result)


def _escape(text):
    return str(text).replace("\\", "\\\\").replace('"', '\\"')


def load_sessions_full(limit=None, names=None):
    """Return every session as a MeTTa cons-list of turn records:

    (Cons
      (Session "<name>"
        (Cons (Turn "<query>" expected_action (Cons acc1 (Cons acc2 ())))
              ... )) rest)

    expected_action and acceptable_actions are emitted as bare MeTTa
    symbols (not quoted strings) so they compare directly against the
    `act_*` symbols produced by selectAction/full-step.

    limit: if set, only the first N sessions are included (for smoke
    testing without burning the full LLM call budget on every run).
    names: if set, only sessions whose name is in this list are included
    (takes priority over limit when both are given).
    """
    return _load_sessions_full_filtered(limit=limit, names=names)


def load_session_a_smoke():
    """Zero-argument smoke-test entry point: only Session A. Kept as a
    dedicated function (rather than relying on py-call marshalling None
    and a string tuple into load_sessions_full's optional args) since
    that argument-passing behavior hasn't been verified against a real
    petta install."""
    return _load_sessions_full_filtered(names=["Session A - 10 turn mixed stress"])


def _load_sessions_full_filtered(limit=None, names=None):
    sessions = _load_session_module()

    if names:
        sessions = [s for s in sessions if s.get("name") in names]
    elif limit:
        sessions = sessions[:limit]

    session_atoms = []
    for session in sessions:
        name = _escape(session.get("name", ""))
        queries = session.get("queries", [])
        expected_actions = session.get("expected_actions", [])
        acceptable_actions = session.get(
            "acceptable_actions", [[] for _ in queries]
        )

        turn_atoms = []
        for query, expected, acceptable in zip(
            queries, expected_actions, acceptable_actions
        ):
            q_escaped = _escape(query)
            acc_list = _to_metta_list(acceptable)
            turn_atoms.append(
                f'(Turn "{q_escaped}" {expected} {acc_list})'
            )

        session_atoms.append(
            f'(Session "{name}" {_to_metta_list(turn_atoms)})'
        )

    return _to_metta_list(session_atoms)