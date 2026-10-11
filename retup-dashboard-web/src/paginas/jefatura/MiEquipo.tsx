// ═══════════════════════════════════════════════════════════════════
// JEFATURA · MI EQUIPO
// Indicadores del equipo del jefe conectado. Responde a los filtros
// globales: periodo, "comparar con" y frecuencia (el gráfico de
// finalización se agrupa por día laboral, semana o mes).
// ═══════════════════════════════════════════════════════════════════
import { useMemo } from 'react';
import { useQuery } from '@tanstack/react-query';
import type { EChartsCoreOption } from 'echarts/core';
import { apiFetch } from '../../api/cliente';
import { rangoComparacion, useFiltros } from '../../filtros/filtros';
import type { Frecuencia } from '../../filtros/filtros';
import TarjetaIndicador from '../../componentes/TarjetaIndicador';
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

interface TramoSerie {
  inicio: string;
  fin: string;
  esperadas: number;
  completadas: number;
  pct: number | null;
}

interface RetoEquipo {
  reto_id: string;
  titulo: string;
  personas: number;
  esperadas: number;
  completadas: number;
  pct: number | null;
}

interface DatosMiEquipo {
  equipos: { id: string; nombre: string }[];
  actual: KpisGrupo;
  comparacion: KpisGrupo | null;
  proximo_mes: { anio: number; mes: number; inscritos: number; integrantes: number };
  frecuencia: Frecuencia;
  serie: TramoSerie[];
  por_reto: RetoEquipo[];
}

interface RespuestaMiEquipo {
  success: boolean;
  datos: DatosMiEquipo;
}

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

const TITULO_SERIE: Record<Frecuencia, string> = {
  dia: 'Finalización diaria del equipo',
  semana: 'Finalización semanal del equipo',
  mes: 'Finalización mensual del equipo',
};

const DESCRIPCION_SERIE: Record<Frecuencia, string> = {
  dia: 'un punto por día laboral',
  semana: 'un punto por semana (lunes a domingo)',
  mes: 'un punto por mes',
};

export default function MiEquipo() {
  const { desde, hasta, comparacion, frecuencia } = useFiltros();
  const comparado = rangoComparacion({ desde, hasta }, comparacion);

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

  // Opciones del gráfico de finalización (solo se recalculan si cambian los datos)
  const opcionesSerie = useMemo<EChartsCoreOption | null>(() => {
    if (!datos) return null;
    const tramos = datos.serie;
    const frec = datos.frecuencia;
    return {
      ...BASE_GRAFICO,
      grid: { left: 44, right: 16, top: 16, bottom: 36 },
      tooltip: {
        ...BASE_GRAFICO.tooltip,
        trigger: 'axis',
        axisPointer: { type: 'shadow', shadowStyle: { color: 'rgba(46,42,114,0.06)' } },
        formatter: (params: { dataIndex: number }[]) => {
          const tramo = tramos[params[0].dataIndex];
          const titulo = textoTramo(tramo, frec);
          if (tramo.esperadas === 0) return `<b>${titulo}</b><br/>Sin retos planificados`;
          return (
            `<b>${titulo}</b><br/>` +
            `Finalización: <b>${String(tramo.pct).replace('.', ',')} %</b><br/>` +
            `${tramo.completadas} completadas de ${tramo.esperadas} esperadas`
          );
        },
      },
      xAxis: {
        type: 'category',
        data: tramos.map((t) => etiquetaEje(t, frec)),
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
      series: [
        {
          name: TITULO_SERIE[frec],
          type: 'bar',
          barMaxWidth: 24,
          itemStyle: { color: COLOR.indigo, borderRadius: [4, 4, 0, 0] },
          data: tramos.map((t) => t.pct),
        },
      ],
    };
  }, [datos]);

  // Retos ordenados de mayor a menor finalización
  const retosOrdenados = useMemo(
    () => [...(datos?.por_reto ?? [])].sort((a, b) => (b.pct ?? -1) - (a.pct ?? -1)),
    [datos],
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

  return (
    <div className={`mi-equipo${consulta.isFetching ? ' mi-equipo--actualizando' : ''}`}>
      <header className="mi-equipo__cabecera">
        <p className="mi-equipo__miga">Jefatura</p>
        <h1 className="mi-equipo__titulo">Mi equipo</h1>
        <p className="mi-equipo__equipos">
          {datos.equipos.map((e) => e.nombre).join(' · ')} · {actual.integrantes}{' '}
          {actual.integrantes === 1 ? 'integrante' : 'integrantes'}
        </p>
      </header>

      {/* ── Tarjetas de indicadores ── */}
      <section className="mi-equipo__tarjetas">
        <TarjetaIndicador
          titulo="Avance del equipo"
          ayuda="Píldoras de sus retos completadas por el equipo, sobre las esperadas en el periodo (1 por día laboral y reto inscrito)."
          valor={actual.avance_pct}
          formato="porcentaje"
          conBarra
          detalle={`${actual.pildoras_completadas} de ${actual.pildoras_esperadas} píldoras`}
          valorAnterior={anterior?.avance_pct}
        />
                <TarjetaIndicador
          titulo="Retos activos en mi equipo"
          ayuda="Integrantes que eligieron voluntariamente al menos un reto en el periodo. Quienes tienen un reto asignado al azar por el sistema se indican aparte."
          valor={actual.retos_voluntarios}
          formato="numero"
          detalle={`de ${actual.integrantes} integrantes · ${actual.retos_asignados} con reto asignado por el sistema`}
          valorAnterior={anterior?.retos_voluntarios}
        />
        <TarjetaIndicador
          titulo="Rachas en mi equipo"
          ayuda="Promedio de días con al menos una píldora completada por integrante (incluye píldoras sueltas). Anónimo: no muestra personas."
          valor={actual.dias_activos_promedio}
          formato="decimal"
          detalle="días activos por persona en el periodo"
          valorAnterior={anterior?.dias_activos_promedio}
        />
        <TarjetaIndicador
          titulo="Inscritos próximo reto"
          ayuda="Integrantes ya inscritos para el reto del mes siguiente. Se calcula respecto a hoy, no al periodo filtrado."
          valor={proximo.inscritos}
          formato="numero"
          detalle={`de ${proximo.integrantes} para ${MESES[proximo.mes - 1]} ${proximo.anio}`}
        />
      </section>

      {/* ── Finalización en el tiempo (sigue a la frecuencia) ── */}
      <section className="mi-equipo__panel">
        <header className="mi-equipo__panel-cabecera">
          <h2>{TITULO_SERIE[datos.frecuencia]}</h2>
          <p>
            Píldoras completadas sobre esperadas · {DESCRIPCION_SERIE[datos.frecuencia]}. Cambia la
            frecuencia en la barra de filtros.
          </p>
        </header>
        {datos.serie.length === 0 ? (
          <p className="mi-equipo__vacio">No hay días laborales en el periodo elegido.</p>
        ) : (
          opcionesSerie && (
            <Grafico
              opciones={opcionesSerie}
              alto={260}
              descripcion={`Gráfico de columnas: ${TITULO_SERIE[datos.frecuencia].toLowerCase()} en el periodo elegido`}
            />
          )
        )}
        <details className="mi-equipo__tabla-datos">
          <summary>Ver datos en tabla</summary>
          <table>
            <thead>
              <tr>
                <th>Tramo</th>
                <th>Completadas</th>
                <th>Esperadas</th>
                <th>Finalización</th>
              </tr>
            </thead>
            <tbody>
              {datos.serie.map((t) => (
                <tr key={t.inicio}>
                  <td>{textoTramo(t, datos.frecuencia)}</td>
                  <td>{t.completadas}</td>
                  <td>{t.esperadas}</td>
                  <td>{t.pct === null ? '—' : `${String(t.pct).replace('.', ',')} %`}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </details>
      </section>

      {/* ── Finalización por reto ── */}
      <section className="mi-equipo__panel">
        <header className="mi-equipo__panel-cabecera">
          <h2>Finalización por reto</h2>
          <p>Retos elegidos por el equipo en el periodo, de mayor a menor finalización</p>
        </header>

        {retosOrdenados.length === 0 ? (
          <p className="mi-equipo__vacio">Nadie del equipo tiene retos en este periodo.</p>
        ) : (
          <ul className="mi-equipo__retos">
            {retosOrdenados.map((reto) => (
              <li key={reto.reto_id} className="mi-equipo__reto">
                <div className="mi-equipo__reto-nombre">
                  <strong>{reto.titulo}</strong>
                  <span>
                    {reto.personas} {reto.personas === 1 ? 'persona' : 'personas'}
                  </span>
                </div>
                <div className="mi-equipo__reto-barra" aria-hidden="true">
                  <div style={{ width: `${reto.pct ?? 0}%` }} />
                </div>
                <div className="mi-equipo__reto-valor">
                  <strong>{reto.pct === null ? '—' : `${String(reto.pct).replace('.', ',')} %`}</strong>
                  <span>
                    {reto.completadas} de {reto.esperadas}
                  </span>
                </div>
              </li>
            ))}
          </ul>
        )}
      </section>
    </div>
  );
}