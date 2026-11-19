Recorded niri event streams (`niri msg --json event-stream`), one event per line, with app ids and titles replaced. `startup.jsonl` is the burst niri sends when a client starts listening, including the reply to the request. `session.jsonl` continues it, and `unplug.jsonl` is the workspace list after the second monitor is unplugged.

`tests/tst_niriState.qml` replays them into `services/niriState.js`, and `tests/fake_niri.py` serves them to the shell tests.
