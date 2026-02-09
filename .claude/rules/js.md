---
paths:
  - "**/*.js"
  - "**/*.ts"
  - "**/*.tsx"
  - "**/*.jsx"
  - "**/package.json"
---

# JavaScript / TypeScript Development

If not specified otherwise in project-specific CLAUDE.md, use these defaults.
When initializing a project CLAUDE.md, don't duplicate these instructions.

## Build Commands

- Build: `yarn build`
- Dev server: `yarn dev`
- Typecheck: `yarn typecheck`
- Lint: `yarn lint` or `yarn lint:fix`
- Format: `yarn prettier` or `yarn prettier:write`
- Unit tests: `yarn test:unit`
- Integration tests: `yarn test`
- Single test: `yarn test tests/integration/path/to/test.spec.ts`

## Code Style

- TypeScript with strict typing and React
- Use absolute imports with path aliases (@components, @utils, etc.)
- Single quotes for strings with trailing commas
- Function components with named exports
- Explicit return types on exported functions
- Tailwind for styling with tailwind-merge for conditional classes
- Prefer functional programming patterns and avoid side effects
- Use Zustand for state management
- Break complex components into smaller functions/components
- Follow existing patterns for error handling (try/catch with error boundaries)
- Use descriptive variable names with camelCase

## Testing

- Jest for unit tests (in tests/unit)
- Playwright for integration tests (in tests/integration)
- Use test fixtures from tests/integration/fixtures
