// ═══════════════════════════════════════════════════════════════════
// RRHH · GERENCIA · EXPORTAR DATOS
// - Resumen ejecutivo en PDF (se genera en el navegador con jsPDF)
// - Datos completos en CSV (lo genera el backend, solo agregados)
// - Configuración del envío automático mensual
// - Historial de reportes
// El periodo es un mes o trimestre CERRADO (no usa la barra de filtros).
// ═══════════════════════════════════════════════════════════════════
import { useMemo, useState } from 'react';
import type { FormEvent } from 'react';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { jsPDF } from 'jspdf';
import * as moduloAutoTable from 'jspdf-autotable';
import { apiFetch } from '../../api/cliente';
import { useSesion } from '../../auth/sesion';
import { aISO, fechaLegible } from '../../filtros/filtros';
import type { DatosScores } from './scores';
import './Resumen.css';
import './Exportar.css';

// ───────────── Librería de tablas del PDF ─────────────
// Según cómo la empaquete Vite, la función llega como "autoTable",
// "default" o "default.default": se busca en todos esos sitios.
type FuncionAutoTable = (doc: jsPDF, opciones: Record<string, unknown>) => void;

function obtenerAutoTable(): FuncionAutoTable {
  const modulo = moduloAutoTable as unknown as Record<string, unknown>;
  const porDefecto = modulo.default as Record<string, unknown> | ((...args: unknown[]) => unknown) | undefined;
  const candidatos: unknown[] = [
    modulo.autoTable,
    porDefecto,
    typeof porDefecto === 'object' && porDefecto ? porDefecto.default : undefined,
    typeof porDefecto === 'object' && porDefecto ? porDefecto.autoTable : undefined,
  ];
  const funcion = candidatos.find((c) => typeof c === 'function');
  if (!funcion) {
    throw new Error('No se pudo cargar la librería de tablas del PDF (jspdf-autotable)');
  }
  return funcion as FuncionAutoTable;
}

// ───────────── Tipos ─────────────
interface PeriodoReporte {
  clave: string;
  tipo: 'mes' | 'trimestre';
  etiqueta: string; // 'Septiembre 2026' / 'T3 2026'
  corta: string; // 'Sep_2026' / 'T3_2026' (para el nombre del archivo)
  desde: string;
  hasta: string;
}

type EstadoReporte = 'generando' | 'descargado' | 'enviado' | 'error';

interface FilaHistorial {
  id: string;
  tipo: 'resumen_ejecutivo' | 'datos_completos';
  formato: 'pdf' | 'csv';
  periodo_etiqueta: string;
  nombre_archivo: string;
  estado: EstadoReporte;
  origen: 'manual' | 'automatico';
  generado_por_nombre: string;
  detalle_error: string | null;
  created_at: string;
}

interface ConfigEnvio {
  tipo: string;
  formato: string;
  destinatarios: string[];
  dia_envio: number;
  activo: boolean;
  updated_at: string | null;
}

interface KpisResumen {
  habilitados: number;
  activos: number;
  activos_pct: number | null;
  retos_iniciados: number;
  retos_completados: number;
  finalizacion_pct: number | null;
}

interface ActivacionArea {
  departamento: string;
  actual: { habilitados: number; activados: number; pct: number | null };
}

interface DatosActivacionPdf {
  objetivo_pct: number;
  actual: { habilitados: number; activados: number; pct: number | null };
  por_area: ActivacionArea[];
}

interface Mensaje {
  tipo: 'ok' | 'error';
  texto: string;
}

// ───────────── Ayudantes ─────────────
const MESES = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

const capitalizar = (t: string) => t.charAt(0).toUpperCase() + t.slice(1);

/** 12.5 -> '12,5' · null -> '-' */
function num(valor: number | null | undefined): string {
  if (typeof valor !== 'number') return '-';
  return new Intl.NumberFormat('es-ES', { maximumFractionDigits: 1 }).format(valor);
}

const pct = (valor: number | null | undefined) => (typeof valor === 'number' ? `${num(valor)} %` : '-');

/** Asegura la extensión del archivo */
function conExtension(nombre: string, extension: string): string {
  const limpio = nombre.trim() || `RetUp_reporte.${extension}`;
  return limpio.toLowerCase().endsWith(`.${extension}`) ? limpio : `${limpio}.${extension}`;
}

/** Últimos 12 meses cerrados y últimos 4 trimestres cerrados */
function periodosCerrados(): PeriodoReporte[] {
  const hoy = new Date();
  const lista: PeriodoReporte[] = [];

  for (let i = 1; i <= 12; i++) {
    const inicio = new Date(hoy.getFullYear(), hoy.getMonth() - i, 1);
    const fin = new Date(inicio.getFullYear(), inicio.getMonth() + 1, 0);
    const mes = MESES[inicio.getMonth()];
    lista.push({
      clave: `m-${aISO(inicio)}`,
      tipo: 'mes',
      etiqueta: `${capitalizar(mes)} ${inicio.getFullYear()}`,
      corta: `${capitalizar(mes.slice(0, 3))}_${inicio.getFullYear()}`,
      desde: aISO(inicio),
      hasta: aISO(fin),
    });
  }

  const trimestreActual = Math.floor(hoy.getMonth() / 3);
  for (let i = 1; i <= 4; i++) {
    const indice = trimestreActual - i;
    const anio = hoy.getFullYear() + Math.floor(indice / 4);
    const t = ((indice % 4) + 4) % 4; // 0..3
    const inicio = new Date(anio, t * 3, 1);
    const fin = new Date(anio, t * 3 + 3, 0);
    lista.push({
      clave: `t-${aISO(inicio)}`,
      tipo: 'trimestre',
      etiqueta: `T${t + 1} ${anio}`,
      corta: `T${t + 1}_${anio}`,
      desde: aISO(inicio),
      hasta: aISO(fin),
    });
  }
  return lista;
}

/** Fecha del historial: 'Hoy, 09:30' o '1 sept 2026' */
function textoFecha(iso: string): string {
  const fecha = new Date(iso);
  const hora = fecha.toLocaleTimeString('es-ES', { hour: '2-digit', minute: '2-digit' });
  if (fecha.toDateString() === new Date().toDateString()) return `Hoy, ${hora}`;
  return fecha.toLocaleDateString('es-ES', { day: 'numeric', month: 'short', year: 'numeric' });
}

const TEXTO_ESTADO: Record<EstadoReporte, string> = {
  generando: '⟳ Generando',
  descargado: '✓ Descargado',
  enviado: '✉ Enviado',
  error: '⚠ Error',
};

// ───────────── Generación del PDF ─────────────
function generarPdf({
  empresa,
  periodo,
  nombre,
  resumen,
  activacion,
  scores,
}: {
  empresa: string;
  periodo: PeriodoReporte;
  nombre: string;
  resumen: KpisResumen;
  activacion: DatosActivacionPdf;
  scores: DatosScores;
}) {
    const autoTable = obtenerAutoTable();
  const doc = new jsPDF({ unit: 'mm', format: 'a4' });
  const ancho = doc.internal.pageSize.getWidth();
  const alto = doc.internal.pageSize.getHeight();
  const INDIGO: [number, number, number] = [46, 42, 114];
  const umbral = scores.umbral_n;

  // Banda superior
  doc.setFillColor(...INDIGO);
  doc.rect(0, 0, ancho, 26, 'F');
  doc.setTextColor(255, 255, 255);
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(18);
  doc.text('RetUp', 14, 16);
  doc.setFont('helvetica', 'normal');
  doc.setFontSize(10);
  doc.text('Informe para RRHH - Gerencia', ancho - 14, 16, { align: 'right' });

  // Título y subtítulo
  doc.setTextColor(14, 15, 23);
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(20);
  doc.text(periodo.tipo === 'mes' ? 'Resumen ejecutivo mensual' : 'Resumen ejecutivo trimestral', 14, 42);
  doc.setFont('helvetica', 'normal');
  doc.setFontSize(11);
  doc.setTextColor(91, 95, 115);
  doc.text(
    `${empresa} - ${periodo.etiqueta} (${fechaLegible(periodo.desde)} al ${fechaLegible(periodo.hasta)}) - Generado el ${fechaLegible(aISO(new Date()))}`,
    14,
    50,
    { maxWidth: ancho - 28 },
  );

  let y = 62;
  const estilo = {
    theme: 'grid' as const,
    headStyles: { fillColor: INDIGO, textColor: 255 },
    styles: { fontSize: 10, cellPadding: 2.5 },
    margin: { left: 14, right: 14, bottom: 18 },
  };
  const seccion = (titulo: string) => {
    if (y > alto - 50) {
      doc.addPage();
      y = 20;
    }
    doc.setFont('helvetica', 'bold');
    doc.setFontSize(13);
    doc.setTextColor(...INDIGO);
    doc.text(titulo, 14, y);
    y += 4;
  };
  const despuesDeTabla = () => {
    y = (doc as unknown as { lastAutoTable: { finalY: number } }).lastAutoTable.finalY + 12;
  };

  // 1) Indicadores principales
  const e = scores.empresa;
  seccion('Indicadores principales');
  autoTable(doc, {
    ...estilo,
    startY: y,
    head: [['Indicador', 'Valor', 'Detalle']],
    body: [
      ['Colaboradores activos', pct(resumen.activos_pct), `${resumen.activos} de ${resumen.habilitados} colaboradores habilitados`],
      [`Activación (objetivo ${pct(activacion.objetivo_pct)})`, pct(activacion.actual.pct), `${activacion.actual.activados} de ${activacion.actual.habilitados} con al menos una píldora`],
      ['Retos finalizados', pct(resumen.finalizacion_pct), `${resumen.retos_completados} de ${resumen.retos_iniciados} retos iniciados`],
      ['Score medio de la empresa', num(e.score), e.score === null ? `Menos de ${umbral} evaluados` : `${e.evaluados} colaboradores evaluados (escala 0-100)`],
      ['Evolución del score', e.evolucion_pts === null ? '-' : `${e.evolucion_pts > 0 ? '+' : ''}${num(e.evolucion_pts)} pts`, `De ${num(e.score_inicio)} a ${num(e.score)} en el periodo`],
    ],
  });
  despuesDeTabla();

  // 2) Avance por habilidad
  seccion('Avance por habilidad');
  autoTable(doc, {
    ...estilo,
    startY: y,
    head: [['Habilidad', 'Score inicio', 'Score final', 'Avance', 'Evaluados']],
    body: scores.habilidades.map((h) => [
      h.habilidad,
      h.score_inicio === null ? '-' : num(h.score_inicio),
      h.score === null ? `n<${umbral}` : num(h.score),
      h.score !== null && h.score_inicio !== null
        ? `${h.score - h.score_inicio > 0 ? '+' : ''}${num(Math.round((h.score - h.score_inicio) * 10) / 10)} pts`
        : '-',
      String(h.evaluados),
    ]),
  });
  despuesDeTabla();

  // 3) Activación por área (áreas pequeñas: sin activos ni %)
  seccion('Activación por área');
  autoTable(doc, {
    ...estilo,
    startY: y,
    head: [['Departamento', 'Habilitados', 'Activos', 'Activación']],
    body: activacion.por_area.map((a) => {
      const pequena = a.actual.habilitados < umbral;
      return [
        a.departamento,
        String(a.actual.habilitados),
        pequena ? '-' : String(a.actual.activados),
        pequena ? `n<${umbral}` : pct(a.actual.pct),
      ];
    }),
  });
  despuesDeTabla();

  // 4) Puntos destacados del mapa de calor
  const nombreDep = new Map(scores.departamentos.map((d) => [d.id ?? 'sin', d.nombre]));
  const nombreHab = new Map(scores.habilidades.map((h) => [h.reto_id, h.habilidad]));
  const visibles = scores.celdas
    .filter((c) => c.score !== null)
    .map((c) => ({
      texto: `${nombreDep.get(c.departamento_id ?? 'sin') ?? 'Sin departamento'} - ${nombreHab.get(c.reto_id) ?? ''}`,
      score: c.score as number,
    }));
  const alta = visibles.length ? visibles.reduce((a, b) => (b.score > a.score ? b : a)) : null;
  const baja = visibles.length ? visibles.reduce((a, b) => (b.score < a.score ? b : a)) : null;
  const sobre = scores.celdas_sobre_umbral;

  seccion('Puntos destacados');
  autoTable(doc, {
    ...estilo,
    startY: y,
    head: [['', 'Área y habilidad', 'Score']],
    body: [
      ['Punto más alto', alta ? alta.texto : 'Sin datos suficientes', alta ? num(alta.score) : '-'],
      ['Punto más bajo', baja ? baja.texto : 'Sin datos suficientes', baja ? num(baja.score) : '-'],
      ['Celdas con datos', `${sobre.sobre_umbral} de ${sobre.total} combinaciones área-habilidad`, pct(sobre.pct)],
    ],
  });

  // Pie de página
  const paginas = doc.getNumberOfPages();
  for (let i = 1; i <= paginas; i++) {
    doc.setPage(i);
    doc.setFont('helvetica', 'normal');
    doc.setFontSize(8);
    doc.setTextColor(150, 150, 160);
    doc.text(`Datos agregados y anónimos. Se omiten los grupos con menos de ${umbral} personas.`, 14, alto - 8);
    doc.text(`Página ${i} de ${paginas}`, ancho - 14, alto - 8, { align: 'right' });
  }

  doc.save(nombre);
}

// ───────────── Formulario del envío automático ─────────────
function FormEnvio({ inicial, onGuardado }: { inicial: ConfigEnvio; onGuardado: () => void }) {
  const [destinatarios, setDestinatarios] = useState(inicial.destinatarios.join(', '));
  const [dia, setDia] = useState(inicial.dia_envio);
  const [activo, setActivo] = useState(inicial.activo);
  const [guardando, setGuardando] = useState(false);
  const [mensaje, setMensaje] = useState<Mensaje | null>(null);

  async function guardar(evento: FormEvent) {
    evento.preventDefault();
    setGuardando(true);
    setMensaje(null);
    try {
      await apiFetch('/dashboard/rrhh/envio-config', {
        metodo: 'PUT',
        cuerpo: { destinatarios, dia_envio: dia, activo, tipo: 'resumen_ejecutivo', formato: 'pdf' },
      });
      setMensaje({ tipo: 'ok', texto: '✅ Configuración guardada' });
      onGuardado();
    } catch (err) {
      setMensaje({ tipo: 'error', texto: `❌ ${err instanceof Error ? err.message : 'No se pudo guardar'}` });
    } finally {
      setGuardando(false);
    }
  }

  return (
    <form className="exportar__form" onSubmit={guardar}>
      <label className="exportar__campo">
        <span>Destinatarios</span>
        <textarea
          rows={2}
          value={destinatarios}
          onChange={(e) => setDestinatarios(e.target.value)}
          placeholder="direccion@empresa.com, rrhh@empresa.com"
        />
        <small>Correos separados por comas.</small>
      </label>

      <label className="exportar__campo">
        <span>Día de envío</span>
        <select value={dia} onChange={(e) => setDia(Number(e.target.value))}>
          {Array.from({ length: 28 }, (_, i) => i + 1).map((d) => (
            <option key={d} value={d}>
              Día {d} de cada mes
            </option>
          ))}
        </select>
      </label>

      <label className="exportar__casilla">
        <input type="checkbox" checked={activo} onChange={(e) => setActivo(e.target.checked)} />
        Activar envío automático (Resumen ejecutivo del mes anterior, en PDF)
      </label>

      <button type="submit" className="exportar__boton exportar__boton--secundario" disabled={guardando}>
        {guardando ? 'Guardando…' : 'Guardar configuración'}
      </button>

      {mensaje && <p className={`exportar__mensaje exportar__mensaje--${mensaje.tipo}`}>{mensaje.texto}</p>}

      <p className="exportar__aviso-correo">
        ℹ️ El envío por correo se activará cuando se configure el proveedor de correo. Mientras tanto,
        la configuración queda guardada.
      </p>
    </form>
  );
}

// ───────────── Pantalla ─────────────
export default function Exportar() {
  const empresa = useSesion((estado) => estado.sesion?.perfil.empresa?.name ?? 'Empresa');
  const queryClient = useQueryClient();

  const periodos = useMemo(() => periodosCerrados(), []);
  const [clavePeriodo, setClavePeriodo] = useState(periodos[0].clave);
  const periodo = periodos.find((p) => p.clave === clavePeriodo) ?? periodos[0];

  // Nombre del PDF: automático según el periodo, salvo que el usuario lo edite
  const [nombreEditado, setNombreEditado] = useState<string | null>(null);
  const nombrePdf = nombreEditado ?? `RetUp_Resumen_Ejecutivo_${periodo.corta}.pdf`;

  const [generandoPdf, setGenerandoPdf] = useState(false);
  const [generandoCsv, setGenerandoCsv] = useState(false);
  const [mensaje, setMensaje] = useState<Mensaje | null>(null);

  const historial = useQuery({
    queryKey: ['rrhh', 'reportes'],
    queryFn: () => apiFetch<{ success: boolean; datos: FilaHistorial[] }>('/dashboard/rrhh/reportes'),
  });

  const config = useQuery({
    queryKey: ['rrhh', 'envio-config'],
    queryFn: () => apiFetch<{ success: boolean; datos: ConfigEnvio }>('/dashboard/rrhh/envio-config'),
  });

  const recargarHistorial = () => queryClient.invalidateQueries({ queryKey: ['rrhh', 'reportes'] });

  // ── Descargar PDF ──
  async function descargarPdf() {
    const nombre = conExtension(nombrePdf, 'pdf');
    const registro = {
      tipo: 'resumen_ejecutivo',
      formato: 'pdf',
      periodo_desde: periodo.desde,
      periodo_hasta: periodo.hasta,
      periodo_etiqueta: periodo.etiqueta,
      nombre_archivo: nombre,
    };
    setGenerandoPdf(true);
    setMensaje(null);
    try {
      const parametros = new URLSearchParams({ desde: periodo.desde, hasta: periodo.hasta });
      const [resumen, activacion, scores] = await Promise.all([
        apiFetch<{ datos: { actual: KpisResumen } }>(`/dashboard/rrhh/resumen?${parametros}`),
        apiFetch<{ datos: DatosActivacionPdf }>(`/dashboard/rrhh/activacion?${parametros}`),
        apiFetch<{ datos: DatosScores }>(`/dashboard/rrhh/scores?${parametros}&frecuencia=mes`),
      ]);

      generarPdf({
        empresa,
        periodo,
        nombre,
        resumen: resumen.datos.actual,
        activacion: activacion.datos,
        scores: scores.datos,
      });

      await apiFetch('/dashboard/rrhh/reportes', { metodo: 'POST', cuerpo: { ...registro, estado: 'descargado' } });
      setMensaje({ tipo: 'ok', texto: `✅ Se descargó ${nombre}` });
    } catch (err) {
      const texto = err instanceof Error ? err.message : 'Error desconocido';
      setMensaje({ tipo: 'error', texto: `❌ No se pudo generar el PDF: ${texto}` });
      // Se anota el error en el historial (si falla, no se insiste)
      apiFetch('/dashboard/rrhh/reportes', {
        metodo: 'POST',
        cuerpo: { ...registro, estado: 'error', detalle_error: texto },
      }).catch(() => undefined);
    } finally {
      setGenerandoPdf(false);
      recargarHistorial();
    }
  }

  // ── Descargar CSV ──
  async function descargarCsv() {
    setGenerandoCsv(true);
    setMensaje(null);
    try {
      const parametros = new URLSearchParams({
        desde: periodo.desde,
        hasta: periodo.hasta,
        etiqueta: periodo.etiqueta,
        nombre: `RetUp_Datos_${periodo.corta}`,
      });
      const respuesta = await apiFetch<{ success: boolean; nombre_archivo: string; csv: string }>(
        `/dashboard/rrhh/exportar-csv?${parametros}`,
      );

      // Descarga en el navegador
      const blob = new Blob([respuesta.csv], { type: 'text/csv;charset=utf-8' });
      const url = URL.createObjectURL(blob);
      const enlace = document.createElement('a');
      enlace.href = url;
      enlace.download = respuesta.nombre_archivo;
      document.body.appendChild(enlace);
      enlace.click();
      enlace.remove();
      URL.revokeObjectURL(url);

      setMensaje({ tipo: 'ok', texto: `✅ Se descargó ${respuesta.nombre_archivo}` });
    } catch (err) {
      setMensaje({ tipo: 'error', texto: `❌ No se pudo generar el CSV: ${err instanceof Error ? err.message : ''}` });
    } finally {
      setGenerandoCsv(false);
      recargarHistorial();
    }
  }

  const filas = historial.data?.datos ?? [];

  return (
    <div className="rrhh-resumen">
      {/* ── Cabecera con el periodo del reporte ── */}
      <header className="banda-cabecera">
        <div>
          <p className="rrhh-resumen__miga">RRHH · Gerencia</p>
          <h1 className="rrhh-resumen__titulo">Exportar datos</h1>
          <p className="rrhh-resumen__subtitulo">Generación de informes ejecutivos y volcado de datos</p>
        </div>
        <label className="exportar__periodo">
          <span>Periodo del reporte</span>
          <select
            value={clavePeriodo}
            onChange={(e) => {
              setClavePeriodo(e.target.value);
              setNombreEditado(null); // el nombre vuelve a ser el automático del nuevo periodo
            }}
          >
            <optgroup label="Meses cerrados">
              {periodos.filter((p) => p.tipo === 'mes').map((p) => (
                <option key={p.clave} value={p.clave}>
                  {p.etiqueta}
                </option>
              ))}
            </optgroup>
            <optgroup label="Trimestres cerrados">
              {periodos.filter((p) => p.tipo === 'trimestre').map((p) => (
                <option key={p.clave} value={p.clave}>
                  {p.etiqueta}
                </option>
              ))}
            </optgroup>
          </select>
          <small>
            Del {fechaLegible(periodo.desde)} al {fechaLegible(periodo.hasta)}
          </small>
        </label>
      </header>

      {mensaje && <p className={`exportar__mensaje exportar__mensaje--${mensaje.tipo}`}>{mensaje.texto}</p>}

      {/* ── Fila 1: PDF y CSV ── */}
      <div className="exportar__fila">
        <section className="rrhh-resumen__panel exportar__tarjeta">
          <div className="exportar__pdf">
            <div className="exportar__miniatura" aria-hidden="true">
              <div className="exportar__miniatura-banda">RetUp</div>
              <span />
              <span />
              <span className="exportar__miniatura-corta" />
              <div className="exportar__miniatura-circulo" />
            </div>
            <div className="exportar__pdf-texto">
              <h2>Resumen Ejecutivo</h2>
              <p>
                {empresa} · {periodo.etiqueta} · Se genera al descargar
              </p>
              <label className="exportar__campo">
                <span>Nombre del archivo</span>
                <input value={nombrePdf} onChange={(e) => setNombreEditado(e.target.value)} />
              </label>
            </div>
          </div>
          <button type="button" className="exportar__boton" onClick={descargarPdf} disabled={generandoPdf}>
            {generandoPdf ? '⏳ Generando PDF…' : '⬇ Descargar PDF'}
          </button>
        </section>

        <section className="rrhh-resumen__panel exportar__tarjeta">
          <div>
            <h2 className="exportar__titulo-tarjeta">Exportar datos completos (CSV)</h2>
            <p className="exportar__texto">
              Incluye: departamento, periodo, participación y métricas agregadas por habilidad. Se abre
              con Excel.
            </p>
            <p className="exportar__privacidad">
              🛡 <strong>Privacidad:</strong> datos agregados y anónimos, sin identificadores personales.
              Se omiten los grupos por debajo del umbral de privacidad de la empresa.
            </p>
          </div>
          <button type="button" className="exportar__boton" onClick={descargarCsv} disabled={generandoCsv}>
            {generandoCsv ? '⏳ Generando CSV…' : '⬇ Descargar CSV'}
          </button>
        </section>
      </div>

      {/* ── Fila 2: envío automático e historial ── */}
      <div className="exportar__fila exportar__fila--inferior">
        <section className="rrhh-resumen__panel">
          <header className="rrhh-resumen__panel-cabecera">
            <h2>Envío automático mensual</h2>
          </header>
          {config.isPending ? (
            <p className="rrhh-resumen__vacio">⏳ Cargando…</p>
          ) : config.isError || !config.data ? (
            <p className="rrhh-resumen__vacio">❌ No se pudo cargar la configuración.</p>
          ) : (
            <FormEnvio
              key={config.data.datos.updated_at ?? 'nueva'}
              inicial={config.data.datos}
              onGuardado={() => queryClient.invalidateQueries({ queryKey: ['rrhh', 'envio-config'] })}
            />
          )}
        </section>

        <section className="rrhh-resumen__panel">
          <header className="rrhh-resumen__panel-cabecera">
            <h2>Historial de reportes</h2>
          </header>
          {historial.isPending ? (
            <p className="rrhh-resumen__vacio">⏳ Cargando…</p>
          ) : filas.length === 0 ? (
            <p className="rrhh-resumen__vacio">Todavía no se ha generado ningún reporte.</p>
          ) : (
            <div className="exportar__historial">
              <table>
                <thead>
                  <tr>
                    <th>Fecha</th>
                    <th>Periodo</th>
                    <th>Formato</th>
                    <th>Estado</th>
                    <th>Generado por</th>
                  </tr>
                </thead>
                <tbody>
                  {filas.map((f) => (
                    <tr key={f.id} title={f.nombre_archivo}>
                      <td>{textoFecha(f.created_at)}</td>
                      <td>{f.periodo_etiqueta}</td>
                      <td className="exportar__formato">{f.formato.toUpperCase()}</td>
                      <td>
                        <span
                          className={`exportar__estado exportar__estado--${f.estado}`}
                          title={f.detalle_error ?? undefined}
                        >
                          {TEXTO_ESTADO[f.estado]}
                        </span>
                      </td>
                      <td>{f.generado_por_nombre}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </section>
      </div>
    </div>
  );
}