// ═══════════════════════════════════════════════════════════════════
// MAPA DE RUTAS DEL DASHBOARD
// ═══════════════════════════════════════════════════════════════════
import { Navigate, Route, Routes } from 'react-router';
import { RutaProtegida, SoloSinSesion } from './auth/RutaProtegida';
import Login from './paginas/Login';
import Inicio from './paginas/Inicio';

export default function App() {
  return (
    <Routes>
      {/* Solo sin sesión: si ya entraste, /login te manda al inicio */}
      <Route element={<SoloSinSesion />}>
        <Route path="/login" element={<Login />} />
      </Route>

      {/* Solo con sesión: si no entraste, te manda a /login */}
      <Route element={<RutaProtegida />}>
        <Route path="/" element={<Inicio />} />
      </Route>

      {/* Cualquier otra dirección: al inicio (y de ahí al login si hace falta) */}
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}