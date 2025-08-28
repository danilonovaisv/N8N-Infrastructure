-- Enable pgvector (Supabase: run as superuser/migration)
create extension if not exists vector;

-- Schema
create schema if not exists knowledge;

-- Documents table
create table if not exists knowledge.documents (
  id uuid primary key default gen_random_uuid(),
  path text unique not null,
  title text,
  content text,
  source_url text,
  hash text not null,
  updated_at timestamptz not null default now()
);

-- Embeddings table (OpenAI text-embedding-3-large: 3072 dims; adjust if needed)
create table if not exists knowledge.embeddings (
  doc_id uuid primary key references knowledge.documents(id) on delete cascade,
  embedding vector(3072) not null,
  model text default 'text-embedding-3-large'
);

-- Vector index (IVFFLAT)
create index if not exists idx_embeddings_ivfflat on knowledge.embeddings using ivfflat (embedding vector_l2_ops) with (lists = 100);

-- Helpful view
create or replace view knowledge.searchable as
  select d.id, d.title, d.path, d.source_url, d.updated_at
  from knowledge.documents d
  order by d.updated_at desc;
