#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const ROOT = path.resolve(__dirname, '..');

// Mapping: authoritative source -> co-located destinations
// Rubrics co-located into skill directories that reference them
const RUBRIC_SYNC = [
  {
    src: 'rubrics/plan-review-rubric-adversarial.md',
    dests: ['skills/plan-review-gate/rubrics/plan-review-rubric-adversarial.md']
  },
  {
    src: 'rubrics/adversarial-review-rubric.md',
    dests: [
      'skills/orchestrated-execution/rubrics/adversarial-review-rubric.md',
      'skills/start/rubrics/adversarial-review-rubric.md'
    ]
  },
  {
    src: 'rubrics/external-tool-review-rubric.md',
    dests: ['skills/external-tools/rubrics/external-tool-review-rubric.md']
  },
  {
    src: 'rubrics/security-review-rubric.md',
    dests: ['skills/start/rubrics/security-review-rubric.md']
  },
  {
    src: 'rubrics/plan-review-rubric.md',
    dests: ['skills/start/rubrics/plan-review-rubric.md']
  },
  {
    src: 'rubrics/release-engineering-rubric.md',
    dests: ['skills/start/rubrics/release-engineering-rubric.md']
  },
  {
    src: 'rubrics/code-review-rubric.md',
    dests: ['skills/start/rubrics/code-review-rubric.md']
  },
];

// Guides co-located into skill directories that reference them
const GUIDE_SYNC = [
  {
    src: 'guides/agent-coordination.md',
    dests: [
      'skills/orchestrated-execution/guides/agent-coordination.md',
      'skills/design-review-gate/guides/agent-coordination.md',
      'skills/pr-shepherd/guides/agent-coordination.md',
      'skills/start/guides/agent-coordination.md'
    ]
  },
  {
    src: 'guides/dispatch-contract.md',
    dests: [
      'skills/orchestrated-execution/guides/dispatch-contract.md',
      'skills/design-review-gate/guides/dispatch-contract.md',
      'skills/plan-review-gate/guides/dispatch-contract.md'
    ]
  },
];

// Dynamic sync: entire directories into skills/setup/
function buildDirSync(srcDir, destDir) {
  const srcPath = path.join(ROOT, srcDir);
  if (!fs.existsSync(srcPath)) return [];
  return fs.readdirSync(srcPath)
    .filter(f => {
      const full = path.join(srcPath, f);
      return fs.statSync(full).isFile();
    })
    .map(f => ({
      src: `${srcDir}/${f}`,
      dests: [`${destDir}/${f}`]
    }));
}

const SYNC_MAP = [
  ...RUBRIC_SYNC,
  ...GUIDE_SYNC,
  ...buildDirSync('agents', 'skills/start/agents'),
  ...buildDirSync('templates', 'skills/setup/templates'),
  ...buildDirSync('knowledge', 'skills/setup/knowledge'),
  ...buildDirSync('bin', 'skills/setup/bin'),
  ...buildDirSync('scripts', 'skills/setup/scripts'),
];

function hashFile(filepath) {
  const content = fs.readFileSync(filepath, 'utf-8')
    .replace(/\r\n/g, '\n')     // LF normalize
    .replace(/[ \t]+$/gm, '');  // strip trailing whitespace
  return crypto.createHash('sha256').update(content).digest('hex');
}

function validateManifests() {
  let issues = 0;
  const pkgPath = path.join(ROOT, 'package.json');
  const claudePluginPath = path.join(ROOT, '.claude-plugin', 'plugin.json');
  const codexPluginPath = path.join(ROOT, '.codex-plugin', 'plugin.json');
  const codexMarketplacePath = path.join(ROOT, '.agents', 'plugins', 'marketplace.json');
  const claudeMarketplacePath = path.join(ROOT, '.claude-plugin', 'marketplace.json');

  const versions = {};
  const manifests = [
    ['package.json', pkgPath],
    ['.claude-plugin/plugin.json', claudePluginPath],
    ['.codex-plugin/plugin.json', codexPluginPath],
  ];

  for (const [label, filePath] of manifests) {
    if (!fs.existsSync(filePath)) continue;
    try {
      versions[label] = JSON.parse(fs.readFileSync(filePath, 'utf-8')).version;
    } catch (e) {
      console.error(`MALFORMED: ${label} — ${e.message}`);
      issues++;
    }
  }

  const uniqueVersions = [...new Set(Object.values(versions))];
  if (uniqueVersions.length > 1) {
    console.error('VERSION MISMATCH across manifests:');
    for (const [file, ver] of Object.entries(versions)) {
      console.error(`  ${file}: ${ver}`);
    }
    issues++;
  }

  if (!fs.existsSync(codexPluginPath)) {
    console.error('MISSING: .codex-plugin/plugin.json');
    issues++;
  } else {
    try {
      const codexPlugin = JSON.parse(fs.readFileSync(codexPluginPath, 'utf-8'));
      if (codexPlugin.name !== 'metaswarm') {
        console.error(`INVALID: .codex-plugin/plugin.json name must be "metaswarm" (found ${JSON.stringify(codexPlugin.name)})`);
        issues++;
      }
      if (codexPlugin.skills !== './skills/') {
        console.error(`INVALID: .codex-plugin/plugin.json skills must be "./skills/" (found ${JSON.stringify(codexPlugin.skills)})`);
        issues++;
      }
    } catch (e) {
      // Already reported by manifest parsing above; keep this guard local.
    }
  }

  if (!fs.existsSync(codexMarketplacePath)) {
    console.error('MISSING: .agents/plugins/marketplace.json');
    issues++;
  } else {
    try {
      const marketplace = JSON.parse(fs.readFileSync(codexMarketplacePath, 'utf-8'));
      const entry = Array.isArray(marketplace.plugins) ? marketplace.plugins[0] : null;
      if (!entry) {
        console.error('INVALID: .agents/plugins/marketplace.json plugins[0] must be the metaswarm entry');
        issues++;
      } else {
        if (entry.name !== 'metaswarm') {
          console.error('INVALID: .agents/plugins/marketplace.json plugins[0] must be the metaswarm entry');
          issues++;
        }
        let expectedRepoUrl = null;
        try {
          const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf-8'));
          const repoField = pkg.repository;
          const rawUrl = typeof repoField === 'string'
            ? repoField
            : (repoField && typeof repoField.url === 'string' ? repoField.url : null);
          expectedRepoUrl = rawUrl ? rawUrl.replace(/\.git$/, '') : null;
        } catch (e) {
          // Malformed package.json is already reported above.
        }
        const actualRepoUrl = entry.source && typeof entry.source.url === 'string'
          ? entry.source.url.replace(/\.git$/, '')
          : null;
        if (!entry.source || entry.source.source !== 'url' || !expectedRepoUrl || actualRepoUrl !== expectedRepoUrl) {
          console.error('INVALID: metaswarm Codex marketplace source must point at the metaswarm repository root URL (package.json repository)');
          issues++;
        }
        const allowedInstallation = new Set(['NOT_AVAILABLE', 'AVAILABLE', 'INSTALLED_BY_DEFAULT']);
        const allowedAuthentication = new Set(['ON_INSTALL', 'ON_USE']);
        const allowedCategories = new Set(['Coding', 'Productivity', 'Engineering']);
        if (!entry.policy || !allowedInstallation.has(entry.policy.installation)) {
          console.error(`INVALID: metaswarm Codex marketplace policy.installation must be one of ${[...allowedInstallation].join(', ')}`);
          issues++;
        }
        if (!entry.policy || !allowedAuthentication.has(entry.policy.authentication)) {
          console.error(`INVALID: metaswarm Codex marketplace policy.authentication must be one of ${[...allowedAuthentication].join(', ')}`);
          issues++;
        }
        if (typeof entry.category !== 'string' || !allowedCategories.has(entry.category)) {
          console.error(`INVALID: metaswarm Codex marketplace category must be one of ${[...allowedCategories].join(', ')}`);
          issues++;
        }
        // The Codex marketplace predates its version field. Preserve profiles
        // without it, but reject a declared version that drifts from package.json.
        if (entry.version !== undefined && entry.version !== versions['package.json']) {
          console.error(`INVALID: .agents/plugins/marketplace.json metaswarm version must match package.json (found ${JSON.stringify(entry.version)}, expected ${JSON.stringify(versions['package.json'])})`);
          issues++;
        }
      }
    } catch (e) {
      console.error(`MALFORMED: .agents/plugins/marketplace.json — ${e.message}`);
      issues++;
    }
  }

  if (!fs.existsSync(claudeMarketplacePath)) {
    console.error('MISSING: .claude-plugin/marketplace.json');
    issues++;
  } else {
    try {
      const marketplace = JSON.parse(fs.readFileSync(claudeMarketplacePath, 'utf-8'));
      const entry = Array.isArray(marketplace.plugins) ? marketplace.plugins[0] : null;
      if (!entry || entry.name !== 'metaswarm') {
        console.error('INVALID: .claude-plugin/marketplace.json plugins[0] must be the metaswarm entry');
        issues++;
      } else if (entry.version !== versions['package.json']) {
        console.error(`INVALID: .claude-plugin/marketplace.json metaswarm version must match package.json (found ${JSON.stringify(entry.version)}, expected ${JSON.stringify(versions['package.json'])})`);
        issues++;
      }
    } catch (e) {
      console.error(`MALFORMED: .claude-plugin/marketplace.json — ${e.message}`);
      issues++;
    }
  }

  // Check template files exist
  const requiredTemplates = ['AGENTS.md', 'AGENTS-append.md', 'CLAUDE.md', 'CLAUDE-append.md'];
  for (const tmpl of requiredTemplates) {
    const tmplPath = path.join(ROOT, 'templates', tmpl);
    if (!fs.existsSync(tmplPath)) {
      console.error(`MISSING: templates/${tmpl}`);
      issues++;
    }
  }

  // Check root instruction files exist
  const rootFiles = ['AGENTS.md'];
  for (const f of rootFiles) {
    if (!fs.existsSync(path.join(ROOT, f))) {
      console.error(`MISSING: ${f} (root)`);
      issues++;
    }
  }

  return issues;
}

// --- Main operations ---

function check() {
  let drifted = 0;

  // Check co-located resource sync
  for (const { src, dests } of SYNC_MAP) {
    const srcPath = path.join(ROOT, src);
    if (!fs.existsSync(srcPath)) continue;
    const srcHash = hashFile(srcPath);
    for (const dest of dests) {
      const destPath = path.join(ROOT, dest);
      if (!fs.existsSync(destPath)) {
        console.error(`MISSING: ${dest} (source: ${src})`);
        drifted++;
      } else {
        const destHash = hashFile(destPath);
        if (srcHash !== destHash) {
          console.error(`DRIFT: ${dest} differs from ${src}`);
          drifted++;
        }
      }
    }
  }

  // Check cross-platform manifests
  drifted += validateManifests();

  if (drifted > 0) {
    console.error(`\n${drifted} issue(s) found.`);
    console.error('For drift/missing issues, run: node lib/sync-resources.js --sync');
    console.error('For version mismatches or malformed files, fix the source files manually.');
    process.exit(1);
  }
  console.log('All resources are in sync.');
}

function sync() {
  let synced = 0;

  // Sync co-located resources
  for (const { src, dests } of SYNC_MAP) {
    const srcPath = path.join(ROOT, src);
    if (!fs.existsSync(srcPath)) continue;
    for (const dest of dests) {
      const destPath = path.join(ROOT, dest);
      fs.mkdirSync(path.dirname(destPath), { recursive: true });
      fs.copyFileSync(srcPath, destPath);
      synced++;
    }
  }

  console.log(`Synced ${synced} file(s).`);
}

const mode = process.argv[2];
if (mode === '--check') {
  check();
} else if (mode === '--sync') {
  sync();
} else {
  console.log('Usage: node lib/sync-resources.js [--check|--sync]');
  console.log('  --check   Verify co-located copies and manifests are in sync');
  console.log('  --sync    Copy authoritative resources to co-located destinations');
  process.exit(1);
}
