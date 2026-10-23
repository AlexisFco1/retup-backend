// ═══════════════════════════════════════════════════════════════════
// RRHH · GERENCIA · MAPA DE BRECHAS (radar)
// - Referencia: el departamento con mejor score medio (verde).
// - Se comparan las 2 áreas con más brecha frente a la referencia.
//   Si no hay otras áreas con datos, se compara con la media de la empresa.
// - Oportunidades generadas con reglas fijas (ALTA / MEDIA / BAJA).
// Usa el periodo de la barra de filtros (score a fecha de fin del periodo).
// ═══════════════════════════════════════════════════════════════════
import { useMemo } from 'react';
import type { EChartsCoreOption } from 'echarts/core';
import DatoCabecera from '../../componentes/DatoCabecera';
import Grafico from '../../graficos/Grafico';
import { BASE_GRAFICO, COLOR } from '../../graficos/tema';
import { textoScore, useScoresRrhh } from './scores';
import type { DatosScores } from './scores';
import './Resumen.css';
import './MapaCalor.css';
import './MapaBrechas.css';

const COLOR_REFERENCIA = '#10B981'; // verde
const COLORES_AREAS = ['#D64545', '#E8A317']; // rojo, naranja
const COLOR_EMPRESA = '#8E89C9'; // índigo claro (media de la empresa)

type Nivel = 'alta' | 'media' | 'baja';

interface Oportunidad {
  nivel: Nivel;
  titulo: string;
  detalle: string;
  orden: number; // para ordenar dentro del mismo nivel
}

interface SerieRadar {
  nombre: string;
  color: string;
  valores: (number | null)[];
  discontinua?: boolean;
}

const TEXTO_NIVEL: Record<Nivel, string> = { alta: 'ALTA', media: 'MEDIA', baja: 'BAJA' };
const PESO_NIVEL: Record<Nivel, number> = { alta: 0, media: 1, baja: 2 };

/** Clave de un departamento ("Sin departamento" tiene id null) */
const claveDep = (id: string | null) => id ?? 'sin-departamento';

/** Calcula referencia, áreas a comparar, series del radar y oportunidades */
function analizar(d: DatosScores) {
  const habilidades = d.habilidades;

  // Score de cada departamento en cada habilidad (solo celdas sobre el umbral)
  const scores = new Map<string, Map<string, number>>();
  for (const c of d.celdas) {
    if (c.score === null) continue;
    const k = claveDep(c.departamento_id);
    if (!scores.has(k)) scores.set(k, new Map());
    scores.get(k)!.set(c.reto_id, c.score);
  }

  // Departamentos con al menos una habilidad con datos
  const deps = d.departamentos
    .filter((dep) => scores.has(claveDep(dep.id)))
    .map((dep) => {
      const s = scores.get(claveDep(dep.id))!;
      const valores = [...s.values()];
      return {
        id: claveDep(dep.id),
        nombre: dep.nombre,
        s,
        media: valores.reduce((a, b) => a + b, 0) / valores.length,
      };
    });
  if (deps.length === 0) return null;

  // Referencia: el área con mejor score medio
  const referencia = deps.reduce((a, b) => (b.media > a.media ? b : a));

  // Resto de áreas, ordenadas de más a menos brecha frente a la referencia
  const otros = deps
    .filter((x) => x.id !== referencia.id)
    .map((x) => {
      let brecha = 0;
      for (const [reto, valor] of x.s) {
        const r = referencia.s.get(reto);
        if (r !== undefined && r > valor) brecha += r - valor;
      }
      return { ...x, brecha };
    })
    .sort((a, b) => b.brecha - a.brecha);
  const comparados = otros.slice(0, 2);

  // Series del radar
  const series: SerieRadar[] = [
    ...comparados.map((x, i) => ({
      nombre: x.nombre,
      color: COLORES_AREAS[i],
      valores: habilidades.map((h) => x.s.get(h.reto_id) ?? null),
    })),
    {
      nombre: `${referencia.nombre} (referencia)`,
      color: COLOR_REFERENCIA,
      valores: habilidades.map((h) => referencia.s.get(h.reto_id) ?? null),
    },
  ];
  if (comparados.length === 0) {
    series.push({
      nombre: 'Media de la empresa',
      color: COLOR_EMPRESA,
      discontinua: true,
      valores: habilidades.map((h) => h.score),
    });
  }

  // ── Oportunidades ──
  const medio = (d.escala.bajo + d.escala.alto) / 2;
  const oportunidades: Oportunidad[] = [];
  const marcadas = new Set<string>();

  // 1) Brechas frente a la referencia
  for (const x of otros) {
    for (const h of habilidades) {
      const v = x.s.get(h.reto_id);
      const r = referencia.s.get(h.reto_id);
      if (v === undefined || r === undefined || r <= 0) continue;
      const pct = Math.round((100 * (r - v)) / r);
      if (pct >= 15) {
        oportunidades.push({
          nivel: pct >= 30 ? 'alta' : 'media',
          titulo: `${x.nombre} vs. ${referencia.nombre}`,
          detalle: `${h.habilidad}: brecha del ${pct} % (${textoScore(v)} vs ${textoScore(r)})`,
          orden: pct,
        });
        marcadas.add(`${x.id}|${h.reto_id}`);
      }
    }
  }

  // 2) Scores bajos o medios, y fortalezas
  for (const x of deps) {
    for (const h of habilidades) {
      const v = x.s.get(h.reto_id);
      if (v === undefined || marcadas.has(`${x.id}|${h.reto_id}`)) continue;
      if (v < d.escala.bajo) {
        oportunidades.push({ nivel: 'alta', titulo: x.nombre, detalle: `${h.habilidad}: ${textoScore(v)} / 100`, orden: 100 - v });
      } else if (v < medio) {
        oportunidades.push({ nivel: 'media', titulo: x.nombre, detalle: `${h.habilidad}: ${textoScore(v)} / 100`, orden: 100 - v });
      } else if (v >= d.escala.alto) {
        oportunidades.push({
          nivel: 'baja',
          titulo: x.nombre,
          detalle: `${h.habilidad}: ${textoScore(v)} / 100, práctica a replicar`,
          orden: v,
        });
      }
    }
  }

  oportunidades.sort((a, b) => PESO_NIVEL[a.nivel] - PESO_NIVEL[b.nivel] || b.orden - a.orden);

  // Habilidades sin datos suficientes en las áreas dibujadas
  const sinDatos = series
    .filter((s) => !s.discontinua)
    .flatMap((s) =>
      habilidades
        .filter((_, i) => s.valores[i] === null)
        .map((h) => `${s.nombre.replace(' (referencia)', '')} · ${h.habilidad}`),
    );

  return {
    referencia: referencia.nombre,
    comparados: comparados.map((c) => c.nombre),
    series,
    oportunidades: oportunidades.slice(0, 6),
    sinDatos,
    areasConDatos: deps.length,
  };
}

export default function MapaBrechas() {
  const scores = useScoresRrhh();
  const datos = scores.data?.datos;

  const analisis = useMemo(() => (datos ? analizar(datos) : null), [datos]);

  // Opciones del radar
  const opciones = useMemo<EChartsCoreOption | null>(() => {
    if (!datos || !analisis) return null;
    const habilidades = datos.habilidades;
    const umbral = datos.umbral_n;

    return {
      ...BASE_GRAFICO,
      legend: {
        bottom: 0,
        icon: 'roundRect',
        itemWidth: 16,
        itemHeight: 4,
        textStyle: { color: COLOR.textoSuave, fontSize: 12 },
        data: analisis.series.map((s) => s.nombre),
      },
      tooltip: {
        ...BASE_GRAFICO.tooltip,
        trigger: 'item',
        formatter: (p: { name: string; value: (number | string)[] }) =>
          `<b>${p.name}</b><br/>` +
          habilidades
            .map((h, i) => {
              const v = p.value[i];
              return `${h.habilidad}: <b>${typeof v === 'number' ? textoScore(v) : `n<${umbral}`}</b>`;
            })
            .join('<br/>'),
      },
      radar: {
        center: ['50%', '47%'],
        radius: '64%',
        splitNumber: 4,
        indicator: habilidades.map((h) => ({ name: h.habilidad, min: 0, max: 100 })),
        axisName: { color: COLOR.texto, fontSize: 12 },
        splitLine: { lineStyle: { color: COLOR.borde } },
        splitArea: { show: false },
        axisLine: { lineStyle: { color: COLOR.borde } },
      },
      series: [
        {
          type: 'radar',
          symbol: 'circle',
          symbolSize: 5,
          data: analisis.series.map((s) => ({
            name: s.nombre,
            value: s.valores.map((v) => (v === null ? '-' : v)),
            lineStyle: { color: s.color, width: 2.5, type: s.discontinua ? 'dashed' : 'solid' },
            itemStyle: { color: s.color },
            areaStyle: { color: s.color, opacity: s.discontinua ? 0 : 0.06 },
          })),
        },
      ],
    };
  }, [datos, analisis]);

  // ───────────── Estados: cargando / error ─────────────
  if (scores.isPending) {
    return <p className="rrhh-resumen__estado">⏳ Calculando el mapa de brechas…</p>;
  }
  if (scores.isError || !datos) {
    return (
      <p className="rrhh-resumen__estado rrhh-resumen__estado--error">
        ❌ {scores.error?.message ?? 'No se pudieron cargar los datos'}
      </p>
    );
  }

  const umbral = datos.umbral_n;

  return (
    <div className={`rrhh-resumen${scores.isFetching ? ' rrhh-resumen--actualizando' : ''}`}>
      {/* ── Cabecera ── */}
      <header className="banda-cabecera">
        <div>
          <p className="rrhh-resumen__miga">RRHH · Gerencia</p>
          <h1 className="rrhh-resumen__titulo">Mapa de brechas</h1>
          <p className="rrhh-resumen__subtitulo">
            Score por habilidad (0–100): cuanto más hundido el radar, mayor la oportunidad de mejora
          </p>
        </div>
        <div className="datos-cabecera">
          <DatoCabecera
            icono="meta"
            titulo="Áreas con datos"
            valor={analisis?.areasConDatos ?? 0}
            total={datos.departamentos.length}
            detalle={`con alguna habilidad de ${umbral} o más evaluados`}
            ayuda={`Departamentos con al menos una habilidad con ${umbral} o más colaboradores evaluados. Solo esas áreas pueden aparecer en el radar.`}
          />
        </div>
      </header>

      <div className="brechas__cuerpo">
        {/* ── Radar ── */}
        <section className="rrhh-resumen__panel">
          <header className="rrhh-resumen__panel-cabecera">
            <h2>Radar por departamento</h2>
            <p>
              {!analisis
                ? 'Todavía no hay áreas con datos suficientes.'
                : analisis.comparados.length > 0
                  ? `${analisis.comparados.length === 1 ? 'El área' : `Las ${analisis.comparados.length} áreas`} con más brechas frente a ${analisis.referencia}, el área de referencia (la de mejor score medio).`
                  : `${analisis.referencia} es la única área con datos suficientes: se compara con la media de la empresa (línea discontinua).`}
            </p>
          </header>

          {opciones ? (
            <Grafico
              opciones={opciones}
              alto={430}
              descripcion="Gráfico de radar: score de cada habilidad en las áreas comparadas y en el área de referencia"
            />
          ) : (
            <p className="rrhh-resumen__vacio">
              Cuando algún departamento tenga {umbral} o más colaboradores evaluados en una habilidad,
              aparecerá aquí.
            </p>
          )}

          {analisis && analisis.sinDatos.length > 0 && (
            <p className="rrhh-resumen__nota">
              Sin datos suficientes (n&lt;{umbral}), no se dibujan: {analisis.sinDatos.join(' · ')}
            </p>
          )}
        </section>

        {/* ── Oportunidades + cómo leerlo ── */}
        <div className="brechas__lateral">
          <section className="rrhh-resumen__panel">
            <header className="rrhh-resumen__panel-cabecera">
              <h2>Oportunidades detectadas automáticamente</h2>
              <p>
                ALTA: brecha ≥ 30 % o score &lt; {datos.escala.bajo} · MEDIA: brecha ≥ 15 % o score
                &lt; {textoScore((datos.escala.bajo + datos.escala.alto) / 2)} · BAJA: score ≥{' '}
                {datos.escala.alto} (práctica a replicar)
              </p>
            </header>

            {!analisis || analisis.oportunidades.length === 0 ? (
              <p className="rrhh-resumen__vacio">No se detectan oportunidades con los datos actuales.</p>
            ) : (
              <ul className="brechas__lista">
                {analisis.oportunidades.map((o) => (
                  <li key={`${o.titulo}-${o.detalle}`} className="brechas__oportunidad">
                    <span className={`brechas__nivel brechas__nivel--${o.nivel}`}>{TEXTO_NIVEL[o.nivel]}</span>
                    <div>
                      <strong>{o.titulo}</strong>
                      <span className="brechas__detalle">{o.detalle}</span>
                    </div>
                  </li>
                ))}
              </ul>
            )}
          </section>

          <section className="mapa-calor__nota mapa-calor__nota--leer">
            <h3>Cómo leerlo</h3>
            <p>
              Cada eje es una habilidad: el centro es 0 y el borde 100. La línea verde es el área de
              referencia. Donde la línea de otra área se hunde hacia el centro hay una brecha: ahí
              conviene sugerir el reto correspondiente.
            </p>
          </section>
        </div>
      </div>
    </div>
  );
}