-- =====================================================================
-- 013 · JEFATURA · MI EQUIPO
--   1) % de días cumplidos del equipo (login + píldora en día laboral)
--   2) Serie del periodo de comparación (barras del lado izquierdo)
--   3) Avance por persona (sustituye a "Finalización por reto")
-- Se puede ejecutar más de una vez.
-- =====================================================================

-- ─────────────────────────────────────────────────────────────────────
-- 1) DÍAS CUMPLIDOS (%)
--    Por persona: días laborales cumplidos / días laborales del rango.
--    Día cumplido = login + al menos una píldora de su reto ese día
--    (misma fuente que las rachas: racha_daily_progress).
--    Hoy solo cuenta si ya lo cumplió (todavía está a tiempo).
--    Resultado: promedio de los porcentajes de todas las personas.
-- ─────────────────────────────────────────────────────────────────────
create or replace function dash_dias_cumplidos_pct(p_usuarios uuid[], p_desde date, p_hasta date)
returns numeric
language sql
stable
as $$
  with
  ref as (
    select (now() at time zone 'Europe/Madrid')::date as hoy
  ),
  -- Días laborales del rango que ya empezaron (los futuros no cuentan)
  dias as (
    select dl.fecha
    from ref, dash_dias_laborales(p_desde, least(p_hasta, ref.hoy)) dl
  ),
  -- Días laborales en que cada persona hizo login + píldora
  cumplidos as (
    select distinct rdp.user_id, rdp.fecha::date as fecha
    from racha_daily_progress rdp
    join dias on dias.fecha = rdp.fecha::date
    where rdp.user_id = any (p_usuarios)
      and rdp.login_hecho = true
      and rdp.pildora_completada = true
  ),
  por_persona as (
    select u.user_id,
           (select count(*) from cumplidos c where c.user_id = u.user_id) as hechos,
           -- Días posibles: los ya pasados + hoy solo si ya lo cumplió
           (select count(*) from dias, ref
             where dias.fecha < ref.hoy
                or exists (select 1 from cumplidos c
                           where c.user_id = u.user_id and c.fecha = dias.fecha)) as posibles
    from unnest(p_usuarios) as u(user_id)
  )
  select round(avg(100.0 * hechos / posibles), 1)
  from por_persona
  where posibles > 0;
$$;

-- ─────────────────────────────────────────────────────────────────────
-- 2) PANTALLA JEFATURA · MI EQUIPO (misma firma que en 006)
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

    -- NUEVO: % de días cumplidos (actual y comparación)
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
               (select count(*) from dash_completadas_plan(v_usuarios, t.inicio, t.fin)) as completadas
        from dash_tramos(p_desde, p_hasta, v_frecuencia) t
      ) s
    ),

    -- NUEVO: serie del periodo de comparación (barras de la izquierda)
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
               (select count(*) from dash_completadas_plan(v_usuarios, t.inicio, t.fin)) as completadas
        from dash_tramos(p_comp_desde, p_comp_hasta, v_frecuencia) t
      ) s
    ) end,

    -- NUEVO: avance por persona (sustituye a "Finalización por reto")
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
               (select count(*) from dash_completadas_plan(array[u.id], p_desde, p_hasta)) as completadas
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
-- 3) SEGURIDAD: solo el backend (clave secreta) puede ejecutarlas
-- ─────────────────────────────────────────────────────────────────────
revoke execute on function dash_dias_cumplidos_pct(uuid[], date, date) from public, anon, authenticated;
grant execute on function dash_dias_cumplidos_pct(uuid[], date, date) to service_role;

revoke execute on function dash_jefatura_mi_equipo(uuid, date, date, date, date, text) from public, anon, authenticated;
grant execute on function dash_jefatura_mi_equipo(uuid, date, date, date, date, text) to service_role;