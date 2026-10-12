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
import Grafico from '../../graficos/Grafico';
import { BASE_GRAFICO, COLOR, EJE_DISCRETO } from '../../graficos/tema';
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
      <header className="rrhh-resumen__cabecera">
        <p className="rrhh-resumen__miga">RRHH · Gerencia</p>
        <h1 className="rrhh-resumen__titulo">Resumen</h1>
        <p className="rrhh-resumen__subtitulo">
          {actual.habilitados} {actual.habilitados === 1 ? 'colaborador habilitado' : 'colaboradores habilitados'}{' '}
          en la empresa
        </p>
      </header>

      {/* ── Tarjetas ── */}
      <section className="rrhh-resumen__tarjetas">
        <TarjetaIndicador
          titulo="Colaboradores activos"
          ayuda="Colaboradores con reto que completaron al menos una píldora de su reto en el periodo, sobre el total de colaboradores habilitados (no de baja ni bloqueados)."
          valor={actual.activos_pct}
          formato="porcentaje"
          conBarra
          detalle={`${actual.activos} de ${actual.habilitados} colaboradores`}
          valorAnterior={anterior?.activos_pct}
        />
        <TarjetaIndicador
          titulo="Finalización de retos"
          ayuda="Retos completados (todas sus píldoras dentro de su mes) sobre los retos iniciados (al menos una píldora) en el periodo. Los retos del mes en curso cuentan como iniciados, por eso el valor sube al terminar el mes."
          valor={actual.finalizacion_pct}
          formato="porcentaje"
          conBarra
          detalle={`${actual.retos_completados} de ${actual.retos_iniciados} retos iniciados`}
          valorAnterior={anterior?.finalizacion_pct}
        />
        <article className="rrhh-resumen__reservada">
          <h3>Score medio de la empresa</h3>
          <p className="rrhh-resumen__reservada-valor">—</p>
          <p>Disponible pronto: se activará cuando esté listo el cálculo del score de habilidades.</p>
        </article>
        <TarjetaIndicador
          titulo="Inscritos próximo mes"
          ayuda="Colaboradores que ya eligieron voluntariamente su reto para el mes siguiente. Se calcula respecto a hoy, no al periodo filtrado."
          valor={proximo.voluntarios}
          formato="numero"
          detalle={`de ${proximo.habilitados} habilitados para ${MESES[proximo.mes - 1]} ${proximo.anio}`}
        />
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

      {/* ── Avance por habilidad (reservado para el score) ── */}
      <section className="rrhh-resumen__panel rrhh-resumen__panel--reservado">
        <header className="rrhh-resumen__panel-cabecera">
          <h2>Avance por habilidad</h2>
          <p>Score inicial frente a score actual en cada habilidad.</p>
        </header>
        <p className="rrhh-resumen__vacio">
          Se mostrará cuando esté listo el cálculo del score de habilidades.
        </p>
      </section>
    </div>
  );
}