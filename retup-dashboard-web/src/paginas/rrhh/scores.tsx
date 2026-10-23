// ═══════════════════════════════════════════════════════════════════
// RRHH · SCORES (compartido por Resumen, Activación, Mapa de calor y Brechas)
// - useScoresRrhh(): pide /dashboard/rrhh/scores con los filtros actuales.
//   Misma "clave" en todas las pantallas -> se pide una vez y se reutiliza.
// - Textos y tarjetas comunes para cuando un score no se puede mostrar.
// ═══════════════════════════════════════════════════════════════════
import { useQuery } from '@tanstack/react-query';
import { apiFetch } from '../../api/cliente';
import { useFiltros } from '../../filtros/filtros';
import type { Frecuencia } from '../../filtros/filtros';

// ───────────── Forma de la respuesta del backend ─────────────
export interface HabilidadScore {
  reto_id: string;
  habilidad: string;
  evaluados: number;
  score: number | null;
  evaluados_inicio: number;
  score_inicio: number | null;
}

export interface TramoScore {
  inicio: string;
  fin: string;
  evaluados: number;
  score: number | null;
}

export interface CeldaScore {
  departamento_id: string | null;
  reto_id: string;
  evaluados: number;
  score: number | null;
}

export interface DatosScores {
  frecuencia: Frecuencia;
  umbral_n: number;
  escala: { bajo: number; alto: number };
  empresa: {
    evaluados: number;
    score: number | null;
    evaluados_inicio: number;
    score_inicio: number | null;
    evolucion_pts: number | null;
  };
  habilidades: HabilidadScore[];
  departamentos: { id: string | null; nombre: string }[];
  celdas: CeldaScore[];
  celdas_sobre_umbral: { total: number; sobre_umbral: number; pct: number | null };
  serie: TramoScore[];
}

interface RespuestaScores {
  success: boolean;
  datos: DatosScores;
}

/** Índigo claro: "valor anterior" en los gráficos (misma familia que el índigo de marca) */
export const INDIGO_CLARO = '#A9A7D3';

/** Scores de RRHH con los filtros actuales (periodo y frecuencia) */
export function useScoresRrhh() {
  const { desde, hasta, frecuencia } = useFiltros();
  return useQuery({
    queryKey: ['rrhh', 'scores', desde, hasta, frecuencia],
    queryFn: () => {
      const parametros = new URLSearchParams({ desde, hasta, frecuencia });
      return apiFetch<RespuestaScores>(`/dashboard/rrhh/scores?${parametros}`);
    },
    placeholderData: (anteriores) => anteriores,
    // El cálculo es pesado: se considera vigente 5 minutos
    staleTime: 5 * 60_000,
  });
}

/** 62.1 -> "62,1" · null -> "—" */
export function textoScore(valor: number | null | undefined): string {
  if (typeof valor !== 'number') return '—';
  return new Intl.NumberFormat('es-ES', { maximumFractionDigits: 1 }).format(valor);
}

/** Por qué no se muestra un score */
export function mensajeSinScore(evaluados: number, umbral: number): string {
  if (evaluados === 0) return 'Todavía no hay colaboradores evaluados.';
  return `Datos insuficientes: ${evaluados} ${evaluados === 1 ? 'evaluado' : 'evaluados'} (mínimo ${umbral}, para proteger la privacidad).`;
}

// ───────────── Textos de los tramos de la serie ─────────────
const MESES = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

/** '2026-09-14' -> '14/09' */
function diaMes(fechaIso: string): string {
  const [, mes, dia] = fechaIso.split('-');
  return `${dia}/${mes}`;
}

/** Etiqueta corta del eje X según la frecuencia */
export function etiquetaTramo(tramo: TramoScore, frecuencia: Frecuencia): string {
  if (frecuencia === 'mes') return MESES[Number(tramo.inicio.split('-')[1]) - 1].slice(0, 3);
  return diaMes(tramo.inicio);
}

/** Texto completo del tramo (tooltip) */
export function textoTramo(tramo: TramoScore, frecuencia: Frecuencia): string {
  if (frecuencia === 'dia') return `Día ${diaMes(tramo.inicio)}`;
  if (frecuencia === 'mes') {
    const mes = MESES[Number(tramo.inicio.split('-')[1]) - 1];
    return `${mes[0].toUpperCase()}${mes.slice(1)} (${diaMes(tramo.inicio)} – ${diaMes(tramo.fin)})`;
  }
  return `Semana del ${diaMes(tramo.inicio)} al ${diaMes(tramo.fin)}`;
}

// ───────────── Tarjeta para un score que no se puede mostrar ─────────────
interface PropsTarjetaPendiente {
  titulo: string;
  mensaje: string;
}

export function TarjetaPendiente({ titulo, mensaje }: PropsTarjetaPendiente) {
  return (
    <article className="rrhh-resumen__reservada">
      <h3>{titulo}</h3>
      <p className="rrhh-resumen__reservada-valor">—</p>
      <p>{mensaje}</p>
    </article>
  );
}