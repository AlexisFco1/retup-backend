-- =====================================================================
-- 010 · RRHH·GERENCIA · ACTIVACIÓN POR ÁREA (sin score)
-- Activación = completó al menos UNA píldora (de reto o suelta) en el rango.
-- Se puede ejecutar más de una vez (create or replace).
-- =====================================================================

-- 1) Activación de un grupo de personas en un rango
create or replace function dash_activacion_grupo(p_usuarios uuid[], p_desde date, p_hasta date)
returns jsonb
language sql
stable
as $$
  select jsonb_build_object(
    'habilitados', coalesce(array_length(p_usuarios, 1), 0),
    'activados', count(distinct c.user_id),
    'pct', case when coalesce(array_length(p_usuarios, 1), 0) > 0
                then round(100.0 * count(distinct c.user_id) / array_length(p_usuarios, 1), 1) end
  )
  from dash_completadas(p_usuarios, p_desde, p_hasta) c;
$$;

-- 2) PANTALLA RRHH · ACTIVACIÓN POR ÁREA
create or replace function dash_rrhh_activacion(
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
  v_comparar boolean := p_comp_desde is not null and p_comp_hasta is not null;
begin
  return jsonb_build_object(
    'periodo', jsonb_build_object('desde', p_desde, 'hasta', p_hasta),

    -- Objetivo de activación de la empresa (85 % si no está configurado)
    'objetivo_pct', coalesce(
      (select s.activation_target_pct from company_settings s where s.company_id = p_empresa), 85),

    'actual', dash_activacion_grupo(v_usuarios, p_desde, p_hasta)
              || jsonb_build_object('finalizacion', dash_rrhh_kpis(v_usuarios, p_desde, p_hasta)),

    'comparacion', case when v_comparar then
                     dash_activacion_grupo(v_usuarios, p_comp_desde, p_comp_hasta)
                     || jsonb_build_object('finalizacion', dash_rrhh_kpis(v_usuarios, p_comp_desde, p_comp_hasta))
                   end,

    -- Por departamento (solo los que tienen colaboradores habilitados) + "Sin departamento"
    'por_area', (
      select coalesce(jsonb_agg(jsonb_build_object(
               'departamento_id', a.id,
               'departamento', a.nombre,
               'actual', dash_activacion_grupo(a.usuarios, p_desde, p_hasta),
               'comparacion', case when v_comparar
                                   then dash_activacion_grupo(a.usuarios, p_comp_desde, p_comp_hasta) end
             ) order by a.sin_departamento, a.nombre), '[]'::jsonb)
      from (
        select d.id, d.name as nombre, false as sin_departamento, array_agg(u.id) as usuarios
        from departments d
        join users u on u.department_id = d.id and u.id = any (v_usuarios)
        where d.company_id = p_empresa
        group by d.id, d.name
        union all
        select null, 'Sin departamento', true, array_agg(u.id)
        from users u
        where u.id = any (v_usuarios) and u.department_id is null
        having count(*) > 0
      ) a
    ),

    'hoy', (now() at time zone 'Europe/Madrid')::date,
    'calculado_en', now()
  );
end;
$$;

-- 3) SEGURIDAD: solo el backend (clave secreta) puede ejecutarlas
revoke execute on function dash_activacion_grupo(uuid[], date, date) from public, anon, authenticated;
revoke execute on function dash_rrhh_activacion(uuid, date, date, date, date) from public, anon, authenticated;

grant execute on function dash_activacion_grupo(uuid[], date, date) to service_role;
grant execute on function dash_rrhh_activacion(uuid, date, date, date, date) to service_role;