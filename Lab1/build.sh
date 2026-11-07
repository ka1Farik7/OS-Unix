#!/bin/sh

if [ $# -ne 1 ]; then
    echo "Usage: $0 <source-file>" >&2
    exit 1
fi

src=$1

if [ ! -f "$src" ] || [ ! -r "$src" ]; then
    echo "Error: cannot read source file '$src'" >&2
    exit 2
fi

output=$(sed -n 's/^.*Output:[[:space:]]*\([^[:space:]]*\).*$/\1/p' "$src" | head -n 1)

if [ -z "$output" ]; then
    echo "Error: comment 'Output: <name>' not found in '$src'" >&2
    exit 3
fi

case $output in
    */*|.|..)
        echo "Error: invalid output name '$output'" >&2
        exit 3
        ;;
esac

srcname=$(basename -- "$src")
srcdir=$(cd "$(dirname -- "$src")" && pwd) || exit 2

case $srcname in
    *.c)              tool=cc ;;
    *.cpp|*.cc|*.cxx) tool=c++ ;;
    *.tex)            tool=pdflatex ;;
    *)
        echo "Error: unsupported file type '$srcname'" >&2
        exit 4
        ;;
esac

if ! command -v "$tool" >/dev/null 2>&1; then
    echo "Error: '$tool' not found" >&2
    exit 5
fi

tmpdir=
cleanup() {
    if [ -n "$tmpdir" ]; then
        rm -rf -- "$tmpdir"
    fi
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 131' QUIT
trap 'exit 143' TERM

tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/build.XXXXXX") || {
    echo "Error: mktemp failed" >&2
    exit 6
}

cp -- "$src" "$tmpdir/" || exit 6
cd "$tmpdir" || exit 6
TMPDIR=$tmpdir
export TMPDIR

case $tool in
    pdflatex)
        job=${output%.pdf}
        result=$job.pdf
        pdflatex -interaction=nonstopmode -halt-on-error \
            -jobname="$job" "$srcname" >build.log 2>&1
        ;;
    *)
        result=$output
        "$tool" -o "$result" "$srcname" >build.log 2>&1
        ;;
esac

if [ $? -ne 0 ]; then
    cat build.log >&2
    echo "Error: build of '$src' failed" >&2
    exit 7
fi

if [ ! -f "$result" ]; then
    echo "Error: '$result' was not produced" >&2
    exit 8
fi

mv -f -- "$result" "$srcdir/$output" || exit 8

echo "Built: $srcdir/$output"
exit 0
