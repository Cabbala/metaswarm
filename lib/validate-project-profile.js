#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');

const ALLOWED_COMMAND_KEYS = [
  'test',
  'coverage',
  'lint',
  'typecheck',
  'format_check',
];

function usage() {
  console.error('Usage: node lib/validate-project-profile.js [--strict] [path]');
}

function isObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

let strict = false;
let profilePath;

for (const argument of process.argv.slice(2)) {
  if (argument === '--strict') {
    strict = true;
  } else if (argument.startsWith('--')) {
    console.error(`INVALID: unknown option ${argument}`);
    usage();
    process.exit(1);
  } else if (profilePath === undefined) {
    profilePath = argument;
  } else {
    console.error('INVALID: only one profile path may be provided');
    usage();
    process.exit(1);
  }
}

const requestedPath = profilePath || '.metaswarm/project-profile.json';
const resolvedPath = path.resolve(process.cwd(), requestedPath);
let profile;

try {
  profile = JSON.parse(fs.readFileSync(resolvedPath, 'utf8'));
} catch (error) {
  const kind = error.code === 'ENOENT' ? 'MISSING' : 'INVALID';
  console.error(`${kind}: ${requestedPath} — ${error.message}`);
  process.exit(1);
}

const errors = [];
const warnings = [];

if (!isObject(profile)) {
  errors.push('profile root must be a JSON object');
} else {
  if (!Object.prototype.hasOwnProperty.call(profile, 'schema_version')) {
    const message = strict
      ? 'schema_version is required in --strict mode'
      : 'schema_version is absent; accepting legacy profile without version validation';
    (strict ? errors : warnings).push(message);
  } else if (!Number.isInteger(profile.schema_version) || profile.schema_version !== 1) {
    errors.push('schema_version must be the integer 1');
  }

  if (!isObject(profile.commands)) {
    errors.push('commands must be an object');
  } else {
    for (const key of Object.keys(profile.commands)) {
      if (!ALLOWED_COMMAND_KEYS.includes(key)) {
        errors.push(`commands.${key} is not allowed`);
      }
    }

    for (const key of ALLOWED_COMMAND_KEYS) {
      if (!Object.prototype.hasOwnProperty.call(profile.commands, key)) {
        errors.push(`commands.${key} is required`);
        continue;
      }

      const value = profile.commands[key];
      if (value !== null && (typeof value !== 'string' || value.trim() === '')) {
        errors.push(`commands.${key} must be a non-empty string or null`);
      }
    }
  }
}

for (const warning of warnings) {
  console.warn(`WARNING: ${warning}`);
}

for (const error of errors) {
  console.error(`INVALID: ${error}`);
}

if (errors.length > 0) {
  process.exit(1);
}

console.log(`VALID: ${requestedPath}`);
