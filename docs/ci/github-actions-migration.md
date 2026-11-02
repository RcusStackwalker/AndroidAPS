# Fork CI migration

## Settled requirements

- Base branch: origin/dev. Working branch: ci/github-actions.
- Replace CircleCI completely with GitHub Actions.
- Run the full JVM and instrumented test suites automatically.
- Trigger on pull requests into dev/master, pushes to master and any branch starting with dev, and manual dispatch.
- Cancel superseded runs.
- Keep test results and coverage as GitHub artifacts; external uploads are optional and must not require upstream credentials.

## Repository findings

- JVM tests already have a GitHub Actions workflow, currently gated in forks by RUN_CI.
- CircleCI uses an upstream self-hosted runner with three API 31 emulators for app shards plus non-app device tests.
- Existing Codecov verification references the upstream repository explicitly.

## Execution design

- Use GitHub-hosted runners; no upstream or fork-owned self-hosted runner is required.
- Run JVM tests independently from device tests.
- Give each app instrumentation shard and the non-app device suite its own job and emulator.
- Preserve the existing device test coverage and failure detection when moving execution.
- Enable test CI directly in this fork without requiring RUN_CI configuration.
- Preserve test reports, logs, and coverage as artifacts, including diagnostics on failures.
- Remove both .circleci/config.yml and .circleci/config.yml.cloud.
- Leave signed release and iOS workflows outside this migration.
- External coverage uploads remain optional; remove dependence on upstream-specific verification.

## Design status

Design confirmed by the user; implemented on ci/github-actions.


## Operating the workflows

Enable GitHub Actions in the fork. No RUN_CI variable or secrets are required.
The JVM workflow and four device jobs run for pushes to master and any branch starting
with dev, PRs targeting dev/master, and manual dispatch. Each device job uses an API 31 Play Store
x86_64 emulator. App shards compile before emulator startup.

Download unit-test-results and device-test-results-{A,B,C,modules} from the run
for reports, coverage, and device diagnostics. Artifacts are retained for seven days.
App shards retry process crashes or missing coverage up to three times; test
assertion failures fail the job. Non-app suites use Gradle's connected test tasks.

Optional: configure a fork-owned CODECOV_TOKEN to upload coverage. Codecov expects
five uploads (JVM plus four device jobs). No upstream verification API is used.
Signed releases and iOS workflows retain their existing configuration.

The workflow files are validated locally with actionlint, and the helper with
bash -n and mocked adb result scenarios. A real GitHub-hosted run is still needed
to validate compilation, emulator startup, memory limits, and end-to-end execution.
