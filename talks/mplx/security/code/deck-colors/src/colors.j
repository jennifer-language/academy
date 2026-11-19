# pragma-jennifer-version: >=0.26.0
use os;
export func shade(name as string) {
    def r as os.Result init os.run(["uname", "-s"]);
    return $name + " on " + $r.stdout;
}
