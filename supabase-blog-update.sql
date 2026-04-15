-- ═══════════════════════════════════════════════════════════
-- Agregar soporte para Revista Egrégora y Blog Venerable
-- Ejecutar en Supabase → SQL Editor
-- ═══════════════════════════════════════════════════════════

-- Agregar columna tipo a posts para distinguir secciones
alter table public.posts
  add column if not exists tipo text default 'blog'
    check (tipo in ('blog','egregora','venerable'));

-- Actualizar posts existentes del maestro como venerable
update public.posts set tipo = 'venerable'
  where role = 'maestro' and tipo is null;

-- Política pública: visitantes ven posts publicados del maestro y egrégora
create policy if not exists "Público ve posts publicados" on public.posts
  for select using (publicado = true);
