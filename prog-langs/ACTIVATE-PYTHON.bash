#!/usr/bin/env bash
# Source this file; do not execute it.

# Do not use the generic name SCRIPT_DIR here: this file is normally sourced
# from dev/SETUP.bash, so assignments made here remain visible to the caller.
_NER_LOCALE_PYTHON_ACTIVATE_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
# shellcheck source=_common.bash
source "$_NER_LOCALE_PYTHON_ACTIVATE_DIR/_common.bash"

activate=$(python_venv_activate) || {
    unset _NER_LOCALE_PYTHON_ACTIVATE_DIR
    return 1
}
if [ ! -f "$activate" ]; then
    echo "Python environment is not installed." >&2
    echo "Run: ./dev/prog-langs/INSTALL-PYTHON.sh" >&2
    unset _NER_LOCALE_PYTHON_ACTIVATE_DIR
    return 1
fi

# Resolve both paths when possible so that harmless spelling differences such
# as symlinks do not cause us to re-activate the same environment.  Comparing
# the complete path (rather than only the basename) avoids treating a venv from
# another checkout with the same name as the NER Locale environment.
_ner_locale_canonical_dir() {
    if [ -d "$1" ]; then
        (cd -- "$1" 2>/dev/null && pwd -P) || printf '%s\n' "$1"
    else
        printf '%s\n' "$1"
    fi
}

_ner_locale_target_venv=$(_ner_locale_canonical_dir "$NER_LOCALE_PYTHON_VENV_DIR")
_ner_locale_active_venv=""
if [ -n "${VIRTUAL_ENV:-}" ]; then
    _ner_locale_active_venv=$(_ner_locale_canonical_dir "$VIRTUAL_ENV")
fi

if [ -n "$_ner_locale_active_venv" ] && [ "$_ner_locale_active_venv" = "$_ner_locale_target_venv" ]; then
    export NER_LOCALE_PYTHON_VENV="$NER_LOCALE_PYTHON_VENV_DIR"
    echo "Python virtual environment already active: $NER_LOCALE_PYTHON_VENV_NAME"
    echo "Activated Python: $(python --version 2>&1)"
else
    if [ -n "${VIRTUAL_ENV:-}" ]; then
        echo "Switching Python virtual environment:"
        echo "  from: $VIRTUAL_ENV"
        echo "  to:   $NER_LOCALE_PYTHON_VENV_DIR"
    fi

    # shellcheck disable=SC1090
    source "$activate"
    export NER_LOCALE_PYTHON_VENV="$NER_LOCALE_PYTHON_VENV_DIR"
    echo "Activated Python: $(python --version 2>&1)"
    echo "Virtual environment: $NER_LOCALE_PYTHON_VENV_DIR"
fi

unset activate
unset _ner_locale_target_venv
unset _ner_locale_active_venv
unset -f _ner_locale_canonical_dir
unset _NER_LOCALE_PYTHON_ACTIVATE_DIR
