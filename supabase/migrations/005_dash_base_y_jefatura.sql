-- =====================================================================
-- 005 · FUNCIONES DEL DASHBOARD · BASE + JEFATURA "MI EQUIPO"
-- Todas las funciones empiezan por dash_ y solo LEEN datos.
-- Horas: se calculan en hora de Madrid.
-- Se puede ejecutar más de una vez (create or replace).
-- =====================================================================

-- ─────────────────────────────────────────────────────────────────────
-- 1) DÍAS LABORALES: lunes a viernes, sin festivos (dias_festivos)
-- ─────────────────────────────────────────────────────────────────────
create or replace function dash_dias_laborales(p_desde date, p_hasta date)
returns table (fecha date)
language sql
stable
as $$
  select d::date
  from generate_series(p_desde, p_hasta, interval '1 day') as d
  where extract(isodow from d) between 1 and 5
    and not exists (select 1 from dias_festivos f where f.fecha = d::date);
$$;

-- ─────────────────────────────────────────────────────────────────────
-- 2) PÍLDORAS ESPERADAS (regla única para todo el dashboard)
--    Cada persona inscrita en un reto debe hacer 1 píldora por día laboral
--    del mes, hasta el total de píldoras del reto (total_pills, o 20).
--    Devuelve UNA FILA POR PÍLDORA ESPERADA (persona, reto, día).
--    Si algún día se cambia la regla, se cambia SOLO aquí.
-- ─────────────────────────────────────────────────────────────────────
create or replace function dash_esperadas(p_usuarios uuid[], p_desde date, p_hasta date)
returns table (user_id uuid, reto_id uuid, fecha date)
language sql
stable
as $$
  with planes as (
    select p.user_id, p.reto_id, p.anio, p.mes,
           coalesce(nullif(r.total_pills, 0), 20) as maximo,
           make_date(p.anio, p.mes, 1) as inicio_mes
    from planificacion_retos p
    join retos r on r.id = p.reto_id
    where p.user_id = any (p_usuarios)
      -- solo los meses que tocan el rango
      and make_date(p.anio, p.mes, 1) <= p_hasta
      and (make_date(p.anio, p.mes, 1) + interval '1 month' - interval '1 day')::date >= p_desde
  ),
  dias_del_plan as (
    select pl.user_id, pl.reto_id, dl.fecha,
           row_number() over (partition by pl.user_id, pl.reto_id, pl.anio, pl.mes
                              order by dl.fecha) as numero_dia,
           pl.maximo
    from planes pl
    cross join lateral dash_dias_laborales(
      pl.inicio_mes,
      (pl.inicio_mes + interval '1 month' - interval '1 day')::date
    ) dl
  )
  select d.user_id, d.reto_id, d.fecha
  from dias_del_plan d
  where d.numero_dia <= d.maximo
    and d.fecha between p_desde and p_hasta;
$$;

-- ─────────────────────────────────────────────────────────────────────
-- 3) PÍLDORAS COMPLETADAS (del reto y sueltas), con fecha y hora de Madrid
--    user_pill_progress.completed_at no tiene zona horaria: el backend la
--    guarda en UTC, así que se interpreta como UTC y se pasa a Madrid.
-- ─────────────────────────────────────────────────────────────────────
create or replace function dash_completadas(p_usuarios uuid[], p_desde date, p_hasta date)
returns table (user_id uuid, pill_id uuid, reto_id uuid, fecha date, hora_local timestamp, origen text)
language sql
stable
as $$
  with todas as (
    select upp.user_id, upp.pill_id, pi.reto_id,
           (upp.completed_at at time zone 'UTC') at time zone 'Europe/Madrid' as hora_local,
           'reto'::text as origen
    from user_pill_progress upp
    join pildoras pi on pi.id = upp.pill_id
    where upp.user_id = any (p_usuarios)
      and upp.is_completed = true
      and upp.completed_at is not null
    union all
    select ps.user_id, ps.pill_id, pi.reto_id,
           ps.completed_at at time zone 'Europe/Madrid' as hora_local,
           'suelta'::text as origen
    from pildoras_sueltas ps
    join pildoras pi on pi.id = ps.pill_id
    where ps.user_id = any (p_usuarios)
      and ps.is_completed = true
      and ps.completed_at is not null
  )
  select t.user_id, t.pill_id, t.reto_id, t.hora_local::date as fecha, t.hora_local, t.origen
  from todas t
  where t.hora_local::date between p_desde and p_hasta;
$$;

-- ─────────────────────────────────────────────────────────────────────
-- 4) INDICADORES DE UN GRUPO DE PERSONAS EN UN RANGO
--    (se usa para el periodo actual y para el de comparación)
-- ─────────────────────────────────────────────────────────────────────
create or replace function dash_kpis_grupo(p_usuarios uuid[], p_desde date, p_hasta date)
returns jsonb
language sql
stable
as $$
  with
  integrantes as (
    select coalesce(array_length(p_usuarios, 1), 0) as total
  ),
  esperadas as (
    select count(*) as total from dash_esperadas(p_usuarios, p_desde, p_hasta)
  ),
  -- Completadas que cuentan para el avance: del reto, y de un reto en el que
  -- la persona estaba inscrita ese mes (las sueltas no cuentan para el avance)
  completadas_plan as (
    select count(*) as total
    from dash_completadas(p_usuarios, p_desde, p_hasta) c
    where c.origen = 'reto'
      and exists (
        select 1 from planificacion_retos p
        where p.user_id = c.user_id and p.reto_id = c.reto_id
          and p.anio = extract(year from c.fecha) and p.mes = extract(month from c.fecha)
      )
  ),
  -- Personas con reto en algún mes del rango (voluntario tiene prioridad)
  con_reto as (
    select p.user_id, bool_or(p.origen = 'voluntario') as alguno_voluntario
    from planificacion_retos p
    where p.user_id = any (p_usuarios)
      and make_date(p.anio, p.mes, 1) <= p_hasta
      and (make_date(p.anio, p.mes, 1) + interval '1 month' - interval '1 day')::date >= p_desde
    group by p.user_id
  ),
  -- Días distintos con al menos una píldora completada (incluye sueltas)
  dias_activos as (
    select count(distinct (c.user_id, c.fecha)) as total
    from dash_completadas(p_usuarios, p_desde, p_hasta) c
  )
  select jsonb_build_object(
    'integrantes', i.total,
    'pildoras_esperadas', e.total,
    'pildoras_completadas', cp.total,
    'avance_pct', case when e.total > 0
                       then least(100, round(100.0 * cp.total / e.total, 1)) end,
    'retos_activos', (select count(*) from con_reto),
    'retos_voluntarios', (select count(*) from con_reto where alguno_voluntario),
    'retos_asignados', (select count(*) from con_reto where not alguno_voluntario),
    'dias_activos_total', d.total,
    'dias_activos_promedio', case when i.total > 0 then round(d.total::numeric / i.total, 1) end
  )
  from integrantes i, esperadas e, completadas_plan cp, dias_activos d;
$$;

-- ─────────────────────────────────────────────────────────────────────
-- 5) PANTALLA JEFATURA · MI EQUIPO
--    p_lider: el jefe conectado (lo pone el backend desde el token, nunca
--    el navegador). p_comp_*: rango de comparación (null = sin comparar).
-- ─────────────────────────────────────────────────────────────────────
create or replace function dash_jefatura_mi_equipo(
  p_lider uuid,
  p_desde date,
  p_hasta date,
  p_comp_desde date default null,
  p_comp_hasta date default null
)
returns jsonb
language plpgsql
stable
as $$
declare
  v_equipos jsonb;
  v_usuarios uuid[];
  v_hoy date := (now() at time zone 'Europe/Madrid')::date;
  v_proximo date := (date_trunc('month', (now() at time zone 'Europe/Madrid')) + interval '1 month')::date;
  v_resultado jsonb;
begin
  -- Equipos que dirige
  select coalesce(jsonb_agg(jsonb_build_object('id', t.id, 'nombre', t.name) order by t.name), '[]'::jsonb)
    into v_equipos
  from teams t
  where t.leader_user_id = p_lider and t.is_active;

  -- Integrantes: colaboradores activos de esos equipos (el jefe no se cuenta)
  select coalesce(array_agg(u.id), '{}')
    into v_usuarios
  from users u
  join teams t on t.id = u.team_id
  where t.leader_user_id = p_lider
    and t.is_active
    and u.role = 'collaborator'
    and u.is_active is not false
    and u.status not in ('baja', 'bloqueado')
    and u.id <> p_lider;

  select jsonb_build_object(
    'equipos', v_equipos,
    'periodo', jsonb_build_object('desde', p_desde, 'hasta', p_hasta),
    'actual', dash_kpis_grupo(v_usuarios, p_desde, p_hasta),
    'comparacion', case when p_comp_desde is not null and p_comp_hasta is not null
                        then dash_kpis_grupo(v_usuarios, p_comp_desde, p_comp_hasta) end,

    -- Inscritos al reto del mes siguiente (siempre respecto a HOY, no al filtro)
    'proximo_mes', jsonb_build_object(
      'anio', extract(year from v_proximo)::int,
      'mes', extract(month from v_proximo)::int,
      'inscritos', (select count(distinct p.user_id) from planificacion_retos p
                    where p.user_id = any (v_usuarios)
                      and p.anio = extract(year from v_proximo)
                      and p.mes = extract(month from v_proximo)),
      'integrantes', coalesce(array_length(v_usuarios, 1), 0)
    ),

    -- Finalización semanal: las 8 semanas (lunes a domingo) que terminan en p_hasta
    'semanal', (
      select coalesce(jsonb_agg(jsonb_build_object(
               'semana_inicio', s.inicio,
               'esperadas', s.esperadas,
               'completadas', s.completadas,
               'pct', case when s.esperadas > 0
                           then least(100, round(100.0 * s.completadas / s.esperadas, 1)) end
             ) order by s.inicio), '[]'::jsonb)
      from (
        select sem.inicio,
               (select count(*) from dash_esperadas(v_usuarios, sem.inicio, sem.inicio + 6)) as esperadas,
               (select count(*) from dash_completadas(v_usuarios, sem.inicio, sem.inicio + 6) c
                where c.origen = 'reto'
                  and exists (select 1 from planificacion_retos p
                              where p.user_id = c.user_id and p.reto_id = c.reto_id
                                and p.anio = extract(year from c.fecha)
                                and p.mes = extract(month from c.fecha))) as completadas
        from (
          select (date_trunc('week', p_hasta)::date - 7 * n) as inicio
          from generate_series(0, 7) as n
        ) sem
      ) s
    ),

    -- Finalización por reto (retos con personas inscritas en el rango)
    'por_reto', (
      select coalesce(jsonb_agg(jsonb_build_object(
               'reto_id', x.reto_id,
               'titulo', x.titulo,
               'personas', x.personas,
               'esperadas', x.esperadas,
               'completadas', x.completadas,
               'pct', case when x.esperadas > 0
                           then least(100, round(100.0 * x.completadas / x.esperadas, 1)) end
             ) order by x.titulo), '[]'::jsonb)
      from (
        select r.id as reto_id, r.title as titulo,
               (select count(distinct e.user_id) from dash_esperadas(v_usuarios, p_desde, p_hasta) e
                where e.reto_id = r.id) as personas,
               (select count(*) from dash_esperadas(v_usuarios, p_desde, p_hasta) e
                where e.reto_id = r.id) as esperadas,
               (select count(*) from dash_completadas(v_usuarios, p_desde, p_hasta) c
                where c.origen = 'reto' and c.reto_id = r.id
                  and exists (select 1 from planificacion_retos p
                              where p.user_id = c.user_id and p.reto_id = c.reto_id
                                and p.anio = extract(year from c.fecha)
                                and p.mes = extract(month from c.fecha))) as completadas
        from retos r
        where exists (select 1 from dash_esperadas(v_usuarios, p_desde, p_hasta) e where e.reto_id = r.id)
      ) x
    ),

    'hoy', v_hoy,
    'calculado_en', now()
  ) into v_resultado;

  return v_resultado;
end;
$$;

-- ─────────────────────────────────────────────────────────────────────
-- 6) SEGURIDAD: solo el backend (clave secreta) puede ejecutar estas funciones.
--    La clave pública de la app (anon / authenticated) NO puede llamarlas.
-- ─────────────────────────────────────────────────────────────────────
revoke execute on function dash_dias_laborales(date, date) from public, anon, authenticated;
revoke execute on function dash_esperadas(uuid[], date, date) from public, anon, authenticated;
revoke execute on function dash_completadas(uuid[], date, date) from public, anon, authenticated;
revoke execute on function dash_kpis_grupo(uuid[], date, date) from public, anon, authenticated;
revoke execute on function dash_jefatura_mi_equipo(uuid, date, date, date, date) from public, anon, authenticated;

grant execute on function dash_dias_laborales(date, date) to service_role;
grant execute on function dash_esperadas(uuid[], date, date) to service_role;
grant execute on function dash_completadas(uuid[], date, date) to service_role;
grant execute on function dash_kpis_grupo(uuid[], date, date) to service_role;
grant execute on function dash_jefatura_mi_equipo(uuid, date, date, date, date) to service_role;