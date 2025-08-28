// Node 20 script: sync knowledge repos into Supabase with embeddings
// Requires: OPENAI_API_KEY, SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, KNOWLEDGE_REPO_URL, KNOWLEDGE_DIRS
import { createClient } from '@supabase/supabase-js';
import crypto from 'node:crypto';
import { execSync } from 'node:child_process';
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

const repoDir = path.join(workdir, 'CHATGPT-knowledge-base');
if (!fs.existsSync(repoDir)) {
  console.log('Cloning KB repo...');
  execSync(`git clone --depth 1 ${KNOWLEDGE_REPO_URL} ${repoDir}`, { stdio: 'inherit' });
} else {
  console.log('Pulling KB repo...');
  execSync(`git -C ${repoDir} pull`, { stdio: 'inherit' });
}

const dirs = KNOWLEDGE_DIRS.split(',').map(s => s.trim());

function sha256(s){ return crypto.createHash('sha256').update(s).digest('hex'); }

async function upsertDoc(pth, content) {
  const title = path.basename(pth);
  const hash = sha256(content);

  // Upsert document
  const { data: doc, error: docErr } = await supabase
    .from('knowledge.documents')
    .upsert({ path: pth, title, content, hash }, { onConflict: 'path' })
    .select()
    .single();
  if (docErr) throw docErr;

  if (openai) {
    // Embedding
    const input = content.slice(0, 12000); // truncate
    const emb = await openai.embeddings.create({
      model: 'text-embedding-3-large',
      input
    });
    const vector = emb.data[0].embedding;

    const { error: embErr } = await supabase
      .from('knowledge.embeddings')
      .upsert({ doc_id: doc.id, embedding: vector, model: 'text-embedding-3-large' });
    if (embErr) throw embErr;
  } else {
    console.warn('OPENAI_API_KEY not set, skipping embeddings for', pth);
  }
}

async function main() {
  for (const rel of dirs) {
    const abs = path.join(repoDir, rel);
    if (!fs.existsSync(abs)) {
      console.warn('Skip missing dir:', rel);
      continue;
    }
    const entries = await fs.promises.readdir(abs, { withFileTypes: true });
    for (const ent of entries) {
      const full = path.join(abs, ent.name);
      if (ent.isDirectory()) continue;
      if (!/\.(md|markdown|json|txt)$/i.test(ent.name)) continue;

      const content = await fs.promises.readFile(full, 'utf8');
      const repoRelPath = path.relative(repoDir, full);
      console.log('Ingest:', repoRelPath);
      await upsertDoc(repoRelPath, content);
    }
  }
  console.log('Sync complete');
}

main().catch(err => { console.error(err); process.exit(1); });
