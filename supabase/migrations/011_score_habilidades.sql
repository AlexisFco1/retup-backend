-- =====================================================================
-- 011 · SCORE DE HABILIDADES POR PERSONA Y RETO, "A FECHA DE"
-- Replica EXACTAMENTE el cálculo de la app (profile_screen.dart +
-- GET /api/nominations/:userId/feedback-score):
--   Feedback:   votos agrupados por votante; a favor si pos > neg, en contra si
--               neg > pos, empates no cuentan. 100 · a favor / (a favor + en contra)
--   Asistencia: 5 puntos por píldora distinta del reto completada (máx. 100).
--               Las sueltas no cuentan.
--   Práctica:   media de estrellas de los Practícalo ENVIADOS en ese reto
--               (completados, con estrellas, no rechazados) · 20
--   Score:      media simple de las partes que tienen dato
-- Evaluado = tiene al menos una parte con dato.
-- USO INTERNO: devuelve datos por persona; el dashboard SOLO muestra medias.
-- Se puede ejecutar más de una vez.
-- =====================================================================

-- La versión anterior devolvía otras columnas: se elimina antes de crearla
drop function if exists dash_score_personas(uuid, uuid[], date);

create function dash_score_personas(p_empresa uuid, p_usuarios uuid[], p_fecha date)
returns table (
  user_id uuid,
  reto_id uuid,
  score numeric,
  feedback numeric,
  asistencia numeric,
  practica numeric,
  votantes_validos integer,
  pildoras_completadas integer,
  practicas_valoradas integer
)
language sql
stable
as $$
  with
  -- FEEDBACK: votos recibidos, agrupados por cada compañero que votó
  votos_por_votante as (
    select n.nominated_user_id as user_id, n.reto_id, n.respondent_user_id,
           count(*) filter (where n.vote_type = 'positive') as positivos,
           count(*) filter (where n.vote_type = 'negative') as negativos
    from anonymous_nominations n
    where n.nominated_user_id = any (p_usuarios)
      and n.reto_id is not null
      and ((n.created_at at time zone 'UTC') at time zone 'Europe/Madrid')::date <= p_fecha
    group by n.nominated_user_id, n.reto_id, n.respondent_user_id
  ),
  feedback as (
    select v.user_id, v.reto_id,
           count(*) filter (where v.positivos <> v.negativos) as validos,
           count(*) filter (where v.positivos > v.negativos) as a_favor
    from votos_por_votante v
    group by v.user_id, v.reto_id
  ),
  -- ASISTENCIA: píldoras distintas del reto completadas (sin sueltas)
  asistencia as (
    select upp.user_id, pi.reto_id, count(distinct upp.pill_id) as completadas
    from user_pill_progress upp
    join pildoras pi on pi.id = upp.pill_id
    where upp.user_id = any (p_usuarios)
      and upp.is_completed = true
      and (upp.completed_at is null
           or ((upp.completed_at at time zone 'UTC') at time zone 'Europe/Madrid')::date <= p_fecha)
    group by upp.user_id, pi.reto_id
  ),
  -- PRÁCTICA: estrellas de los Practícalo enviados
  practica as (
    select pr.sender_user_id as user_id, pr.reto_id,
           count(*) as valoradas, avg(pr.star_rating) as media
    from practicalo pr
    where pr.sender_user_id = any (p_usuarios)
      and pr.reto_id is not null
      and pr.status = 'completed'
      and pr.star_rating is not null
      and pr.response is distinct from 'no_thanks'
      and (coalesce(pr.confirmed_date, pr.response_date, pr.created_at) at time zone 'Europe/Madrid')::date <= p_fecha
    group by pr.sender_user_id, pr.reto_id
  ),
  -- Persona + reto con al menos una parte con dato
  pares as (
    select f.user_id, f.reto_id from feedback f where f.validos > 0
    union
    select a.user_id, a.reto_id from asistencia a where a.completadas > 0
    union
    select p.user_id, p.reto_id from practica p
  ),
  partes as (
    select pa.user_id, pa.reto_id,
           case when f.validos > 0 then 100.0 * f.a_favor / f.validos end as fb,
           case when a.completadas > 0 then least(100, a.completadas * 5.0) end as asis,
           case when p.valoradas > 0 then p.media * 20 end as prac,
           coalesce(f.validos, 0) as validos,
           coalesce(a.completadas, 0) as completadas,
           coalesce(p.valoradas, 0) as valoradas
    from pares pa
    left join feedback f on f.user_id = pa.user_id and f.reto_id = pa.reto_id
    left join asistencia a on a.user_id = pa.user_id and a.reto_id = pa.reto_id
    left join practica p on p.user_id = pa.user_id and p.reto_id = pa.reto_id
  )
  select x.user_id, x.reto_id,
         -- Media simple de las partes con dato
         round((coalesce(x.fb, 0) + coalesce(x.asis, 0) + coalesce(x.prac, 0))
               / ((x.fb is not null)::int + (x.asis is not null)::int + (x.prac is not null)::int), 1) as score,
         round(x.fb, 1),
         round(x.asis, 1),
         round(x.prac, 1),
         x.validos::int,
         x.completadas::int,
         x.valoradas::int
  from partes x;
$$;

-- SEGURIDAD: datos por persona -> SOLO el backend puede ejecutarla
revoke execute on function dash_score_personas(uuid, uuid[], date) from public, anon, authenticated;
grant execute on function dash_score_personas(uuid, uuid[], date) to service_role;