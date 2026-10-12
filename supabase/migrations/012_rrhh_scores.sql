-- =====================================================================
-- 012 · RRHH·GERENCIA · INDICADORES DE SCORE (siempre agregados, n >= umbral)
-- Usa dash_score_personas (011). Nunca devuelve scores individuales.
-- Reglas:
--   · Score medio empresa = media de las medias de cada persona.
--   · Inicial = a fecha de p_desde; actual = a fecha de p_hasta.
--   · Todo score con menos de privacy_min_n evaluados se devuelve vacío (null).
-- Se puede ejecutar más de una vez.
-- =====================================================================
create or replace function dash_rrhh_scores(
  p_empresa uuid,
  p_desde date,
  p_hasta date,
  p_frecuencia text default 'semana'
)
returns jsonb
language sql
stable
as $$
  with
  -- Configuración de la empresa (umbral de privacidad y escala del mapa de calor)
  cfg as (
    select dash_colaboradores_empresa(p_empresa) as usuarios,
           coalesce((select s.privacy_min_n from company_settings s where s.company_id = p_empresa), 5) as min_n,
           coalesce((select s.heatmap_low from company_settings s where s.company_id = p_empresa), 40) as bajo,
           coalesce((select s.heatmap_high from company_settings s where s.company_id = p_empresa), 75) as alto,
           case when p_frecuencia in ('dia', 'semana', 'mes') then p_frecuencia else 'semana' end as frecuencia
  ),
  -- Scores por persona y habilidad al final y al inicio del periodo
  actual as (
    select s.user_id, s.reto_id, s.score
    from cfg, dash_score_personas(p_empresa, cfg.usuarios, p_hasta) s
  ),
  inicial as (
    select s.user_id, s.reto_id, s.score
    from cfg, dash_score_personas(p_empresa, cfg.usuarios, p_desde) s
  ),
  personas as (
    select u.id as user_id, u.department_id
    from users u, cfg
    where u.id = any (cfg.usuarios)
  ),
  -- Empresa: media de las medias de cada persona
  empresa_actual as (
    select count(*) as n, avg(x.media) as media
    from (select a.user_id, avg(a.score) as media from actual a group by a.user_id) x
  ),
  empresa_inicial as (
    select count(*) as n, avg(x.media) as media
    from (select i.user_id, avg(i.score) as media from inicial i group by i.user_id) x
  ),
  -- Habilidades (retos) con al menos un evaluado
  habilidades as (select distinct a.reto_id from actual a),
  por_habilidad as (
    select h.reto_id, r.title as titulo,
           (select count(*) from actual a where a.reto_id = h.reto_id) as n_actual,
           (select avg(a.score) from actual a where a.reto_id = h.reto_id) as actual,
           (select count(*) from inicial i where i.reto_id = h.reto_id) as n_inicial,
           (select avg(i.score) from inicial i where i.reto_id = h.reto_id) as inicial
    from habilidades h
    join retos r on r.id = h.reto_id
  ),
  -- Departamentos con colaboradores habilitados (+ "Sin departamento")
  departamentos as (
    select d.id, d.name as nombre, false as sin_departamento
    from departments d
    where d.company_id = p_empresa
      and exists (select 1 from personas p where p.department_id = d.id)
    union all
    select null::uuid, 'Sin departamento', true
    where exists (select 1 from personas p where p.department_id is null)
  ),
  -- Matriz departamento × habilidad
  celdas as (
    select dp.id as departamento_id, h.reto_id,
           count(a.user_id) as n, avg(a.score) as media
    from departamentos dp
    cross join habilidades h
    left join personas p on p.department_id is not distinct from dp.id
    left join actual a on a.user_id = p.user_id and a.reto_id = h.reto_id
    group by dp.id, h.reto_id
  ),
  -- Evolución del score medio de la empresa (un punto por tramo según la frecuencia)
  serie as (
    select t.inicio, t.fin, x.n, x.media
    from cfg,
         dash_tramos(p_desde, p_hasta, cfg.frecuencia) t,
         lateral (
           select count(*) as n, avg(pp.media) as media
           from (select s.user_id, avg(s.score) as media
                 from dash_score_personas(p_empresa, cfg.usuarios, t.fin) s
                 group by s.user_id) pp
         ) x
  )
  select jsonb_build_object(
    'periodo', jsonb_build_object('desde', p_desde, 'hasta', p_hasta),
    'frecuencia', cfg.frecuencia,
    'umbral_n', cfg.min_n,
    'escala', jsonb_build_object('bajo', cfg.bajo, 'alto', cfg.alto),

    'empresa', jsonb_build_object(
      'evaluados', ea.n,
      'score', case when ea.n >= cfg.min_n then round(ea.media, 1) end,
      'evaluados_inicio', ei.n,
      'score_inicio', case when ei.n >= cfg.min_n then round(ei.media, 1) end,
      'evolucion_pts', case when ea.n >= cfg.min_n and ei.n >= cfg.min_n
                            then round(ea.media - ei.media, 1) end
    ),

    'habilidades', (
      select coalesce(jsonb_agg(jsonb_build_object(
               'reto_id', ph.reto_id,
               'habilidad', ph.titulo,
               'evaluados', ph.n_actual,
               'score', case when ph.n_actual >= cfg.min_n then round(ph.actual, 1) end,
               'evaluados_inicio', ph.n_inicial,
               'score_inicio', case when ph.n_inicial >= cfg.min_n then round(ph.inicial, 1) end
             ) order by ph.titulo), '[]'::jsonb)
      from por_habilidad ph
    ),

    'departamentos', (
      select coalesce(jsonb_agg(jsonb_build_object('id', d.id, 'nombre', d.nombre)
                                order by d.sin_departamento, d.nombre), '[]'::jsonb)
      from departamentos d
    ),

    'celdas', (
      select coalesce(jsonb_agg(jsonb_build_object(
               'departamento_id', c.departamento_id,
               'reto_id', c.reto_id,
               'evaluados', c.n,
               'score', case when c.n >= cfg.min_n then round(c.media, 1) end
             )), '[]'::jsonb)
      from celdas c
    ),

    'celdas_sobre_umbral', (
      select jsonb_build_object(
               'total', count(*),
               'sobre_umbral', count(*) filter (where c.n >= cfg.min_n),
               'pct', case when count(*) > 0
                           then round(100.0 * count(*) filter (where c.n >= cfg.min_n) / count(*), 1) end)
      from celdas c
    ),

    'serie', (
      select coalesce(jsonb_agg(jsonb_build_object(
               'inicio', s.inicio,
               'fin', s.fin,
               'evaluados', s.n,
               'score', case when s.n >= cfg.min_n then round(s.media, 1) end
             ) order by s.inicio), '[]'::jsonb)
      from serie s
    ),

    'hoy', (now() at time zone 'Europe/Madrid')::date,
    'calculado_en', now()
  )
  from cfg, empresa_actual ea, empresa_inicial ei;
$$;

-- SEGURIDAD: solo el backend (clave secreta) puede ejecutarla
revoke execute on function dash_rrhh_scores(uuid, date, date, text) from public, anon, authenticated;
grant execute on function dash_rrhh_scores(uuid, date, date, text) to service_role;