// ═══════════════════════════════════════════════════════════════════
// Al entrar a "/", lleva a la primera pantalla del primer nivel del usuario
// ═══════════════════════════════════════════════════════════════════
import { Navigate } from 'react-router';
import { useSesion } from '../auth/sesion';
import { rutaInicial } from '../navegacion';

export default function RedireccionInicial() {
  const sesion = useSesion((estado) => estado.sesion);
  if (!sesion) return null;

  const destino = rutaInicial(sesion.perfil);
  if (!destino) {
    return <p>Tu usuario no tiene pantallas asignadas. Contacta con soporte.</p>;
  }

  return <Navigate to={destino} replace />;
}