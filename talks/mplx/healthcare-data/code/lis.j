#!/usr/bin/env -S jennifer run
# The laboratory information system: takes the analyzer's ASTM results on
# 127.0.0.1:4001, maps them to an HL7 v2 ORU^R01 and sends it over MLLP to
# the bridge on 127.0.0.1:2575.
#   jennifer run lis.j           (start bridge.j first, then analyzer.j)

use io;
use strings;

import "@deckyard/astm/" as astm;
import "@deckyard/hl7/" as hl7;

# instrument code to LOINC code, display and UCUM unit
def const TESTS as map of string to list of string init {
    "GLU": ["14749-6", "Glucose [Moles/volume] in Serum or Plasma", "mmol/L"],
    "CREA": ["14682-9", "Creatinine [Moles/volume] in Serum or Plasma", "umol/L"]
};

# one ORU^R01 for the results of one ASTM message
func toOru(m as astm.Message, id as string) {
    def results as list of astm.Result init astm.results($m);
    def p as astm.Record;
    for (def rec in $m.records) {
        if (astm.recordType($rec) == "P") { $p = $rec; }
    }
    def oru as hl7.Message init hl7.newMessage("ORU", "R01", $id, "2.5.1");
    $oru = hl7.set($oru, "MSH-3", "LIS");
    $oru = hl7.set($oru, "MSH-5", "FHIRBRIDGE");
    def pid as hl7.Segment init hl7.segment("PID", $oru.delimiters);
    $pid = hl7.setField($pid, 1, "1");
    $pid = hl7.setField($pid, 3, astm.field($p, 3));
    $pid = hl7.setComponent($pid, 5, 1, 1, astm.component($p, 6, 1, 1));
    $pid = hl7.setComponent($pid, 5, 1, 2, astm.component($p, 6, 1, 2));
    $pid = hl7.setField($pid, 7, astm.field($p, 8));
    $pid = hl7.setField($pid, 8, astm.field($p, 9));
    $oru = hl7.addSegment($oru, $pid);
    def obr as hl7.Segment init hl7.segment("OBR", $oru.delimiters);
    $obr = hl7.setField($obr, 1, "1");
    $obr = hl7.setField($obr, 3, $results[0].sampleId);
    $oru = hl7.addSegment($oru, $obr);
    def n as int init 0;
    for (def r in $results) {
        $n = $n + 1;
        def t as list of string init TESTS[$r.test];   # a missing key throws
        def obx as hl7.Segment init hl7.segment("OBX", $oru.delimiters);
        $obx = hl7.setField($obx, 1, "{$n}");
        $obx = hl7.setField($obx, 2, "NM");
        $obx = hl7.setComponent($obx, 3, 1, 1, $t[0]);
        $obx = hl7.setComponent($obx, 3, 1, 2, $t[1]);
        $obx = hl7.setComponent($obx, 3, 1, 3, "LN");
        $obx = hl7.setField($obx, 5, $r.value);
        $obx = hl7.setComponent($obx, 6, 1, 1, $t[2]);
        $obx = hl7.setComponent($obx, 6, 1, 3, "UCUM");
        def range as list of string init astm.components($r.record, 6, 1);
        $obx = hl7.setField($obx, 7, strings.join($range, "-"));
        $obx = hl7.setField($obx, 8, strings.join($r.flags, "~"));
        $obx = hl7.setField($obx, 11, "F");
        $obx = hl7.setField($obx, 14, $r.completed);
        $oru = hl7.addSegment($oru, $obx);
    }
    return $oru;
}

def link as astm.Link init astm.accept(astm.listen("127.0.0.1:4001"),
    astm.profile());
def mllp as hl7.Connection init hl7.connect("127.0.0.1:2575", hl7.options());
def sent as int init 0;
for (def m in astm.receive($link, 30000)) {
    $sent = $sent + 1;
    def oru as hl7.Message init toOru($m, io.sprintf("LIS%d|pad=5|fill=0", $sent));
    io.printf("%s\n", strings.replace(hl7.encode($oru), "\r", "\n"));
    def ack as hl7.Message init hl7.send($mllp, $oru);
    io.printf("ack: %s %s\n", hl7.get($ack, "MSA-1"), hl7.get($ack, "MSA-3"));
}
hl7.close($mllp);
astm.close($link);
