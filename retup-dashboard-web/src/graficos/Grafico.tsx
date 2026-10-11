// ═══════════════════════════════════════════════════════════════════
// GRÁFICO (envoltorio de Apache ECharts para React)
// - Solo se cargan los tipos de gráfico que usa el dashboard (web más ligera)
// - Se redibuja al cambiar los datos y se adapta al ancho de su contenedor
// ═══════════════════════════════════════════════════════════════════
import { useEffect, useRef } from 'react';
import * as echarts from 'echarts/core';
import type { EChartsCoreOption } from 'echarts/core';
import { BarChart, LineChart, HeatmapChart, RadarChart } from 'echarts/charts';
import {
  GridComponent,
  TooltipComponent,
  LegendComponent,
  VisualMapComponent,
  RadarComponent,
  MarkLineComponent,
} from 'echarts/components';
import { CanvasRenderer } from 'echarts/renderers';

echarts.use([
  BarChart,
  LineChart,
  HeatmapChart,
  RadarChart,
  GridComponent,
  TooltipComponent,
  LegendComponent,
  VisualMapComponent,
  RadarComponent,
  MarkLineComponent,
  CanvasRenderer,
]);

interface PropsGrafico {
  /** Configuración del gráfico en formato ECharts */
  opciones: EChartsCoreOption;
  /** Alto en píxeles (el ancho se adapta al contenedor) */
  alto?: number;
  /** Texto para lectores de pantalla: qué muestra el gráfico */
  descripcion: string;
}

export default function Grafico({ opciones, alto = 280, descripcion }: PropsGrafico) {
  const contenedor = useRef<HTMLDivElement | null>(null);
  const instancia = useRef<echarts.ECharts | null>(null);

  // Crear el gráfico una vez y destruirlo al salir de la pantalla
  useEffect(() => {
    if (!contenedor.current) return;
    instancia.current = echarts.init(contenedor.current, undefined, { renderer: 'canvas' });

    // Se adapta si cambia el ancho (ej. al redimensionar la ventana)
    const observador = new ResizeObserver(() => instancia.current?.resize());
    observador.observe(contenedor.current);

    return () => {
      observador.disconnect();
      instancia.current?.dispose();
      instancia.current = null;
    };
  }, []);

  // Redibujar cuando cambian los datos (notMerge: reemplaza todo, sin restos)
  useEffect(() => {
    instancia.current?.setOption(opciones, { notMerge: true });
  }, [opciones]);

  return (
    <div
      ref={contenedor}
      style={{ width: '100%', height: alto }}
      role="img"
      aria-label={descripcion}
    />
  );
}