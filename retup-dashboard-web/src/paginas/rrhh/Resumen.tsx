// ═══════════════════════════════════════════════════════════════════
// RRHH · GERENCIA · RESUMEN
// Indicadores agregados de toda la empresa (nunca datos individuales).
// Responde al periodo y a "comparar con" de la barra de filtros.
// Inscritos y retos del mes se calculan respecto a HOY.
// Las tarjetas de score se activarán cuando exista el cálculo del score.
// ═══════════════════════════════════════════════════════════════════
import { useMemo } from 'react';
import { useQuery } from '@tanstack/react-query';
import type { EChartsCoreOption } from 'echarts/core';
import { apiFetch } from '../../api/cliente';
import { rangoComparacion, useFiltros } from '../../filtros/filtros';
import TarjetaIndicador from '../../componentes/TarjetaIndicador';
import DatoCabecera from '../../componentes/DatoCabecera';
import Grafico from '../../graficos/Grafico';
import { BASE_GRAFICO, COLOR, EJE_DISCRETO } from '../../graficos/tema';
import { mensajeSinScore, TarjetaPendiente, textoScore, useScoresRrhh } from './scores';
import './Resumen.css';

// ───────────── Forma de la respuesta del backend ─────────────
interface KpisRrhh {
  habilitados: number;
  con_reto: number;
  activos: number;
  activos_pct: number | null;
  retos_iniciados: number;
  retos_completados: number;
  finalizacion_pct: number | null;
}

interface RetoMes {
  reto_id: string;
  titulo: string;
  personas: number;
  voluntarios: number;
  asignados: number;
}

interface DatosResumen {
  actual: KpisRrhh;
  comparacion: KpisRrhh | null;
  proximo_mes: { anio: number; mes: number; voluntarios: number; inscritos: number; habilitados: number };
  retos_mes: { anio: number; mes: number; inscritos: number; retos: RetoMes[] };
}

interface RespuestaResumen {
  success: boolean;
  datos: DatosResumen;
}

const MESES = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

/** Índigo claro para "asignados por el sistema" (misma familia que el índigo de marca) */
const INDIGO_CLARO = '#A9A7D3';

function porcentaje(parte: number, total: number): number {
  return total > 0 ? Math.round((100 * parte) / total) : 0;
}

export default function Resumen() {
  const { desde, hasta, comparacion } = useFiltros();
  const comparado = rangoComparacion({ desde, hasta }, comparacion);

  // Los filtros forman parte de la "clave": si cambian, se vuelven a pedir los datos
  const consulta = useQuery({
    queryKey: ['rrhh', 'resumen', desde, hasta, comparado?.desde ?? null, comparado?.hasta ?? null],
    queryFn: () => {
      const parametros = new URLSearchParams({ desde, hasta });
      if (comparado) {
        parametros.set('comp_desde', comparado.desde);
        parametros.set('comp_hasta', comparado.hasta);
      }
      return apiFetch<RespuestaResumen>(`/dashboard/rrhh/resumen?${parametros}`);
    },
    placeholderData: (anteriores) => anteriores,
  });

   const datos = consulta.data?.datos;

  // Scores (se piden aparte porque su cálculo es más lento)
  const scores = useScoresRrhh();
  const datosScores = scores.data?.datos;

  // Avance por habilidad: inicio del periodo (índigo claro) frente a actual (índigo)
  const opcionesAvance = useMemo<EChartsCoreOption | null>(() => {
    const visibles = (datosScores?.habilidades ?? []).filter((h) => h.score !== null);
    if (visibles.length === 0) return null;
    // Barras horizontales: el primer dato va abajo -> de menor a mayor para que la mejor quede arriba
    const filas = [...visibles].sort((a, b) => (a.score ?? 0) - (b.score ?? 0));
    const hayInicio = filas.some((h) => h.score_inicio !== null);

    const series: Record<string, unknown>[] = [];
    if (hayInicio) {
      series.push({
        name: 'Inicio del periodo',
        type: 'bar',
        barMaxWidth: 14,
        itemStyle: { color: INDIGO_CLARO, borderRadius: [0, 3, 3, 0] },
        data: filas.map((h) => h.score_inicio),
      });
    }
    series.push({
      name: 'Actual',
      type: 'bar',
      barMaxWidth: 14,
      itemStyle: { color: COLOR.indigo, borderRadius: [0, 3, 3, 0] },
      data: filas.map((h) => h.score),
      label: {
        show: true,
        position: 'right',
        color: COLOR.texto,
        fontSize: 12,
        formatter: (p: { value: number }) => textoScore(p.value),
      },
    });

    return {
      ...BASE_GRAFICO,
      grid: { left: 8, right: 48, top: hayInicio ? 36 : 8, bottom: 8, containLabel: true },
      ...(hayInicio
        ? {
            legend: {
              top: 0,
              left: 0,
              itemWidth: 12,
              itemHeight: 12,
              textStyle: { color: COLOR.textoSuave, fontSize: 12 },
              data: ['Inicio del periodo', 'Actual'],
            },
          }
        : {}),
      tooltip: {
        ...BASE_GRAFICO.tooltip,
        trigger: 'axis',
        axisPointer: { type: 'shadow', shadowStyle: { color: 'rgba(46,42,114,0.06)' } },
        formatter: (params: { dataIndex: number }[]) => {
          const h = filas[params[0].dataIndex];
          let texto = `<b>${h.habilidad}</b><br/>Actual: <b>${textoScore(h.score)}</b> (${h.evaluados} evaluados)`;
          if (h.score_inicio !== null) {
            const diferencia = Math.round((h.score! - h.score_inicio) * 10) / 10;
            texto += `<br/>Inicio del periodo: ${textoScore(h.score_inicio)}`;
            texto += `<br/>Avance: ${diferencia > 0 ? '+' : ''}${textoScore(diferencia)} pts`;
          }
          return texto;
        },
      },
      xAxis: { type: 'value', min: 0, max: 100, interval: 25, ...EJE_DISCRETO },
      yAxis: {
        type: 'category',
        data: filas.map((h) => h.habilidad),
        ...EJE_DISCRETO,
        splitLine: { show: false },
        axisLabel: { ...EJE_DISCRETO.axisLabel, color: COLOR.texto, fontSize: 13 },
      },
      series,
    };
  }, [datosScores]);

  // Gráfico de retos más elegidos (barras horizontales apiladas)
  const opcionesRetos = useMemo<EChartsCoreOption | null>(() => {
    if (!datos || datos.retos_mes.retos.length === 0) return null;
    // En barras horizontales el primer dato va abajo: se invierte para que el más elegido quede arriba
    const retos = [...datos.retos_mes.retos].reverse();
    const inscritos = datos.retos_mes.inscritos;

    return {
      ...BASE_GRAFICO,
      grid: { left: 8, right: 72, top: 36, bottom: 8, containLabel: true },
      legend: {
        top: 0,
        left: 0,
        itemWidth: 12,
        itemHeight: 12,
        textStyle: { color: COLOR.textoSuave, fontSize: 12 },
        data: ['Elegido voluntariamente', 'Asignado por el sistema'],
      },
      tooltip: {
        ...BASE_GRAFICO.tooltip,
        trigger: 'axis',
        axisPointer: { type: 'shadow', shadowStyle: { color: 'rgba(46,42,114,0.06)' } },
        formatter: (params: { dataIndex: number }[]) => {
          const reto = retos[params[0].dataIndex];
          return (
            `<b>${reto.titulo}</b><br/>` +
            `${reto.personas} ${reto.personas === 1 ? 'persona' : 'personas'} ` +
            `(${porcentaje(reto.personas, inscritos)} % de los inscritos)<br/>` +
            `${reto.voluntarios} voluntarios · ${reto.asignados} asignados`
          );
        },
      },
      xAxis: { type: 'value', minInterval: 1, ...EJE_DISCRETO },
      yAxis: {
        type: 'category',
        data: retos.map((r) => r.titulo),
        ...EJE_DISCRETO,
        splitLine: { show: false },
        axisLabel: { ...EJE_DISCRETO.axisLabel, color: COLOR.texto, fontSize: 13 },
      },
      series: [
        {
          name: 'Elegido voluntariamente',
          type: 'bar',
          stack: 'total',
          barMaxWidth: 22,
          itemStyle: { color: COLOR.indigo },
          data: retos.map((r) => r.voluntarios),
        },
        {
          name: 'Asignado por el sistema',
          type: 'bar',
          stack: 'total',
          barMaxWidth: 22,
          itemStyle: { color: INDIGO_CLARO, borderRadius: [0, 4, 4, 0] },
          data: retos.map((r) => r.asignados),
          // Al final de cada barra: personas y % sobre los inscritos
          label: {
            show: true,
            position: 'right',
            color: COLOR.texto,
            fontSize: 12,
            formatter: (p: { dataIndex: number }) => {
              const reto = retos[p.dataIndex];
              return `${reto.personas} · ${porcentaje(reto.personas, inscritos)} %`;
            },
          },
        },
      ],
    };
  }, [datos]);

  // ───────────── Estados: cargando / error ─────────────
  if (consulta.isPending) {
    return <p className="rrhh-resumen__estado">⏳ Calculando los indicadores de la empresa…</p>;
  }
  if (consulta.isError || !datos) {
    return (
      <p className="rrhh-resumen__estado rrhh-resumen__estado--error">
        ❌ {consulta.error?.message ?? 'No se pudieron cargar los datos'}
      </p>
    );
  }

  const { actual, proximo_mes: proximo, retos_mes: retosMes } = datos;
  const anterior = datos.comparacion;
  const nombreMesActual = `${MESES[retosMes.mes - 1]} ${retosMes.anio}`;

  return (
    <div className={`rrhh-resumen${consulta.isFetching ? ' rrhh-resumen--actualizando' : ''}`}>
            {/* ── Cabecera: una sola banda con el título y 2 datos ── */}
      <header className="banda-cabecera">
        <div>
          <p className="rrhh-resumen__miga">RRHH · Gerencia</p>
          <h1 className="rrhh-resumen__titulo">Resumen</h1>
          <p className="rrhh-resumen__subtitulo">
            {actual.habilitados} {actual.habilitados === 1 ? 'colaborador habilitado' : 'colaboradores habilitados'}{' '}
            en la empresa
          </p>
        </div>

        <div className="datos-cabecera">
          <DatoCabecera
            icono="meta"
            titulo="Retos finalizados"
            valor={actual.retos_completados}
            total={actual.retos_iniciados}
            detalle={
              actual.finalizacion_pct === null
                ? 'sin retos iniciados en el periodo'
                : `${String(actual.finalizacion_pct).replace('.', ',')} % de los iniciados en el periodo`
            }
            ayuda="Retos completados (todas sus píldoras dentro de su mes) sobre los retos iniciados (al menos una píldora) en el periodo. Los retos del mes en curso cuentan como iniciados, por eso el valor sube al terminar el mes."
          />
          <DatoCabecera
            icono="calendario"
            titulo="Inscritos próximo mes"
            valor={proximo.voluntarios}
            total={proximo.habilitados}
            detalle={`para ${MESES[proximo.mes - 1]} ${proximo.anio}`}
            ayuda="Colaboradores que ya eligieron voluntariamente su reto para el mes siguiente. Se calcula respecto a hoy, no al periodo filtrado."
          />
        </div>
      </header>

      {/* ── Tarjetas ── */}
      <section className="rrhh-resumen__tarjetas rrhh-resumen__tarjetas--dos">
        <TarjetaIndicador
          titulo="Colaboradores activos"
          ayuda="Colaboradores con reto que completaron al menos una píldora de su reto en el periodo, sobre el total de colaboradores habilitados (no de baja ni bloqueados)."
          valor={actual.activos_pct}
          formato="porcentaje"
          conBarra
          detalle={`${actual.activos} de ${actual.habilitados} colaboradores`}
          valorAnterior={anterior?.activos_pct}
        />
     
                {datosScores && datosScores.empresa.score !== null ? (
                   <TarjetaIndicador
            titulo="Score medio de la empresa"
            ayuda="Cada colaborador evaluado tiene un score de 0 a 100 (media de feedback, asistencia y práctica, igual que en la app). Se suman los scores de todos y se divide entre el número de evaluados. Cada persona pesa lo mismo."
            valor={datosScores.empresa.score}
            formato="decimal"
            detalle={`${Math.round((datosScores.empresa.score ?? 0) * datosScores.empresa.evaluados)} pts ÷ ${datosScores.empresa.evaluados} colaboradores evaluados (escala 0–100)`}
          />
        ) : (
          <TarjetaPendiente
            titulo="Score medio de la empresa"
            mensaje={
              scores.isPending
                ? 'Calculando…'
                : scores.isError
                  ? 'No se pudo calcular el score.'
                  : mensajeSinScore(datosScores?.empresa.evaluados ?? 0, datosScores?.umbral_n ?? 5)
            }
          />
        )}
             </section>

      {/* ── Retos más elegidos ── */}
      <section className="rrhh-resumen__panel">
        <header className="rrhh-resumen__panel-cabecera">
          <h2>Retos más elegidos este mes</h2>
          <p>
            {retosMes.inscritos} {retosMes.inscritos === 1 ? 'persona inscrita' : 'personas inscritas'} en{' '}
            {nombreMesActual}. El % es sobre las personas inscritas (una persona puede tener más de un reto).
          </p>
        </header>
        {opcionesRetos ? (
          <Grafico
            opciones={opcionesRetos}
            alto={70 + retosMes.retos.length * 44}
            descripcion={`Gráfico de barras: personas inscritas en cada reto en ${nombreMesActual}, separando voluntarios y asignados`}
          />
        ) : (
          <p className="rrhh-resumen__vacio">Nadie se ha inscrito todavía a un reto este mes.</p>
        )}
      </section>

           {/* ── Avance por habilidad ── */}
      <section className="rrhh-resumen__panel">
        <header className="rrhh-resumen__panel-cabecera">
          <h2>Avance por habilidad</h2>
          <p>
            Score medio de cada habilidad al final del periodo y, si había datos suficientes, al
            inicio del periodo.
          </p>
        </header>

        {scores.isPending ? (
          <p className="rrhh-resumen__vacio">⏳ Calculando los scores…</p>
        ) : opcionesAvance ? (
          <Grafico
            opciones={opcionesAvance}
            alto={60 + (datosScores?.habilidades.filter((h) => h.score !== null).length ?? 0) * 40}
            descripcion="Gráfico de barras: score medio de cada habilidad al inicio y al final del periodo"
          />
        ) : (
          <p className="rrhh-resumen__vacio">
            Todavía no hay ninguna habilidad con datos suficientes para mostrarse.
          </p>
        )}

        {datosScores && datosScores.habilidades.some((h) => h.score === null) && (
          <p className="rrhh-resumen__nota">
            Sin datos suficientes (menos de {datosScores.umbral_n} evaluados):{' '}
            {datosScores.habilidades
              .filter((h) => h.score === null)
              .map((h) => `${h.habilidad} (${h.evaluados})`)
              .join(' · ')}
          </p>
        )}
      </section>
    </div>
  );
}