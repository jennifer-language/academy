#!/usr/bin/env -S jennifer run
# HL7 in, FHIR out: serves MLLP on 127.0.0.1:2575, turns every ORU^R01 into
# one FHIR R4 transaction (a Patient and an Observation per OBX) and posts
# it to the FHIR server, by default the fake on 127.0.0.1:8090.
#   jennifer run bridge.j [fhir-base-url]     (start fhirfake.j first)

use io;
use os;
use convert;
use json;
use uuid;

import "@deckyard/hl7/" as hl7;
import "@deckyard/fhir/" as fhir;

def const MRN as string init "urn:oid:2.999.1.1";   # was http://example.org/...
def const LOINC as string init "http://loinc.org";
def const UCUM as string init "http://unitsofmeasure.org";
def const FLAGS as string init
    "http://terminology.hl7.org/CodeSystem/v3-ObservationInterpretation";
def const ZONE as string init "+01:00";   # the lab's time zone

def base as string init "http://127.0.0.1:8090/fhir";
if (len(os.ARGS) > 1) { $base = os.ARGS[1]; }

# 19800214 -> 1980-02-14; 20260312094410 -> 2026-03-12T09:44:10+01:00
func fhirDate(d as string) {
    return $d[0..4] + "-" + $d[4..6] + "-" + $d[6..8];
}
func fhirTime(t as string) {
    return fhirDate($t) + "T" + $t[8..10] + ":" + $t[10..12] + ":" +
        $t[12..14] + ZONE;
}

func patientFrom(m as hl7.Message) {
    def sex as map of string to string init {"F": "female", "M": "male",
        "O": "other", "U": "unknown"};
    def p as json.Value init json.map({"resourceType": "Patient"});
    $p = json.set($p, "/identifier",
        json.list([fhir.identifier(MRN, hl7.get($m, "PID-3-1"))]));
    def name as json.Value init json.map({"family": hl7.get($m, "PID-5-1")});
    $name = json.set($name, "/given", json.list([hl7.get($m, "PID-5-2")]));
    $p = json.set($p, "/name", json.list([$name]));
    $p = json.set($p, "/birthDate", fhirDate(hl7.get($m, "PID-7")));
    $p = json.set($p, "/gender", $sex[hl7.get($m, "PID-8")]);   # F -> female
    return $p;
}

func observationFrom(obx as hl7.Segment, subject as string) {
    def o as json.Value init json.map({"resourceType": "Observation",
        "status": "final"});
    $o = json.set($o, "/code", fhir.concept(LOINC,
        hl7.component($obx, 3, 1, 1), hl7.component($obx, 3, 1, 2)));
    $o = json.set($o, "/subject", json.map({"reference": $subject}));
    $o = json.set($o, "/effectiveDateTime", fhirTime(hl7.field($obx, 14)));
    def unit as string init hl7.component($obx, 6, 1, 1);
    def q as json.Value init json.map(
        {"unit": $unit, "system": UCUM, "code": $unit});
    $q = json.set($q, "/value", convert.toFloat(hl7.field($obx, 5)));
    $o = json.set($o, "/valueQuantity", $q);
    def flag as string init hl7.field($obx, 8);
    if ($flag != "") {
        $o = json.set($o, "/interpretation",
            json.list([fhir.concept(FLAGS, $flag, "")]));
    }
    return $o;
}

func onMessage(m as hl7.Message) {
    def c as fhir.Client init fhir.client($base);
    def mrn as string init hl7.get($m, "PID-3-1");
    def pid as string init "urn:uuid:" + uuid.v4();
    def b as json.Value init fhir.bundle("transaction");
    $b = fhir.entry($b, "PUT", "Patient?identifier={MRN}|{$mrn}",
        patientFrom($m), $pid);
    for (def obx in hl7.segmentsOf($m, "OBX")) {
        $b = fhir.entry($b, "POST", "Observation", observationFrom($obx, $pid), "");
    }
    def result as json.Value init fhir.transaction($c, $b);
    io.printf("bridge: %s -> %d FHIR entries\n", hl7.get($m, "MSH-10"),
        json.length($result, "/entry"));
    return hl7.ack($m, "AA", "", "ACK" + hl7.get($m, "MSH-10"));
}

io.printf("bridge: MLLP on 127.0.0.1:2575, FHIR at %s\n", $base);
hl7.serve(hl7.listen("127.0.0.1:2575"), hl7.options(), onMessage);
