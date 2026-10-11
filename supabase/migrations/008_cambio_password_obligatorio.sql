-- =====================================================================
-- 008 · CONTRASEÑA TEMPORAL: obligar a cambiarla al entrar
-- debe_cambiar_password = true  ->  la app pide crear una contraseña nueva
-- Se marca al dar de alta (formulario o CSV) y al restablecer la contraseña.
-- Se puede ejecutar más de una vez.
-- =====================================================================

-- 1) Columna nueva (por defecto "no": no afecta a quien ya usa la app)
alter table public.users
  add column if not exists debe_cambiar_password boolean not null default false;

-- 2) Los invitados actuales tienen todavía su contraseña temporal
update public.users
set debe_cambiar_password = true
where status = 'invitado';

-- 3) Directorio de Mantenimiento: igual que en la 007, + debe_cambiar_password
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
      'reset_solicitado', u.password_reset_requested_at,
      'debe_cambiar_password', u.debe_cambiar_password
    ) as fila
    from users u
    left join departments d on d.id = u.department_id
    left join teams t on t.id = u.team_id
    where u.company_id = p_empresa
  ) x;
$$;