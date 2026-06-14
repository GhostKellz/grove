# Security Policy

## Supported Versions

Security fixes are handled on the main development branch. Released package versions should update to the latest patched release once one is available.

## Reporting a Vulnerability

Please report security issues privately instead of opening a public issue.

Use the repository's GitHub security advisory flow if available, or contact the maintainers through the project owner listed on GitHub.

Include:

- Affected version or commit
- A minimal reproduction case
- Expected and actual behavior
- Potential impact
- Any known workaround

## Scope

Security-relevant issues may include:

- Parser crashes or memory-safety problems triggered by untrusted `.gla` input
- Query behavior that causes downstream tools to execute unintended injections
- Packaging issues that expose unexpected files or scripts
- Editor integration behavior that can run untrusted commands

Regular syntax bugs, highlighting mistakes, and documentation issues can be reported through public issues.

## Handling

Maintainers will acknowledge valid reports as soon as practical, investigate the affected parser or integration surface, and coordinate a fix before public disclosure when the issue has security impact.

## Downstream Consumers

Grove, GhostLS, Grim, and editor plugins should treat `.gla` source as untrusted input. Consumers should avoid executing code discovered through parse trees, query captures, or injection names unless they have an explicit trust boundary and user consent.
