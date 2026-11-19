# Alert once when a filesystem fills up, and once when it recovers.
# usage: jennifer run diskcheck.j PATH WARN CRIT   (percent)
# pragma-jennifer-capability: exec
use io;
use os;
use fs;
use strings;
use convert;
use regex;
use maps;
import "dotenv.j" as dotenv;
import "./alerts.j" as alerts;

def const STATE as string init "diskcheck.state";

# percent used of the filesystem holding path, from POSIX df
func usedPercent(path as string) {
    def r as os.Result init os.run(["df", "-P", "-k", $path]);
    if ($r.exitCode != 0) {
        throw Error{kind: "disk", message: "df failed: " + strings.trim($r.stderr)};
    }
    def lines as list of string init strings.split(strings.trim($r.stdout), "\n");
    def cols as list of string init regex.split('\s+', $lines[len($lines) - 1]);
    return convert.toInt(strings.replace($cols[4], "%", ""));
}

# last known severity per key, one "key severity" line each
func loadState() {
    def out as map of string to string init {};
    if (not fs.exists(STATE)) {
        return $out;
    }
    for (def line in strings.split(fs.readString(STATE), "\n")) {
        if ($line == "") {
            continue;
        }
        def parts as list of string init strings.split($line, " ");
        if (len($parts) != 2) {
            throw Error{kind: "disk", message: "bad state line: " + $line};
        }
        $out[$parts[0]] = $parts[1];
    }
    return $out;
}

func saveState(state as map of string to string) {
    def text as string init "";
    for (def k in $state) {
        $text = $text + $k + " " + $state[$k] + "\n";
    }
    fs.writeString(STATE + ".tmp", $text);
    fs.rename(STATE + ".tmp", STATE);
}

func severity(used as int, warn as int, crit as int) {
    if ($used >= $crit) {
        return "critical";
    }
    if ($used >= $warn) {
        return "warning";
    }
    return "ok";
}

# the severity last reported for key; "ok" for a new key
func stateOf(state as map of string to string, key as string) {
    if (maps.has($state, $key)) {
        return $state[$key];
    }
    return "ok";
}

dotenv.autoload(os.cwd());
def path as string init os.ARGS[1];
def warn as int init convert.toInt(os.ARGS[2]);
def crit as int init convert.toInt(os.ARGS[3]);
def key as string init "disk:" + $path;

def state as map of string to string init loadState();
def used as int init usedPercent($path);
def now as string init severity($used, $warn, $crit);
def before as string init stateOf($state, $key);
io.printf("%s: %d%% used, %s (was %s)\n", $path, $used, $now, $before);
if ($now == $before) {
    exit 0; # nothing new: stay quiet
}

def a as alerts.Alert init alerts.Alert{
    key: $key,
    severity: $now,
    title: "{$path} is {$used}% full",
    text: "Limits: warning {$warn}%, critical {$crit}%."
};
if ($now == "ok") {
    $a.title = "Resolved: {$path} is back to {$used}%";
}
def c as alerts.Channels init alerts.fromEnv();
def failed as list of string init alerts.notify($c, $a);
for (def f in $failed) {
    io.eprintf("%s\n", $f);
}
if (len($failed) == len(alerts.enabled($c))) {
    exit 1; # nobody heard it: keep the old state, try next run
}
$state[$key] = $now;
saveState($state);
io.printf("sent %s to %d channel(s)\n", $now, len(alerts.enabled($c)) - len($failed));
