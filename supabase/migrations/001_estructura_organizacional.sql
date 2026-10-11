-- =====================================================================
-- 001 · ESTRUCTURA ORGANIZACIONAL PARA EL DASHBOARD
-- Crea departamentos y equipos (con su jefe) y añade a users los datos
-- que necesita el dashboard. Solo AÑADE: no borra ni renombra nada.
-- Se puede ejecutar más de una vez sin romper nada (if not exists).
-- =====================================================================

-- 1) DEPARTAMENTOS de cada empresa cliente
create table if not exists departments (
  id          uuid primary key default gen_random_uuid(),
  company_id  uuid not null references companies(id) on delete cascade,
  name        text not null,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  unique (company_id, name)          -- no se repite el nombre dentro de una empresa
);

-- 2) EQUIPOS dentro de un departamento, con su jefe (leader_user_id)
create table if not exists teams (
  id              uuid primary key default gen_random_uuid(),
  company_id      uuid not null references companies(id) on delete cascade,
  department_id   uuid not null references departments(id) on delete restrict,
  name            text not null,
  leader_user_id  uuid references users(id) on delete set null,
  is_active       boolean not null default true,
  created_at      timestamptz not null default now(),
  unique (department_id, name)       -- no se repite el nombre dentro de un departamento
);

-- 3) NUEVOS DATOS EN USERS (todos opcionales, la app no se entera)
alter table users
  add column if not exists department_id uuid references departments(id) on delete set null,
  add column if not exists team_id       uuid references teams(id) on delete set null,
  add column if not exists job_title     text,          -- cargo (se muestra en la cabecera)
  add column if not exists hire_date     date,          -- fecha de ingreso (filtro antigüedad)
  add column if not exists status        text not null default 'activo'
    check (status in ('invitado', 'activo', 'bloqueado', 'baja')),
  add column if not exists password_reset_requested_at timestamptz; -- alerta en Mantenimiento

-- 4) ÍNDICES para que los filtros del dashboard sean rápidos
create index if not exists idx_users_company     on users(company_id);
create index if not exists idx_users_department  on users(department_id);
create index if not exists idx_users_team        on users(team_id);
create index if not exists idx_teams_department  on teams(department_id);
create index if not exists idx_teams_leader      on teams(leader_user_id);

-- 5) SEGURIDAD: tablas nuevas nacen protegidas.
--    Sin políticas = la clave pública de la app NO puede leerlas.
--    El backend (clave secreta) sí puede, porque ignora RLS.
alter table departments enable row level security;
alter table teams       enable row level security;