-- =====================================================================
-- SEED 001 · DATOS DE PRUEBA PARA LA EMPRESA "RetUp Test"
-- Solo para desarrollo. Busca a los usuarios por email (sin copiar UUIDs).
-- Requisito: los 4 usuarios @retuptest.com ya creados en Authentication.
-- Se puede ejecutar más de una vez sin duplicar nada.
-- =====================================================================

-- 1) DEPARTAMENTOS (los mismos que ofrece la pantalla de registro de la app)
insert into departments (company_id, name)
select '7a7ec5b3-fe8c-4ef2-975f-340cf4197e73', nombre
from unnest(array['Finanzas', 'Comercial', 'Producción', 'Logística', 'Tecnología']) as nombre
on conflict (company_id, name) do nothing;

-- 2) USUARIOS DE GESTIÓN: se crean en la tabla users a partir de Supabase Auth
--    El admin de RetUp NO pertenece a ninguna empresa cliente (company_id vacío)
insert into users (id, company_id, email, full_name, first_name, last_name_1,
                   role, is_active, job_title, status)
select
  au.id,
  case when v.role = 'super_admin' then null
       else '7a7ec5b3-fe8c-4ef2-975f-340cf4197e73'::uuid end,
  v.email, v.full_name, v.first_name, v.last_name_1,
  v.role, true, v.job_title, 'activo'
from (values
  ('admin@retuptest.com',          'Admin RetUp',     'Admin',   'RetUp',     'super_admin',   'Super Admin RetUp'),
  ('rrhh@retuptest.com',           'Gerente RRHH',    'Gerente', 'RRHH',      'company_admin', 'Gerente de RRHH'),
  ('jefe.comercial@retuptest.com', 'Jefe Comercial',  'Jefe',    'Comercial', 'collaborator',  'Jefe Comercial'),
  ('mantenimiento@retuptest.com',  'Admin Usuarios',  'Admin',   'Usuarios',  'company_admin', 'Administrador de usuarios')
) as v(email, full_name, first_name, last_name_1, role, job_title)
join auth.users au on lower(au.email) = v.email
on conflict (id) do nothing;

-- 3) EQUIPO "Comercial A" dentro de Comercial, con el jefe nuevo
insert into teams (company_id, department_id, name, leader_user_id)
select
  d.company_id,
  d.id,
  'Comercial A',
  (select id from users where email = 'jefe.comercial@retuptest.com')
from departments d
where d.company_id = '7a7ec5b3-fe8c-4ef2-975f-340cf4197e73'
  and d.name = 'Comercial'
on conflict (department_id, name) do nothing;

-- 4) UBICAR PERSONAS EN EL ORGANIGRAMA
--    - El jefe va al departamento Comercial, pero no como integrante de su propio equipo.
--    - Los 4 colaboradores existentes pasan a ser el equipo "Comercial A".
--      Su rol, retos, rachas y votos NO se tocan; solo se completa el cargo si estaba vacío.
update users u
set
  department_id = d.id,
  department    = 'Comercial',   -- mantiene coherente el texto que usa la app
  team_id       = case when u.email = 'jefe.comercial@retuptest.com' then null else t.id end,
  job_title     = coalesce(u.job_title, 'Ejecutivo Comercial')
from departments d
join teams t on t.department_id = d.id and t.name = 'Comercial A'
where d.company_id = '7a7ec5b3-fe8c-4ef2-975f-340cf4197e73'
  and d.name = 'Comercial'
  and u.company_id = d.company_id
  and u.email in (
    'jefe.comercial@retuptest.com',
    'cecilia@gmail.com', 'alexis@gmail.com', 'ejunior@gmail.com', 'cristiano@gmail.com'
  );

-- 5) NIVELES DE ACCESO AL DASHBOARD (solo los usuarios de gestión)
insert into dashboard_access (user_id, company_id, level)
select
  u.id,
  case when a.level = 'retup' then null else u.company_id end,
  a.level
from (values
  ('admin@retuptest.com',          'retup'),
  ('rrhh@retuptest.com',           'rrhh_gerencia'),
  ('rrhh@retuptest.com',           'mantenimiento'),
  ('jefe.comercial@retuptest.com', 'jefatura'),
  ('mantenimiento@retuptest.com',  'mantenimiento')
) as a(email, level)
join users u on u.email = a.email
on conflict (user_id, level) do nothing;