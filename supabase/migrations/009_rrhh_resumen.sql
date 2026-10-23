-- =====================================================================
-- 009 · RRHH·GERENCIA · PANTALLA RESUMEN (indicadores que no usan score)
-- Solo LEEN datos. La empresa la pone el backend desde el perfil.
-- Se puede ejecutar más de una vez (create or replace).
-- =====================================================================

-- 1) Colaboradores "habilitados" de una empresa (los que cuentan en RRHH):
--    rol colaborador, no de baja ni bloqueados (los invitados SÍ cuentan)
create or replace function dash_colaboradores_empresa(p_empresa uuid)
returns uuid[]
language sql
stable
as $$
  select coalesce(array_agg(u.id), '{}')
  from users u
  where u.company_id = p_empresa
    and u.role = 'collaborator'
    and u.is_active is not false
    and coalesce(u.status, 'activo') not in ('baja', 'bloqueado');
$$;

-- 2) Participación de un grupo de personas en un rango de fechas
create or replace function dash_rrhh_kpis(p_usuarios uuid[], p_desde date, p_hasta date)
returns jsonb
language sql
stable
as $$
  with
  -- Retos en los que estaban inscritos en algún mes del rango
  inscripciones as (
    select p.user_id, p.reto_id, p.origen,
           make_date(p.anio, p.mes, 1) as inicio,
           (make_date(p.anio, p.mes, 1) + interval '1 month' - interval '1 day')::date as fin,
           coalesce(nullif(r.total_pills, 0), 20) as total_pildoras
    from planificacion_retos p
    join retos r on r.id = p.reto_id
    where p.user_id = any (p_usuarios)
      and make_date(p.anio, p.mes, 1) <= p_hasta
      and (make_date(p.anio, p.mes, 1) + interval '1 month' - interval '1 day')::date >= p_desde
  ),
  -- Píldoras de su reto completadas (desde el inicio del primer mes inscrito)
  completadas as (
    select c.user_id, c.reto_id, c.fecha
    from dash_completadas_plan(
      p_usuarios,
      coalesce((select min(inicio) from inscripciones), p_desde),
      p_hasta
    ) c
  ),
  -- Cuántas píldoras hizo de cada reto dentro de su mes
  estado_retos as (
    select i.user_id, i.reto_id, i.total_pildoras,
           (select count(*) from completadas c
            where c.user_id = i.user_id and c.reto_id = i.reto_id
              and c.fecha between i.inicio and least(i.fin, p_hasta)) as hechas
    from inscripciones i
  ),
  -- Con actividad = al menos 1 píldora de su reto completada EN el rango
  activos as (
    select count(distinct c.user_id) as total
    from completadas c
    where c.fecha between p_desde and p_hasta
  ),
  totales as (
    select coalesce(array_length(p_usuarios, 1), 0) as habilitados,
           (select count(distinct user_id) from inscripciones) as con_reto,
           (select total from activos) as activos,
           (select count(*) from estado_retos where hechas > 0) as retos_iniciados,
           (select count(*) from estado_retos where hechas >= total_pildoras) as retos_completados
  )
  select jsonb_build_object(
    'habilitados', t.habilitados,
    'con_reto', t.con_reto,
    'activos', t.activos,
    'activos_pct', case when t.habilitados > 0 then round(100.0 * t.activos / t.habilitados, 1) end,
    'retos_iniciados', t.retos_iniciados,
    'retos_completados', t.retos_completados,
    'finalizacion_pct', case when t.retos_iniciados > 0
                             then round(100.0 * t.retos_completados / t.retos_iniciados, 1) end
  )
  from totales t;
$$;

-- 3) PANTALLA RRHH · RESUMEN
create or replace function dash_rrhh_resumen(
  p_empresa uuid,
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
  v_usuarios uuid[] := dash_colaboradores_empresa(p_empresa);
  v_hoy date := (now() at time zone 'Europe/Madrid')::date;
  v_mes_actual date := date_trunc('month', v_hoy)::date;
  v_proximo date := (date_trunc('month', v_hoy) + interval '1 month')::date;
begin
  return jsonb_build_object(
    'periodo', jsonb_build_object('desde', p_desde, 'hasta', p_hasta),
    'actual', dash_rrhh_kpis(v_usuarios, p_desde, p_hasta),
    'comparacion', case when p_comp_desde is not null and p_comp_hasta is not null
                        then dash_rrhh_kpis(v_usuarios, p_comp_desde, p_comp_hasta) end,

    -- Inscritos al mes siguiente (respecto a HOY, no al filtro): voluntarios y total
    'proximo_mes', (
      select jsonb_build_object(
        'anio', extract(year from v_proximo)::int,
        'mes', extract(month from v_proximo)::int,
        'voluntarios', count(distinct p.user_id) filter (where p.origen = 'voluntario'),
        'inscritos', count(distinct p.user_id),
        'habilitados', coalesce(array_length(v_usuarios, 1), 0)
      )
      from planificacion_retos p
      where p.user_id = any (v_usuarios)
        and p.anio = extract(year from v_proximo)
        and p.mes = extract(month from v_proximo)
    ),

    -- Retos más elegidos este mes (respecto a HOY)
    'retos_mes', jsonb_build_object(
      'anio', extract(year from v_mes_actual)::int,
      'mes', extract(month from v_mes_actual)::int,
      'inscritos', (select count(distinct p.user_id) from planificacion_retos p
                    where p.user_id = any (v_usuarios)
                      and p.anio = extract(year from v_mes_actual)
                      and p.mes = extract(month from v_mes_actual)),
      'retos', (
        select coalesce(jsonb_agg(jsonb_build_object(
                 'reto_id', x.reto_id,
                 'titulo', x.titulo,
                 'personas', x.personas,
                 'voluntarios', x.voluntarios,
                 'asignados', x.personas - x.voluntarios
               ) order by x.personas desc, x.titulo), '[]'::jsonb)
        from (
          select r.id as reto_id, r.title as titulo,
                 count(distinct p.user_id) as personas,
                 count(distinct p.user_id) filter (where p.origen = 'voluntario') as voluntarios
          from planificacion_retos p
          join retos r on r.id = p.reto_id
          where p.user_id = any (v_usuarios)
            and p.anio = extract(year from v_mes_actual)
            and p.mes = extract(month from v_mes_actual)
          group by r.id, r.title
        ) x
      )
    ),

    'hoy', v_hoy,
    'calculado_en', now()
  );
end;
$$;

-- 4) SEGURIDAD: solo el backend (clave secreta) puede ejecutarlas
revoke execute on function dash_colaboradores_empresa(uuid) from public, anon, authenticated;
revoke execute on function dash_rrhh_kpis(uuid[], date, date) from public, anon, authenticated;
revoke execute on function dash_rrhh_resumen(uuid, date, date, date, date) from public, anon, authenticated;

grant execute on function dash_colaboradores_empresa(uuid) to service_role;
grant execute on function dash_rrhh_kpis(uuid[], date, date) to service_role;
grant execute on function dash_rrhh_resumen(uuid, date, date, date, date) to service_role;