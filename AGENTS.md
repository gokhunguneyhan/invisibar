# Invisibar

Hide the iOS status bar for product screenshots and screen recordings, which also
removes the red screen-recording indicator from the Dynamic Island.

**The instructions are in [`SKILL.md`](SKILL.md). Read it before making changes.**

It is written as a task guide: what to copy, where the two call sites go, and how to
verify the result. It is plain Markdown with no tool-specific syntax, so it works
whatever agent you are.

Two things in it that are easy to get wrong and expensive to miss:

- The root wrapper must go **above every early return** in the app's root view, or it
  silently misses whatever screens those branches serve.
- Verification needs a **control string**. Checking that a debug key is absent from a
  release build proves nothing on its own — a typo gives the same clean zero.

`references/verify.md` has the full method.
