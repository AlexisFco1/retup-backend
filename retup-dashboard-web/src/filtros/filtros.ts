// ═══════════════════════════════════════════════════════════════════
// FILTROS GLOBALES (compartidos por todos los gráficos de la pantalla)
// Las fechas se manejan como texto 'YYYY-MM-DD' (hora local del usuario)
// Periodos: Hoy · Semana actual (L-V) · Mes actual · Trimestre actual
// (todos contados hasta hoy).
// "Periodo anterior" compara el MISMO TRAMO del periodo anterior
// (ej. 1–23 oct  vs  1–23 sep).
// La frecuencia se elige dentro de cada gráfico, no en la barra.
// ═══════════════════════════════════════════════════════════════════
import { create } from 'zustand';

export type PeriodoRapido = 'hoy' | 'semana_actual' | 'mes_actual' | 'trimestre_actual';
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

/** Lunes a viernes */
function esLaboral(fecha: Date): boolean {
  const dia = fecha.getDay(); // 0 = domingo, 6 = sábado
  return dia >= 1 && dia <= 5;
}

/** El mismo día N meses antes (si no existe, el último día de ese mes) */
function restarMeses(fecha: Date, meses: number): Date {
  const destino = new Date(fecha.getFullYear(), fecha.getMonth() - meses, 1);
  const ultimoDia = new Date(destino.getFullYear(), destino.getMonth() + 1, 0).getDate();
  destino.setDate(Math.min(fecha.getDate(), ultimoDia));
  return destino;
}

function hoySinHora(): Date {
  const hoy = new Date();
  hoy.setHours(0, 0, 0, 0);
  return hoy;
}

/** Fechas de un periodo, contando hasta hoy */
export function rangoDePeriodo(periodo: PeriodoRapido): RangoFechas {
  const hoy = hoySinHora();

  switch (periodo) {
    case 'hoy':
      return { desde: aISO(hoy), hasta: aISO(hoy) };

    case 'semana_actual': {
      // Lunes de esta semana hasta hoy (en fin de semana, hasta el viernes)
      const lunes = sumarDias(hoy, -((hoy.getDay() + 6) % 7));
      const viernes = sumarDias(lunes, 4);
      return { desde: aISO(lunes), hasta: aISO(hoy < viernes ? hoy : viernes) };
    }

    case 'mes_actual':
      return { desde: aISO(new Date(hoy.getFullYear(), hoy.getMonth(), 1)), hasta: aISO(hoy) };

    case 'trimestre_actual': {
      const primerMes = Math.floor(hoy.getMonth() / 3) * 3; // 0, 3, 6 o 9
      return { desde: aISO(new Date(hoy.getFullYear(), primerMes, 1)), hasta: aISO(hoy) };
    }
  }
}

/**
 * Rango con el que se compara (o null si no hay comparación).
 * "Periodo anterior" = el mismo tramo del periodo anterior:
 *   Hoy       -> el día laboral anterior
 *   Semana    -> los mismos días de la semana pasada
 *   Mes       -> los mismos días del mes pasado
 *   Trimestre -> los mismos días del trimestre pasado
 */
export function rangoComparacion(
  rango: RangoFechas,
  comparacion: Comparacion,
  periodo: PeriodoRapido = useFiltros.getState().periodo,
): RangoFechas | null {
  if (comparacion === 'ninguna') return null;

  const desde = deISO(rango.desde);
  const hasta = deISO(rango.hasta);

  if (comparacion === 'anio_anterior') {
    return { desde: aISO(restarMeses(desde, 12)), hasta: aISO(restarMeses(hasta, 12)) };
  }

  switch (periodo) {
    case 'hoy': {
      let anterior = sumarDias(desde, -1);
      while (!esLaboral(anterior)) anterior = sumarDias(anterior, -1);
      return { desde: aISO(anterior), hasta: aISO(anterior) };
    }
    case 'semana_actual':
      return { desde: aISO(sumarDias(desde, -7)), hasta: aISO(sumarDias(hasta, -7)) };
    case 'mes_actual':
      return { desde: aISO(restarMeses(desde, 1)), hasta: aISO(restarMeses(hasta, 1)) };
    case 'trimestre_actual':
      return { desde: aISO(restarMeses(desde, 3)), hasta: aISO(restarMeses(hasta, 3)) };
  }
}

// ───────────────────────── Almacén de filtros ─────────────────────────

interface EstadoFiltros extends RangoFechas {
  periodo: PeriodoRapido;
  frecuencia: Frecuencia;
  comparacion: Comparacion;
  elegirPeriodo: (periodo: PeriodoRapido) => void;
  elegirFrecuencia: (frecuencia: Frecuencia) => void;
  elegirComparacion: (comparacion: Comparacion) => void;
  restablecer: () => void;
}

function valoresIniciales() {
  return {
    periodo: 'mes_actual' as PeriodoRapido,
    ...rangoDePeriodo('mes_actual'),
    frecuencia: 'semana' as Frecuencia,
    comparacion: 'periodo_anterior' as Comparacion,
  };
}

export const useFiltros = create<EstadoFiltros>()((set) => ({
  ...valoresIniciales(),

  elegirPeriodo: (periodo) => set({ periodo, ...rangoDePeriodo(periodo) }),

  elegirFrecuencia: (frecuencia) => set({ frecuencia }),

  elegirComparacion: (comparacion) => set({ comparacion }),

  restablecer: () => set(valoresIniciales()),
}));