#!/usr/bin/env node

/**
 * Security Check Script
 * Performs security audit of the repository and configuration
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// Colors for output
const colors = {
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  reset: '\x1b[0m'
};

function log(level, message) {
  const color = colors[level] || colors.reset;
  console.log(`${color}[${level.toUpperCase()}]${colors.reset} ${message}`);
}

function checkGitHistory() {
  log('info', '🔍 Checking Git history for sensitive data...');
  
  try {
    // Check for common sensitive patterns in git history
    const sensitivePatterns = [
      'password',
      'secret',
      'key',
      'token',
      'api_key',
      'database_url',
      'db_password'
    ];
    
    let foundIssues = false;
    
    for (const pattern of sensitivePatterns) {
      try {
        const result = execSync(`git log --all --full-history -- "*" | grep -i "${pattern}" || true`, 
          { encoding: 'utf8', stdio: 'pipe' });
        
        if (result.trim()) {
          log('yellow', `⚠️  Found potential sensitive data in history: ${pattern}`);
          foundIssues = true;
        }
      } catch (error) {
        // Ignore grep errors (no matches found)
      }
    }
    
    if (!foundIssues) {
      log('green', '✅ No obvious sensitive patterns found in Git history');
    } else {
      log('red', '❌ Potential sensitive data found in Git history');
      log('info', '🔧 Consider running: git filter-branch to clean history');
    }
    
  } catch (error) {
    log('yellow', '⚠️  Could not check Git history (not a git repository?)');
  }
}

function checkFilePermissions() {
  log('info', '🔍 Checking file permissions...');
  
  const sensitiveFiles = [
    'config/.env',
    'config/credentials',
    'scripts/backup.sh',
    'scripts/restore.sh'
  ];
  
  let hasIssues = false;
  
  for (const filePath of sensitiveFiles) {
    const fullPath = path.join(process.cwd(), filePath);
    
    if (fs.existsSync(fullPath)) {
      try {
        const stats = fs.statSync(fullPath);
        const mode = stats.mode & parseInt('777', 8);
        
        // Check if file is world-readable (others can read)
        if (mode & parseInt('004', 8)) {
          log('yellow', `⚠️  ${filePath} is world-readable`);
          hasIssues = true;
        }
        
        // Check if file is world-writable (others can write)
        if (mode & parseInt('002', 8)) {
          log('red', `❌ ${filePath} is world-writable`);
          hasIssues = true;
        }
        
      } catch (error) {
        log('yellow', `⚠️  Could not check permissions for ${filePath}`);
      }
    }
  }
  
  if (!hasIssues) {
    log('green', '✅ File permissions look secure');
  }
}

function checkDockerSecurity() {
  log('info', '🔍 Checking Docker configuration security...');
  
  const dockerfilePath = path.join(process.cwd(), 'docker', 'Dockerfile');
  
  if (fs.existsSync(dockerfilePath)) {
    const content = fs.readFileSync(dockerfilePath, 'utf8');
    let hasIssues = false;
    
    // Check for non-root user
    if (content.includes('USER node') || content.includes('USER 1000')) {
      log('green', '✅ Docker container runs as non-root user');
    } else {
      log('red', '❌ Docker container may be running as root');
      hasIssues = true;
    }
    
    // Check for health checks
    if (content.includes('HEALTHCHECK')) {
      log('green', '✅ Docker health check configured');
    } else {
      log('yellow', '⚠️  No Docker health check found');
      hasIssues = true;
    }
    
    // Check for pinned versions
    if (content.match(/FROM.*:\d+\.\d+\.\d+/)) {
      log('green', '✅ Base image version is pinned');
    } else {
      log('yellow', '⚠️  Base image version not pinned (using latest?)');
      hasIssues = true;
    }
    
  } else {
    log('yellow', '⚠️  No Dockerfile found');
  }
}

function checkEnvironmentSecurity() {
  log('info', '🔍 Checking environment configuration...');
  
  const envExamplePath = path.join(process.cwd(), 'config', '.env.example');
  const envPath = path.join(process.cwd(), 'config', '.env');
  
  // Check if .env is in .gitignore
  const gitignorePath = path.join(process.cwd(), '.gitignore');
  if (fs.existsSync(gitignorePath)) {
    const gitignoreContent = fs.readFileSync(gitignorePath, 'utf8');
    if (gitignoreContent.includes('.env') || gitignoreContent.includes('config/.env')) {
      log('green', '✅ .env file is properly ignored by Git');
    } else {
      log('red', '❌ .env file is not in .gitignore');
    }
  }
  
  // Check for .env in repository
  if (fs.existsSync(envPath)) {
    try {
      execSync('git ls-files config/.env', { stdio: 'pipe' });
      log('red', '❌ .env file is tracked by Git - SECURITY RISK!');
    } catch (error) {
      log('green', '✅ .env file is not tracked by Git');
    }
  }
}

function checkScriptSecurity() {
  log('info', '🔍 Checking script security...');
  
  const scriptFiles = [
    'scripts/backup.sh',
    'scripts/restore.sh',
    'scripts/sync-knowledge.sh'
  ];
  
  for (const scriptPath of scriptFiles) {
    const fullPath = path.join(process.cwd(), scriptPath);
    
    if (fs.existsSync(fullPath)) {
      const content = fs.readFileSync(fullPath, 'utf8');
      
      // Check for set -e (exit on error)
      if (content.includes('set -e') || content.includes('set -euo pipefail')) {
        log('green', `✅ ${scriptPath} has proper error handling`);
      } else {
        log('yellow', `⚠️  ${scriptPath} lacks error handling (set -e)`);
      }
      
      // Check for password exposure
      if (content.includes('export PGPASSWORD') && !content.includes('unset PGPASSWORD')) {
        log('yellow', `⚠️  ${scriptPath} exports password without cleanup`);
      }
    }
  }
}

function main() {
  log('info', '🛡️  Starting security audit...');
  console.log('='.repeat(50));
  
  checkGitHistory();
  console.log('');
  
  checkFilePermissions();
  console.log('');
  
  checkDockerSecurity();
  console.log('');
  
  checkEnvironmentSecurity();
  console.log('');
  
  checkScriptSecurity();
  console.log('');
  
  console.log('='.repeat(50));
  log('info', '🔍 Security audit completed');
  log('info', '💡 Review warnings and errors above');
  log('info', '📚 See SECURITY.md for detailed security guidelines');
}

if (require.main === module) {
  main();
}

module.exports = { checkGitHistory, checkFilePermissions, checkDockerSecurity };