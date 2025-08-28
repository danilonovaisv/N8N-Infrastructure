// Node 20 script: sync knowledge repos into Supabase with embeddings
// Requires: OPENAI_API_KEY, SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, KNOWLEDGE_REPO_URL, KNOWLEDGE_DIRS
import { createClient } from '@supabase/supabase-js';
import crypto from 'node:crypto';
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import OpenAI from 'openai';

const {
  OPENAI_API_KEY,
  SUPABASE_URL,
  SUPABASE_SERVICE_ROLE_KEY,
  KNOWLEDGE_REPO_URL,
  KNOWLEDGE_DIRS = 'projects/n8n,projects/videos-e-animacoes,projects/midjorney-prompt',
} = process.env;

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY || !KNOWLEDGE_REPO_URL) {
  console.error('Missing env SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY or KNOWLEDGE_REPO_URL');
  process.exit(1);
}

const openai = OPENAI_API_KEY ? new OpenAI({ apiKey: OPENAI_API_KEY }) : null;
const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

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
  runCommand('git', ['clone', '--depth', '1', KNOWLEDGE_REPO_URL, repoDir]);
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
  const { data: doc, error: docErr } = await supabase
    .from('documents')
    .upsert({ path: pth, title, content, hash, updated_at: new Date() }, { onConflict: 'path' })
    .select('id, hash')
    .single();

  if (docErr) throw new Error(`Supabase doc upsert error: ${docErr.message}`);
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
    const vector = emb.data[0].embedding;

    const { error: embErr } = await supabase
      .from('embeddings')
      .upsert({ doc_id: doc.id, embedding: vector, model: 'text-embedding-3-large' }, { onConflict: 'doc_id' });
    if (embErr) throw new Error(`Supabase embedding upsert error: ${embErr.message}`);
  } else {
    console.warn('OPENAI_API_KEY not set, skipping embeddings for', pth);
  }
}

async function main() {
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
  if (errorCount > 0) {
      process.exit(1);
  }
}

main().catch(err => { console.error(err); process.exit(1); });
