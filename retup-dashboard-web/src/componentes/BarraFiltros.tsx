// ═══════════════════════════════════════════════════════════════════
// BARRA DE FILTROS GLOBAL (debajo de la cabecera, en todas las pantallas)
// Cambiar un filtro aquí actualizará TODOS los gráficos de la pantalla.
// ═══════════════════════════════════════════════════════════════════
import { aISO, fechaLegible, rangoComparacion, useFiltros } from '../filtros/filtros';
import type { Comparacion, Frecuencia, PeriodoRapido } from '../filtros/filtros';
import './BarraFiltros.css';

const OPCIONES_PERIODO: { valor: PeriodoRapido; texto: string }[] = [
  { valor: '7d', texto: 'Últimos 7 días' },
  { valor: '30d', texto: 'Últimos 30 días' },
  { valor: '90d', texto: 'Últimos 90 días' },
  { valor: 'mes_actual', texto: 'Mes actual' },
  { valor: 'mes_anterior', texto: 'Mes anterior' },
  { valor: 'personalizado', texto: 'Personalizado…' },
];

const OPCIONES_FRECUENCIA: { valor: Frecuencia; texto: string }[] = [
  { valor: 'dia', texto: 'Día' },
  { valor: 'semana', texto: 'Semana' },
  { valor: 'mes', texto: 'Mes' },
];

const OPCIONES_COMPARACION: { valor: Comparacion; texto: string }[] = [
  { valor: 'ninguna', texto: 'Sin comparación' },
  { valor: 'periodo_anterior', texto: 'Periodo anterior' },
  { valor: 'anio_anterior', texto: 'Mismo periodo del año anterior' },
];

export default function BarraFiltros() {
  const filtros = useFiltros();
  const hoy = aISO(new Date());
  const comparado = rangoComparacion(filtros, filtros.comparacion);

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

        {filtros.periodo === 'personalizado' && (
          <>
            <label className="filtros__campo">
              <span>Desde</span>
              <input
                type="date"
                value={filtros.desde}
                max={hoy}
                onChange={(e) => e.target.value && filtros.elegirFechas(e.target.value, filtros.hasta)}
              />
            </label>
            <label className="filtros__campo">
              <span>Hasta</span>
              <input
                type="date"
                value={filtros.hasta}
                max={hoy}
                onChange={(e) => e.target.value && filtros.elegirFechas(filtros.desde, e.target.value)}
              />
            </label>
          </>
        )}

        {/* ── Frecuencia (botones segmentados) ── */}
        <div className="filtros__campo">
          <span>Frecuencia</span>
          <div className="filtros__segmentado" role="group" aria-label="Frecuencia">
            {OPCIONES_FRECUENCIA.map((opcion) => (
              <button
                key={opcion.valor}
                type="button"
                className={filtros.frecuencia === opcion.valor ? 'activo' : ''}
                aria-pressed={filtros.frecuencia === opcion.valor}
                onClick={() => filtros.elegirFrecuencia(opcion.valor)}
              >
                {opcion.texto}
              </button>
            ))}
          </div>
        </div>

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