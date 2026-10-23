// ═══════════════════════════════════════════════════════════════════
// DATO DE CABECERA (compartido)
// Dato compacto para la banda de cabecera de una pantalla:
// icono · título (i) · "X de Y" · detalle
// ═══════════════════════════════════════════════════════════════════
import type { ReactNode } from 'react';
import './TarjetaIndicador.css'; // estilos de la (i) y su burbuja
import './DatoCabecera.css';

export type IconoDato = 'reto' | 'calendario' | 'meta';

const ICONOS: Record<IconoDato, ReactNode> = {
  reto: (
    <>
      <circle cx="12" cy="12" r="9" />
      <circle cx="12" cy="12" r="5" />
      <circle cx="12" cy="12" r="1" />
    </>
  ),
  calendario: (
    <>
      <rect x="3" y="5" width="18" height="16" rx="2" />
      <path d="M16 3v4M8 3v4M3 10h18" />
    </>
  ),
  meta: (
    <>
      <circle cx="12" cy="12" r="9" />
      <path d="M8 12.5l2.5 2.5L16 9.5" />
    </>
  ),
};

interface PropsDato {
  icono: IconoDato;
  titulo: string;
  valor: number;
  total: number;
  detalle: string;
  ayuda: string;
}

export default function DatoCabecera({ icono, titulo, valor, total, detalle, ayuda }: PropsDato) {
  return (
    <div className="dato-cabecera">
      <span className="dato-cabecera__icono" aria-hidden="true">
        <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor"
             strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          {ICONOS[icono]}
        </svg>
      </span>
      <div className="dato-cabecera__texto">
        <p className="dato-cabecera__titulo">
          {titulo}
          <span className="tarjeta__ayuda" tabIndex={0} aria-label={`Qué es: ${ayuda}`}>
            i
            <span className="tarjeta__burbuja" role="tooltip">
              {ayuda}
            </span>
          </span>
        </p>
        <p className="dato-cabecera__valor">
          {valor}
          <span> de {total}</span>
        </p>
        <p className="dato-cabecera__detalle">{detalle}</p>
      </div>
    </div>
  );
}