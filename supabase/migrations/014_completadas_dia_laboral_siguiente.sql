-- =====================================================================
-- 014 · MI EQUIPO: píldoras hechas en fin de semana o festivo cuentan
--       en el SIGUIENTE día laboral (dentro del mismo mes).
--   - Nueva función dash_completadas_plan_laboral (solo la usa Jefatura)
--   - dash_kpis_grupo: el avance usa la nueva función
--   - dash_jefatura_mi_equipo: serie, serie comparada y por persona
--     usan la nueva función
-- dash_completadas_plan NO cambia (la usa RRHH para "reto completado").
-- Se puede ejecutar más de una vez.
-- =====================================================================

-- ─────────────────────────────────────────────────────────────────────
-- 1) PÍLDORAS DEL RETO con fecha "laboral efectiva"
--    Día laboral -> ese mismo día.
--    Sábado, domingo o festivo -> siguiente día laboral DEL MISMO MES
--    (si no queda ninguno en el mes, el último día laboral anterior).
--    Se miran 14 días antes del rango para recoger, por ejemplo,
--    el fin de semana anterior a un lunes de inicio.
-- ─────────────────────────────────────────────────────────────────────
create or replace function dash_completadas_plan_laboral(p_usuarios uuid[], p_desde date, p_hasta date)
returns table (user_id uuid, reto_id uuid, fecha date)
language sql
stable
as $$
  select c.user_id, c.reto_id, ef.fecha
  from dash_completadas_plan(p_usuarios, p_desde - 14, p_hasta) c
  cross join lateral (
    select coalesce(
      -- siguiente día laboral (o el mismo) hasta fin de mes
      (select min(dl.fecha)
         from dash_dias_laborales(
           c.fecha,
           (date_trunc('month', c.fecha) + interval '1 month' - interval '1 day')::date
         ) dl),
      -- si no hay, el último día laboral anterior del mismo mes
      (select max(dl.fecha)
         from dash_dias_laborales(date_trunc('month', c.fecha)::date, c.fecha) dl)
    ) as fecha
  ) ef
  where ef.fecha between p_desde and p_hasta;
$$;

-- ─────────────────────────────────────────────────────────────────────
-- 2) INDICADORES DE UN GRUPO (igual que en 005, pero el avance usa
--    la fecha laboral efectiva)
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
  -- Completadas que cuentan para el avance (fin de semana / festivo -> siguiente día laboral)
  completadas_plan as (
    select count(*) as total
    from dash_completadas_plan_laboral(p_usuarios, p_desde, p_hasta)
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
-- 3) PANTALLA JEFATURA · MI EQUIPO (igual que en 013, con la nueva función)
-- ─────────────────────────────────────────────────────────────────────
create or replace function dash_jefatura_mi_equipo(
  p_lider uuid,
  p_desde date,
  p_hasta date,
  p_comp_desde date default null,
  p_comp_hasta date default null,
  p_frecuencia text default 'semana'
)
returns jsonb
language plpgsql
stable
as $$
declare
  v_equipos jsonb;
  v_usuarios uuid[];
  v_frecuencia text := case when p_frecuencia in ('dia', 'semana', 'mes') then p_frecuencia else 'semana' end;
  v_hay_comp boolean := p_comp_desde is not null and p_comp_hasta is not null;
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
    'periodo_comparacion', case when v_hay_comp
                                then jsonb_build_object('desde', p_comp_desde, 'hasta', p_comp_hasta) end,
    'frecuencia', v_frecuencia,
    'actual', dash_kpis_grupo(v_usuarios, p_desde, p_hasta),
    'comparacion', case when v_hay_comp
                        then dash_kpis_grupo(v_usuarios, p_comp_desde, p_comp_hasta) end,

    -- % de días cumplidos (actual y comparación)
    'dias_cumplidos', jsonb_build_object(
      'actual', dash_dias_cumplidos_pct(v_usuarios, p_desde, p_hasta),
      'comparacion', case when v_hay_comp
                          then dash_dias_cumplidos_pct(v_usuarios, p_comp_desde, p_comp_hasta) end
    ),

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

    -- Serie del periodo elegido (barras de la derecha)
    'serie', (
      select coalesce(jsonb_agg(jsonb_build_object(
               'inicio', s.inicio,
               'fin', s.fin,
               'esperadas', s.esperadas,
               'completadas', s.completadas,
               'pct', case when s.esperadas > 0
                           then least(100, round(100.0 * s.completadas / s.esperadas, 1)) end
             ) order by s.inicio), '[]'::jsonb)
      from (
        select t.inicio, t.fin,
               (select count(*) from dash_esperadas(v_usuarios, t.inicio, t.fin)) as esperadas,
               (select count(*) from dash_completadas_plan_laboral(v_usuarios, t.inicio, t.fin)) as completadas
        from dash_tramos(p_desde, p_hasta, v_frecuencia) t
      ) s
    ),

    -- Serie del periodo de comparación (barras de la izquierda)
    'serie_comparacion', case when v_hay_comp then (
      select coalesce(jsonb_agg(jsonb_build_object(
               'inicio', s.inicio,
               'fin', s.fin,
               'esperadas', s.esperadas,
               'completadas', s.completadas,
               'pct', case when s.esperadas > 0
                           then least(100, round(100.0 * s.completadas / s.esperadas, 1)) end
             ) order by s.inicio), '[]'::jsonb)
      from (
        select t.inicio, t.fin,
               (select count(*) from dash_esperadas(v_usuarios, t.inicio, t.fin)) as esperadas,
               (select count(*) from dash_completadas_plan_laboral(v_usuarios, t.inicio, t.fin)) as completadas
        from dash_tramos(p_comp_desde, p_comp_hasta, v_frecuencia) t
      ) s
    ) end,

    -- Avance por persona
    'por_persona', (
      select coalesce(jsonb_agg(jsonb_build_object(
               'user_id', x.user_id,
               'nombre', x.nombre,
               'esperadas', x.esperadas,
               'completadas', x.completadas,
               'pct', case when x.esperadas > 0
                           then least(100, round(100.0 * x.completadas / x.esperadas, 1)) end
             ) order by x.nombre), '[]'::jsonb)
      from (
        select u.id as user_id,
               coalesce(nullif(trim(u.full_name), ''), u.email) as nombre,
               (select count(*) from dash_esperadas(array[u.id], p_desde, p_hasta)) as esperadas,
               (select count(*) from dash_completadas_plan_laboral(array[u.id], p_desde, p_hasta)) as completadas
        from users u
        where u.id = any (v_usuarios)
      ) x
    ),

    'hoy', v_hoy,
    'calculado_en', now()
  ) into v_resultado;

  return v_resultado;
end;
$$;

-- ─────────────────────────────────────────────────────────────────────
-- 4) SEGURIDAD: solo el backend (clave secreta) puede ejecutarla
-- ─────────────────────────────────────────────────────────────────────
revoke execute on function dash_completadas_plan_laboral(uuid[], date, date) from public, anon, authenticated;
grant execute on function dash_completadas_plan_laboral(uuid[], date, date) to service_role;