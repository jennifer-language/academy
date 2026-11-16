# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.26.0

/**
 * The translation review a pull request with non-English talk content needs.
 *
 * Such a pull request passes only with an approving review by a maintainer
 * (not its author) on its current head commit, whose body carries the ticked
 * reviewer declaration (CONTRIBUTING.md, "Review of talks in other
 * languages"). `tools/check-review.j` feeds it what the GitHub API returns.
 * @module review
 * @author mplx <mplx@jennifer-lang.dev>
 * @license LGPL-3.0-only
 */

use fs;
use json;
use lists;
use path;
use regex;
use strings;
use toml;

import "./declaration.j" as declaration;

/** One phrase per reviewer declaration item, lower case, in order. */
export def const PHRASES as list of string init [
    "i translated the complete text, speaker notes and code comments of every " +
        "non-english talk file in this pull request into english",
    "i looked at every image in it",
    "the content is lawful and follows the academy's content policy",
];

/** The author associations of a maintainer. */
export def const MAINTAINERS as list of string init ["OWNER", "MEMBER", "COLLABORATOR"];

/** A pull request review, as the GitHub API reports it. */
export def struct Review {
    user as string,
    association as string,
    state as string,
    commit as string,
    body as string
};

/** The `lang` of an academy.toml, and whether any language in it is not English. */
func tomlLangs(file as string) {
    def out as list of string;
    if (not fs.isFile($file)) {
        return $out;
    }
    def doc as toml.Value;
    try {
        $doc = toml.decode(fs.readString($file));
    } catch (e) {
        # An invalid file fails the site job; count it as not English here.
        return ["?"];
    }
    if (toml.has($doc, "/lang") and toml.typeOf($doc, "/lang") == "string") {
        $out[] = toml.asString($doc, "/lang");
    }
    if (toml.has($doc, "/translations") and toml.typeOf($doc, "/translations") == "map") {
        for (def lang in toml.keys($doc, "/translations")) {
            $out[] = $lang;
        }
    }
    return $out;
}

/** Is any of these languages something other than English? */
func anyNotEnglish(langs as list of string) {
    for (def lang in $langs) {
        if ($lang != "en") {
            return true;
        }
    }
    return false;
}

/**
 * The changed files whose content is not English: a `talk.<lang>.md` with
 * `lang` other than `en`, a `talk.md` whose academy.toml names another
 * language, and an academy.toml that holds another language's title or
 * description.
 * @param {string} root the checked-out repository (the pull request's head)
 * @param {list of string} changed the paths the pull request adds or changes
 * @return {list of string} those of them that need a translation review
 */
export func nonEnglish(root as string, changed as list of string) {
    def out as list of string;
    for (def file in $changed) {
        def parts as list of string init strings.split($file, "/");
        if (len($parts) != 4 or $parts[0] != "talks") {
            continue;
        }
        def name as string init $parts[3];
        def toml2 as string init path.join($root, "talks", $parts[1], $parts[2], "academy.toml");
        def m as regex.Match init regex.find('^talk\.([^/]+)\.md$', $name);
        if ($m.start >= 0) {
            if ($m.groups[0] != "en") {
                $out[] = $file;
            }
        } elseif ($name == "talk.md") {
            def langs as list of string init tomlLangs($toml2);
            if (len($langs) > 0 and $langs[0] != "en") {
                $out[] = $file;
            }
        } elseif ($name == "academy.toml" and anyNotEnglish(tomlLangs($toml2))) {
            $out[] = $file;
        }
    }
    return $out;
}

/**
 * Read the reviews: one JSON object per line, as `gh api ... --jq '.[]'`
 * prints them.
 * @param {string} jsonl the reviews
 * @return {list of Review} in the API's order (oldest first)
 */
export func parseReviews(jsonl as string) {
    def out as list of Review;
    for (def line in strings.split($jsonl, "\n")) {
        if (strings.trim($line) == "") {
            continue;
        }
        def v as json.Value init json.decode($line);
        $out[] = Review{
            user: field($v, "/user/login"),
            association: field($v, "/author_association"),
            state: field($v, "/state"),
            commit: field($v, "/commit_id"),
            body: field($v, "/body"),
        };
    }
    return $out;
}

/** A string field of a JSON object, or "" when absent or not a string. */
func field(v as json.Value, ptr as string) {
    if (json.typeOf($v, $ptr) != "string") {
        return "";
    }
    return json.asString($v, $ptr);
}

/** Each reviewer's latest review that counts (an approval, change request or dismissal). */
func latestPerReviewer(reviews as list of Review) {
    def users as list of string;
    def latest as list of Review;
    for (def r in $reviews) {
        if ($r.state == "COMMENTED" or $r.state == "PENDING") {
            continue;
        }
        def at as int init lists.indexOf($users, $r.user);
        if ($at < 0) {
            $users[] = $r.user;
            $latest[] = $r;
        } else {
            $latest[$at] = $r;
        }
    }
    return $latest;
}

/** What is wrong with one maintainer's approval; empty when it is enough. */
func approvalProblems(r as Review, head as string) {
    def out as list of string;
    if ($r.commit != $head) {
        $out[] = "@{$r.user} approved an older commit; a new push needs a new review";
    }
    def st as list of string init declaration.statesOf($r.body, PHRASES);
    for (def i in 0..len(PHRASES)) {
        if ($st[$i] != "ticked") {
            def n as int init $i + 1;
            def phrase as string init PHRASES[$i];
            $out[] = "@{$r.user}'s review: declaration item {$n} is {$st[$i]}: \"{$phrase} ...\"";
        }
    }
    return $out;
}

/**
 * Does the pull request have the translation review it needs?
 * @param {list of Review} reviews all its reviews, oldest first
 * @param {string} author the pull request's author
 * @param {string} head the pull request's current head commit
 * @return {list of string} why not; empty when one maintainer's approval suffices
 */
export func verdict(reviews as list of Review, author as string, head as string) {
    def problems as list of string;
    def candidates as int init 0;
    for (def r in latestPerReviewer($reviews)) {
        if ($r.state != "APPROVED" or $r.user == $author or
            not lists.contains(MAINTAINERS, $r.association)) {
            continue;
        }
        $candidates = $candidates + 1;
        def mine as list of string init approvalProblems($r, $head);
        if (len($mine) == 0) {
            return [];
        }
        for (def p in $mine) {
            $problems[] = $p;
        }
    }
    if ($candidates == 0) {
        $problems[] = "no approving review by a maintainer other than the author";
    }
    return $problems;
}
