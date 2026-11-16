# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.26.0

/**
 * Tests for the translation review: which files need it, and which reviews
 * satisfy it.
 * @module reviewTest
 * @author mplx <mplx@jennifer-lang.dev>
 * @license LGPL-3.0-only
 */

use testing;

def const HEAD as string init "abc123";

/** The reviewer declaration as CONTRIBUTING.md has it, every item ticked. */
def const DECLARATION as string init "## Reviewer declaration\n\n" +
    "- [x] I translated the complete text, speaker notes and code comments of every " +
    "non-English talk file in this pull request into English, myself or with a translation " +
    "tool, and read the translation in full.\n" +
    "- [x] I looked at every image in it.\n" +
    "- [x] To the best of my knowledge and judgement, the content is lawful and follows " +
    "the academy's content policy.\n";

/** An approving review by a maintainer on the head commit, with the declaration. */
func good() {
    return Review{
        user: "mplx",
        association: "OWNER",
        state: "APPROVED",
        commit: HEAD,
        body: DECLARATION
    };
}

func testDeclarationInContributing() {
    # Reviewers paste the text from CONTRIBUTING.md, so the phrases must match it.
    def doc as string init fs.readString("CONTRIBUTING.md");
    testing.assertEqual(
        declaration.statesOf(strings.replace($doc, "- [ ]", "- [x]"), PHRASES),
        ["ticked", "ticked", "ticked"]);
}

func testApprovalPasses() {
    testing.assertEqual(verdict([good()], "ada", HEAD), []);
}

func testNoReviewFails() {
    testing.assertEqual(
        verdict([], "ada", HEAD),
        ["no approving review by a maintainer other than the author"]);
}

func testOlderCommitFails() {
    def r as Review init good();
    $r.commit = "old999";
    testing.assertContains(verdict([$r], "ada", HEAD)[0], "approved an older commit");
}

func testNonMaintainerAndSelfApprovalFail() {
    def r as Review init good();
    $r.association = "CONTRIBUTOR";
    testing.assertEqual(len(verdict([$r], "ada", HEAD)), 1);
    def own as Review init good();
    $own.user = "ada";
    testing.assertContains(verdict([$own], "ada", HEAD)[0], "no approving review");
}

func testDeclarationMustBeTicked() {
    def r as Review init good();
    $r.body = strings.replace(DECLARATION, "- [x] I looked", "- [ ] I looked");
    def found as list of string init verdict([$r], "ada", HEAD);
    testing.assertEqual(len($found), 1);
    testing.assertContains($found[0], "item 2 is unticked");
    $r.body = "LGTM";
    testing.assertEqual(len(verdict([$r], "ada", HEAD)), 3);
}

func testLaterReviewReplacesEarlier() {
    def again as Review init good();
    $again.state = "CHANGES_REQUESTED";
    testing.assertContains(verdict([good(), $again], "ada", HEAD)[0], "no approving review");
    def dismissed as Review init good();
    $dismissed.state = "DISMISSED";
    testing.assertContains(verdict([good(), $dismissed], "ada", HEAD)[0], "no approving review");
    def comment as Review init good();
    $comment.state = "COMMENTED";
    testing.assertEqual(verdict([good(), $comment], "ada", HEAD), []);
    def other as Review init good();
    $other.user = "bob";
    $other.commit = "old999";
    testing.assertEqual(verdict([$other, good()], "ada", HEAD), []);
}

func testParseReviews() {
    def line as string init '{"user":{"login":"mplx"},"author_association":"OWNER",' +
        '"state":"APPROVED","commit_id":"abc123","body":"x"}';
    def found as list of Review init parseReviews($line + "\n\n" +
        '{"user":null,"state":"COMMENTED","body":null}' + "\n");
    testing.assertEqual(len($found), 2);
    testing.assertEqual(
        $found[0],
        Review{user: "mplx", association: "OWNER", state: "APPROVED", commit: "abc123", body: "x"});
    testing.assertEqual($found[1].user, "");
}

/** A repository root with three talks: English, German, and English plus German. */
func tree() {
    def root as string init fs.makeTempDir("", "academy-review-");
    for (def t in ["en-only", "de-only", "both"]) {
        fs.mkdirAll(path.join($root, "talks", "ada", $t));
    }
    fs.writeString(
        path.join($root, "talks", "ada", "en-only", "academy.toml"),
        'lang = "en"' + "\n");
    fs.writeString(
        path.join($root, "talks", "ada", "de-only", "academy.toml"),
        'lang = "de"' + "\n");
    fs.writeString(
        path.join($root, "talks", "ada", "both", "academy.toml"),
        'lang = "en"' + "\n[translations.de]\ntitle = \"x\"\n");
    return $root;
}

func testNonEnglishFiles() {
    def root as string init tree();
    defer fs.removeAll($root);
    def changed as list of string init [
        "README.md",
        "talks/ada/en-only/talk.md",
        "talks/ada/en-only/academy.toml",
        "talks/ada/en-only/logo.png",
        "talks/ada/de-only/talk.md",
        "talks/ada/both/talk.en.md",
        "talks/ada/both/talk.de.md",
        "talks/ada/both/academy.toml",
    ];
    testing.assertEqual(
        nonEnglish($root, $changed),
        ["talks/ada/de-only/talk.md", "talks/ada/both/talk.de.md", "talks/ada/both/academy.toml",
        ]);
    testing.assertEqual(nonEnglish($root, ["talks/ada/en-only/talk.md"]), []);
}
