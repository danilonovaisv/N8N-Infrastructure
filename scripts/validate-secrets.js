#!/usr/bin/env node

/**
 * Secret Validation Script
 * Validates environment variables and secrets for security compliance
 */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

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

// Required environment variables with validation rules
const requiredSecrets = {
  N8N_ENCRYPTION_KEY: {
    minLength: 32,
    description: 'n8n encryption key for securing credentials',
    generate: () => crypto.randomBytes(32).toString('hex')
  },
  N8N_USER_MANAGEMENT_JWT_SECRET: {
    minLength: 32,
    description: 'JWT secret for user management',
    generate: () => crypto.randomBytes(32).toString('hex')
  },
  DB_POSTGRESDB_HOST: {
    required: true,
    description: 'Supabase PostgreSQL host'
  },
  DB_POSTGRESDB_DATABASE: {
    required: true,
    description: 'Supabase database name'
  },
  DB_POSTGRESDB_USER: {
    required: true,
    description: 'Supabase database user'
  },
  DB_POSTGRESDB_PASSWORD: {
    minLength: 12,
    description: 'Supabase database password'
  }
};

function loadEnvironment() {
  const envPath = path.join(process.cwd(), 'config', '.env');
  
  if (!fs.existsSync(envPath)) {
    log('yellow', '⚠️  No .env file found. Using environment variables.');
    return process.env;
  }
  
  const envContent = fs.readFileSync(envPath, 'utf8');
  const env = { ...process.env };
  
  envContent.split('\n').forEach(line => {
    const trimmed = line.trim();
    if (trimmed && !trimmed.startsWith('#')) {
      const [key, ...valueParts] = trimmed.split('=');
      if (key && valueParts.length > 0) {
        env[key.trim()] = valueParts.join('=').trim().replace(/^["']|["']$/g, '');
      }
    }
  });
  
  return env;
}

function validateSecret(key, value, rules) {
  const issues = [];
  
  if (!value || value.trim() === '') {
    if (rules.required) {
      issues.push(`${key} is required but not set`);
    }
    return issues;
  }
  
  if (rules.minLength && value.length < rules.minLength) {
    issues.push(`${key} must be at least ${rules.minLength} characters long`);
  }
  
  // Check for common weak patterns
  if (value === 'changeme' || value === 'password' || value === '123456') {
    issues.push(`${key} uses a weak/default value`);
  }
  
  // Check for placeholder values
  if (value.includes('REPLACE') || value.includes('CHANGE') || value.includes('TODO')) {
    issues.push(`${key} contains placeholder text`);
  }
  
  return issues;
}

function generateMissingSecrets(env) {
  const updates = {};
  let hasUpdates = false;
  
  for (const [key, rules] of Object.entries(requiredSecrets)) {
    if ((!env[key] || env[key].trim() === '') && rules.generate) {
      updates[key] = rules.generate();
      hasUpdates = true;
      log('info', `🔑 Generated new ${key}`);
    }
  }
  
  if (hasUpdates) {
    log('yellow', '⚠️  Generated secrets above. Please update your .env file:');
    console.log('\n# Add these to your config/.env file:');
    for (const [key, value] of Object.entries(updates)) {
      console.log(`${key}=${value}`);
    }
    console.log('');
  }
  
  return hasUpdates;
}

function main() {
  log('info', '🔐 Validating secrets and environment variables...');
  
  const env = loadEnvironment();
  let hasErrors = false;
  let hasWarnings = false;
  
  // Validate each required secret
  for (const [key, rules] of Object.entries(requiredSecrets)) {
    const value = env[key];
    const issues = validateSecret(key, value, rules);
    
    if (issues.length > 0) {
      issues.forEach(issue => {
        if (rules.required && (!value || value.trim() === '')) {
          log('red', `❌ ${issue}`);
          hasErrors = true;
        } else {
          log('yellow', `⚠️  ${issue}`);
          hasWarnings = true;
        }
      });
      
      if (rules.description) {
        log('info', `   ℹ️  ${rules.description}`);
      }
    } else if (value && value.trim() !== '') {
      log('green', `✅ ${key} is properly configured`);
    }
  }
  
  // Generate missing secrets
  const hasGenerated = generateMissingSecrets(env);
  
  // Check SSL configuration
  if (env.DB_POSTGRESDB_SSL_REJECT_UNAUTHORIZED === 'false') {
    log('yellow', '⚠️  SSL certificate verification is disabled');
    log('info', '   💡 Consider enabling SSL_REJECT_UNAUTHORIZED=true for production');
    hasWarnings = true;
  }
  
  // Summary
  console.log('\n' + '='.repeat(50));
  if (hasErrors) {
    log('red', '❌ Validation failed with errors');
    log('info', '🔧 Please fix the errors above before proceeding');
    process.exit(1);
  } else if (hasWarnings || hasGenerated) {
    log('yellow', '⚠️  Validation completed with warnings');
    log('info', '💡 Consider addressing the warnings for better security');
  } else {
    log('green', '✅ All secrets are properly configured');
  }
}

if (require.main === module) {
  main();
}

module.exports = { validateSecret, loadEnvironment, generateMissingSecrets };