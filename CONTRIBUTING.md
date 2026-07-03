# Contributing Guidelines

We welcome suggestions and contributions to improve the AI Agent Skills Catalog. However, to maintain high catalog quality and prevent build breaks, we enforce a strict workflow:

---

## 🚫 Pull Request Policy

*   **Do not open unsolicited Pull Requests.** Pull Requests opened without an approved, pre-existing issue will be closed automatically.
*   All additions or modifications to public skills must be discussed and approved in an Issue first.

---

## 📋 How to Contribute

### 1. Open an Issue
If you find a bug, a missing API signature, or want to suggest a new skill:
1. Search the existing Issues to make sure it hasn't already been reported.
2. Open a new **Issue** describing the bug or detailing the skill proposal.

### 2. Discussion & Staging
Once the issue is approved:
1. We will invite you to collaborate or instruct you on how to submit a PR from your fork.
2. All changes must be tested against local client configurations before merging.

---

## ✅ Verified-Truth Standard

Every API claim in this catalog is **verified against ground truth — nothing is guessed**:

* Type and member signatures are extracted from the actual release binaries (reflection surface dumps of the pinned NuGet packages).
* Usage patterns that metadata cannot prove (implicit conversions, optional parameters) are **compile-tested** against the exact pinned package versions.
* Each reference document carries a verification stamp (*Verified against MAF vX.Y.Z DLL surface (date)*) naming the version it was validated against.
* An automated gate rejects any documentation containing identifiers that cannot be traced to the verified surface — plausible-sounding APIs from tutorials or LLM memory do not pass.

Contributions must follow the same loop: name your evidence (binary surface, compile test, or executable example) for every claimed signature. PRs asserting APIs "from experience" will be asked for verification before review.
