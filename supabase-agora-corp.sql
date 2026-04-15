-- ═══════════════════════════════════════════════════════════
-- Tablas para Radio Ágora y Corporación Elqui
-- Ejecutar en Supabase → SQL Editor
-- ═══════════════════════════════════════════════════════════

-- ── RADIO ÁGORA — episodios de podcast ──
create table if not exists public.episodios (
  id           uuid default uuid_generate_v4() primary key,
  numero       integer not null,
  titulo       text not null,
  descripcion  text,
  duracion     text,
  categoria    text default 'Filosofía masónica',
  audio_url    text,
  imagen_url   text,
  publicado    boolean default false,
  autor_id     uuid references public.profiles(id),
  created_at   timestamptz default now()
);

alter table public.episodios enable row level security;

create policy "Ver episodios publicados" on public.episodios
  for select using (publicado = true);

create policy "Admin gestiona episodios" on public.episodios
  for all using (
    exists (select 1 from public.profiles where id = auth.uid() and role in ('admin','maestro'))
  );

-- ── CORPORACIÓN ELQUI — noticias ──
create table if not exists public.corp_noticias (
  id           uuid default uuid_generate_v4() primary key,
  titulo       text not null,
  contenido    text not null,
  extracto     text,
  tag          text default 'Corporación',
  fecha_pub    date default current_date,
  imagen_url   text,
  autor_id     uuid references public.profiles(id),
  autor_nombre text,
  publicado    boolean default false,
  created_at   timestamptz default now()
);

alter table public.corp_noticias enable row level security;

create policy "Ver corp noticias publicadas" on public.corp_noticias
  for select using (publicado = true);

create policy "Admin gestiona corp noticias" on public.corp_noticias
  for all using (
    exists (select 1 from public.profiles where id = auth.uid() and role in ('admin','maestro'))
  );

-- ── CORPORACIÓN ELQUI — blog ──
create table if not exists public.corp_posts (
  id           uuid default uuid_generate_v4() primary key,
  titulo       text not null,
  contenido    text not null,
  extracto     text,
  categoria    text default 'Cultura',
  autor_id     uuid references public.profiles(id),
  autor_nombre text,
  publicado    boolean default false,
  created_at   timestamptz default now()
);

alter table public.corp_posts enable row level security;

create policy "Ver corp posts publicados" on public.corp_posts
  for select using (publicado = true);

create policy "Admin gestiona corp posts" on public.corp_posts
  for all using (
    exists (select 1 from public.profiles where id = auth.uid() and role in ('admin','maestro'))
  );
