// ═══════════════════════════════════════════════════════════════════
// RRHH · GERENCIA · ACTIVACIÓN POR ÁREA
// Activación = colaboradores habilitados que completaron al menos una
// píldora (de reto o suelta) en el periodo. Objetivo de company_settings.
// Los indicadores de score se activarán cuando exista el cálculo del score.
// ═══════════════════════════════════════════════════════════════════
import { useMemo } from 'react';
import { useQuery } from '@tanstack/react-query';
import type { EChartsCoreOption } from 'echarts/core';
import { apiFetch } from '../../api/cliente';
import { rangoComparacion, useFiltros } from '../../filtros/filtros';
import TarjetaIndicador from '../../componentes/TarjetaIndicador';
import Grafico from '../../graficos/Grafico';
import { BASE_GRAFICO, COLOR, EJE_DISCRETO } from '../../graficos/tema';
import {
  etiquetaTramo,
  mensajeSinScore,
  TarjetaPendiente,
  textoScore,
  textoTramo,
  useScoresRrhh,
} from './scores';
import './Resumen.css';
import './Activacion.css';

// ───────────── Forma de la respuesta del backend ─────────────
interface Activacion {
  habilitados: number;
  activados: number;
  pct: number | null;
}

interface Finalizacion {
  retos_iniciados: number;
  retos_completados: number;
  finalizacion_pct: number | null;
}

interface ActivacionEmpresa extends Activacion {
  finalizacion: Finalizacion;
}

interface Area {
  departamento_id: string | null;
  departamento: string;
  actual: Activacion;
  comparacion: Activacion | null;
}

interface DatosActivacion {
  objetivo_pct: number;
  actual: ActivacionEmpresa;
  comparacion: ActivacionEmpresa | null;
  por_area: Area[];
}

interface RespuestaActivacion {
  success: boolean;
  datos: DatosActivacion;
}

/** 66.7 -> "66,7 %" */
function textoPct(valor: number | null | undefined): string {
  if (typeof valor !== 'number') return '—';
  return `${new Intl.NumberFormat('es-ES', { maximumFractionDigits: 1 }).format(valor)} %`;
}

export default function ActivacionPorArea() {
  const { desde, hasta, comparacion } = useFiltros();
  const comparado = rangoComparacion({ desde, hasta }, comparacion);

  const consulta = useQuery({
    queryKey: ['rrhh', 'activacion', desde, hasta, comparado?.desde ?? null, comparado?.hasta ?? null],
    queryFn: () => {
      const parametros = new URLSearchParams({ desde, hasta });
      if (comparado) {
        parametros.set('comp_desde', comparado.desde);
        parametros.set('comp_hasta', comparado.hasta);
      }
      return apiFetch<RespuestaActivacion>(`/dashboard/rrhh/activacion?${parametros}`);
    },
    placeholderData: (anteriores) => anteriores,
  });

    const datos = consulta.data?.datos;

  // Scores (los mismos datos que usa Resumen: se reutilizan si ya se pidieron)
  const scores = useScoresRrhh();
  const datosScores = scores.data?.datos;

  // Evolución del score medio de la empresa (un punto por tramo según la frecuencia)
  const opcionesEvolucion = useMemo<EChartsCoreOption | null>(() => {
    if (!datosScores || !datosScores.serie.some((t) => t.score !== null)) return null;
    const serie = datosScores.serie;
    const frecuencia = datosScores.frecuencia;

    return {
      ...BASE_GRAFICO,
      grid: { left: 44, right: 16, top: 16, bottom: 36 },
      tooltip: {
        ...BASE_GRAFICO.tooltip,
        trigger: 'axis',
        formatter: (params: { dataIndex: number }[]) => {
          const tramo = serie[params[0].dataIndex];
          const titulo = textoTramo(tramo, frecuencia);
          if (tramo.score === null) {
            return `<b>${titulo}</b><br/>${mensajeSinScore(tramo.evaluados, datosScores.umbral_n)}`;
          }
          return `<b>${titulo}</b><br/>Score medio: <b>${textoScore(tramo.score)}</b><br/>${tramo.evaluados} evaluados`;
        },
      },
      xAxis: {
        type: 'category',
        data: serie.map((t) => etiquetaTramo(t, frecuencia)),
        ...EJE_DISCRETO,
        splitLine: { show: false },
      },
      yAxis: { type: 'value', min: 0, max: 100, interval: 25, ...EJE_DISCRETO },
      series: [
        {
          name: 'Score medio',
          type: 'line',
          data: serie.map((t) => t.score),
          connectNulls: false,
          symbol: 'circle',
          symbolSize: 7,
          lineStyle: { color: COLOR.indigo, width: 2 },
          itemStyle: { color: COLOR.indigo },
        },
      ],
    };
  }, [datosScores]);

  // Áreas ordenadas de mayor a menor activación
  const areas = useMemo(
    () => [...(datos?.por_area ?? [])].sort((a, b) => (b.actual.pct ?? -1) - (a.actual.pct ?? -1)),
    [datos],
  );

  // Barras horizontales con línea de objetivo
  const opcionesAreas = useMemo<EChartsCoreOption | null>(() => {
    if (!datos || areas.length === 0) return null;
    // En barras horizontales el primer dato va abajo: se invierte para que la mayor quede arriba
    const filas = [...areas].reverse();
    const objetivo = datos.objetivo_pct;

    return {
      ...BASE_GRAFICO,
      grid: { left: 8, right: 64, top: 28, bottom: 8, containLabel: true },
      tooltip: {
        ...BASE_GRAFICO.tooltip,
        trigger: 'axis',
        axisPointer: { type: 'shadow', shadowStyle: { color: 'rgba(46,42,114,0.06)' } },
        formatter: (params: { dataIndex: number }[]) => {
          const area = filas[params[0].dataIndex];
          let texto =
            `<b>${area.departamento}</b><br/>` +
            `Activación: <b>${textoPct(area.actual.pct)}</b><br/>` +
            `${area.actual.activados} de ${area.actual.habilitados} colaboradores`;
          if (area.comparacion) {
            texto += `<br/>Periodo de comparación: ${textoPct(area.comparacion.pct)}`;
          }
          return texto;
        },
      },
      xAxis: {
        type: 'value',
        min: 0,
        max: 100,
        interval: 25,
        ...EJE_DISCRETO,
        axisLabel: { ...EJE_DISCRETO.axisLabel, formatter: '{value} %' },
      },
      yAxis: {
        type: 'category',
        data: filas.map((a) => a.departamento),
        ...EJE_DISCRETO,
        splitLine: { show: false },
        axisLabel: { ...EJE_DISCRETO.axisLabel, color: COLOR.texto, fontSize: 13 },
      },
      series: [
        {
          name: 'Activación',
          type: 'bar',
          barMaxWidth: 22,
          itemStyle: { color: COLOR.indigo, borderRadius: [0, 4, 4, 0] },
          data: filas.map((a) => a.actual.pct ?? 0),
          label: {
            show: true,
            position: 'right',
            color: COLOR.texto,
            fontSize: 12,
            formatter: (p: { dataIndex: number }) => textoPct(filas[p.dataIndex].actual.pct),
          },
          // Línea vertical del objetivo
          markLine: {
            symbol: 'none',
            silent: true,
            lineStyle: { color: COLOR.texto, type: 'dashed', width: 1 },
            label: {
              position: 'end',
              formatter: `Objetivo ${textoPct(objetivo)}`,
              color: COLOR.texto,
              fontSize: 12,
            },
            data: [{ xAxis: objetivo }],
          },
        },
      ],
    };
  }, [datos, areas]);

  // ───────────── Estados: cargando / error ─────────────
  if (consulta.isPending) {
    return <p className="rrhh-resumen__estado">⏳ Calculando la activación de la empresa…</p>;
  }
  if (consulta.isError || !datos) {
    return (
      <p className="rrhh-resumen__estado rrhh-resumen__estado--error">
        ❌ {consulta.error?.message ?? 'No se pudieron cargar los datos'}
      </p>
    );
  }

  const { actual, objetivo_pct: objetivo } = datos;
  const anterior = datos.comparacion;

  // Texto bajo el valor de activación: cuánto falta para el objetivo
  let detalleActivacion = `${actual.activados} de ${actual.habilitados} colaboradores`;
  if (typeof actual.pct === 'number') {
    detalleActivacion +=
      actual.pct >= objetivo
        ? ` · ✅ objetivo del ${textoPct(objetivo)} alcanzado`
        : ` · faltan ${textoPct(Math.round((objetivo - actual.pct) * 10) / 10).replace(' %', '')} pts para el ${textoPct(objetivo)}`;
  }

  return (
    <div className={`rrhh-resumen${consulta.isFetching ? ' rrhh-resumen--actualizando' : ''}`}>
      <header className="rrhh-resumen__cabecera">
        <p className="rrhh-resumen__miga">RRHH · Gerencia</p>
        <h1 className="rrhh-resumen__titulo">Activación por área</h1>
        <p className="rrhh-resumen__subtitulo">
          Participación de los {actual.habilitados} colaboradores habilitados en la plataforma
        </p>
      </header>

      {/* ── Tarjetas ── */}
      <section className="rrhh-resumen__tarjetas">
        <TarjetaIndicador
          titulo="Activación"
          ayuda="Colaboradores habilitados que completaron al menos una píldora (de su reto o suelta) en el periodo. El objetivo se configura por empresa."
          valor={actual.pct}
          formato="porcentaje"
          conBarra
          detalle={detalleActivacion}
          valorAnterior={anterior?.pct}
        />
        <TarjetaIndicador
          titulo="Finalización de retos"
          ayuda="Retos completados (todas sus píldoras dentro de su mes) sobre los retos iniciados en el periodo. Los retos del mes en curso cuentan como iniciados."
          valor={actual.finalizacion.finalizacion_pct}
          formato="porcentaje"
          conBarra
          detalle={`${actual.finalizacion.retos_completados} de ${actual.finalizacion.retos_iniciados} retos iniciados`}
          valorAnterior={anterior?.finalizacion.finalizacion_pct}
        />
                {datosScores && datosScores.empresa.evolucion_pts !== null ? (
          <TarjetaIndicador
            titulo="Evolución del score (pts)"
            ayuda="Diferencia entre el score medio de la empresa al final y al inicio del periodo elegido."
            valor={datosScores.empresa.evolucion_pts}
            formato="decimal"
            detalle={`De ${textoScore(datosScores.empresa.score_inicio)} a ${textoScore(datosScores.empresa.score)} en el periodo`}
          />
        ) : (
          <TarjetaPendiente
            titulo="Evolución del score (pts)"
            mensaje={
              scores.isPending
                ? 'Calculando…'
                : scores.isError
                  ? 'No se pudo calcular el score.'
                  : datosScores && datosScores.empresa.score !== null
                    ? `Al inicio del periodo había ${datosScores.empresa.evaluados_inicio} evaluados (mínimo ${datosScores.umbral_n}). Elige un periodo que empiece más tarde para poder comparar.`
                    : mensajeSinScore(datosScores?.empresa.evaluados ?? 0, datosScores?.umbral_n ?? 5)
            }
          />
        )}
        {datosScores ? (
          <TarjetaIndicador
            titulo="Celdas sobre el umbral"
            ayuda="Combinaciones departamento × habilidad del mapa de calor con suficientes evaluados para mostrar su score sin comprometer la privacidad."
            valor={datosScores.celdas_sobre_umbral.pct}
            formato="porcentaje"
            conBarra
            detalle={`${datosScores.celdas_sobre_umbral.sobre_umbral} de ${datosScores.celdas_sobre_umbral.total} combinaciones con ${datosScores.umbral_n} o más evaluados`}
          />
        ) : (
          <TarjetaPendiente
            titulo="Celdas sobre el umbral"
            mensaje={scores.isError ? 'No se pudo calcular el score.' : 'Calculando…'}
          />
        )}
      </section>

      {/* ── Activación por área ── */}
      <section className="rrhh-resumen__panel">
        <header className="rrhh-resumen__panel-cabecera">
          <h2>Activación por área</h2>
          <p>
            % de colaboradores habilitados de cada departamento que completaron al menos una píldora en
            el periodo. La línea discontinua marca el objetivo ({textoPct(objetivo)}).
          </p>
        </header>

        {opcionesAreas ? (
          <Grafico
            opciones={opcionesAreas}
            alto={60 + areas.length * 44}
            descripcion={`Gráfico de barras: activación de cada departamento frente al objetivo del ${textoPct(objetivo)}`}
          />
        ) : (
          <p className="rrhh-resumen__vacio">No hay colaboradores habilitados en ningún departamento.</p>
        )}

        {areas.length > 0 && (
          <details className="activacion__tabla-datos">
            <summary>Ver datos en tabla</summary>
            <table>
              <thead>
                <tr>
                  <th>Departamento</th>
                  <th>Activados</th>
                  <th>Habilitados</th>
                  <th>Activación</th>
                  {anterior && <th>Periodo de comparación</th>}
                </tr>
              </thead>
              <tbody>
                {areas.map((a) => (
                  <tr key={a.departamento_id ?? 'sin-departamento'}>
                    <td>{a.departamento}</td>
                    <td>{a.actual.activados}</td>
                    <td>{a.actual.habilitados}</td>
                    <td>{textoPct(a.actual.pct)}</td>
                    {anterior && <td>{textoPct(a.comparacion?.pct)}</td>}
                  </tr>
                ))}
              </tbody>
            </table>
          </details>
        )}
      </section>

            {/* ── Evolución del score medio ── */}
      <section className="rrhh-resumen__panel">
        <header className="rrhh-resumen__panel-cabecera">
          <h2>Evolución del score medio de la empresa</h2>
          <p>
            Un punto por {datosScores?.frecuencia === 'dia' ? 'día laboral' : datosScores?.frecuencia === 'mes' ? 'mes' : 'semana'}.
            Cambia la frecuencia en la barra de filtros. Los huecos son tramos sin datos suficientes.
          </p>
        </header>

        {scores.isPending ? (
          <p className="rrhh-resumen__vacio">⏳ Calculando los scores…</p>
        ) : opcionesEvolucion ? (
          <Grafico
            opciones={opcionesEvolucion}
            alto={260}
            descripcion="Gráfico de líneas: evolución del score medio de la empresa en el periodo"
          />
        ) : (
          <p className="rrhh-resumen__vacio">
            Todavía no hay datos suficientes para mostrar la evolución del score.
          </p>
        )}
      </section>
    </div>
  );
}