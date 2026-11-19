#!/usr/bin/env -S jennifer run
# Read the stored results back from the FHIR server, and a 404.
#   jennifer run readback.j      (after run.sh, with fhirfake.j still up)

use io;
use json;

import "@deckyard/fhir/" as fhir;

def c as fhir.Client init fhir.client("http://127.0.0.1:8090/fhir");
for (def o in fhir.search($c, "Observation", ["subject=Patient/1"])) {
    io.printf("%s %v %s\n", json.asString($o, "/code/coding/0/code"),
        json.asFloat($o, "/valueQuantity/value"),
        json.asString($o, "/valueQuantity/unit"));
}
try {
    fhir.read($c, "Patient", "999");
} catch (e) {
    if ($e.kind == "fhir.http") {
        io.printf("%d %s: %s\n", $e.status, $e.issues[0].code,
            $e.issues[0].diagnostics);
    }
}
