-- =====================================================================
-- 004 · ORIGEN DE LA PLANIFICACIÓN DE RETOS
-- Distingue si el reto lo eligió la persona o lo asignó el sistema al azar.
-- Las filas existentes quedan como 'voluntario' (no se puede saber cuáles
-- fueron asignadas). Se puede ejecutar más de una vez sin romper nada.
-- =====================================================================
alter table planificacion_retos
  add column if not exists origen text not null default 'voluntario'
    check (origen in ('voluntario', 'sistema'));

-- Índice para los cálculos del dashboard (planes por mes)
create index if not exists idx_planificacion_anio_mes on planificacion_retos(anio, mes);