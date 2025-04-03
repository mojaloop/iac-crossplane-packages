const path = require('path');
const fs = require('fs');

const cwd = process.cwd(); // e.g., /home/runner/work/repo/packages/utils
const parts = cwd.split(path.sep);

// Find package name (assumes you're in `packages/<name>`)
const packageIndex = parts.lastIndexOf('packages');
const pkgName = parts[packageIndex + 1] || 'unknown';

module.exports = {
  branches: ['main'],
  tagFormat: `${pkgName}/v\${version}`,
  plugins: [
    '@semantic-release/commit-analyzer',
    '@semantic-release/release-notes-generator',
  ],
};
