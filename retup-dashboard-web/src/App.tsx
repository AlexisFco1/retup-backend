// ═══════════════════════════════════════════════════════════════════
// MAPA DE RUTAS DEL DASHBOARD
// ═══════════════════════════════════════════════════════════════════
import { Navigate, Route, Routes } from 'react-router';
import { RutaProtegida, SoloSinSesion } from './auth/RutaProtegida';
import Marco from './componentes/Marco';
import Login from './paginas/Login';
import RedireccionInicial from './paginas/RedireccionInicial';
import PantallaDashboard from './paginas/PantallaDashboard';
import MiEquipo from './paginas/jefatura/MiEquipo';
import Directorio from './paginas/mantenimiento/Directorio';
import RequiereAtencion from './paginas/mantenimiento/RequiereAtencion';

export default function App() {
  return (
    <Routes>
      {/* Solo sin sesión */}
      <Route element={<SoloSinSesion />}>
        <Route path="/login" element={<Login />} />
      </Route>

      {/* Solo con sesión, y dentro del marco (cabecera + menú + filtros) */}
      <Route element={<RutaProtegida />}>
        <Route element={<Marco />}>
          <Route path="/" element={<RedireccionInicial />} />
          {/* Cualquier pantalla del menú. Las pantallas reales se añadirán
              ENCIMA de esta línea con su ruta exacta (ej. /rrhh/mapa-calor) */}
                    <Route path="/jefatura/mi-equipo" element={<MiEquipo />} />
                    <Route path="/mantenimiento/directorio" element={<Directorio />} />
                    <Route path="/mantenimiento/atencion" element={<RequiereAtencion />} />
          <Route path="/:nivel/:pantalla" element={<PantallaDashboard />} />
        </Route>
      </Route>

      {/* Cualquier otra dirección: al inicio */}
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}