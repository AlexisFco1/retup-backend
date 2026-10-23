// ═══════════════════════════════════════════════════════════════════
// SELECTOR DE FRECUENCIA (Día / Semana / Mes)
// Va en la esquina superior derecha de los gráficos de evolución.
// Usa la frecuencia del almacén de filtros: al cambiarla se recalcula
// el gráfico.
// ═══════════════════════════════════════════════════════════════════
import { useFiltros } from '../filtros/filtros';
import type { Frecuencia } from '../filtros/filtros';
import './SelectorFrecuencia.css';

const OPCIONES: { valor: Frecuencia; texto: string }[] = [
  { valor: 'dia', texto: 'Día' },
  { valor: 'semana', texto: 'Semana' },
  { valor: 'mes', texto: 'Mes' },
];

export default function SelectorFrecuencia() {
  const frecuencia = useFiltros((estado) => estado.frecuencia);
  const elegirFrecuencia = useFiltros((estado) => estado.elegirFrecuencia);

  return (
    <div className="selector-frecuencia">
      <span className="selector-frecuencia__etiqueta">Frecuencia</span>
      <div className="selector-frecuencia__opciones" role="group" aria-label="Frecuencia del gráfico">
        {OPCIONES.map((opcion) => (
          <button
            key={opcion.valor}
            type="button"
            className={frecuencia === opcion.valor ? 'activo' : ''}
            aria-pressed={frecuencia === opcion.valor}
            onClick={() => elegirFrecuencia(opcion.valor)}
          >
            {opcion.texto}
          </button>
        ))}
      </div>
    </div>
  );
}