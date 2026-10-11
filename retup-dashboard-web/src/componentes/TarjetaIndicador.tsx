// ═══════════════════════════════════════════════════════════════════
// TARJETA DE INDICADOR (KPI)
// Título + (i) de ayuda · valor grande · detalle · comparación ▲▼
// Si no hay datos en el periodo, muestra "—" (no es lo mismo que 0).
// ═══════════════════════════════════════════════════════════════════
import './TarjetaIndicador.css';

export type FormatoIndicador = 'porcentaje' | 'numero' | 'decimal';

interface PropsTarjeta {
  titulo: string;
  /** Explicación breve que aparece al pasar el cursor por la (i) */
  ayuda: string;
  valor: number | null | undefined;
  formato: FormatoIndicador;
  /** Texto pequeño bajo el valor, ej. "57 de 102 píldoras" */
  detalle?: string;
  /** Valor del periodo de comparación (null/undefined = no se compara) */
  valorAnterior?: number | null;
  /** true si subir es bueno (por defecto). Define el color de ▲▼ */
  mejorSiSube?: boolean;
  /** Muestra una barra de progreso (solo para porcentajes) */
  conBarra?: boolean;
}

function formatear(valor: number, formato: FormatoIndicador): string {
  const opciones: Intl.NumberFormatOptions =
    formato === 'numero' ? { maximumFractionDigits: 0 } : { maximumFractionDigits: 1 };
  const texto = new Intl.NumberFormat('es-ES', opciones).format(valor);
  return formato === 'porcentaje' ? `${texto} %` : texto;
}

export default function TarjetaIndicador({
  titulo,
  ayuda,
  valor,
  formato,
  detalle,
  valorAnterior,
  mejorSiSube = true,
  conBarra = false,
}: PropsTarjeta) {
  const hayValor = typeof valor === 'number';
  const hayComparacion = hayValor && typeof valorAnterior === 'number';

  // Diferencia con el periodo de comparación
  let comparacion: { texto: string; clase: string; lectura: string } | null = null;
  if (hayComparacion) {
    const diferencia = Math.round(((valor as number) - (valorAnterior as number)) * 10) / 10;
    const unidad = formato === 'porcentaje' ? ' pts' : '';
    if (diferencia === 0) {
      comparacion = { texto: '= sin cambios', clase: 'igual', lectura: 'Sin cambios' };
    } else {
      const sube = diferencia > 0;
      const esBueno = sube === mejorSiSube;
      comparacion = {
        texto: `${sube ? '▲ +' : '▼ '}${formatear(diferencia, formato === 'porcentaje' ? 'decimal' : formato)}${unidad}`,
        clase: esBueno ? 'bueno' : 'malo',
        lectura: `${sube ? 'Sube' : 'Baja'} respecto al periodo de comparación`,
      };
    }
  }

  return (
    <article className="tarjeta">
      <header className="tarjeta__cabecera">
        <h3 className="tarjeta__titulo">{titulo}</h3>
        <span className="tarjeta__ayuda" tabIndex={0} aria-label={`Qué es: ${ayuda}`}>
          i
          <span className="tarjeta__burbuja" role="tooltip">
            {ayuda}
          </span>
        </span>
      </header>

      <p className="tarjeta__valor">{hayValor ? formatear(valor as number, formato) : '—'}</p>

      {conBarra && hayValor && (
        <div className="tarjeta__barra" aria-hidden="true">
          <div style={{ width: `${Math.max(0, Math.min(100, valor as number))}%` }} />
        </div>
      )}

      <p className="tarjeta__detalle">{hayValor ? detalle : 'Sin datos en el periodo'}</p>

      {comparacion && (
        <p
          className={`tarjeta__comparacion tarjeta__comparacion--${comparacion.clase}`}
          title={comparacion.lectura}
        >
          {comparacion.texto} <span>vs. periodo de comparación</span>
        </p>
      )}
    </article>
  );
}