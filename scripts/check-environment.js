#!/usr/bin/env node

/**
 * Environment Check Script
 * Validates the runtime environment and provides appropriate guidance
 */

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

// Colors for output
const colors = {
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  reset: '\x1b[0m'
};

function log(level, message) {
  const timestamp = new Date().toISOString();
  const color = colors[level] || colors.reset;
  console.log(`${color}[${level.toUpperCase()}]${colors.reset} ${timestamp} - ${message}`);
}

function checkDockerAvailability() {
  try {
    execSync('docker --version', { stdio: 'pipe' });
    return true;
  } catch (error) {
    return false;
  }
}

function checkEnvironmentFile() {
  const envPath = path.join(process.cwd(), 'config', '.env');
  return fs.existsSync(envPath);
}

function checkWebContainerEnvironment() {
  // Check if running in WebContainer (Bolt.new environment)
  return process.env.NODE_ENV === 'development' && !checkDockerAvailability();
}

function main() {
  log('info', '🔍 Checking environment compatibility...');
  
  const isWebContainer = checkWebContainerEnvironment();
  const hasDocker = checkDockerAvailability();
  const hasEnvFile = checkEnvironmentFile();
  
  if (isWebContainer) {
    log('yellow', '⚠️  WebContainer environment detected');
    log('info', '📋 This is a development/preview environment');
    log('info', '🐳 Docker operations are not available in this environment');
    log('info', '💡 For full functionality, deploy to:');
    log('info', '   - Local machine with Docker installed');
    log('info', '   - Hugging Face Spaces (Docker)');
    log('info', '   - Cloud provider with container support');
    return;
  }
  
  if (!hasDocker) {
    log('red', '❌ Docker is not available');
    log('info', '📦 Please install Docker to run this application locally');
    log('info', '🔗 Visit: https://docs.docker.com/get-docker/');
    process.exit(1);
  }
  
  if (!hasEnvFile) {
    log('yellow', '⚠️  Environment file not found');
    log('info', '📝 Copy config/.env.example to config/.env and configure it');
    log('info', '🔧 Run: cp config/.env.example config/.env');
  }
  
  log('green', '✅ Environment check passed');
  log('info', '🚀 Ready to run n8n infrastructure');
}

if (require.main === module) {
  main();
}

module.exports = { checkDockerAvailability, checkEnvironmentFile, checkWebContainerEnvironment };