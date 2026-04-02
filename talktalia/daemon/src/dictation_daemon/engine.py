"""RealtimeSTT wrapper that emits events via callback."""

import threading
from RealtimeSTT import AudioToTextRecorder


class DictationEngine:
    def __init__(self, emit, model="base", language="en", device="cpu", compute_type="auto"):
        self._emit = emit
        self._model = model
        self._language = language
        self._device = device
        self._compute_type = compute_type
        self._silence_duration = 1.5
        self._recorder = None
        self._active = False

    def initialize(self):
        self._emit("model_loading")

        self._recorder = AudioToTextRecorder(
            model=self._model,
            language=self._language if self._language != "auto" else None,
            device=self._device,
            compute_type=self._compute_type,
            spinner=False,
            use_microphone=True,
            enable_realtime_transcription=True,
            realtime_model_type=self._model,
            on_recording_start=self._on_recording_start,
            on_recording_stop=self._on_recording_stop,
            on_realtime_transcription_update=self._on_partial,
            silero_sensitivity=0.4,
            post_speech_silence_duration=self._silence_duration,
            min_length_of_recording=0.3,
        )
        # Mute mic after init so it doesn't auto-listen
        self._recorder.set_microphone(False)
        self._emit("ready")

    def start(self):
        if self._recorder and not self._active:
            self._active = True
            self._recorder.set_microphone(True)
            self._recorder.start()
            # text() blocks until recording stops + transcription finishes
            threading.Thread(target=self._wait_and_transcribe, daemon=True).start()

    def stop(self):
        if self._recorder and self._active:
            self._recorder.stop()
            # _wait_and_transcribe thread will pick up the result

    def cancel(self):
        """Abort recording, discard audio, don't transcribe."""
        if self._recorder and self._active:
            self._active = False  # Tell _wait_and_transcribe to discard
            self._recorder.abort()
            self._recorder.set_microphone(False)
            self._emit("ready")

    def _wait_and_transcribe(self):
        """Called in background thread after start(). text() blocks until
        recording stops (by stop() or silence detection) and returns
        the transcribed text."""
        try:
            text = self._recorder.text()
            self._active = False
            self._recorder.set_microphone(False)
            if text and text.strip():
                self._emit("text", text.strip())
            else:
                self._emit("text", "")
        except Exception as e:
            self._active = False
            self._recorder.set_microphone(False)
            self._emit("error", str(e))
        self._emit("ready")

    def configure(self, model=None, language=None, silence_duration=None):
        if model:
            self._model = model
        if language:
            self._language = language
        if silence_duration is not None:
            self._silence_duration = silence_duration
            if self._recorder:
                self._recorder.post_speech_silence_duration = silence_duration

    def shutdown(self):
        self._active = False
        if self._recorder:
            try:
                self._recorder.shutdown()
            except Exception:
                pass
            self._recorder = None

    def _on_recording_start(self):
        if self._active:
            self._emit("listening")

    def _on_recording_stop(self):
        if self._active:
            self._emit("processing")

    def _on_partial(self, text):
        if self._active and text and text.strip():
            self._emit("partial", text.strip())
