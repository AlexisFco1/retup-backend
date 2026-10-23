// ═══════════════════════════════════════════════════════════════════
// RRHH · GERENCIA · MAPA DE CALOR
// Score medio (0–100) por departamento y habilidad (= reto).
// - Morado más oscuro = score más alto (escala de la empresa, 40–75).
// - Celdas con menos evaluados que el umbral: "n<5" (privacidad).
// - Notas laterales generadas con frases predefinidas a partir de los datos.
// Usa el periodo de la barra de filtros (score a fecha de fin del periodo).
// ═══════════════════════════════════════════════════════════════════
import { useMemo } from 'react';
import DatoCabecera from '../../componentes/DatoCabecera';
import { textoScore, useScoresRrhh } from './scores';
import type { DatosScores } from './scores';
import './Resumen.css';
import './MapaCalor.css';

// Escala de color: lila muy claro (bajo) → morado de marca (alto)
const COLOR_BAJO = [241, 236, 251];
const COLOR_ALTO = [114, 9, 183];

function colorCelda(score: number, bajo: number, alto: number) {
  const t = Math.max(0, Math.min(1, (score - bajo) / (alto - bajo || 1)));
  const [r, g, b] = COLOR_BAJO.map((c, i) => Math.round(c + (COLOR_ALTO[i] - c) * t));
  return { fondo: `rgb(${r}, ${g}, ${b})`, texto: t > 0.5 ? '#ffffff' : '#0E0F17' };
}

/** Clave de un departamento ("Sin departamento" tiene id null) */
const claveDep = (id: string | null) => id ?? 'sin-departamento';

const redondear = (valor: number) => Math.round(valor * 10) / 10;

interface CeldaVisible {
  dep: string;
  hab: string;
  score: number;
}

/** Frases de "Brechas principales" y "Fortalezas y umbral" a partir de los datos */
function generarResumenes(d: DatosScores): { brechas: string[]; fortalezas: string[] } {
  const nombreDep = new Map(d.departamentos.map((x) => [claveDep(x.id), x.nombre]));
  const nombreHab = new Map(d.habilidades.map((h) => [h.reto_id, h.habilidad]));

  const visibles: CeldaVisible[] = d.celdas
    .filter((c) => c.score !== null)
    .map((c) => ({
      dep: nombreDep.get(claveDep(c.departamento_id)) ?? 'Sin departamento',
      hab: nombreHab.get(c.reto_id) ?? '',
      score: c.score as number,
    }));

  const brechas: string[] = [];
  const fortalezas: string[] = [];

  if (visibles.length === 0) {
    brechas.push('Todavía no hay celdas con datos suficientes para comparar departamentos.');
  } else {
    // Mayor brecha entre departamentos dentro de una misma habilidad
    let mayor: { hab: string; min: CeldaVisible; max: CeldaVisible; brecha: number } | null = null;
    for (const hab of new Set(visibles.map((v) => v.hab))) {
      const celdas = visibles.filter((v) => v.hab === hab);
      if (celdas.length < 2) continue;
      const min = celdas.reduce((a, b) => (b.score < a.score ? b : a));
      const max = celdas.reduce((a, b) => (b.score > a.score ? b : a));
      const brecha = max.score - min.score;
      if (!mayor || brecha > mayor.brecha) mayor = { hab, min, max, brecha };
    }

    if (mayor && mayor.brecha > 0) {
      brechas.push(
        `${mayor.min.dep} tiene una brecha de ${textoScore(redondear(mayor.brecha))} pts ` +
          `(${Math.round((100 * mayor.brecha) / mayor.max.score)} %) en ${mayor.hab} frente a ` +
          `${mayor.max.dep} (${textoScore(mayor.min.score)} vs ${textoScore(mayor.max.score)}).`,
      );
    } else {
      brechas.push('Aún no hay dos departamentos con datos en la misma habilidad para compararlos.');
    }

    // Punto más bajo de toda la matriz
    const baja = visibles.reduce((a, b) => (b.score < a.score ? b : a));
    brechas.push(
      `El punto más bajo es ${baja.hab} en ${baja.dep} (${textoScore(baja.score)})` +
        `${baja.score < d.escala.bajo ? ', por debajo del nivel bajo' : ''}.`,
    );

    // Punto más alto de toda la matriz
    const alta = visibles.reduce((a, b) => (b.score > a.score ? b : a));
    fortalezas.push(`${alta.dep} lidera en ${alta.hab} (${textoScore(alta.score)}).`);

    // Habilidad más fuerte de la empresa
    const habFuerte = d.habilidades
      .filter((h) => h.score !== null)
      .sort((a, b) => (b.score as number) - (a.score as number))[0];
    if (habFuerte) {
      fortalezas.push(
        `En toda la empresa, la habilidad más fuerte es ${habFuerte.habilidad} (${textoScore(habFuerte.score)}).`,
      );
    }
  }

  // Umbral de privacidad
  const total = d.celdas_sobre_umbral.total;
  const bajoUmbral = total - d.celdas_sobre_umbral.sobre_umbral;
  fortalezas.push(
    bajoUmbral === 0
      ? 'Todas las celdas superan el umbral de privacidad.'
      : `${bajoUmbral} de ${total} celdas no llegan al umbral de ${d.umbral_n} personas.`,
  );

  return { brechas, fortalezas };
}

export default function MapaCalor() {
  const scores = useScoresRrhh();
  const datos = scores.data?.datos;

  // Celdas indexadas por "departamento|habilidad"
  const mapaCeldas = useMemo(
    () => new Map((datos?.celdas ?? []).map((c) => [`${claveDep(c.departamento_id)}|${c.reto_id}`, c])),
    [datos],
  );

  const resumenes = useMemo(() => (datos ? generarResumenes(datos) : null), [datos]);

  // ───────────── Estados: cargando / error ─────────────
  if (scores.isPending) {
    return <p className="rrhh-resumen__estado">⏳ Calculando el mapa de calor…</p>;
  }
  if (scores.isError || !datos) {
    return (
      <p className="rrhh-resumen__estado rrhh-resumen__estado--error">
        ❌ {scores.error?.message ?? 'No se pudieron cargar los datos'}
      </p>
    );
  }

  const { escala, umbral_n: umbral } = datos;
  const sobreUmbral = datos.celdas_sobre_umbral;

  return (
    <div className={`rrhh-resumen${scores.isFetching ? ' rrhh-resumen--actualizando' : ''}`}>
      {/* ── Cabecera ── */}
      <header className="banda-cabecera">
        <div>
          <p className="rrhh-resumen__miga">RRHH · Gerencia</p>
          <h1 className="rrhh-resumen__titulo">Mapa de calor</h1>
          <p className="rrhh-resumen__subtitulo">
            Score promedio (0–100) por departamento y habilidad · solo celdas con {umbral} o más
            colaboradores evaluados
          </p>
        </div>
        <div className="datos-cabecera">
          <DatoCabecera
            icono="meta"
            titulo="Celdas con datos"
            valor={sobreUmbral.sobre_umbral}
            total={sobreUmbral.total}
            detalle={
              sobreUmbral.pct === null
                ? 'sin celdas en el periodo'
                : `${textoScore(sobreUmbral.pct)} % sobre el umbral de ${umbral} personas`
            }
            ayuda={`Combinaciones departamento-habilidad con al menos ${umbral} colaboradores evaluados. Por debajo de ese mínimo el score no se muestra, para proteger la privacidad.`}
          />
        </div>
      </header>

      <div className="mapa-calor__cuerpo">
        {/* ── Matriz ── */}
        <section className="rrhh-resumen__panel">
          <header className="rrhh-resumen__panel-cabecera">
            <h2>Score por departamento y habilidad</h2>
            <p>
              Más oscuro = score más alto · n&lt;{umbral} = datos insuficientes. Pasa el ratón por una
              celda para ver el detalle.
            </p>
          </header>

          {datos.departamentos.length === 0 || datos.habilidades.length === 0 ? (
            <p className="rrhh-resumen__vacio">Todavía no hay colaboradores evaluados en el periodo.</p>
          ) : (
            <div className="mapa-calor__scroll">
              <table className="mapa-calor__tabla">
                <thead>
                  <tr>
                    <th scope="col" aria-label="Departamento" />
                    {datos.habilidades.map((h) => (
                      <th key={h.reto_id} scope="col">
                        {h.habilidad}
                      </th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  {datos.departamentos.map((dep) => (
                    <tr key={claveDep(dep.id)}>
                      <th scope="row">{dep.nombre}</th>
                      {datos.habilidades.map((h) => {
                        const celda = mapaCeldas.get(`${claveDep(dep.id)}|${h.reto_id}`);
                        const evaluados = celda?.evaluados ?? 0;

                        if (celda && celda.score !== null) {
                          const color = colorCelda(celda.score, escala.bajo, escala.alto);
                          return (
                            <td
                              key={h.reto_id}
                              className="mapa-calor__celda"
                              style={{ background: color.fondo, color: color.texto }}
                              title={`${dep.nombre} · ${h.habilidad}: ${textoScore(celda.score)} (${evaluados} evaluados)`}
                            >
                              {textoScore(celda.score)}
                            </td>
                          );
                        }
                        if (evaluados > 0) {
                          return (
                            <td
                              key={h.reto_id}
                              className="mapa-calor__celda mapa-calor__celda--insuficiente"
                              title={`${dep.nombre} · ${h.habilidad}: ${evaluados} ${evaluados === 1 ? 'evaluado' : 'evaluados'} (mínimo ${umbral})`}
                            >
                              n&lt;{umbral}
                            </td>
                          );
                        }
                        return (
                          <td
                            key={h.reto_id}
                            className="mapa-calor__celda mapa-calor__celda--vacia"
                            title={`${dep.nombre} · ${h.habilidad}: nadie evaluado`}
                          >
                            —
                          </td>
                        );
                      })}
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}

          {/* Leyenda de la escala */}
          <div className="mapa-calor__leyenda" aria-label={`Escala de color de ${escala.bajo} a ${escala.alto}`}>
            <span>Bajo ({escala.bajo})</span>
            {[0, 0.25, 0.5, 0.75, 1].map((t) => (
              <span
                key={t}
                className="mapa-calor__muestra"
                style={{
                  background: colorCelda(escala.bajo + t * (escala.alto - escala.bajo), escala.bajo, escala.alto).fondo,
                }}
              />
            ))}
            <span>Alto ({escala.alto})</span>
            <span className="mapa-calor__muestra mapa-calor__muestra--insuficiente">n&lt;{umbral}</span>
          </div>
        </section>

        {/* ── Notas laterales ── */}
        <aside className="mapa-calor__lateral">
          <section className="mapa-calor__nota mapa-calor__nota--leer">
            <h3>Cómo leerlo</h3>
            <p>
              Por fila, el perfil de un área; por columna, una habilidad entre áreas. El color va de
              claro (score bajo, {escala.bajo}) a morado intenso (score alto, {escala.alto}). Pasa el
              ratón por una celda para ver su número de evaluados.
            </p>
          </section>

          <section className="mapa-calor__nota mapa-calor__nota--brechas">
            <h3>Brechas principales</h3>
            {resumenes?.brechas.map((texto) => <p key={texto}>{texto}</p>)}
          </section>

          <section className="mapa-calor__nota mapa-calor__nota--fortalezas">
            <h3>Fortalezas y umbral</h3>
            {resumenes?.fortalezas.map((texto) => <p key={texto}>{texto}</p>)}
          </section>
        </aside>
      </div>
    </div>
  );
}