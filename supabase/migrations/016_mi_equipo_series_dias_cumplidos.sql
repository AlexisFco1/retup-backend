-- =====================================================================
-- 016 · MI EQUIPO: datos de "Días cumplidos" para los gráficos
--   serie_dias              -> días cumplidos por tramo (periodo elegido)
--   serie_dias_comparacion  -> días cumplidos por tramo (comparación)
--   dias_por_persona        -> días cumplidos por integrante
-- Misma forma que los datos de avance:
--   completadas = días cumplidos · esperadas = días posibles · pct
-- Todo lo demás queda igual que en 014.
-- Se puede ejecutar más de una vez.
-- =====================================================================

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

    -- Días cumplidos (tarjeta): { pct, hechos, posibles, personas }
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

    -- ═════════ AVANCE (píldoras) ═════════

    -- Serie del periodo elegido
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

    -- Serie del periodo de comparación
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

    -- ═════════ DÍAS CUMPLIDOS (NUEVO) ═════════
    -- completadas = días cumplidos · esperadas = días posibles

    -- Serie del periodo elegido
    'serie_dias', (
      select coalesce(jsonb_agg(jsonb_build_object(
               'inicio', t.inicio,
               'fin', t.fin,
               'esperadas', (d.dc->>'posibles')::int,
               'completadas', (d.dc->>'hechos')::int,
               'pct', (d.dc->>'pct')::numeric
             ) order by t.inicio), '[]'::jsonb)
      from dash_tramos(p_desde, p_hasta, v_frecuencia) t
      cross join lateral (select dash_dias_cumplidos_pct(v_usuarios, t.inicio, t.fin) as dc) d
    ),

    -- Serie del periodo de comparación
    'serie_dias_comparacion', case when v_hay_comp then (
      select coalesce(jsonb_agg(jsonb_build_object(
               'inicio', t.inicio,
               'fin', t.fin,
               'esperadas', (d.dc->>'posibles')::int,
               'completadas', (d.dc->>'hechos')::int,
               'pct', (d.dc->>'pct')::numeric
             ) order by t.inicio), '[]'::jsonb)
      from dash_tramos(p_comp_desde, p_comp_hasta, v_frecuencia) t
      cross join lateral (select dash_dias_cumplidos_pct(v_usuarios, t.inicio, t.fin) as dc) d
    ) end,

    -- Días cumplidos por persona
    'dias_por_persona', (
      select coalesce(jsonb_agg(jsonb_build_object(
               'user_id', u.id,
               'nombre', coalesce(nullif(trim(u.full_name), ''), u.email),
               'esperadas', (d.dc->>'posibles')::int,
               'completadas', (d.dc->>'hechos')::int,
               'pct', (d.dc->>'pct')::numeric
             ) order by u.full_name), '[]'::jsonb)
      from users u
      cross join lateral (select dash_dias_cumplidos_pct(array[u.id], p_desde, p_hasta) as dc) d
      where u.id = any (v_usuarios)
    ),

    'hoy', v_hoy,
    'calculado_en', now()
  ) into v_resultado;

  return v_resultado;
end;
$$;

revoke execute on function dash_jefatura_mi_equipo(uuid, date, date, date, date, text) from public, anon, authenticated;
grant execute on function dash_jefatura_mi_equipo(uuid, date, date, date, date, text) to service_role;