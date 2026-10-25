# My Agent Skills

Two portable skills for keeping project decisions traceable and coordinating work across agents. Chinese-first instructions; no fixed model or agent identity.

[中文](README.md) · [Installation](docs/INSTALL.md) · [Examples](docs/EXAMPLES.md) · [Compatibility](docs/COMPATIBILITY.md) · [Changelog](CHANGELOG.md)

## Skills

| Skill | Purpose |
|---|---|
| [project-records-steward](skills/project-records-steward/SKILL.md) | Find past decisions, reconcile confirmed updates, preserve evidence and history, and maintain directory navigation. Includes PowerShell directory tools. |
| [cost-aware-delegation](skills/cost-aware-delegation/SKILL.md) | Choose direct execution or delegation, define handoffs and acceptance, resume existing work, and keep self-checks distinct from independent review. |

Each skill can be installed separately. Neither requires the other.

## Quick start

Give this repository URL or an extracted copy to your agent:

```text
Install project-records-steward and cost-aware-delegation for this platform.
Preserve each complete skill folder. Read SKILL.md and the first-use setup guide.
Reuse existing settings and ask only for choices that are missing and needed now.
Do not start project work, spawn agents, or generate project navigation during installation.
Report installation, setup, and verified capabilities separately.
```

Your platform determines the installation directory. A copy-only installer may not run setup; the first agent that actually uses the skill should then complete the relevant choices. Persistent settings must live outside the distributable skill and be reachable through an entry point the platform reads.

Detailed instructions and references are currently in Chinese. An agent can follow them when responding in another language; this repository does not claim a complete English translation of every reference.

## Try it

```text
Use project-records-steward to find the current decision and its source.
Keep this query read-only and report any conflicting evidence.
```

```text
Use cost-aware-delegation to resume this authorized task.
Check existing owners and outputs before assigning more work.
State the inputs, write scope, acceptance criteria, and evidence required.
```

## Requirements and verified scope

- The agent must be able to read the skill and relevant project materials. Writing, command execution, delegation, and independent review require their own capabilities and authorization.
- Core instructions do not require a specific model or agent platform. The optional `agents/openai.yaml` is interface metadata for compatible products.
- First-use questions, persistence, rediscovery, read-only use, and restricted-capability cases have been exercised in local isolated fixtures and independently reviewed. Some capability restrictions were simulated. Other agent products and fresh-session automatic loading have not been verified.
- Directory scripts require PowerShell. Ordinary Windows paths have been tested; PowerShell 7 passed a deep-path fixture, while Windows PowerShell 5.1 has a known long-path limitation. Other operating systems have not been tested.
- Self-checks are not independent review. Navigation checks do not validate project facts. Lower cost, token usage, or elapsed time is not guaranteed.

See [compatibility and validation scope](docs/COMPATIBILITY.md) before relying on an untested setup.

## Feedback and license

Use repository Issues for bugs or suggestions. Include the skill version, platform, expected and observed behavior, and a minimal example with sensitive information removed. See [Contributing](CONTRIBUTING.md).

[MIT licensed](LICENSE): use, modify, redistribute, and use commercially while retaining the copyright and license notice. Each standalone skill includes its own license file.
