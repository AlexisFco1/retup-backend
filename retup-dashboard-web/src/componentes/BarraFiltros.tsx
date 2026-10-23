// ═══════════════════════════════════════════════════════════════════
// BARRA DE FILTROS GLOBAL (debajo de la cabecera, en todas las pantallas)
// Periodo + Comparar con. Cambiar un filtro aquí actualiza TODOS los
// gráficos de la pantalla. La frecuencia se elige dentro de cada gráfico.
// ═══════════════════════════════════════════════════════════════════
import { fechaLegible, rangoComparacion, useFiltros } from '../filtros/filtros';
import type { Comparacion, PeriodoRapido } from '../filtros/filtros';
import './BarraFiltros.css';

const OPCIONES_PERIODO: { valor: PeriodoRapido; texto: string }[] = [
  { valor: 'hoy', texto: 'Hoy' },
  { valor: 'semana_actual', texto: 'Semana actual (L-V)' },
  { valor: 'mes_actual', texto: 'Mes actual' },
  { valor: 'trimestre_actual', texto: 'Trimestre actual' },
];

const OPCIONES_COMPARACION: { valor: Comparacion; texto: string }[] = [
  { valor: 'ninguna', texto: 'Sin comparación' },
  { valor: 'periodo_anterior', texto: 'Periodo anterior' },
  { valor: 'anio_anterior', texto: 'Mismo periodo del año anterior' },
];

export default function BarraFiltros() {
  const filtros = useFiltros();
  const comparado = rangoComparacion(filtros, filtros.comparacion, filtros.periodo);

  return (
    <section className="filtros" aria-label="Filtros">
      <div className="filtros__fila">
        {/* ── Periodo ── */}
        <label className="filtros__campo">
          <span>Periodo</span>
          <select
            value={filtros.periodo}
            onChange={(e) => filtros.elegirPeriodo(e.target.value as PeriodoRapido)}
          >
            {OPCIONES_PERIODO.map((opcion) => (
              <option key={opcion.valor} value={opcion.valor}>
                {opcion.texto}
              </option>
            ))}
          </select>
        </label>

        {/* ── Comparar con ── */}
        <label className="filtros__campo">
          <span>Comparar con</span>
          <select
            value={filtros.comparacion}
            onChange={(e) => filtros.elegirComparacion(e.target.value as Comparacion)}
          >
            {OPCIONES_COMPARACION.map((opcion) => (
              <option key={opcion.valor} value={opcion.valor}>
                {opcion.texto}
              </option>
            ))}
          </select>
        </label>

        <div className="filtros__acciones">
          <button
            type="button"
            className="filtros__boton"
            disabled
            title="Departamento, equipo, reto, habilidad… (disponible al conectar los indicadores)"
          >
            + Más filtros
          </button>
          <button type="button" className="filtros__boton" onClick={filtros.restablecer}>
            Restablecer
          </button>
        </div>
      </div>

      {/* ── Resumen en texto claro ── */}
      <p className="filtros__resumen">
        Del <strong>{fechaLegible(filtros.desde)}</strong> al <strong>{fechaLegible(filtros.hasta)}</strong>
        {comparado && (
          <>
            {' '}· comparado con {fechaLegible(comparado.desde)} – {fechaLegible(comparado.hasta)}
          </>
        )}
      </p>
    </section>
  );
}