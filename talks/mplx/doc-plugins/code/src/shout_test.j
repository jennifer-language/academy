# White-box tests, spliced into shout.j by `jennifer test src/shout_test.j`.
# Run from code/: the timeout test starts `sh` with a path relative to it.
use testing;

func req(settings as string, content as string) {
    return json.decode('{"api":1,"kind":"preprocessor","plugin":{"name":"shout","settings":' +
        $settings + '},"chapters":[{"src":"a.md","content":' + json.encode($content) + '}]}');
}

func anotherApi() {
    request('{"api":2,"kind":"preprocessor"}');
}

func aRenderer() {
    request('{"api":1,"kind":"renderer"}');
}

func unknownKey() {
    settingsOf(req('{"colour":"red"}', ""));
}

func zeroTimeout() {
    settingsOf(req('{"timeout":0}', ""));
}

func textTimeout() {
    settingsOf(req('{"timeout":"10s"}', ""));
}

func unclosed() {
    fencesIn("a.md", "text\n\n```shout\nhi\n");
}

func oversized() {
    fencesIn("a.md", "```shout\n" + strings.replicate("x", MAX_SOURCE + 1) + "\n```\n");
}

func slow() {
    runBounded(["sh", "tests/slow.sh"], 200);
}

func missing() {
    runBounded(["no-such-program-here"], 200);
}

func testAnotherApiOrKindIsRefused() {
    testing.assertThrows("anotherApi", "plugin");
    testing.assertThrows("aRenderer", "plugin");
}

func testBadSettingsAreRefused() {
    testing.assertThrows("unknownKey", "plugin");
    testing.assertThrows("zeroTimeout", "plugin");
    testing.assertThrows("textTimeout", "plugin");
}

func testTheHostsOwnKeysAreAccepted() {
    def s as Settings init settingsOf(req('{"command":"bin/grimoire-shout","args":[]}', ""));
    testing.assertEqual($s.program, "awk");
}

func testOnlyShoutFencesCount() {
    def text as string init "```shout\nhi\n```\n\n````markdown\n```shout\nno\n```\n````\n";
    def found as list of Fence init fencesIn("a.md", $text);
    testing.assertEqual(len($found), 1);
    testing.assertEqual($found[0].body, "hi");
}

func testAnUnclosedFenceNamesItsPlace() {
    testing.assertThrows("unclosed", "plugin");
    try {
        unclosed();
    } catch (e) {
        testing.assertContains($e.message, "a.md:3:");
    }
}

func testAFenceOverTheCapThrowsLimit() {
    testing.assertThrows("oversized", "limit");
}

func testAFenceIsReplacedByTheOutput() {
    def reply as json.Value init json.decode(replyFor(req('{}', "# A\n\n```shout\nhi\n```\n")));
    testing.assertEqual(json.asString($reply, "/chapters/0/content"), "# A\n\n```text\nHI\n```\n");
}

func testAChapterWithoutFencesIsLeftOut() {
    testing.assertEqual(replyFor(req('{}', "# A\n")), '{"api":1,"chapters":[]}');
}

func testASlowProgramIsStopped() {
    testing.assertThrows("slow", "timeout");
}

func testAMissingProgramIsAPluginError() {
    testing.assertThrows("missing", "plugin");
}
