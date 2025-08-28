#!/usr/bin/env sh
# Universal bisect helper for multi-language repos: Python, Node, Java, Go, Rust, R, Fortran, C/C++.
# Exit codes for `git bisect run`:
#   0   => "good"  (bug absent)
#   1..127 except 125 => "bad" (bug present)
#   125 => "skip" (can’t build/test this commit; do not classify)

set -eu

# -------------------------- CONFIG (edit these) --------------------------------
# Fastest reliable command that returns 0 when healthy (bug NOT present),
# non-zero when bug IS present. If set, this takes priority across stacks.
: "${BUG_PROBE_CMD:=}"     # e.g., "pytest -q -k test_handles_utf8_crash"

# Optional: cap test runtime so hung commits don't waste time.
: "${BUG_PROBE_TIMEOUT:=60s}"

# Optional: control CPU parallelism for builders that honor -j/threads flags.
: "${BISect_NPROC:=}"

# -------------------------- UTILITIES ------------------------------------------
log() { printf '%s\n' "$*" >&2; }
get_nproc() {
  if [ -n "${BISect_NPROC}" ]; then printf '%s\n' "$BISect_NPROC"; return; fi
  if command -v nproc >/dev/null 2>&1; then nproc
  elif [ "$(uname 2>/dev/null || echo Unknown)" = "Darwin" ]; then sysctl -n hw.ncpu 2>/dev/null || echo 2
  else echo 2
  fi
}
with_timeout() {
  _t="$1"; shift
  if command -v timeout >/dev/null 2>&1; then timeout --preserve-status "$_t" "$@"
  else "$@"
  fi
}

BISect_TMP="$(mktemp -d 2>/dev/null || mktemp -d -t bisect)"
trap 'rm -rf "$BISect_TMP"' EXIT INT TERM

export LC_ALL=C
export PYTHONDONTWRITEBYTECODE=1
export COLUMNS=80

# -------------------------- DETECTORS ------------------------------------------
is_python() { [ -f pyproject.toml ] || [ -f setup.py ] || [ -f setup.cfg ] || [ -d tests ] && command -v python >/dev/null 2>&1; }
is_node()   { [ -f package.json ] && command -v node >/dev/null 2>&1; }
is_java()   { [ -f pom.xml ] || [ -f build.gradle ] || [ -f settings.gradle ] || [ -f build.gradle.kts ]; }
is_go()     { [ -f go.mod ] && command -v go >/dev/null 2>&1; }
is_rust()   { [ -f Cargo.toml ] && command -v cargo >/dev/null 2>&1; }
is_r()      { [ -f DESCRIPTION ] || [ -d tests ] && command -v R >/dev/null 2>&1 || command -v Rscript >/dev/null 2>&1; }
is_fortran(){ [ -f fpm.toml ] || grep -iq 'fortran' Makefile 2>/dev/null || ls *.f *.f90 *.F90 2>/dev/null >/dev/null; }
is_cmake()  { [ -f CMakeLists.txt ]; }
has_make()  { [ -f Makefile ] || [ -f makefile ] || [ -f GNUmakefile ]; }

# -------------------------- CLEAN ----------------------------------------------
project_clean() {
  # Gentle cleanup to reduce cross-commit cache poison
  [ -d build ] && rm -rf build 2>/dev/null || true
  [ -d .pytest_cache ] && rm -rf .pytest_cache 2>/dev/null || true
  [ -d .tox ] && rm -rf .tox 2>/dev/null || true
  [ -d target ] && rm -rf target 2>/dev/null || true
  [ -d node_modules ] && true  # keep to speed up unless package-lock changed
  return 0
}

# -------------------------- BUILD (best-effort) --------------------------------
project_build() {
  # Makefile trumps most things (monorepos often wrap builds)
  if has_make; then
    make -s -j"$(get_nproc)" >/dev/null 2>&1 || return 125
    return 0
  fi

  # CMake (C/C++/Fortran)
  if is_cmake; then
    mkdir -p build && cd build || return 125
    cmake .. >/dev/null 2>&1 || return 125
    cmake --build . -- -j"$(get_nproc)" >/dev/null 2>&1 || return 125
    cd - >/dev/null 2>&1 || true
    return 0
  fi

  # Fortran via fpm (Fortran Package Manager)
  if is_fortran && command -v fpm >/dev/null 2>&1; then
    fpm build >/dev/null 2>&1 || return 125
    return 0
  fi

  # Rust
  if is_rust; then
    cargo build --quiet >/dev/null 2>&1 || return 125
    return 0
  fi

  # Go
  if is_go; then
    go build ./... >/dev/null 2>&1 || return 125
    return 0
  fi

  # Node.js
  if is_node; then
    if command -v npm >/dev/null 2>&1; then
      (npm ci >/dev/null 2>&1 || npm install >/dev/null 2>&1) || return 125
      if npm run >/dev/null 2>&1 | grep -q " build"; then npm run -s build >/dev/null 2>&1 || return 125; fi
      return 0
    fi
    return 125
  fi

  # Python (editable for speed; tolerate missing extras)
  if is_python; then
    if command -v python >/dev/null 2>&1; then
      VENV="$BISect_TMP/.venv"
      python -m venv "$VENV" >/dev/null 2>&1 || return 125
      # shellcheck disable=SC1090
      . "$VENV/bin/activate" || return 125
      pip -q install --upgrade pip >/dev/null 2>&1 || return 125
      pip -q install -e ".[test]" >/dev/null 2>&1 || pip -q install -e . >/dev/null 2>&1 || return 125
      deactivate || true
      return 0
    fi
    return 125
  fi

  # Java (Maven/Gradle)
  if is_java; then
    if [ -f pom.xml ] && command -v mvn >/dev/null 2>&1; then
      mvn -q -DskipTests package >/dev/null 2>&1 || return 125
      return 0
    fi
    if ( [ -f build.gradle ] || [ -f build.gradle.kts ] ) && command -v ./gradlew >/dev/null 2>&1; then
      ./gradlew -q assemble >/dev/null 2>&1 || return 125
      return 0
    fi
    if command -v gradle >/dev/null 2>&1; then
      gradle -q assemble >/dev/null 2>&1 || return 125
      return 0
    fi
    return 125
  fi

  # R typically doesn’t need a compile, but let tests build artifacts later.
  if is_r; then
    return 0
  fi

  # Nothing to build; script-only repo.
  return 0
}

# -------------------------- PROBES (return 0=good, nonzero=bad) ----------------
probe_python() {
  if command -v pytest >/dev/null 2>&1; then
    pytest -q -k "bug|regression|fail|crash" >/dev/null 2>&1 && return 0 || return 1
  fi
  # Fallback: run module CLI if present
  if [ -f setup.py ] && grep -q "entry_points" setup.py 2>/dev/null; then
    python -c "import pkgutil;import sys;sys.exit(0)"
  fi
  return 125
}

probe_node() {
  if command -v npm >/dev/null 2>&1; then
    if npm run >/dev/null 2>&1 | grep -q " test"; then
      npm -s test >/dev/null 2>&1 && return 0 || return 1
    fi
  fi
  return 125
}

probe_java() {
  if [ -f pom.xml ] && command -v mvn >/dev/null 2>&1; then
    mvn -q -Dtest='*Bug*Test,*Regression*' -DfailIfNoTests=false test >/dev/null 2>&1 && return 0 || return 1
  fi
  if ( [ -f build.gradle ] || [ -f build.gradle.kts ] ); then
    if command -v ./gradlew >/dev/null 2>&1; then
      ./gradlew -q test >/dev/null 2>&1 && return 0 || return 1
    elif command -v gradle >/dev/null 2>&1; then
      gradle -q test >/dev/null 2>&1 && return 0 || return 1
    fi
  fi
  return 125
}

probe_go() {
  go test ./... >/dev/null 2>&1 && return 0 || return 1
}

probe_rust() {
  cargo test --quiet >/dev/null 2>&1 && return 0 || return 1
}

probe_r() {
  # Prefer testthat; fall back to R CMD check for packages
  if command -v Rscript >/dev/null 2>&1; then
    if [ -d tests ] || grep -q "testthat" DESCRIPTION 2>/dev/null; then
      Rscript -e "quit(status=!testthat::test_dir('tests', reporter='silent'))" >/dev/null 2>&1 && return 0 || return 1
    fi
  fi
  if command -v R >/dev/null 2>&1 && [ -f DESCRIPTION ]; then
    R CMD check --no-manual --no-tests . >/dev/null 2>&1 || true
    # If CMD check even runs, we rely on explicit tests; otherwise inconclusive
    return 125
  fi
  return 125
}

probe_fortran() {
  # If fpm is present, use its test runner
  if command -v fpm >/dev/null 2>&1 && [ -f fpm.toml ]; then
    fpm test >/dev/null 2>&1 && return 0 || return 1
  fi
  # If CMake/Make built an executable with "test" or in build/, try to run it
  if [ -x build/tests ] ; then ./build/tests >/dev/null 2>&1 && return 0 || return 1; fi
  # Search for ctest if CMake used
  if command -v ctest >/dev/null 2>&1 && [ -d build ]; then
    (cd build && ctest -q) >/dev/null 2>&1 && return 0 || return 1
  fi
  return 125
}

probe_cmake_c() {
  if command -v ctest >/dev/null 2>&1 && [ -d build ]; then
    (cd build && ctest -q) >/dev/null 2>&1 && return 0 || return 1
  fi
  # Try a known binary
  if [ -x ./build/app ] ; then ./build/app --selftest >/dev/null 2>&1 && return 0 || return 1; fi
  return 125
}

# Master probe selector
bug_probe() {
  # Highest priority: explicit override
  if [ -n "$BUG_PROBE_CMD" ]; then
    sh -c "$BUG_PROBE_CMD"
    return $?
  fi

  # Language-specific heuristics (order matters for monorepos)
  if is_python;  then probe_python;  rc=$?; [ $rc -ne 125 ] && return $rc; fi
  if is_r;       then probe_r;       rc=$?; [ $rc -ne 125 ] && return $rc; fi
  if is_node;    then probe_node;    rc=$?; [ $rc -ne 125 ] && return $rc; fi
  if is_java;    then probe_java;    rc=$?; [ $rc -ne 125 ] && return $rc; fi
  if is_go;      then probe_go;      rc=$?; [ $rc -ne 125 ] && return $rc; fi
  if is_rust;    then probe_rust;    rc=$?; [ $rc -ne 125 ] && return $rc; fi
  if is_fortran; then probe_fortran; rc=$?; [ $rc -ne 125 ] && return $rc; fi
  if is_cmake;   then probe_cmake_c; rc=$?; [ $rc -ne 125 ] && return $rc; fi

  # Last-chance app smoke: run ./build/* --version or a custom script if present
  if [ -x ./tests/bug_probe.sh ]; then ./tests/bug_probe.sh; return $?; fi

  return 125
}

# -------------------------- MAIN ----------------------------------------------
project_clean || true
project_build || exit 125

if with_timeout "$BUG_PROBE_TIMEOUT" bug_probe; then
  exit 0   # "good"
else
  rc=$?
  [ "$rc" -eq 125 ] && exit 125
  exit 1   # "bad"
fi
