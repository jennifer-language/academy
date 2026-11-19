#!/usr/bin/env -S jennifer run
# A fake FHIR R4 server for the demo, on http://127.0.0.1:8090/fhir, in
# memory: transactions (conditional PUT of a Patient, POST of Observations),
# read and search. No authentication; never put it in front of real data.
#   jennifer run fhirfake.j

use io;
use json;
use strings;
use httpd;
use maps;
use convert;

def patients as map of string to json.Value;
def observations as list of json.Value;

func outcome(code as string, text as string) {
    def issue as json.Value init json.map({"severity": "error",
        "code": $code, "diagnostics": $text});
    return json.set(json.map({"resourceType": "OperationOutcome"}), "/issue",
        json.list([$issue]));
}

func answer(req as httpd.Request, status as int, body as json.Value) {
    httpd.setHeader($req, "Content-Type", "application/fhir+json");
    httpd.respond($req, $status, json.encode($body));
}

func bySubject(subject as string) {
    def found as list of json.Value;
    for (def o in $observations) {
        if (json.asString($o, "/subject/reference") == $subject) { $found[] = $o; }
    }
    return $found;
}

func searchset(found as list of json.Value) {
    def entries as list of json.Value;
    for (def r in $found) { $entries[] = json.map({"resource": $r}); }
    def b as json.Value init json.map({"resourceType": "Bundle",
        "type": "searchset", "total": len($found)});
    return json.set($b, "/entry", json.list($entries));
}

# Patient?identifier=system|value: the patient with that identifier, or a new one
func putPatient(url as string, p as json.Value) {
    def wanted as string init strings.split($url, "identifier=")[1];
    for (def id in $patients) {
        def i as json.Value init json.get($patients[$id], "/identifier/0");
        if (json.asString($i, "/system") + "|" + json.asString($i, "/value") == $wanted) {
            $patients[$id] = json.set($p, "/id", $id);
            return "Patient/" + $id;
        }
    }
    def id as string init "{len($patients) + 1}";
    $patients[$id] = json.set($p, "/id", $id);
    return "Patient/" + $id;
}

func transaction(b as json.Value) {
    def refs as map of string to string;
    def out as list of json.Value;
    for (def i in 0..json.length($b, "/entry")) {
        def e as json.Value init json.get($b, "/entry/{$i}");
        def url as string init json.asString($e, "/request/url");
        def r as json.Value init json.get($e, "/resource");
        def loc as string;
        if (json.asString($e, "/request/method") == "PUT") {
            $loc = putPatient($url, $r);
        } else {
            def ref as string init json.asString($r, "/subject/reference");
            if (maps.has($refs, $ref)) {
                $r = json.set($r, "/subject/reference", $refs[$ref]);
            }
            $r = json.set($r, "/id", "{len($observations) + 1}");
            $observations[] = $r;
            $loc = "Observation/" + json.asString($r, "/id");
            io.printf("%s\n", json.encodePretty($r));
        }
        if (json.has($e, "/fullUrl")) { $refs[json.asString($e, "/fullUrl")] = $loc; }
        $out[] = json.map({"response": json.map({"status": "201 Created",
            "location": $loc})});
    }
    def reply as json.Value init json.map({"resourceType": "Bundle",
        "type": "transaction-response"});
    return json.set($reply, "/entry", json.list($out));
}

def srv as httpd.Server init httpd.listen("127.0.0.1:8090");
io.printf("fhirfake: http://127.0.0.1:8090/fhir\n");
while (true) {   # until stopped # lint-disable: L105
    def req as httpd.Request init httpd.accept($srv);
    def path as string init httpd.path($req);
    io.printf("fhirfake: %s %s\n", httpd.method($req), $path);
    try {
        if (httpd.method($req) == "POST" and $path == "/fhir") {
            answer($req, 200, transaction(json.decode(
                convert.stringFromBytes("utf-8", httpd.body($req)))));
        } elseif ($path == "/fhir/Observation") {
            answer($req, 200, searchset(bySubject(httpd.query($req, "subject"))));
        } elseif (strings.startsWith($path, "/fhir/Patient/")) {
            def id as string init $path[14..len($path)];
            if (maps.has($patients, $id)) {
                answer($req, 200, $patients[$id]);
            } else {
                answer($req, 404, outcome("not-found",
                    "Resource Patient/{$id} is not known"));
            }
        } else {
            answer($req, 404, outcome("not-supported", "not in this fake: " + $path));
        }
    } catch (e) {
        answer($req, 400, outcome("invalid", $e.message));
    }
}
