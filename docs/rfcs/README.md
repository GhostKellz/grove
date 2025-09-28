# Grove RFCs (Request for Comments)

This directory contains Grove's RFC (Request for Comments) process for proposing and discussing significant changes to the library.

## What is an RFC?

An RFC is a design document that describes a new feature, significant change, or architectural decision for Grove. RFCs are used to:

- Propose breaking changes to public APIs
- Introduce new major features or modules
- Change fundamental architectural decisions
- Establish new conventions or standards

## When to Write an RFC

You should write an RFC if your change:

- Adds a new public API surface area
- Changes existing public APIs in breaking ways
- Introduces new dependencies or build requirements
- Significantly changes performance characteristics
- Affects backward compatibility
- Requires coordination across multiple modules

You probably don't need an RFC for:

- Bug fixes
- Documentation improvements
- Internal refactoring without API changes
- Adding new language support (use contribution guide instead)
- Small additive features that don't change existing behavior

## RFC Process

### 1. Preliminary Discussion

Before writing an RFC, consider:

- Opening a GitHub issue to gauge interest
- Discussing in GitHub Discussions
- Reaching out to maintainers for guidance

### 2. Write the RFC

Copy the template from `template.md` and fill it out:

```bash
cp docs/rfcs/template.md docs/rfcs/0000-your-feature.md
```

Follow the template structure and provide detailed information about:
- Motivation and problem statement
- Detailed design proposal
- Implementation strategy
- Migration plan for breaking changes
- Alternatives considered

### 3. Submit for Review

1. Create a pull request with your RFC
2. Name it "RFC: Your Feature Name"
3. The RFC will receive a number when accepted
4. Link any related issues or discussions

### 4. Community Review

The RFC will go through community review:

- Maintainers and community members provide feedback
- Author updates the RFC based on feedback
- Technical concerns are addressed
- Consensus is built around the design

### 5. Final Comment Period

When the RFC is ready for decision:

- A "final comment period" begins (typically 1-2 weeks)
- Last chance for major objections or concerns
- Maintainers make final decision

### 6. Decision

RFCs can be:

- **Accepted** - Implementation can begin
- **Rejected** - Change will not be made (with reasoning)
- **Postponed** - Good idea but not the right time

### 7. Implementation

For accepted RFCs:

- Implementation follows the RFC design
- RFC is updated if design changes during implementation
- RFC is marked as "Implemented" when complete

## RFC Lifecycle

RFCs progress through these states:

- **Draft** - Being written and refined
- **Proposed** - Under community review
- **Final Comment Period** - Last chance for feedback
- **Accepted** - Approved for implementation
- **Rejected** - Not accepted
- **Postponed** - Delayed for future consideration
- **Implemented** - Completed and shipped

## Active RFCs

### Under Review

Currently no RFCs under review.

### Accepted

Currently no accepted RFCs pending implementation.

### Implemented

Currently no implemented RFCs (first RFC cycle).

## RFC Categories

RFCs are categorized by impact area:

- **Core** - Parser, Tree, Node APIs
- **Editor** - Integration, highlighting, services
- **Semantic** - Analysis, LSP, language features
- **Build** - Build system, dependencies, tooling
- **Meta** - Process, governance, project structure

## Guidelines for RFC Authors

### Writing Style

- Be clear and concise
- Include concrete examples
- Consider edge cases and error conditions
- Explain trade-offs and alternatives
- Use diagrams or code samples when helpful

### Technical Depth

- Provide enough detail for implementation
- Consider API design carefully
- Address backward compatibility
- Plan for testing and validation
- Consider performance implications

### Community Focus

- Explain benefits to users
- Consider learning curve for new APIs
- Address migration burden for existing users
- Seek feedback early and often

## Guidelines for Reviewers

### Constructive Feedback

- Focus on technical merit and design
- Suggest alternatives when criticizing
- Ask clarifying questions
- Share relevant experience or examples

### Review Scope

- API design and usability
- Implementation feasibility
- Backward compatibility concerns
- Performance and resource implications
- Testing and validation approach

## Historical Context

This RFC process is inspired by:

- [Rust RFC Process](https://github.com/rust-lang/rfcs)
- [Python PEP Process](https://peps.python.org/)
- [React RFC Process](https://github.com/reactjs/rfcs)

Adapted for Grove's specific needs and community size.

## Contact

For questions about the RFC process:

- Open an issue with the "rfc-question" label
- Start a discussion in GitHub Discussions
- Reach out to maintainers directly

Thank you for helping improve Grove through thoughtful design discussion!