#!/usr/bin/env bash
# Fix the recurring nanopb BUILD-vs-build case-insensitive collision.
#
# nanopb (Firebase dependency) ships a Bazel config file named `BUILD`.
# Xcode's build system wants to create a `build/` directory at the same
# path. On macOS APFS (case-insensitive by default), these collide and
# the build fails with:
#
#   error: File exists but is not a directory:
#     .../SourcePackages/checkouts/nanopb/build
#
# Run this script after every `resolvePackageDependencies` or DerivedData
# wipe to neutralize the conflict. The BUILD file is only used by Bazel
# and is irrelevant to Xcode/SPM builds.

set -euo pipefail

DERIVED_DATA="${HOME}/Library/Developer/Xcode/DerivedData"
PROJECT_PREFIX="StripMate-"

# Find every matching DerivedData directory (handles multiple Xcode workspaces)
shopt -s nullglob
matches=("${DERIVED_DATA}/${PROJECT_PREFIX}"*/SourcePackages/checkouts/nanopb/BUILD)

if [ ${#matches[@]} -eq 0 ]; then
  echo "No nanopb BUILD file found — nothing to do."
  exit 0
fi

for build_file in "${matches[@]}"; do
  echo "Removing: $build_file"
  chmod +w "$build_file"
  rm "$build_file"
done

echo "Done. You can now run xcodebuild."
