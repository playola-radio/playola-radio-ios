import contextlib
import datetime
import io
import os
import tempfile
import unittest
from pathlib import Path

import changelog

PREAMBLE = (
    "# Changelog\n"
    "\n"
    "Don't edit this file in a pull request; add a file to changelog.d/ "
    "(see changelog.d/README.md).\n"
    "\n"
)

EMPTY_CHANGELOG = PREAMBLE + "## [Unreleased]\n\n" + changelog.UNRELEASED_COMMENT + "\n"

HISTORY = "## [7.4.0] - 2026-10-01\n\n### Changes\n\n- Older note\n"


class ChangelogTestCase(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)
        (self.root / "changelog.d").mkdir()
        self.write("changelog.d/README.md", "# changelog.d\n\nProse that is never parsed.\n")
        self.write("CHANGELOG.md", EMPTY_CHANGELOG)

    def tearDown(self):
        self._tmp.cleanup()

    def write(self, relative_path, text):
        (self.root / relative_path).write_text(text, encoding="utf-8")

    def read(self, relative_path):
        return (self.root / relative_path).read_text(encoding="utf-8")

    def snapshot(self):
        return {
            str(path.relative_to(self.root)): path.read_bytes()
            for path in sorted(self.root.rglob("*"))
            if path.is_file()
        }

    def run_main(self, *args):
        stdout, stderr = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
            code = changelog.main(["--root", str(self.root), *args])
        return code, stdout.getvalue(), stderr.getvalue()

    def assert_collect_error(self, expected):
        with self.assertRaises(changelog.ChangelogError) as caught:
            changelog.collect(self.root)
        self.assertIn(expected, str(caught.exception))


class CollectTests(ChangelogTestCase):
    def testCollectsFragmentBulletsInFileNameOrder(self):
        self.write("changelog.d/b-second.md", "### Changes\n\n- Second note\n")
        self.write("changelog.d/a-first.md", "### Changes\n\n- First note\n- Also first\n")

        self.assertEqual(
            changelog.collect(self.root).notes,
            ["First note", "Also first", "Second note"],
        )

    def testLegacyUnreleasedBulletsComeBeforeFragments(self):
        self.write(
            "CHANGELOG.md",
            PREAMBLE + "## [Unreleased]\n\n### Changes\n\n- Legacy note\n\n" + HISTORY,
        )
        self.write("changelog.d/new.md", "### Changes\n\n- Fragment note\n")

        self.assertEqual(changelog.collect(self.root).notes, ["Legacy note", "Fragment note"])

    def testHistoryBelowUnreleasedIsNotCollected(self):
        self.write("CHANGELOG.md", EMPTY_CHANGELOG + "\n" + HISTORY)

        self.assertEqual(changelog.collect(self.root).notes, [])

    def testCommentLinesAndBlankLinesAreAllowed(self):
        self.write(
            "changelog.d/note.md",
            "<!-- one comment -->\n\n### Changes\n<!-- another -->\n\n- Note\n\n",
        )

        self.assertEqual(changelog.collect(self.root).notes, ["Note"])

    def testReadmeIsNeverCollected(self):
        self.assertEqual(changelog.collect(self.root).fragments, [])

    def testHiddenNonMarkdownFilesAreIgnored(self):
        self.write("changelog.d/.DS_Store", "binary junk")

        self.assertEqual(changelog.collect(self.root).fragments, [])

    def testHiddenMarkdownFileIsStillCollected(self):
        self.write("changelog.d/.hidden.md", "")

        self.assert_collect_error("changelog.d/.hidden.md:1: no notes")

    def testEmptyFragmentIsAnError(self):
        self.write("changelog.d/empty.md", "")

        self.assert_collect_error("changelog.d/empty.md:1: no notes")

    def testHeadingWithoutBulletsIsAnError(self):
        self.write("changelog.d/heading-only.md", "### Changes\n\n<!-- todo -->\n")

        self.assert_collect_error("changelog.d/heading-only.md:1: no notes")

    def testUnknownHeadingIsAnError(self):
        self.write("changelog.d/fixed.md", "### Fixed\n- Something\n")

        self.assert_collect_error("changelog.d/fixed.md:1: unknown heading '### Fixed'")

    def testBulletBeforeHeadingIsAnError(self):
        self.write("changelog.d/no-heading.md", "- Orphan note\n")

        self.assert_collect_error("changelog.d/no-heading.md:1: bullet before '### Changes'")

    def testWrappedLineIsAnError(self):
        self.write("changelog.d/wrapped.md", "### Changes\n- A long note\n  that wraps\n")

        self.assert_collect_error("changelog.d/wrapped.md:3: unexpected line")

    def testNestedBulletIsAnError(self):
        self.write("changelog.d/nested.md", "### Changes\n- Parent\n  - Child\n")

        self.assert_collect_error("changelog.d/nested.md:3: unexpected line")

    def testEmptyBulletIsAnError(self):
        self.write("changelog.d/bare.md", "### Changes\n-\n- Real note\n")

        self.assert_collect_error("changelog.d/bare.md:2: unexpected line")

    def testTextBetweenCommentsIsAnError(self):
        self.write("changelog.d/comment.md", "### Changes\n<!-- a --> lost text <!-- b -->\n- Note\n")

        self.assert_collect_error("changelog.d/comment.md:2: unexpected line")

    def testInvalidUtf8IsAnError(self):
        (self.root / "changelog.d/binary.md").write_bytes(b"### Changes\n- \xff\n")

        self.assert_collect_error("changelog.d/binary.md: not valid UTF-8")

    def testUnclosedCommentIsAnError(self):
        self.write("changelog.d/comment.md", "### Changes\n<!-- starts here\n- Note\n")

        self.assert_collect_error("changelog.d/comment.md:2: unexpected line")

    def testNonMarkdownFileIsAnError(self):
        self.write("changelog.d/note.txt", "### Changes\n- Note\n")

        self.assert_collect_error("changelog.d/note.txt: not a .md file")

    def testEveryErrorIsReported(self):
        self.write("changelog.d/a.md", "")
        self.write("changelog.d/b.md", "### Ops\n- ENV: X\n")

        with self.assertRaises(changelog.ChangelogError) as caught:
            changelog.collect(self.root)
        self.assertIn("changelog.d/a.md:1", str(caught.exception))
        self.assertIn("changelog.d/b.md:1", str(caught.exception))

    def testMalformedLegacyUnreleasedLineNamesChangelogLine(self):
        self.write(
            "CHANGELOG.md",
            PREAMBLE + "## [Unreleased]\n\n### Changes\n\n- Note\nwrapped text\n",
        )

        self.assert_collect_error("CHANGELOG.md:10: unexpected line")

    def testNonVersionHeadingUnderUnreleasedIsAnError(self):
        self.write(
            "CHANGELOG.md",
            PREAMBLE + "## [Unreleased]\n\n### Changes\n\n- Note\n## Ops\n- Hidden\n\n" + HISTORY,
        )

        self.assert_collect_error("CHANGELOG.md:10: unknown heading '## Ops'")

    def testMissingUnreleasedHeadingIsAnError(self):
        self.write("CHANGELOG.md", PREAMBLE + HISTORY)

        self.assert_collect_error("CHANGELOG.md: no '## [Unreleased]' heading")

    def testMissingChangelogIsAnError(self):
        (self.root / "CHANGELOG.md").unlink()

        self.assert_collect_error("CHANGELOG.md: not found")


class RollTests(ChangelogTestCase):
    def testRollWritesDatedSectionBelowEmptyUnreleased(self):
        self.write("CHANGELOG.md", EMPTY_CHANGELOG + "\n" + HISTORY)
        self.write("changelog.d/note.md", "### Changes\n\n- New note\n")

        changelog.roll(self.root, "7.5.0", "2026-11-07")

        self.assertEqual(
            self.read("CHANGELOG.md"),
            PREAMBLE
            + "## [Unreleased]\n\n"
            + changelog.UNRELEASED_COMMENT
            + "\n\n## [7.5.0] - 2026-11-07\n\n### Changes\n\n- New note\n\n"
            + HISTORY,
        )

    def testRollMovesLegacyUnreleasedBulletsIntoVersionSection(self):
        self.write("CHANGELOG.md", PREAMBLE + "## [Unreleased]\n\n### Changes\n\n- Legacy note\n")
        self.write("changelog.d/note.md", "### Changes\n- Fragment note\n")

        changelog.roll(self.root, "7.5.0", "2026-11-07")

        self.assertEqual(
            self.read("CHANGELOG.md"),
            PREAMBLE
            + "## [Unreleased]\n\n"
            + changelog.UNRELEASED_COMMENT
            + "\n\n## [7.5.0] - 2026-11-07\n\n### Changes\n\n- Legacy note\n- Fragment note\n",
        )

    def testRolledChangelogHasNothingLeftToCollect(self):
        self.write("changelog.d/note.md", "### Changes\n- Note\n")

        changelog.roll(self.root, "7.5.0", "2026-11-07")

        self.assertEqual(changelog.collect(self.root).notes, [])

    def testRollDeletesExactlyTheFragmentsItRead(self):
        self.write("changelog.d/one.md", "### Changes\n- One\n")
        self.write("changelog.d/two.md", "### Changes\n- Two\n")
        self.write("changelog.d/.gitkeep", "")

        changelog.roll(self.root, "7.5.0", "2026-11-07")

        self.assertEqual(
            sorted(os.listdir(self.root / "changelog.d")), [".gitkeep", "README.md"]
        )

    def testRollWithNoNotesSaysSo(self):
        changelog.roll(self.root, "7.5.0", "2026-11-07")

        self.assertIn(
            "## [7.5.0] - 2026-11-07\n\nNo user-facing changes.\n", self.read("CHANGELOG.md")
        )

    def testRollReturnsTheNotesItWrote(self):
        self.write("changelog.d/note.md", "### Changes\n- Note\n")

        self.assertEqual(changelog.roll(self.root, "7.5.0", "2026-11-07"), ["Note"])

    def assert_roll_fails_without_changes(self, version, expected):
        self.write("changelog.d/note.md", "### Changes\n- Note\n")
        before = self.snapshot()

        with self.assertRaises(changelog.ChangelogError) as caught:
            changelog.roll(self.root, version, "2026-11-07")

        self.assertIn(expected, str(caught.exception))
        self.assertEqual(self.snapshot(), before)

    def testRollFailsWithoutChangesOnMalformedNote(self):
        self.write("changelog.d/bad.md", "### Changes\nnot a bullet\n")

        self.assert_roll_fails_without_changes("7.5.0", "changelog.d/bad.md:2")

    def testRollFailsWithoutChangesOnMissingVersion(self):
        self.assert_roll_fails_without_changes("", "version is required")

    def testRollFailsWithoutChangesOnMalformedVersion(self):
        self.assert_roll_fails_without_changes("v7.5", "version must look like 1.2.3")

    def testRollFailsWithoutChangesWhenVersionAlreadyExists(self):
        self.write("CHANGELOG.md", EMPTY_CHANGELOG + "\n" + HISTORY)

        self.assert_roll_fails_without_changes(
            "7.4.0", "CHANGELOG.md already has a section for 7.4.0"
        )


class MainTests(ChangelogTestCase):
    def testCheckPrintsNotes(self):
        self.write("changelog.d/note.md", "### Changes\n- Note\n")

        self.assertEqual(self.run_main("check"), (0, "- Note\n", ""))

    def testCheckWithNoNotesSaysSo(self):
        self.assertEqual(self.run_main("check"), (0, "No user-facing changes.\n", ""))

    def testCheckFailsOnMalformedNote(self):
        self.write("changelog.d/bad.md", "oops\n")

        code, stdout, stderr = self.run_main("check")

        self.assertEqual((code, stdout), (1, ""))
        self.assertIn("changelog.d/bad.md:1", stderr)

    def testRollPrintsNotesAndRewritesChangelog(self):
        self.write("changelog.d/note.md", "### Changes\n- Note\n")

        code, stdout, _ = self.run_main("roll", "--version", "7.5.0")

        self.assertEqual((code, stdout), (0, "- Note\n"))
        self.assertIn(
            f"## [7.5.0] - {datetime.date.today().isoformat()}", self.read("CHANGELOG.md")
        )

    def testRollWithoutVersionFails(self):
        before = self.snapshot()

        code, _, stderr = self.run_main("roll")

        self.assertEqual(code, 1)
        self.assertIn("version is required", stderr)
        self.assertEqual(self.snapshot(), before)


if __name__ == "__main__":
    unittest.main()
