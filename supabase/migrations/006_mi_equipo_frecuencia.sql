-- =====================================================================
-- 006 · "MI EQUIPO" CON FRECUENCIA (día / semana / mes)
-- La serie de finalización ahora sigue al periodo y a la frecuencia
-- elegidos en los filtros (antes: 8 semanas fijas).
-- Se puede ejecutar más de una vez.
-- =====================================================================

-- 1) Ayudante: píldoras DEL RETO completadas, de un reto en el que la persona
--    estaba inscrita ese mes (las sueltas no cuentan para el avance)
create or replace function dash_completadas_plan(p_usuarios uuid[], p_desde date, p_hasta date)
returns table (user_id uuid, reto_id uuid, fecha date)
language sql
stable
as $$
  select c.user_id, c.reto_id, c.fecha
  from dash_completadas(p_usuarios, p_desde, p_hasta) c
  where c.origen = 'reto'
    and exists (
      select 1 from planificacion_retos p
      where p.user_id = c.user_id and p.reto_id = c.reto_id
        and p.anio = extract(year from c.fecha) and p.mes = extract(month from c.fecha)
    );
$$;

-- 2) Ayudante: tramos de tiempo de un periodo según la frecuencia
--    'dia'    -> cada día laboral del periodo
--    'semana' -> semanas de lunes a domingo, recortadas al periodo
--    'mes'    -> meses, recortados al periodo
create or replace function dash_tramos(p_desde date, p_hasta date, p_frecuencia text)
returns table (inicio date, fin date)
language sql
stable
as $$
  select dl.fecha, dl.fecha
  from dash_dias_laborales(p_desde, p_hasta) dl
  where p_frecuencia = 'dia'
  union all
  select greatest(s::date, p_desde), least((s + interval '6 days')::date, p_hasta)
  from generate_series(date_trunc('week', p_desde), p_hasta, interval '1 week') s
  where p_frecuencia = 'semana'
  union all
  select greatest(m::date, p_desde), least((m + interval '1 month' - interval '1 day')::date, p_hasta)
  from generate_series(date_trunc('month', p_desde), p_hasta, interval '1 month') m
  where p_frecuencia = 'mes'
  order by 1;
$$;

-- 3) La función anterior (sin frecuencia) se elimina para evitar ambigüedades
drop function if exists dash_jefatura_mi_equipo(uuid, date, date, date, date);

-- 4) PANTALLA JEFATURA · MI EQUIPO (con frecuencia)
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
    'frecuencia', v_frecuencia,
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

    -- Serie de finalización: un punto por tramo (día laboral / semana / mes)
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
               count(distinct e.user_id) as personas,
               count(*) as esperadas,
               (select count(*) from dash_completadas_plan(v_usuarios, p_desde, p_hasta) c
                where c.reto_id = r.id) as completadas
        from dash_esperadas(v_usuarios, p_desde, p_hasta) e
        join retos r on r.id = e.reto_id
        group by r.id, r.title
      ) x
    ),

    'hoy', v_hoy,
    'calculado_en', now()
  ) into v_resultado;

  return v_resultado;
end;
$$;

-- 5) SEGURIDAD: solo el backend (clave secreta) puede ejecutarlas
revoke execute on function dash_completadas_plan(uuid[], date, date) from public, anon, authenticated;
revoke execute on function dash_tramos(date, date, text) from public, anon, authenticated;
revoke execute on function dash_jefatura_mi_equipo(uuid, date, date, date, date, text) from public, anon, authenticated;

grant execute on function dash_completadas_plan(uuid[], date, date) to service_role;
grant execute on function dash_tramos(date, date, text) to service_role;
grant execute on function dash_jefatura_mi_equipo(uuid, date, date, date, date, text) to service_role;