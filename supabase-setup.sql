-- ═══════════════════════════════════════════════════════════
-- PASOS PERDIDOS — Intranet Logia Crisol del Elqui N°189
-- Script SQL para Supabase — ejecutar en SQL Editor
-- ═══════════════════════════════════════════════════════════

-- 1. EXTENSIONES
create extension if not exists "uuid-ossp";

-- ═══════════════════════════════════════════════════════════
-- 2. TABLA DE PERFILES (extiende auth.users de Supabase)
-- ═══════════════════════════════════════════════════════════
create table public.profiles (
  id            uuid references auth.users(id) on delete cascade primary key,
  role          text not null check (role in ('aprendiz','companero','maestro','admin')),
  nombre        text not null,
  apellido      text,
  email         text,
  telefono      text,
  grado         text,
  profesion     text,
  lugar_trabajo text,
  estado_civil  text,
  fecha_ingreso date,
  fecha_nacimiento date,
  familiares    jsonb default '[]',
  biografia     text,
  avatar_url    text,
  hero_url      text,
  activo        boolean default true,
  created_at    timestamptz default now(),
  updated_at    timestamptz default now()
);

-- Trigger para crear perfil automáticamente al registrar usuario
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, role, nombre, email)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'role', 'aprendiz'),
    coalesce(new.raw_user_meta_data->>'nombre', 'Hermano'),
    new.email
  );
  return new;
end;
$$ language plpgsql security definer;

create or replace trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ═══════════════════════════════════════════════════════════
-- 3. GALERÍA DE FOTOS
-- ═══════════════════════════════════════════════════════════
create table public.gallery (
  id          uuid default uuid_generate_v4() primary key,
  role        text not null check (role in ('aprendiz','companero','maestro','todos')),
  url         text not null,
  caption     text,
  author_id   uuid references public.profiles(id),
  created_at  timestamptz default now()
);

-- ═══════════════════════════════════════════════════════════
-- 4. BLOG POSTS (por rol: 2°Vigilante / 1°Vigilante / Orador)
-- ═══════════════════════════════════════════════════════════
create table public.posts (
  id          uuid default uuid_generate_v4() primary key,
  role        text not null check (role in ('aprendiz','companero','maestro')),
  titulo      text not null,
  contenido   text not null,
  extracto    text,
  autor_id    uuid references public.profiles(id),
  autor_nombre text,
  publicado   boolean default false,
  created_at  timestamptz default now(),
  updated_at  timestamptz default now()
);

-- ═══════════════════════════════════════════════════════════
-- 5. DOCUMENTOS / BIBLIOTECA
-- ═══════════════════════════════════════════════════════════
create table public.documents (
  id          uuid default uuid_generate_v4() primary key,
  role        text not null check (role in ('aprendiz','companero','maestro','todos')),
  nombre      text not null,
  descripcion text,
  tipo        text check (tipo in ('pdf','docx','jpg','png','otro')),
  url         text not null,
  categoria   text,
  autor_id    uuid references public.profiles(id),
  created_at  timestamptz default now()
);

-- ═══════════════════════════════════════════════════════════
-- 6. MENSAJERÍA PRIVADA
-- ═══════════════════════════════════════════════════════════
create table public.messages (
  id           uuid default uuid_generate_v4() primary key,
  from_id      uuid references public.profiles(id) not null,
  to_id        uuid references public.profiles(id) not null,
  contenido    text not null,
  leido        boolean default false,
  created_at   timestamptz default now()
);

-- ═══════════════════════════════════════════════════════════
-- 7. CHAT POR ROL (mensajes grupales en tiempo real)
-- ═══════════════════════════════════════════════════════════
create table public.chat_messages (
  id          uuid default uuid_generate_v4() primary key,
  role        text not null check (role in ('aprendiz','companero','maestro')),
  author_id   uuid references public.profiles(id) not null,
  autor_nombre text not null,
  contenido   text not null,
  created_at  timestamptz default now()
);

-- ═══════════════════════════════════════════════════════════
-- 8. HÉROE / PORTADA por rol
-- ═══════════════════════════════════════════════════════════
create table public.hero_images (
  id          uuid default uuid_generate_v4() primary key,
  role        text not null check (role in ('aprendiz','companero','maestro')) unique,
  url         text not null,
  titulo      text,
  subtitulo   text,
  updated_at  timestamptz default now()
);

-- Insertar heroes iniciales
insert into public.hero_images (role, url, titulo, subtitulo) values
  ('aprendiz',  '', 'Bienvenido, Aprendiz',  'El camino comienza con la piedra bruta'),
  ('companero', '', 'Bienvenido, Compañero', 'La sabiduría se construye paso a paso'),
  ('maestro',   '', 'Bienvenido, Maestro',   'El arte se perfecciona en el silencio');

-- ═══════════════════════════════════════════════════════════
-- 9. ROW LEVEL SECURITY (RLS) — cada rol solo ve sus datos
-- ═══════════════════════════════════════════════════════════

-- Habilitar RLS en todas las tablas
alter table public.profiles      enable row level security;
alter table public.gallery        enable row level security;
alter table public.posts          enable row level security;
alter table public.documents      enable row level security;
alter table public.messages       enable row level security;
alter table public.chat_messages  enable row level security;
alter table public.hero_images    enable row level security;

-- Función auxiliar: obtener el rol del usuario actual
create or replace function public.get_my_role()
returns text as $$
  select role from public.profiles where id = auth.uid();
$$ language sql security definer;

-- ── PROFILES: ver todos los perfiles activos si estás autenticado
create policy "Ver perfiles" on public.profiles
  for select using (auth.role() = 'authenticated');

create policy "Editar propio perfil" on public.profiles
  for update using (id = auth.uid());

-- ── GALLERY: ver las imágenes de tu rol o las de 'todos'
create policy "Ver galería de mi rol" on public.gallery
  for select using (
    auth.role() = 'authenticated' and
    (role = public.get_my_role() or role = 'todos')
  );

create policy "Insertar en galería" on public.gallery
  for insert with check (auth.role() = 'authenticated');

-- ── POSTS: ver los posts de tu rol
create policy "Ver posts de mi rol" on public.posts
  for select using (
    auth.role() = 'authenticated' and
    role = public.get_my_role() and
    publicado = true
  );

create policy "Maestros ven todos los posts" on public.posts
  for select using (
    public.get_my_role() = 'maestro'
  );

create policy "Insertar posts propios" on public.posts
  for insert with check (auth.role() = 'authenticated');

create policy "Editar posts propios" on public.posts
  for update using (autor_id = auth.uid());

-- ── DOCUMENTS: ver documentos de tu rol o los de 'todos'
create policy "Ver documentos de mi rol" on public.documents
  for select using (
    auth.role() = 'authenticated' and
    (role = public.get_my_role() or role = 'todos')
  );

create policy "Insertar documentos" on public.documents
  for insert with check (auth.role() = 'authenticated');

-- ── MESSAGES: ver solo tus mensajes (enviados o recibidos)
create policy "Ver mis mensajes" on public.messages
  for select using (
    auth.role() = 'authenticated' and
    (from_id = auth.uid() or to_id = auth.uid())
  );

create policy "Enviar mensajes" on public.messages
  for insert with check (
    auth.role() = 'authenticated' and
    from_id = auth.uid()
  );

create policy "Marcar como leído" on public.messages
  for update using (to_id = auth.uid());

-- ── CHAT: ver y enviar mensajes del chat de tu rol
create policy "Ver chat de mi rol" on public.chat_messages
  for select using (
    auth.role() = 'authenticated' and
    role = public.get_my_role()
  );

create policy "Enviar al chat de mi rol" on public.chat_messages
  for insert with check (
    auth.role() = 'authenticated' and
    role = public.get_my_role() and
    author_id = auth.uid()
  );

-- ── HERO: ver el hero de tu rol
create policy "Ver hero de mi rol" on public.hero_images
  for select using (
    auth.role() = 'authenticated' and
    role = public.get_my_role()
  );

create policy "Maestros actualizan heroes" on public.hero_images
  for update using (public.get_my_role() = 'maestro');

-- ═══════════════════════════════════════════════════════════
-- 10. REALTIME — habilitar para chat y mensajería
-- ═══════════════════════════════════════════════════════════
-- Ejecutar en Supabase Dashboard > Database > Replication
-- O con este comando:
alter publication supabase_realtime add table public.chat_messages;
alter publication supabase_realtime add table public.messages;

-- ═══════════════════════════════════════════════════════════
-- 11. STORAGE — buckets para archivos
-- ═══════════════════════════════════════════════════════════
-- Crear en Dashboard > Storage > New Bucket:
-- Bucket: "gallery"     → público: false
-- Bucket: "documents"   → público: false
-- Bucket: "avatars"     → público: true
-- Bucket: "heroes"      → público: true

-- ═══════════════════════════════════════════════════════════
-- 12. USUARIOS DE PRUEBA (ejecutar después de crear el proyecto)
-- Crear en Dashboard > Authentication > Users > Invite user
-- O usar la API con el script de seed que se entrega aparte
-- ═══════════════════════════════════════════════════════════

-- Ejemplo para insertar manualmente un perfil de maestro/admin:
-- (Primero crea el usuario en Auth, luego actualiza su perfil)
-- update public.profiles
-- set role = 'maestro', nombre = 'Venerable Maestro', activo = true
-- where email = 'venerable@logia189.cl';
