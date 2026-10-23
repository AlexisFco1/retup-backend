// ═══════════════════════════════════════════════════════════════════
// JEFATURA · MI EQUIPO
// - Cabecera: título + Retos activos e Inscritos próximo reto
// - Tarjetas seleccionables: Avance del equipo / Días cumplidos por equipo.
//   La elegida decide qué datos muestran el gráfico y la lista de abajo.
// - Gráfico con selector de frecuencia y, si se compara, periodo anterior
//   (izquierda) vs periodo elegido (derecha) + líneas de promedio y
//   tramo de tendencia (verde si sube, roja si baja)
// - Lista por persona
// ═══════════════════════════════════════════════════════════════════
import { useMemo, useState } from 'react';
import type { ReactNode } from 'react';
import { useQuery } from '@tanstack/react-query';
import type { EChartsCoreOption } from 'echarts/core';
import { apiFetch } from '../../api/cliente';
import { fechaLegible, rangoComparacion, useFiltros } from '../../filtros/filtros';
import type { Frecuencia } from '../../filtros/filtros';
import TarjetaIndicador from '../../componentes/TarjetaIndicador';
import SelectorFrecuencia from '../../componentes/SelectorFrecuencia';
import Grafico from '../../graficos/Grafico';
import { BASE_GRAFICO, COLOR, EJE_DISCRETO } from '../../graficos/tema';
import './MiEquipo.css';

// ───────────── Forma de la respuesta del backend ─────────────
interface KpisGrupo {
  integrantes: number;
  pildoras_esperadas: number;
  pildoras_completadas: number;
  avance_pct: number | null;
  retos_activos: number;
  retos_voluntarios: number;
  retos_asignados: number;
  dias_activos_total: number;
  dias_activos_promedio: number | null;
}

/** Un tramo del gráfico. En "días cumplidos": completadas = días cumplidos, esperadas = días posibles */
interface TramoSerie {
  inicio: string;
  fin: string;
  esperadas: number;
  completadas: number;
  pct: number | null;
}

/** Una persona de la lista. En "días cumplidos": completadas = días cumplidos, esperadas = días posibles */
interface PersonaDato {
  user_id: string;
  nombre: string;
  esperadas: number;
  completadas: number;
  pct: number | null;
}

interface DiasCumplidos {
  pct: number | null;
  hechos: number; // días cumplidos, sumando a todo el equipo
  posibles: number; // días laborales posibles, sumando a todo el equipo
  personas: number;
}

interface RangoTexto {
  desde: string;
  hasta: string;
}

interface DatosMiEquipo {
  equipos: { id: string; nombre: string }[];
  periodo: RangoTexto;
  periodo_comparacion: RangoTexto | null;
  actual: KpisGrupo;
  comparacion: KpisGrupo | null;
  dias_cumplidos: { actual: DiasCumplidos | null; comparacion: DiasCumplidos | null };
  proximo_mes: { anio: number; mes: number; inscritos: number; integrantes: number };
  frecuencia: Frecuencia;
  // Avance (píldoras)
  serie: TramoSerie[];
  serie_comparacion: TramoSerie[] | null;
  por_persona: PersonaDato[];
  // Días cumplidos
  serie_dias: TramoSerie[];
  serie_dias_comparacion: TramoSerie[] | null;
  dias_por_persona: PersonaDato[];
}

interface RespuestaMiEquipo {
  success: boolean;
  datos: DatosMiEquipo;
}

// ───────────── Qué muestran los gráficos ─────────────
type Vista = 'avance' | 'dias';

const TEXTOS: Record<
  Vista,
  {
    titulo: Record<Frecuencia, string>;
    medida: string;
    tooltip: (completadas: number, esperadas: number) => string;
    sinDatos: string;
    columnas: [string, string, string];
    listaTitulo: string;
    listaDescripcion: string;
    listaDetalle: (completadas: number, esperadas: number) => string;
    listaSinDatos: string;
  }
> = {
  avance: {
    titulo: {
      dia: 'Finalización diaria del equipo',
      semana: 'Finalización semanal del equipo',
      mes: 'Finalización mensual del equipo',
    },
    medida: 'Píldoras completadas sobre esperadas',
    tooltip: (c, e) => `${c} completadas de ${e} esperadas`,
    sinDatos: 'Sin retos planificados',
    columnas: ['Completadas', 'Esperadas', 'Finalización'],
    listaTitulo: 'Avance por persona',
    listaDescripcion: 'Píldoras de su reto completadas sobre las esperadas en el periodo, de mayor a menor avance',
    listaDetalle: (c, e) => `${c} de ${e} píldoras`,
    listaSinDatos: 'Sin reto en el periodo',
  },
  dias: {
    titulo: {
      dia: 'Días cumplidos del equipo · por día',
      semana: 'Días cumplidos del equipo · por semana',
      mes: 'Días cumplidos del equipo · por mes',
    },
    medida: 'Días con login + píldora sobre días laborales posibles',
    tooltip: (c, e) => `${c} de ${e} días cumplidos`,
    sinDatos: 'Sin días laborales posibles',
    columnas: ['Días cumplidos', 'Días posibles', '% cumplido'],
    listaTitulo: 'Días cumplidos por persona',
    listaDescripcion: 'Días laborales con login + píldora sobre los días posibles del periodo, de mayor a menor',
    listaDetalle: (c, e) => `${c} de ${e} días`,
    listaSinDatos: 'Sin días laborales en el periodo',
  },
};

// ───────────── Ayudantes ─────────────
const MESES = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

const COLOR_ANTERIOR = '#B7B4DD'; // índigo claro: periodo anterior
const COLOR_SUBE = '#10B981'; // verde
const COLOR_BAJA = '#D64545'; // rojo

/** 12.5 -> '12,5 %' · null -> '—' */
function textoPct(valor: number | null | undefined): string {
  if (valor === null || valor === undefined) return '—';
  return `${String(valor).replace('.', ',')} %`;
}

/** '2026-09-14' -> '14/09' */
function diaMes(fechaIso: string): string {
  const [, mes, dia] = fechaIso.split('-');
  return `${dia}/${mes}`;
}

/** Etiqueta corta del eje X según la frecuencia */
function etiquetaEje(tramo: TramoSerie, frecuencia: Frecuencia): string {
  if (frecuencia === 'mes') {
    const mes = Number(tramo.inicio.split('-')[1]);
    return MESES[mes - 1].slice(0, 3);
  }
  return diaMes(tramo.inicio);
}

/** Texto completo del tramo (tooltip y tabla) */
function textoTramo(tramo: TramoSerie, frecuencia: Frecuencia): string {
  if (frecuencia === 'dia') return `Día ${diaMes(tramo.inicio)}`;
  if (frecuencia === 'mes') {
    const mes = Number(tramo.inicio.split('-')[1]);
    return `${MESES[mes - 1][0].toUpperCase()}${MESES[mes - 1].slice(1)} (${diaMes(tramo.inicio)} – ${diaMes(tramo.fin)})`;
  }
  return `Semana del ${diaMes(tramo.inicio)} al ${diaMes(tramo.fin)}`;
}

/** 'ALEXIS FERNANDEZ' -> 'AF' */
function iniciales(nombre: string): string {
  return nombre
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((parte) => parte[0])
    .join('')
    .toUpperCase();
}

const DESCRIPCION_FRECUENCIA: Record<Frecuencia, string> = {
  dia: 'un punto por día laboral',
  semana: 'un punto por semana (lunes a domingo)',
  mes: 'un punto por mes',
};

type Grupo = 'anterior' | 'hueco' | 'actual';
interface PuntoGrafico {
  grupo: Grupo;
  tramo: TramoSerie | null;
}

/** Dato compacto de la cabecera: icono · título (i) · "X de Y" · detalle */
function DatoCabecera({
  icono,
  titulo,
  valor,
  total,
  detalle,
  ayuda,
}: {
  icono: 'reto' | 'calendario';
  titulo: string;
  valor: number;
  total: number;
  detalle: string;
  ayuda: string;
}) {
  return (
    <div className="mi-equipo__dato">
      <span className="mi-equipo__dato-icono" aria-hidden="true">
        {icono === 'reto' ? (
          <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor"
               strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <circle cx="12" cy="12" r="9" />
            <circle cx="12" cy="12" r="5" />
            <circle cx="12" cy="12" r="1" />
          </svg>
        ) : (
          <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor"
               strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <rect x="3" y="5" width="18" height="16" rx="2" />
            <path d="M16 3v4M8 3v4M3 10h18" />
          </svg>
        )}
      </span>
      <div className="mi-equipo__dato-texto">
        <p className="mi-equipo__dato-titulo">
          {titulo}
          <span className="tarjeta__ayuda" tabIndex={0} aria-label={`Qué es: ${ayuda}`}>
            i
            <span className="tarjeta__burbuja" role="tooltip">
              {ayuda}
            </span>
          </span>
        </p>
        <p className="mi-equipo__dato-valor">
          {valor}
          <span> de {total}</span>
        </p>
        <p className="mi-equipo__dato-detalle">{detalle}</p>
      </div>
    </div>
  );
}

/** Envoltorio que convierte una tarjeta en opción seleccionable */
function OpcionTarjeta({
  activa,
  onElegir,
  children,
}: {
  activa: boolean;
  onElegir: () => void;
    children: ReactNode;
}) {
  return (
    <div
      role="button"
      tabIndex={0}
      aria-pressed={activa}
      className={`mi-equipo__opcion${activa ? ' mi-equipo__opcion--activa' : ''}`}
      onClick={onElegir}
      onKeyDown={(e) => {
        if (e.key === 'Enter' || e.key === ' ') {
          e.preventDefault();
          onElegir();
        }
      }}
    >
      <span className="mi-equipo__opcion-etiqueta">
        {activa ? '● Viendo en los gráficos' : 'Clic para ver en los gráficos'}
      </span>
      {children}
    </div>
  );
}

export default function MiEquipo() {
  const { desde, hasta, comparacion, frecuencia, periodo } = useFiltros();
  const comparado = rangoComparacion({ desde, hasta }, comparacion, periodo);
  const [vista, setVista] = useState<Vista>('avance');
  const textos = TEXTOS[vista];

  // Los filtros forman parte de la "clave": si cambian, se vuelven a pedir los datos
  const consulta = useQuery({
    queryKey: [
      'jefatura', 'mi-equipo', desde, hasta, frecuencia,
      comparado?.desde ?? null, comparado?.hasta ?? null,
    ],
    queryFn: () => {
      const parametros = new URLSearchParams({ desde, hasta, frecuencia });
      if (comparado) {
        parametros.set('comp_desde', comparado.desde);
        parametros.set('comp_hasta', comparado.hasta);
      }
      return apiFetch<RespuestaMiEquipo>(`/dashboard/jefatura/mi-equipo?${parametros}`);
    },
    // Mientras llegan los datos nuevos, se siguen viendo los anteriores (sin parpadeos)
    placeholderData: (anteriores) => anteriores,
  });

  const datos = consulta.data?.datos;

  // ───────────── Gráfico (según la tarjeta elegida) ─────────────
  const grafico = useMemo(() => {
    if (!datos) return null;
    const frec = datos.frecuencia;
    const texto = TEXTOS[vista];

    // Datos de la vista elegida
    const serieActual = (vista === 'avance' ? datos.serie : datos.serie_dias) ?? [];
    const anteriores =
      (vista === 'avance' ? datos.serie_comparacion : datos.serie_dias_comparacion) ?? [];
    const pctAnterior =
      vista === 'avance'
        ? datos.comparacion?.avance_pct ?? null
        : datos.dias_cumplidos.comparacion?.pct ?? null;
    const pctActual =
      vista === 'avance' ? datos.actual.avance_pct : datos.dias_cumplidos.actual?.pct ?? null;

    const comparando = anteriores.length > 0;

    // Orden en el eje: [periodo anterior] [3 huecos] [periodo elegido]
    // En los huecos van la línea de tendencia y sus etiquetas (no tocan barras)
    const puntos: PuntoGrafico[] = [
      ...anteriores.map((t) => ({ grupo: 'anterior' as const, tramo: t })),
      ...(comparando
        ? [0, 1, 2].map(() => ({ grupo: 'hueco' as const, tramo: null }))
        : []),
      ...serieActual.map((t) => ({ grupo: 'actual' as const, tramo: t })),
    ];

    const hayLinea =
      comparando && serieActual.length > 0 && pctAnterior !== null && pctActual !== null;
    const colorLinea =
      hayLinea && (pctActual as number) < (pctAnterior as number) ? COLOR_BAJA : COLOR_SUBE;

    // Extremos del tramo de tendencia: primer y último hueco de la separación
    const ultimoAnterior = anteriores.length;
    const primerActual = anteriores.length + 2;

    const series: Record<string, unknown>[] = [
      {
        name: 'Periodo anterior',
        type: 'bar',
        stack: 'barras',
        barMaxWidth: 24,
        itemStyle: { color: COLOR_ANTERIOR, borderRadius: [4, 4, 0, 0] },
        data: puntos.map((p) => (p.grupo === 'anterior' ? p.tramo!.pct : null)),
        ...(comparando && {
          markLine: {
            silent: true,
            symbol: 'none',
            label: { show: false },
            lineStyle: { color: COLOR.borde, type: 'dashed', width: 1.5 },
            data: [{ xAxis: anteriores.length + 1 }],
          },
        }),
      },
      {
        name: 'Periodo elegido',
        type: 'bar',
        stack: 'barras',
        barMaxWidth: 24,
        itemStyle: { color: COLOR.indigo, borderRadius: [4, 4, 0, 0] },
        data: puntos.map((p) => (p.grupo === 'actual' ? p.tramo!.pct : null)),
      },
    ];

    if (hayLinea) {
      // Línea discontinua horizontal con el promedio de un periodo: cruza sus
      // barras y se alarga hasta el hueco donde empieza/termina la tendencia
      const lineaPromedio = (
        nombre: string,
        color: string,
        grupo: Grupo,
        valor: number | null,
        indiceExtremo: number,
      ) => ({
        name: nombre,
        type: 'line',
        z: 4,
        symbol: 'none',
        silent: true,
        tooltip: { show: false },
        lineStyle: { color, width: 2, type: 'dashed' },
        data: puntos.map((p, i) => (p.grupo === grupo || i === indiceExtremo ? valor : null)),
      });

      series.push(
        lineaPromedio('Promedio periodo anterior', '#8E89C9', 'anterior', pctAnterior, ultimoAnterior),
        lineaPromedio('Promedio periodo elegido', COLOR.indigo, 'actual', pctActual, primerActual),
        {
          // Tramo verde (sube) o rojo (baja) que une los dos promedios
          name: 'Tendencia',
          type: 'line',
          z: 5,
          connectNulls: true,
          symbol: 'circle',
          symbolSize: 9,
          lineStyle: { color: colorLinea, width: 3 },
          itemStyle: { color: colorLinea },
          label: {
            show: true,
            position: 'top',
            color: colorLinea,
            fontWeight: 'bold',
            backgroundColor: '#ffffff',
            padding: [2, 4],
            borderRadius: 4,
            formatter: (p: { value: number | null }) => textoPct(p.value),
          },
          tooltip: { show: false },
          data: puntos.map((_, i) =>
            i === ultimoAnterior ? pctAnterior : i === primerActual ? pctActual : null,
          ),
        },
      );
    }

    const opciones: EChartsCoreOption = {
      ...BASE_GRAFICO,
      grid: { left: 44, right: 16, top: 28, bottom: 36 },
      tooltip: {
        ...BASE_GRAFICO.tooltip,
        trigger: 'axis',
        axisPointer: { type: 'shadow', shadowStyle: { color: 'rgba(46,42,114,0.06)' } },
        formatter: (params: { dataIndex: number }[]) => {
          const punto = puntos[params[0].dataIndex];
          if (!punto || !punto.tramo) return '';
          const tramo = punto.tramo;
          const etiqueta =
            punto.grupo === 'anterior' ? 'Periodo anterior · ' : comparando ? 'Periodo elegido · ' : '';
          const titulo = `${etiqueta}${textoTramo(tramo, frec)}`;
          if (tramo.esperadas === 0) return `<b>${titulo}</b><br/>${texto.sinDatos}`;
          return (
            `<b>${titulo}</b><br/>` +
            `${texto.columnas[2]}: <b>${textoPct(tramo.pct)}</b><br/>` +
            texto.tooltip(tramo.completadas, tramo.esperadas)
          );
        },
      },
      xAxis: {
        type: 'category',
        data: puntos.map((p) => (p.tramo ? etiquetaEje(p.tramo, frec) : '')),
        ...EJE_DISCRETO,
        splitLine: { show: false },
      },
      yAxis: {
        type: 'value',
        min: 0,
        max: 100,
        interval: 25,
        ...EJE_DISCRETO,
        axisLabel: { ...EJE_DISCRETO.axisLabel, formatter: '{value} %' },
      },
      series,
    };

    return { opciones, comparando, pctAnterior, pctActual, hayLinea, serieActual, anteriores };
  }, [datos, vista]);

  // Personas de mayor a menor (sin datos al final), según la vista
  const personas = useMemo(
    () =>
      [...((vista === 'avance' ? datos?.por_persona : datos?.dias_por_persona) ?? [])].sort(
        (a, b) => (b.pct ?? -1) - (a.pct ?? -1) || a.nombre.localeCompare(b.nombre),
      ),
    [datos, vista],
  );

  // ───────────── Estados: cargando / error / sin equipo ─────────────
  if (consulta.isPending) {
    return <p className="mi-equipo__estado">⏳ Calculando los indicadores de tu equipo…</p>;
  }
  if (consulta.isError || !datos) {
    return (
      <p className="mi-equipo__estado mi-equipo__estado--error">
        ❌ {consulta.error?.message ?? 'No se pudieron cargar los datos'}
      </p>
    );
  }
  if (datos.equipos.length === 0) {
    return (
      <p className="mi-equipo__estado">
        Todavía no tienes ningún equipo a cargo. Pide a RRHH que te asigne como jefe de un equipo.
      </p>
    );
  }

  const { actual } = datos;
  const anterior = datos.comparacion;
  const proximo = datos.proximo_mes;

  // Diferencia entre periodos (franja bajo el gráfico)
  let diferencia: { texto: string; clase: string } | null = null;
  if (grafico?.hayLinea) {
    const pts = Math.round(((grafico.pctActual as number) - (grafico.pctAnterior as number)) * 10) / 10;
    diferencia =
      pts === 0
        ? { texto: '= sin cambios', clase: 'igual' }
        : {
            texto: `${pts > 0 ? '▲ +' : '▼ '}${String(pts).replace('.', ',')} pts`,
            clase: pts > 0 ? 'sube' : 'baja',
          };
  }

  return (
    <div className={`mi-equipo${consulta.isFetching ? ' mi-equipo--actualizando' : ''}`}>
      {/* ── Cabecera: una sola banda con el título y 2 datos que cambian poco ── */}
      <header className="mi-equipo__cabecera">
        <div className="mi-equipo__cabecera-texto">
          <p className="mi-equipo__miga">Jefatura</p>
          <h1 className="mi-equipo__titulo">Mi equipo</h1>
          <p className="mi-equipo__equipos">
            {datos.equipos.map((e) => e.nombre).join(' · ')} · {actual.integrantes}{' '}
            {actual.integrantes === 1 ? 'integrante' : 'integrantes'}
          </p>
        </div>

        <div className="mi-equipo__datos">
          <DatoCabecera
            icono="reto"
            titulo="Retos activos"
            valor={actual.retos_voluntarios}
            total={actual.integrantes}
            detalle={
              actual.retos_asignados === 0
                ? 'todos elegidos voluntariamente'
                : `${actual.retos_asignados} con reto asignado por el sistema`
            }
            ayuda="Integrantes que eligieron voluntariamente al menos un reto en el periodo. Quienes tienen un reto asignado por el sistema se indican aparte."
          />
          <DatoCabecera
            icono="calendario"
            titulo="Inscritos próximo reto"
            valor={proximo.inscritos}
            total={proximo.integrantes}
            detalle={`para ${MESES[proximo.mes - 1]} ${proximo.anio}`}
            ayuda="Integrantes ya inscritos para el reto del mes siguiente. Se calcula respecto a hoy, no al periodo filtrado."
          />
        </div>
      </header>

      {/* ── Tarjetas seleccionables: deciden qué muestran los gráficos ── */}
      <section className="mi-equipo__tarjetas">
        <OpcionTarjeta activa={vista === 'avance'} onElegir={() => setVista('avance')}>
          <TarjetaIndicador
            titulo="Avance del equipo"
            ayuda="Píldoras de sus retos completadas por el equipo, sobre las esperadas en el periodo (1 por día laboral y reto inscrito). Las hechas en fin de semana o festivo cuentan el siguiente día laboral."
            valor={actual.avance_pct}
            formato="porcentaje"
            conBarra
            detalle={`${actual.pildoras_completadas} de ${actual.pildoras_esperadas} píldoras`}
            valorAnterior={anterior?.avance_pct}
          />
        </OpcionTarjeta>
        <OpcionTarjeta activa={vista === 'dias'} onElegir={() => setVista('dias')}>
          <TarjetaIndicador
            titulo="Días cumplidos por equipo"
            ayuda="Días laborales en que cada integrante hizo login y al menos una píldora de su reto, sumando a todo el equipo, sobre los días laborales posibles de todos. Sábados, domingos y festivos no cuentan. Hoy solo cuenta si ya lo cumplió."
            valor={datos.dias_cumplidos.actual?.pct}
            formato="porcentaje"
            conBarra
            detalle={`${datos.dias_cumplidos.actual?.hechos ?? 0} de ${datos.dias_cumplidos.actual?.posibles ?? 0} días cumplidos (sumando a todo el equipo)`}
            valorAnterior={datos.dias_cumplidos.comparacion?.pct}
          />
        </OpcionTarjeta>
      </section>

      {/* ── Gráfico de la vista elegida ── */}
      <section className="mi-equipo__panel">
        <header className="mi-equipo__panel-cabecera cabecera-con-frecuencia">
          <div>
            <h2>{textos.titulo[datos.frecuencia]}</h2>
            <p>
              {textos.medida} · {DESCRIPCION_FRECUENCIA[datos.frecuencia]}
              {grafico?.comparando &&
                '. Barras claras: periodo anterior · barras oscuras: periodo elegido · líneas discontinuas: promedio de cada periodo'}
            </p>
          </div>
          <SelectorFrecuencia />
        </header>

        {!grafico || grafico.serieActual.length === 0 ? (
          <p className="mi-equipo__vacio">No hay días laborales en el periodo elegido.</p>
        ) : (
          <Grafico
            opciones={grafico.opciones}
            alto={280}
            descripcion={`Gráfico de columnas: ${textos.titulo[datos.frecuencia].toLowerCase()}${grafico.comparando ? ', periodo anterior frente al periodo elegido' : ''}`}
          />
        )}

        {/* Franja: periodo anterior  vs  periodo elegido */}
        {grafico?.comparando && datos.periodo_comparacion && (
          <div className="mi-equipo__comparativa">
            <div className="mi-equipo__comparativa-lado">
              <span className="mi-equipo__muestra mi-equipo__muestra--anterior" aria-hidden="true" />
              <div>
                <strong>Periodo anterior</strong>
                <span>
                  {fechaLegible(datos.periodo_comparacion.desde)} – {fechaLegible(datos.periodo_comparacion.hasta)} ·{' '}
                  {textoPct(grafico.pctAnterior)}
                </span>
              </div>
            </div>

            <div className={`mi-equipo__comparativa-centro mi-equipo__comparativa-centro--${diferencia?.clase ?? 'igual'}`}>
              {diferencia?.texto ?? '—'}
              <span>vs</span>
            </div>

            <div className="mi-equipo__comparativa-lado mi-equipo__comparativa-lado--derecha">
              <div>
                <strong>Periodo elegido</strong>
                <span>
                  {fechaLegible(datos.periodo.desde)} – {fechaLegible(datos.periodo.hasta)} ·{' '}
                  {textoPct(grafico.pctActual)}
                </span>
              </div>
              <span className="mi-equipo__muestra mi-equipo__muestra--actual" aria-hidden="true" />
            </div>
          </div>
        )}

        <details className="mi-equipo__tabla-datos">
          <summary>Ver datos en tabla</summary>
          <table>
            <thead>
              <tr>
                {grafico?.comparando && <th>Periodo</th>}
                <th>Tramo</th>
                <th>{textos.columnas[0]}</th>
                <th>{textos.columnas[1]}</th>
                <th>{textos.columnas[2]}</th>
              </tr>
            </thead>
            <tbody>
              {(grafico?.anteriores ?? []).map((t) => (
                <tr key={`anterior-${t.inicio}`}>
                  <td>Anterior</td>
                  <td>{textoTramo(t, datos.frecuencia)}</td>
                  <td>{t.completadas}</td>
                  <td>{t.esperadas}</td>
                  <td>{textoPct(t.pct)}</td>
                </tr>
              ))}
              {(grafico?.serieActual ?? []).map((t) => (
                <tr key={`actual-${t.inicio}`}>
                  {grafico?.comparando && <td>Elegido</td>}
                  <td>{textoTramo(t, datos.frecuencia)}</td>
                  <td>{t.completadas}</td>
                  <td>{t.esperadas}</td>
                  <td>{textoPct(t.pct)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </details>
      </section>

      {/* ── Lista por persona de la vista elegida ── */}
      <section className="mi-equipo__panel">
        <header className="mi-equipo__panel-cabecera">
          <h2>{textos.listaTitulo}</h2>
          <p>{textos.listaDescripcion}</p>
        </header>

        {personas.length === 0 ? (
          <p className="mi-equipo__vacio">No hay integrantes en el equipo.</p>
        ) : (
          <ul className="mi-equipo__personas">
            {personas.map((persona) => (
              <li key={persona.user_id} className="mi-equipo__persona">
                <span className="mi-equipo__persona-avatar" aria-hidden="true">
                  {iniciales(persona.nombre)}
                </span>
                <div className="mi-equipo__persona-nombre">
                  <strong>{persona.nombre}</strong>
                  <span>
                    {persona.esperadas === 0
                      ? textos.listaSinDatos
                      : textos.listaDetalle(persona.completadas, persona.esperadas)}
                  </span>
                </div>
                <div className="mi-equipo__persona-barra" aria-hidden="true">
                  <div style={{ width: `${persona.pct ?? 0}%` }} />
                </div>
                <strong className="mi-equipo__persona-valor">{textoPct(persona.pct)}</strong>
              </li>
            ))}
          </ul>
        )}
      </section>
    </div>
  );
}