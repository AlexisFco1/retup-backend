-- =====================================================================
-- 007 · FUNCIONES DE MANTENIMIENTO (directorio, alertas, catálogo)
-- Solo LEEN datos. Siempre filtradas por una empresa (p_empresa), que el
-- backend toma del perfil del usuario conectado, nunca del navegador.
-- Se puede ejecutar más de una vez (create or replace).
-- =====================================================================

-- ─────────────────────────────────────────────────────────────────────
-- 1) DIRECTORIO: todas las personas de la empresa con sus datos
-- ─────────────────────────────────────────────────────────────────────
create or replace function dash_mant_directorio(p_empresa uuid)
returns jsonb
language sql
stable
as $$
  select coalesce(jsonb_agg(fila order by fila->>'nombre'), '[]'::jsonb)
  from (
    select jsonb_build_object(
      'id', u.id,
      'email', u.email,
      'nombre', coalesce(nullif(trim(u.full_name), ''), u.email),
      'first_name', u.first_name,
      'last_name_1', u.last_name_1,
      'last_name_2', u.last_name_2,
      'rol_app', u.role,
      'cargo', u.job_title,
      'departamento_id', u.department_id,
      'departamento', coalesce(d.name, nullif(trim(u.department), '')),
      'equipo_id', u.team_id,
      'equipo', t.name,
      'jefe_de', (select coalesce(jsonb_agg(tl.name order by tl.name), '[]'::jsonb)
                  from teams tl where tl.leader_user_id = u.id and tl.is_active),
      'niveles', (select coalesce(jsonb_agg(a.level order by a.level), '[]'::jsonb)
                  from dashboard_access a where a.user_id = u.id),
      'estado', case when u.is_active = false and u.status = 'activo' then 'baja' else u.status end,
      'fecha_ingreso', u.hire_date,
      'creado', u.created_at,
      'ultimo_acceso', (select max(e.occurred_at) from user_activity_events e
                        where e.user_id = u.id and e.event_type in ('login', 'app_open', 'app_resume')),
      'reset_solicitado', u.password_reset_requested_at
    ) as fila
    from users u
    left join departments d on d.id = u.department_id
    left join teams t on t.id = u.team_id
    where u.company_id = p_empresa
  ) x;
$$;

-- ─────────────────────────────────────────────────────────────────────
-- 2) ALERTAS "REQUIERE ATENCIÓN"
--    Prioridad 1: bloqueados y quienes pidieron restablecer la contraseña
--    Prioridad 2: invitados que todavía no han entrado nunca
-- ─────────────────────────────────────────────────────────────────────
create or replace function dash_mant_alertas(p_empresa uuid)
returns jsonb
language sql
stable
as $$
  with alertas as (
    select 1 as prioridad, 'restablecer'::text as tipo, u.id, u.email, u.full_name, u.job_title,
           u.department_id, u.password_reset_requested_at as desde
    from users u
    where u.company_id = p_empresa and u.password_reset_requested_at is not null
    union all
    select 1, 'bloqueado', u.id, u.email, u.full_name, u.job_title, u.department_id, null::timestamptz
    from users u
    where u.company_id = p_empresa and u.status = 'bloqueado'
    union all
    select 2, 'sin_registrar', u.id, u.email, u.full_name, u.job_title, u.department_id, u.created_at
    from users u
    where u.company_id = p_empresa and u.status = 'invitado'
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'prioridad', a.prioridad,
           'tipo', a.tipo,
           'usuario_id', a.id,
           'email', a.email,
           'nombre', coalesce(nullif(trim(a.full_name), ''), a.email),
           'cargo', a.job_title,
           'departamento', d.name,
           'desde', a.desde,
           'dias', case when a.desde is not null
                        then ((now() at time zone 'Europe/Madrid')::date - (a.desde at time zone 'Europe/Madrid')::date) end
         ) order by a.prioridad, a.desde nulls first, a.email), '[]'::jsonb)
  from alertas a
  left join departments d on d.id = a.department_id;
$$;

-- ─────────────────────────────────────────────────────────────────────
-- 3) CATÁLOGO: departamentos y sus equipos (con jefe e integrantes)
-- ─────────────────────────────────────────────────────────────────────
create or replace function dash_mant_catalogo(p_empresa uuid)
returns jsonb
language sql
stable
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', d.id,
           'nombre', d.name,
           'activo', d.is_active,
           'personas', (select count(*) from users u where u.department_id = d.id),
           'equipos', (
             select coalesce(jsonb_agg(jsonb_build_object(
                      'id', t.id,
                      'nombre', t.name,
                      'activo', t.is_active,
                      'jefe_id', t.leader_user_id,
                      'jefe', coalesce(nullif(trim(j.full_name), ''), j.email),
                      'integrantes', (select count(*) from users u where u.team_id = t.id)
                    ) order by t.name), '[]'::jsonb)
             from teams t
             left join users j on j.id = t.leader_user_id
             where t.department_id = d.id
           )
         ) order by d.name), '[]'::jsonb)
  from departments d
  where d.company_id = p_empresa;
$$;

-- ─────────────────────────────────────────────────────────────────────
-- 4) SEGURIDAD: solo el backend (clave secreta) puede ejecutarlas
-- ─────────────────────────────────────────────────────────────────────
revoke execute on function dash_mant_directorio(uuid) from public, anon, authenticated;
revoke execute on function dash_mant_alertas(uuid) from public, anon, authenticated;
revoke execute on function dash_mant_catalogo(uuid) from public, anon, authenticated;

grant execute on function dash_mant_directorio(uuid) to service_role;
grant execute on function dash_mant_alertas(uuid) to service_role;
grant execute on function dash_mant_catalogo(uuid) to service_role;