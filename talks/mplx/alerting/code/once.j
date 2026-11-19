# Send one alert to every configured channel.
use io;
use os;
import "dotenv.j" as dotenv;
import "./alerts.j" as alerts;

dotenv.autoload(os.cwd());
def c as alerts.Channels init alerts.fromEnv();
def a as alerts.Alert init alerts.Alert{
    key: "disk:/srv",
    severity: "critical",
    title: "/srv is 96% full",
    text: "38 GiB free, limit 90%.\nTop: backup <daily>"
};
def failed as list of string init alerts.notify($c, $a);
io.printf("sent to %d channel(s), %d failed\n", len(alerts.enabled($c)), len($failed));
for (def f in $failed) {
    io.printf("  %s\n", $f);
}
