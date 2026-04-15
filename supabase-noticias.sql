-- ═══════════════════════════════════════════════════════════
-- Crear tabla noticias en Supabase
-- Ejecutar en Supabase → SQL Editor
-- ═══════════════════════════════════════════════════════════

create table if not exists public.noticias (
  id           uuid default uuid_generate_v4() primary key,
  titulo       text not null,
  contenido    text not null,
  extracto     text,
  tag          text default 'Noticia',
  fecha_pub    date default current_date,
  imagen_url   text,
  autor_id     uuid references public.profiles(id),
  autor_nombre text,
  publicado    boolean default false,
  created_at   timestamptz default now(),
  updated_at   timestamptz default now()
);

alter table public.noticias enable row level security;

-- Admin puede gestionar todo
create policy "Admin gestiona noticias" on public.noticias
  for all using (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and role in ('admin','maestro')
    )
  );

-- Público autenticado ve las publicadas
create policy "Ver noticias publicadas" on public.noticias
  for select using (publicado = true);
