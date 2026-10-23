-- =====================================================================
-- 015 · DÍAS CUMPLIDOS CON DETALLE
-- dash_dias_cumplidos_pct pasa a devolver un objeto:
--   { pct, hechos, posibles, personas }
--   hechos   = días laborales cumplidos (login + píldora), sumando a todos
--   posibles = días laborales posibles, sumando a todos
--   pct      = hechos / posibles (cuadra siempre con el detalle)
-- dash_jefatura_mi_equipo no cambia: la llama por su nombre.
-- Se puede ejecutar más de una vez.
-- =====================================================================

drop function if exists dash_dias_cumplidos_pct(uuid[], date, date);

create function dash_dias_cumplidos_pct(p_usuarios uuid[], p_desde date, p_hasta date)
returns jsonb
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
  select jsonb_build_object(
    'pct', case when sum(posibles) > 0
                then round(100.0 * sum(hechos) / sum(posibles), 1) end,
    'hechos', coalesce(sum(hechos), 0),
    'posibles', coalesce(sum(posibles), 0),
    'personas', count(*) filter (where posibles > 0)
  )
  from por_persona;
$$;

revoke execute on function dash_dias_cumplidos_pct(uuid[], date, date) from public, anon, authenticated;
grant execute on function dash_dias_cumplidos_pct(uuid[], date, date) to service_role;