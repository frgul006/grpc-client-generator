# Discovery Questions

These questions help understand the broader context and requirements for enhancing the `lab setup` command to install dependencies across all packages in the monorepo.

## Q1: Should the setup process fail if any individual package's dependency installation fails?
**Default if unknown:** No (better to continue with warnings and report failures at the end)

## Q2: Should the setup maintain a local npm cache shared across all package installations?
**Default if unknown:** Yes (improves installation speed and reduces network usage)

## Q3: Should packages be installed in parallel to improve setup performance?
**Default if unknown:** No (sequential installation ensures dependencies are available in order)

## Q4: Should the setup validate package.json files before attempting installation?
**Default if unknown:** Yes (prevents errors from malformed package.json files)

## Q5: Should the setup display real-time progress for each package installation?
**Default if unknown:** Yes (provides better developer experience and troubleshooting)