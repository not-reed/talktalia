"""Dictation daemon entry point — JSONL over stdio."""

import json
import sys
import threading
import signal

from .engine import DictationEngine

_stdout_lock = threading.Lock()


def emit_event(event, text=None):
    msg = {"event": event}
    if text is not None:
        msg["text"] = text
    with _stdout_lock:
        sys.stdout.write(json.dumps(msg) + "\n")
        sys.stdout.flush()


def emit_error(message):
    with _stdout_lock:
        sys.stdout.write(json.dumps({"event": "error", "message": message}) + "\n")
        sys.stdout.flush()


def main():
    model = "base"
    language = "en"
    device = "cpu"
    compute_type = "auto"
    engine = None

    def shutdown():
        if engine:
            engine.shutdown()
        sys.exit(0)

    signal.signal(signal.SIGTERM, lambda *_: shutdown())
    signal.signal(signal.SIGINT, lambda *_: shutdown())

    try:
        engine = DictationEngine(emit_event, model=model, language=language, device=device, compute_type=compute_type)
        engine.initialize()
    except Exception as e:
        emit_error(f"Failed to initialize: {e}")
        sys.exit(1)

    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue

        try:
            cmd = json.loads(line)
        except json.JSONDecodeError as e:
            emit_error(f"Invalid JSON: {e}")
            continue

        action = cmd.get("cmd")

        if action == "start":
            try:
                engine.start()
            except Exception as e:
                emit_error(f"Start failed: {e}")

        elif action == "stop":
            try:
                engine.stop()
            except Exception as e:
                emit_error(f"Stop failed: {e}")

        elif action == "cancel":
            try:
                engine.cancel()
            except Exception as e:
                emit_error(f"Cancel failed: {e}")

        elif action == "configure":
            new_model = cmd.get("model")
            new_lang = cmd.get("language")
            new_silence = cmd.get("silenceDuration")
            engine.configure(model=new_model, language=new_lang, silence_duration=new_silence)

        elif action == "shutdown":
            shutdown()

        else:
            emit_error(f"Unknown command: {action}")

    # stdin closed
    shutdown()


if __name__ == "__main__":
    main()
