## ADDED Requirements

### Requirement: Pure structural refactor with no behavior changes

Extracting modules from Main.elm SHALL NOT change any observable behavior. All existing Elm unit tests and Playwright E2E tests SHALL pass unchanged without modification.

#### Scenario: All existing tests pass after refactor

- **WHEN** the refactor is complete
- **THEN** all Elm unit tests (`npx elm-test`) and Playwright E2E tests pass without any test modifications
