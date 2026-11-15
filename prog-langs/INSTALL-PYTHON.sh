#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
# shellcheck source=_common.bash
source "$SCRIPT_DIR/_common.bash"

"$SCRIPT_DIR/DOWNLOAD-PYTHON.sh"
archive="$NER_LOCALE_DOWNLOAD_DIR/$(python_archive_name)"
install=$(python_install_path)
python_exe=$(python_base_executable)

python_matches() {
    [ -x "$python_exe" ] || return 1
    version=$("$python_exe" -c 'import sys; print(".".join(map(str, sys.version_info[:3])))' 2>/dev/null || true)
    [ "$version" = "$NER_LOCALE_PYTHON_VERSION" ]
}

if python_matches; then
    echo "Portable Python already installed:"
    echo "  $install"
else
    echo "Installing portable Python $NER_LOCALE_PYTHON_VERSION"
    tmp="$NER_LOCALE_PROG_LANGS_DIR/.tmp-python-$$"
    rm -rf "$tmp"
    mkdir -p "$tmp"
    trap 'rm -rf "$tmp"' EXIT
    tar -xzf "$archive" -C "$tmp"
    [ -d "$tmp/python" ] || fail "Python archive did not contain the expected python/ directory"
    rm -rf "$install"
    mv "$tmp/python" "$install"
    rm -rf "$tmp"
    trap - EXIT
    python_exe=$(python_base_executable)
    python_matches || fail "Installed Python does not report version $NER_LOCALE_PYTHON_VERSION"
    echo "Installed portable Python:"
    echo "  $install"
fi

venv_python=$(python_venv_executable)
venv_ok=0
if [ -x "$venv_python" ]; then
    venv_version=$("$venv_python" -c 'import sys; print(".".join(map(str, sys.version_info[:3])))' 2>/dev/null || true)
    if [ "$venv_version" = "$NER_LOCALE_PYTHON_VERSION" ]; then
        venv_ok=1
    fi
fi

if [ "$venv_ok" -eq 0 ]; then
    echo "Creating virtual environment:"
    echo "  $NER_LOCALE_PYTHON_VENV_DIR"
    rm -rf "$NER_LOCALE_PYTHON_VENV_DIR"
    "$python_exe" -m venv "$NER_LOCALE_PYTHON_VENV_DIR"
else
    echo "Virtual environment already present:"
    echo "  $NER_LOCALE_PYTHON_VENV_DIR"
fi

venv_python=$(python_venv_executable)
if [ "${NER_LOCALE_DEV_SKIP_PIP_UPGRADE:-0}" != "1" ]; then
    echo "Updating pip/setuptools/wheel in $NER_LOCALE_PYTHON_VENV_NAME"
    "$venv_python" -m pip install --upgrade pip setuptools wheel
fi

# Keep dependency versions in the workbench's pyproject.toml. Use a relative
# editable requirement: Windows pip cannot interpret Git Bash's /c/... paths
# when extras are appended to them.
workbench_dir=$(cd -- "$NER_LOCALE_DEV_ROOT/.." && pwd -P)
if [ -f "$workbench_dir/pyproject.toml" ]; then
    echo "Installing GLiNER, GLiNER2 and computation measurement packages"
    (
        cd -- "$workbench_dir"
        "$venv_python" -c '
import pathlib
import tomllib

project = tomllib.loads(pathlib.Path("pyproject.toml").read_text(encoding="utf-8"))["project"]
required = {"gliner", "gliner2", "telemetry"}
if project.get("name") != "ner-locale-workbench" or not required <= project.get("optional-dependencies", {}).keys():
    raise SystemExit("Apply the GLiNER workbench overlay before installing these development tools.")
'
        "$venv_python" -m pip install -e ".[gliner,gliner2,telemetry]"
    )
else
    echo "No parent workbench pyproject.toml; skipping NER package installation."
fi

echo "Python environment ready. Activate with:"
echo "  source ./dev/prog-langs/ACTIVATE-PYTHON.bash"
