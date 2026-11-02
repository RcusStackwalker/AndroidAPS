# GitHub Actions migration plan

1. Enable the existing JVM workflow in forks and remove upstream coverage verification.
2. Add a hosted instrumentation matrix for app shards A/B/C and non-app device tests, retaining API 31, failure checks and coverage artifacts.
3. Remove CircleCI configuration and update migration documentation.
4. Validate workflows with actionlint and shell scripts with bash -n; exercise instrumentation result parsing with mocked adb. Hosted execution remains necessary for end-to-end validation.
