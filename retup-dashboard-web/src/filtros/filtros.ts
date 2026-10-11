// ═══════════════════════════════════════════════════════════════════
// FILTROS GLOBALES (compartidos por todos los gráficos de la pantalla)
// Las fechas se manejan como texto 'YYYY-MM-DD' (hora local del usuario)
// ═══════════════════════════════════════════════════════════════════
import { create } from 'zustand';

export type PeriodoRapido = '7d' | '30d' | '90d' | 'mes_actual' | 'mes_anterior' | 'personalizado';
export type Frecuencia = 'dia' | 'semana' | 'mes';
export type Comparacion = 'ninguna' | 'periodo_anterior' | 'anio_anterior';

export interface RangoFechas {
  desde: string; // 'YYYY-MM-DD'
  hasta: string; // 'YYYY-MM-DD'
}

// ───────────────────────── Utilidades de fechas ─────────────────────────

/** Date -> 'YYYY-MM-DD' (en hora local, no UTC) */
export function aISO(fecha: Date): string {
  const anio = fecha.getFullYear();
  const mes = String(fecha.getMonth() + 1).padStart(2, '0');
  const dia = String(fecha.getDate()).padStart(2, '0');
  return `${anio}-${mes}-${dia}`;
}

/** 'YYYY-MM-DD' -> Date (a medianoche local) */
export function deISO(texto: string): Date {
  const [anio, mes, dia] = texto.split('-').map(Number);
  return new Date(anio, mes - 1, dia);
}

/** 'YYYY-MM-DD' -> 'DD/MM/YYYY' (para mostrar) */
export function fechaLegible(texto: string): string {
  const [anio, mes, dia] = texto.split('-');
  return `${dia}/${mes}/${anio}`;
}

function sumarDias(fecha: Date, dias: number): Date {
  const copia = new Date(fecha);
  copia.setDate(copia.getDate() + dias);
  return copia;
}

/** Fechas de un periodo rápido, contando hasta hoy */
export function rangoDePeriodo(periodo: Exclude<PeriodoRapido, 'personalizado'>): RangoFechas {
  const hoy = new Date();
  hoy.setHours(0, 0, 0, 0);

  switch (periodo) {
    case '7d':
      return { desde: aISO(sumarDias(hoy, -6)), hasta: aISO(hoy) };
    case '30d':
      return { desde: aISO(sumarDias(hoy, -29)), hasta: aISO(hoy) };
    case '90d':
      return { desde: aISO(sumarDias(hoy, -89)), hasta: aISO(hoy) };
    case 'mes_actual':
      return { desde: aISO(new Date(hoy.getFullYear(), hoy.getMonth(), 1)), hasta: aISO(hoy) };
    case 'mes_anterior':
      return {
        desde: aISO(new Date(hoy.getFullYear(), hoy.getMonth() - 1, 1)),
        hasta: aISO(new Date(hoy.getFullYear(), hoy.getMonth(), 0)), // día 0 = último del mes anterior
      };
  }
}

/** Rango con el que se compara (o null si no hay comparación) */
export function rangoComparacion(rango: RangoFechas, comparacion: Comparacion): RangoFechas | null {
  if (comparacion === 'ninguna') return null;

  const desde = deISO(rango.desde);
  const hasta = deISO(rango.hasta);

  if (comparacion === 'anio_anterior') {
    desde.setFullYear(desde.getFullYear() - 1);
    hasta.setFullYear(hasta.getFullYear() - 1);
    return { desde: aISO(desde), hasta: aISO(hasta) };
  }

  // Periodo anterior: los mismos días, justo antes
  const dias = Math.round((hasta.getTime() - desde.getTime()) / 86_400_000) + 1;
  return {
    desde: aISO(sumarDias(desde, -dias)),
    hasta: aISO(sumarDias(desde, -1)),
  };
}

// ───────────────────────── Almacén de filtros ─────────────────────────

interface EstadoFiltros extends RangoFechas {
  periodo: PeriodoRapido;
  frecuencia: Frecuencia;
  comparacion: Comparacion;
  elegirPeriodo: (periodo: PeriodoRapido) => void;
  elegirFechas: (desde: string, hasta: string) => void;
  elegirFrecuencia: (frecuencia: Frecuencia) => void;
  elegirComparacion: (comparacion: Comparacion) => void;
  restablecer: () => void;
}

function valoresIniciales() {
  return {
    periodo: '30d' as PeriodoRapido,
    ...rangoDePeriodo('30d'),
    frecuencia: 'semana' as Frecuencia,
    comparacion: 'periodo_anterior' as Comparacion,
  };
}

export const useFiltros = create<EstadoFiltros>()((set) => ({
  ...valoresIniciales(),

  elegirPeriodo: (periodo) =>
    set(periodo === 'personalizado' ? { periodo } : { periodo, ...rangoDePeriodo(periodo) }),

  elegirFechas: (desde, hasta) =>
    // Si las ponen al revés, se ordenan solas
    set(desde <= hasta
      ? { periodo: 'personalizado', desde, hasta }
      : { periodo: 'personalizado', desde: hasta, hasta: desde }),

  elegirFrecuencia: (frecuencia) => set({ frecuencia }),

  elegirComparacion: (comparacion) => set({ comparacion }),

  restablecer: () => set(valoresIniciales()),
}));