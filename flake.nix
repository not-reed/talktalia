{
  description = "Talktalia — speech-to-text dictation daemon for Noctalia";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }: {
    packages.x86_64-linux.dictation-daemon =
      let
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        lib = pkgs.lib;
        fhsEnv = pkgs.buildFHSEnv {
          name = "dictation-daemon";

          targetPkgs = pkgs: with pkgs; [
            python311
            uv
            gcc
            pkg-config
            portaudio
            alsa-lib
            pulseaudio
            ffmpeg
            zlib
            stdenv.cc.cc.lib
          ];

          runScript = pkgs.writeShellScript "dictation-daemon-run" ''
            set -euo pipefail

            VENV_DIR="''${XDG_DATA_HOME:-$HOME/.local/share}/dictation-daemon"
            PROJECT_DIR="${self}/talktalia/daemon"

            if [ ! -f "$VENV_DIR/.synced" ] || \
               [ "$PROJECT_DIR/pyproject.toml" -nt "$VENV_DIR/.synced" ]; then
              mkdir -p "$VENV_DIR"
              UV_PYTHON=python3.11 UV_PROJECT_ENVIRONMENT="$VENV_DIR/venv" uv sync --project "$PROJECT_DIR" 2>&1 | while IFS= read -r line; do
                printf '{"event":"model_loading","detail":"%s"}\n' "$line"
              done
              touch "$VENV_DIR/.synced"
            fi

            cd "$VENV_DIR"
            exec env UV_PYTHON=python3.11 UV_PROJECT_ENVIRONMENT="$VENV_DIR/venv" uv run --project "$PROJECT_DIR" python -m dictation_daemon "$@"
          '';

          profile = ''
            export LD_LIBRARY_PATH="${lib.makeLibraryPath (with pkgs; [ portaudio alsa-lib pulseaudio ])}"
            export C_INCLUDE_PATH="${pkgs.portaudio}/include"
            export LIBRARY_PATH="${pkgs.portaudio}/lib"
          '';
        };
      in fhsEnv;

    packages.x86_64-linux.default = self.packages.x86_64-linux.dictation-daemon;
  };
}
