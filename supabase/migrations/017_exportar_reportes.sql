-- =====================================================================
-- 017 · EXPORTAR DATOS (RRHH · Gerencia)
--   reportes_historial     -> cada reporte generado (PDF / CSV)
--   reportes_envio_config  -> envío automático mensual por empresa
-- Seguridad: RLS activado SIN políticas -> solo el backend (service_role)
-- puede leer y escribir. La clave pública de la app no tiene acceso.
-- Se puede ejecutar más de una vez.
-- =====================================================================

-- ─────────────────────────────────────────────────────────────────────
-- 1) HISTORIAL DE REPORTES
-- ─────────────────────────────────────────────────────────────────────
create table if not exists reportes_historial (
  id               uuid primary key default gen_random_uuid(),
  company_id       uuid not null references companies(id) on delete cascade,
  tipo             text not null check (tipo in ('resumen_ejecutivo', 'datos_completos')),
  formato          text not null check (formato in ('pdf', 'csv')),
  periodo_desde    date not null,
  periodo_hasta    date not null,
  periodo_etiqueta text not null,               -- ej. 'T3 2026', 'Septiembre 2026'
  nombre_archivo   text not null,
  estado           text not null default 'descargado'
                   check (estado in ('generando', 'descargado', 'enviado', 'error')),
  origen           text not null default 'manual'
                   check (origen in ('manual', 'automatico')),
  generado_por     uuid references users(id) on delete set null,  -- null = automático
  detalle_error    text,
  created_at       timestamptz not null default now(),
  constraint reportes_historial_periodo_ok check (periodo_desde <= periodo_hasta)
);

create index if not exists reportes_historial_empresa_fecha
  on reportes_historial (company_id, created_at desc);

-- ─────────────────────────────────────────────────────────────────────
-- 2) CONFIGURACIÓN DEL ENVÍO AUTOMÁTICO (una fila por empresa)
-- ─────────────────────────────────────────────────────────────────────
create table if not exists reportes_envio_config (
  company_id     uuid primary key references companies(id) on delete cascade,
  tipo           text not null default 'resumen_ejecutivo'
                 check (tipo in ('resumen_ejecutivo', 'datos_completos')),
  formato        text not null default 'pdf' check (formato in ('pdf', 'csv')),
  destinatarios  text[] not null default '{}',    -- correos electrónicos
  dia_envio      smallint not null default 1 check (dia_envio between 1 and 28),
  activo         boolean not null default false,
  updated_by     uuid references users(id) on delete set null,
  updated_at     timestamptz not null default now()
);

-- ─────────────────────────────────────────────────────────────────────
-- 3) SEGURIDAD: RLS activado y sin políticas -> solo el backend
-- ─────────────────────────────────────────────────────────────────────
alter table reportes_historial    enable row level security;
alter table reportes_envio_config enable row level security;

revoke all on reportes_historial    from anon, authenticated;
revoke all on reportes_envio_config from anon, authenticated;