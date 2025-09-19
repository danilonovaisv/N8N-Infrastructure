// Node 20 script: sync knowledge repos into PostgreSQL with embeddings
// Requires: OPENAI_API_KEY, DB_POSTGRESDB_CONNECTION, KNOWLEDGE_REPO_URL, KNOWLEDGE_DIRS
import pkg from 'pg';
const { Client } = pkg;
import crypto from 'node:crypto';
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import OpenAI from 'openai';

const {
  OPENAI_API_KEY,
  DB_POSTGRESDB_CONNECTION,
  CLAW_TOKEN,
  KNOWLEDGE_REPO_URL,
  KNOWLEDGE_DIRS = 'projects/n8n,projects/videos-e-animacoes,projects/midjorney-prompt',
} = process.env;

if (!DB_POSTGRESDB_CONNECTION || !KNOWLEDGE_REPO_URL) {
  console.error('Missing env DB_POSTGRESDB_CONNECTION or KNOWLEDGE_REPO_URL');
  process.exit(1);
}

const openai = OPENAI_API_KEY ? new OpenAI({ apiKey: OPENAI_API_KEY }) : null;
const pgClient = new Client({ connectionString: DB_POSTGRESDB_CONNECTION });

const workdir = path.resolve('knowledge');
if (!fs.existsSync(workdir)) fs.mkdirSync(workdir, { recursive: true });

function runCommand(command, args, options = {}) {
  const result = spawnSync(command, args, { stdio: 'inherit', ...options });
  if (result.error) {
    throw result.error;
  }
  if (result.status !== 0) {
    throw new Error(`Command failed: ${command} ${args.join(' ')}`);
  }
}

const repoDir = path.join(workdir, 'CHATGPT-knowledge-base');
if (!fs.existsSync(repoDir)) {
  console.log('Cloning KB repo...');
  const repoUrl = CLAW_TOKEN ? KNOWLEDGE_REPO_URL.replace('https://', `https://x-access-token:${CLAW_TOKEN}@`) : KNOWLEDGE_REPO_URL;
  runCommand('git', ['clone', '--depth', '1', repoUrl, repoDir]);
} else {
  console.log('Pulling KB repo...');
  runCommand('git', ['pull'], { cwd: repoDir });
}

const dirs = KNOWLEDGE_DIRS.split(',').map(s => s.trim());

function sha256(s){ return crypto.createHash('sha256').update(s).digest('hex'); }

async function upsertDoc(pth, content) {
  const title = path.basename(pth);
  const hash = sha256(content);

  // Upsert document
  const docQuery = `
    INSERT INTO documents (path, title, content, hash, updated_at) 
    VALUES ($1, $2, $3, $4, NOW())
    ON CONFLICT (path) 
    DO UPDATE SET title = $2, content = $3, hash = $4, updated_at = NOW()
    RETURNING id, hash
  `;
  
  const docResult = await pgClient.query(docQuery, [pth, title, content, hash]);
  const doc = docResult.rows[0];
  
  if (!doc) throw new Error('Upsert did not return a document.');

  // If hash is the same, skip embedding
  if (doc.hash === hash && !process.env.FORCE_REEMBED) {
      console.log(`Skipping ${pth} (content unchanged)`);
      return;
  }

  if (openai) {
    // Embedding
    const input = content.slice(0, 12000); // truncate
    const emb = await openai.embeddings.create({
      model: 'text-embedding-3-large',
      input
    });
    const vector = JSON.stringify(emb.data[0].embedding);

    const embQuery = `
      INSERT INTO embeddings (doc_id, embedding, model) 
      VALUES ($1, $2, $3)
      ON CONFLICT (doc_id) 
      DO UPDATE SET embedding = $2, model = $3
    `;
    
    await pgClient.query(embQuery, [doc.id, vector, 'text-embedding-3-large']);
  } else {
    console.warn('OPENAI_API_KEY not set, skipping embeddings for', pth);
  }
}

async function main() {
  await pgClient.connect();
  console.log('Connected to PostgreSQL database');
  
  let successCount = 0;
  let errorCount = 0;

  for (const rel of dirs) {
    const abs = path.join(repoDir, rel);
    if (!fs.existsSync(abs)) {
      console.warn('Skip missing dir:', rel);
      continue;
    }
    const entries = await fs.promises.readdir(abs, { withFileTypes: true });
    for (const ent of entries) {
      if (ent.isDirectory() || !/\.(md|markdown|json|txt)$/i.test(ent.name)) {
        continue;
      }
      const full = path.join(abs, ent.name);
      const repoRelPath = path.relative(repoDir, full);
      try {
        const content = await fs.promises.readFile(full, 'utf8');
        console.log('Ingesting:', repoRelPath);
        await upsertDoc(repoRelPath, content);
        successCount++;
      } catch (err) {
        console.error(`Failed to process ${repoRelPath}: ${err.message}`);
        errorCount++;
      }
    }
  }
  console.log(`\nSync complete. ${successCount} processed, ${errorCount} errors.`);
  
  await pgClient.end();
  console.log('Database connection closed');
  
  if (errorCount > 0) {
      process.exit(1);
  }
}

main().catch(err => { console.error(err); process.exit(1); });
