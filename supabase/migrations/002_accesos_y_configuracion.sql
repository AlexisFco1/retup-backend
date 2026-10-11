-- =====================================================================
-- 002 · ACCESOS AL DASHBOARD Y CONFIGURACIÓN
-- Solo AÑADE tablas nuevas. No toca ninguna tabla que use la app.
-- Se puede ejecutar más de una vez sin romper nada.
-- =====================================================================

-- 1) ACCESOS AL DASHBOARD (una fila por cada nivel que tenga una persona)
create table if not exists dashboard_access (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references users(id) on delete cascade,
  company_id  uuid references companies(id) on delete cascade,
  level       text not null
    check (level in ('retup', 'rrhh_gerencia', 'jefatura', 'mantenimiento')),
  created_at  timestamptz not null default now(),
  created_by  uuid references users(id) on delete set null,
  unique (user_id, level),            -- el mismo nivel no se repite para una persona
  -- RetUp ve todas las empresas (sin company_id); los niveles de cliente
  -- SIEMPRE van atados a una empresa
  check (
    (level = 'retup' and company_id is null)
    or (level <> 'retup' and company_id is not null)
  )
);

create index if not exists idx_dashboard_access_user    on dashboard_access(user_id);
create index if not exists idx_dashboard_access_company on dashboard_access(company_id);

-- 2) CONFIGURACIÓN POR EMPRESA (valores que la spec pide que sean ajustables)
create table if not exists company_settings (
  company_id              uuid primary key references companies(id) on delete cascade,
  privacy_min_n           integer not null default 5
    check (privacy_min_n between 3 and 10),            -- umbral n<5 (spec §7.2)
  weight_nominations      numeric(4,2) not null default 0.55,  -- spec §7.1
  weight_performance      numeric(4,2) not null default 0.30,
  weight_self_assessment  numeric(4,2) not null default 0.15,
  activation_target_pct   numeric(5,2) not null default 85,    -- objetivo de activación
  heatmap_low             integer not null default 40,          -- escala de color
  heatmap_high            integer not null default 75,
  support_email           text,                                  -- botón de ayuda
  updated_at              timestamptz not null default now(),
  check (weight_nominations + weight_performance + weight_self_assessment = 1.00),
  check (heatmap_low < heatmap_high)
);

-- Crear la configuración por defecto para las empresas que ya existen
insert into company_settings (company_id)
select id from companies
on conflict (company_id) do nothing;

-- 3) PREFERENCIAS PERSONALES DEL DASHBOARD (se usarán más adelante)
create table if not exists dashboard_user_prefs (
  user_id          uuid primary key references users(id) on delete cascade,
  language         text not null default 'es' check (language in ('es', 'en')),
  refresh_minutes  integer not null default 60 check (refresh_minutes between 5 and 1440),
  updated_at       timestamptz not null default now()
);

-- 4) SEGURIDAD: las tablas nuevas nacen protegidas (el backend sí puede usarlas)
alter table dashboard_access     enable row level security;
alter table company_settings     enable row level security;
alter table dashboard_user_prefs enable row level security;