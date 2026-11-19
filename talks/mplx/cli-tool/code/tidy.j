#!/usr/bin/env -S jennifer run
# tidy: rename files to one naming style.
use fs;
use io;
use maps;
use os;
use path;
use strings;
import "args.j" as args;
import "ansi.j" as ansi;
import "log.j" as log;
import "@mplx/xformat/" as xformat;
import "@mplx/clispinner/" as spinner;

def const OK as int init 0;
def const FAILED as int init 1;
def const USAGE as int init 2;

def struct Step {
    file as string,
    target as string,
    problem as string
};

func newName(file as string, style as string) {
    def stem as string init xformat.toCase(path.stem($file), $style);
    def ext as string init strings.lower(path.ext($file));
    return path.join(path.dir($file), $stem + $ext);
}

func plan(file as string, style as string) {
    if (not fs.isFile($file)) {
        return Step{file: $file, target: "", problem: "not a file"};
    }
    def target as string init newName($file, $style);
    return Step{file: $file, target: $target, problem: ""};
}

func buildParser() {
    def p as args.Parser init args.parser("tidy", "rename files tidily");
    $p = args.flag($p, "case", "c", "kebab", "naming style");
    $p = args.choices($p, ["kebab", "snake", "camel", "pascal"]);
    $p = args.boolFlag($p, "dry-run", "n", "only show the new names");
    $p = args.countFlag($p, "verbose", "v", "log more (-v, -vv)");
    $p = args.positionalList1($p, "files", "the files to rename");
    return args.version($p, "tidy 1.0.0");
}

func logLevel(verbose as int) {
    if ($verbose >= 2) {
        return "debug";
    }
    if ($verbose == 1) {
        return "info";
    }
    return "warn";
}

def r as args.Result init args.Result{};
try {
    $r = args.parse(buildParser(), os.ARGS);
} catch (e) {
    if ($e.kind != "args") {
        throw $e;
    }
    io.eprintf("tidy: %s\n", $e.message);
    io.eprintf("try 'tidy --help'\n");
    exit USAGE;
}
if ($r.done) {
    io.printf("%s\n", $r.helpText);
    exit OK;
}

def style as string init args.asString($r, "case");
def dryRun as bool init args.asBool($r, "dry-run");
def verbose as int init args.count($r, "verbose");
def files as list of string init args.asList($r, "files");
def level as string init logLevel($verbose);
def lg as log.Logger init log.toStderr("logfmt", $level);

# Phase 1: check every file. The spinner owns the terminal line,
# so nothing is printed until it is removed.
def opts as spinner.Options init spinner.options("dots", "checking");
def sp as spinner.Spinner init spinner.startSpinner($opts);
def steps as list of Step init [];
for (def file in $files) {
    $sp = spinner.statusSpinner($sp, $file);
    $steps[] = plan($file, $style);
}
spinner.removeSpinner($sp);

# Phase 2: report problems, rename the rest.
def total as int init len($steps);
log.info($lg, "planned", {"files": "{$total}", "case": $style});
def failures as int init 0;
def renamed as int init 0;
def taken as map of string to bool init {};
for (def s in $steps) {
    if ($s.problem != "") {
        log.error($lg, $s.problem, {"file": $s.file});
        $failures = $failures + 1;
        continue;
    }
    if ($s.target == $s.file) {
        log.debug($lg, "already tidy", {"file": $s.file});
        continue;
    }
    if (maps.has($taken, $s.target) or fs.exists($s.target)) {
        log.error($lg, "exists", {"file": $s.file, "target": $s.target});
        $failures = $failures + 1;
        continue;
    }
    $taken[$s.target] = true;
    if (not $dryRun) {
        try {
            fs.rename($s.file, $s.target);
        } catch (e) {
            def why as string init $e.message;
            log.error($lg, "rename failed", {"file": $s.file, "why": $why});
            $failures = $failures + 1;
            continue;
        }
    }
    io.printf("%s -> %s\n", $s.file, ansi.green($s.target));
    $renamed = $renamed + 1;
}

log.info($lg, "done", {"renamed": "{$renamed}", "failed": "{$failures}"});
if ($failures > 0) {
    exit FAILED;
}
exit OK;
