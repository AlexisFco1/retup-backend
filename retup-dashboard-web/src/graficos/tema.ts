// ═══════════════════════════════════════════════════════════════════
// TEMA DE LOS GRÁFICOS
// ECharts dibuja en un lienzo (canvas) y NO entiende var(--rt-...).
// ⚠️ Estos valores deben coincidir con los de src/index.css
// ═══════════════════════════════════════════════════════════════════
export const COLOR = {
  indigo: '#2E2A72', // marcas principales (barras, líneas)
  turquesa: '#12B5A6', // solo acentos con texto (bajo contraste sobre blanco)
  morado: '#7209B7', // escala del mapa de calor
  texto: '#0E0F17',
  textoSuave: '#5B5F73',
  borde: '#E4E6EF',
  rejilla: '#EEF0F5', // líneas de fondo, discretas
  superficie: '#FFFFFF',
} as const;

/** Ajustes comunes a todos los gráficos */
export const BASE_GRAFICO = {
  textStyle: {
    fontFamily: 'Inter, system-ui, -apple-system, "Segoe UI", Roboto, sans-serif',
    color: COLOR.textoSuave,
  },
  tooltip: {
    backgroundColor: COLOR.superficie,
    borderColor: COLOR.borde,
    borderWidth: 1,
    textStyle: { color: COLOR.texto, fontSize: 13 },
    extraCssText: 'box-shadow: 0 4px 16px rgba(14,15,23,0.08); border-radius: 8px;',
  },
  animationDuration: 300,
};

/** Eje con líneas finas y discretas (lo importante son los datos, no la rejilla) */
export const EJE_DISCRETO = {
  axisLine: { lineStyle: { color: COLOR.borde } },
  axisTick: { show: false },
  axisLabel: { color: COLOR.textoSuave, fontSize: 12 },
  splitLine: { lineStyle: { color: COLOR.rejilla, width: 1 } },
};