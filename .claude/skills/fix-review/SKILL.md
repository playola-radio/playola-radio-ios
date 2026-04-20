---
name: fix-review
description: Fetch Claude review comments from the current branch's GitHub PR and fix all reported issues
---

# Fix PR Review Issues

## Step 1: Find the PR and capture repo context

```bash
gh pr view --json number,url --jq '{number, url}'
gh repo view --json owner,name --jq '{owner: .owner.login, repo: .name}'
```

Capture `{number}`, `{owner}`, and `{repo}` from these commands — all subsequent steps substitute those values into API calls. If no PR exists, tell the user and stop.

## Step 2: Check for unresolved review comments (with polling)

Check if there are any unresolved review threads. If the skill was invoked right after PR creation, the review bot may not have posted yet — so poll for up to ~3 minutes before giving up.

Run this query:

```bash
gh api graphql -f query='
  query {
    repository(owner: "{owner}", name: "{repo}") {
      pullRequest(number: {number}) {
        reviewThreads(last: 100) {
          nodes {
            isResolved
            comments(first: 1) {
              nodes { body, author { login } }
            }
          }
        }
      }
    }
  }
' --jq '.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false)'
```

**Polling behavior:**
- If the query returns unresolved threads OR the summary body has findings (see below), proceed to Step 3.
- If both are empty, wait 20 seconds and retry. Repeat up to 9 times (~3 minutes total).
- If still nothing after that, say "No unresolved review comments after polling for 3 minutes" and exit. The user can re-invoke the skill later if a review lands.

**Also check the PR summary body.** Some reviewers (e.g. Greptile) post findings as an issue comment on the PR rather than as inline review threads. These appear under a "Comments Outside Diff" / "greptile_failed_comments" section and are NOT returned by the `reviewThreads` query. Always fetch them too:

```bash
gh api repos/{owner}/{repo}/issues/{number}/comments \
  --jq '.[] | select(.user.login | test("greptile|claude"; "i")) | {id, body}'
```

If any of those comment bodies contain a "Comments Outside Diff" block or P0/P1/P2 badges, treat each bulleted finding as a review comment and feed it into Step 4 alongside any inline threads.

## Step 3: Fetch review comments

Fetch both the inline review comments AND the summary-body findings from the PR:

```bash
# Inline reviews (threads on specific lines)
gh api repos/{owner}/{repo}/pulls/{number}/reviews --jq '.[] | {id, state, user: .user.login}'
gh api repos/{owner}/{repo}/pulls/{number}/reviews/{review_id}/comments --jq '.[] | {id, path, line, body}'

# Summary-body findings (Greptile "Comments Outside Diff", etc.)
gh api repos/{owner}/{repo}/issues/{number}/comments \
  --jq '.[] | select(.user.login | test("greptile|claude"; "i")) | .body' > /tmp/pr_summary_{number}.html
```

For the summary body, extract each bulleted finding — it'll reference:
- The file and line range (e.g., `fastlane/Fastfile`, line 84-91)
- A P0/P1/P2 badge
- A title and description

Summary-body findings don't have a thread to resolve or reply to individually. Track them separately — for these, add a thumbs-up reaction to the parent issue comment and mention the fix in the commit message (no per-thread reply).

Extract all FAIL and WARN items from inline reviews — each will reference:
- The comment ID (needed for acknowledging fixes)
- The check that failed
- Specific files and line numbers
- A description of the issue

## Step 4: Fix issues

Work through each issue, starting with FAILs:

1. Read the referenced file to understand the full context
2. Apply the fix following project conventions (reference the relevant doc in `.claude/` if needed — e.g., `PAGE_CREATION.md`, `API_CLIENT.md`, `NAVIGATION.md`, `VIEWS.md`, `TESTING.md`)
3. Verify formatting/linting stays clean: `make format && make lint`
4. The user will run tests in Xcode. If a test file changed, ask the user to run the relevant tests and report the result before proceeding.
5. After fixing, acknowledge the review comment (but do NOT resolve the thread yet — resolution happens in Step 6 once all checks pass):
   ```bash
   # For INLINE review comments:
   gh api repos/{owner}/{repo}/pulls/comments/{comment_id}/reactions -f content="+1"
   gh api repos/{owner}/{repo}/pulls/{number}/comments/{comment_id}/replies -f body="Fixed"

   # For SUMMARY-BODY findings (no inline thread exists):
   gh api repos/{owner}/{repo}/issues/comments/{issue_comment_id}/reactions -f content="+1"
   # No per-finding reply — mention what was fixed in the commit message instead.
   ```

   Track each inline `{comment_id}` you replied to with "Fixed" — you'll need the matching thread IDs in Step 6. Summary-body findings don't have threads to resolve, so they're done after the thumbs-up + commit.

   **Reply guidelines:**
   - If the fix was straightforward, reply "Fixed".
   - If there were multiple valid approaches (e.g., document vs. change behavior), briefly explain the choice: "Fixed — chose to document rather than change behavior because this is admin-only and hasVoted has no consumer."
   - If you chose NOT to fix something, reply explaining why: "Won't fix — this is intentional because [reason]." Do not resolve the thread in this case; leave it for the user to decide.

## Step 5: Verify

After all fixes are applied:

1. Run `make format` to auto-fix formatting.
2. Run `make lint` to check SwiftLint passes in strict mode.
3. Ask the user to run the full test suite in Xcode and report any failures.
4. Fix any lint or test failures before proceeding. **Do not move on to Step 6 until every check is green** — resolving threads before this point would give a false signal of completion if a later fix regresses.

## Step 6: Resolve review threads

Now that all checks pass, resolve the threads for comments that were fixed:

```bash
# Get all unresolved review thread IDs and their associated comment IDs
gh api graphql -f query='
  query {
    repository(owner: "{owner}", name: "{repo}") {
      pullRequest(number: {number}) {
        reviewThreads(last: 100) {
          nodes {
            id
            isResolved
            comments(first: 1) {
              nodes { databaseId }
            }
          }
        }
      }
    }
  }
' --jq '.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false) | {id, commentId: .comments.nodes[0].databaseId}'

# For each unresolved thread whose comment you replied to with "Fixed", resolve it:
gh api graphql -f query='mutation { resolveReviewThread(input: {threadId: "{thread_id}"}) { thread { isResolved } } }'
```

Leave "Won't fix" threads unresolved for the user to decide.

## Step 7: Commit and push

1. Commit the fixes with a clear message (e.g., `fix: address PR review comments`)
2. Push to the remote branch
3. List what was fixed and what (if anything) was left for the user to decide.

## Step 8: Request re-review if needed

Check the original Greptile review for a score (e.g., "4/5", "3/5"). If the score was 4/5 or lower, comment on the PR to trigger a re-review:

```bash
gh pr comment {number} --body "@greptile review this"
```

If the score was 5/5, skip this step.
