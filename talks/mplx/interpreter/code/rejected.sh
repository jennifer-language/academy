#!/bin/sh
# Writes the programs that the slides show being refused to a temporary
# directory, under the names the slides print, and runs the command each
# slide shows. They cannot be kept here as .j files: some do not parse, and
# every program in this folder must pass jennifer lint.
# Usage: sh rejected.sh
dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT
cd "$dir" || exit 1

# "Before the lexer: the requirement header"
cat > upper.j <<'END'
# pragma-jennifer-version: >=0.25.0 <0.26.0
use io;
io.printf("hi\n");
END

cat > typo.j <<'END'
# pragma-jennifer-verison: >=0.25.0
use io;
io.printf("hi\n");
END

# "Reserved words are one table in the lexer"
cat > kw.j <<'END'
func span(from as int, to as int) {
    return $to - $from;
}
END

# "The resolver: errors before anything runs"
cat > undef.j <<'END'
use io;
io.printf("%d\n", $count);
END

echo '$ jennifer run upper.j'
jennifer run upper.j
echo '$ jennifer run typo.j'
jennifer run typo.j
echo '$ jennifer tokens kw.j | grep TO'
jennifer tokens kw.j | grep ' TO$'
echo '$ jennifer run kw.j'
jennifer run kw.j
echo '$ jennifer ast undef.j'
jennifer ast undef.j
exit 0
