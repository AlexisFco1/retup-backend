-- =====================================================================
-- 003 · EVENTOS DE ACTIVIDAD DE LA APP (para los indicadores del dashboard)
-- Solo AÑADE tablas nuevas. La app aún no escribe en ellas (eso es el paso 11).
-- Se puede ejecutar más de una vez sin romper nada.
-- =====================================================================

-- 1) ACTIVIDAD GENERAL: aperturas de la app, logins, inicio y fin de píldoras.
--    Alimenta la "Matriz de sesiones por día y hora" y el "Total por hora".
create table if not exists user_activity_events (
  id           bigint generated always as identity primary key,
  user_id      uuid not null references users(id) on delete cascade,
  company_id   uuid references companies(id) on delete set null,
  event_type   text not null
    check (event_type in ('app_open', 'app_resume', 'login', 'pill_start', 'pill_complete')),
  occurred_at  timestamptz not null default now(),   -- hora del SERVIDOR (fiable)
  reto_id      uuid references retos(id) on delete set null,
  pill_id      uuid references pildoras(id) on delete set null,
  origen       text check (origen in ('reto', 'suelta'))  -- píldora del reto o suelta (Inicio)
);

create index if not exists idx_activity_company_fecha on user_activity_events(company_id, occurred_at);
create index if not exists idx_activity_user_fecha    on user_activity_events(user_id, occurred_at);
create index if not exists idx_activity_tipo_fecha    on user_activity_events(event_type, occurred_at);

-- 2) RECORRIDO DENTRO DE LA PÍLDORA: una fila por cada sección visitada.
--    Alimenta tiempo por píldora/sección, embudo de retención y abandono.
create table if not exists pill_section_events (
  id               bigint generated always as identity primary key,
  user_id          uuid not null references users(id) on delete cascade,
  company_id       uuid references companies(id) on delete set null,
  reto_id          uuid references retos(id) on delete set null,
  pill_id          uuid not null references pildoras(id) on delete cascade,
  origen           text not null default 'reto' check (origen in ('reto', 'suelta')),
  pill_session_id  uuid not null,       -- agrupa una misma "visita" a la píldora (lo genera la app)
  section_number   smallint not null check (section_number between 1 and 20),
  entered_at       timestamptz not null,
  left_at          timestamptz,
  exit_type        text check (exit_type in ('siguiente', 'anterior', 'enviar', 'salir')),
  -- Calculados por la base de datos (no se pueden escribir a mano):
  duration_seconds integer generated always as (
    case when left_at is null then null
         else greatest(0, round(extract(epoch from (left_at - entered_at))))::integer
    end
  ) stored,
  completed        boolean generated always as (
    coalesce(exit_type in ('siguiente', 'enviar'), false)
  ) stored,                            -- "alcanzado" según el Word: pasó a la siguiente o envió
  created_at       timestamptz not null default now(),
  check (left_at is null or left_at >= entered_at)
);

create index if not exists idx_section_company_fecha on pill_section_events(company_id, entered_at);
create index if not exists idx_section_pill_seccion  on pill_section_events(pill_id, section_number);
create index if not exists idx_section_user_pill     on pill_section_events(user_id, pill_id);
create index if not exists idx_section_sesion        on pill_section_events(pill_session_id);

-- 3) SEGURIDAD: nacen protegidas (el backend sí puede escribir/leer)
alter table user_activity_events enable row level security;
alter table pill_section_events  enable row level security;