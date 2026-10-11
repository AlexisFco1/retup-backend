// ═══════════════════════════════════════════════════════════════════
// INICIO (PROVISIONAL)
// Comprueba el circuito completo: sesión guardada + petición con token
// a /api/dashboard/me. Se reemplazará por la cabecera y el menú reales.
// ═══════════════════════════════════════════════════════════════════
import { useEffect } from 'react';
import type { CSSProperties } from 'react';
import { useQuery } from '@tanstack/react-query';
import { apiFetch } from '../api/cliente';
import { useSesion } from '../auth/sesion';
import type { PerfilDashboard } from '../auth/sesion';

interface RespuestaMe {
  success: boolean;
  perfil: PerfilDashboard;
}

export default function Inicio() {
  const sesion = useSesion((estado) => estado.sesion);
  const actualizarPerfil = useSesion((estado) => estado.actualizarPerfil);
  const cerrarSesion = useSesion((estado) => estado.cerrarSesion);

  // Pide el perfil al backend usando el token guardado
  const consultaPerfil = useQuery({
    queryKey: ['dashboard', 'me'],
    queryFn: () => apiFetch<RespuestaMe>('/dashboard/me'),
  });

  // Si el servidor devuelve un perfil más reciente, lo guardamos
  useEffect(() => {
    if (consultaPerfil.data?.perfil) {
      actualizarPerfil(consultaPerfil.data.perfil);
    }
  }, [consultaPerfil.data, actualizarPerfil]);

  if (!sesion) return null; // El guardián se encarga de mandar al login

  const { perfil } = sesion;

  const textoVerificacion = consultaPerfil.isPending
    ? '⏳ Verificando tu perfil con el servidor…'
    : consultaPerfil.isError
      ? `❌ ${consultaPerfil.error?.message}`
      : '✅ Perfil verificado con el servidor';

  return (
    <main style={estilos.pagina}>
      {/* ── Quién soy ── */}
      <section style={estilos.tarjeta}>
        <div style={estilos.fila}>
          <div style={estilos.avatar}>{perfil.usuario.iniciales}</div>
          <div style={{ flex: 1 }}>
            <h1 style={estilos.titulo}>Hola, {perfil.usuario.nombre ?? perfil.usuario.email}</h1>
            <p style={estilos.suave}>
              {perfil.usuario.cargo ?? 'Sin cargo'} ·{' '}
              {perfil.empresa?.name ?? 'RetUp (todas las empresas)'}
            </p>
          </div>
          <button type="button" style={estilos.botonSalir} onClick={cerrarSesion}>
            Salir
          </button>
        </div>
        <p style={estilos.verificacion}>{textoVerificacion}</p>
      </section>

      {/* ── Mi menú según mis niveles ── */}
      <section style={estilos.tarjeta}>
        <h2 style={estilos.subtitulo}>Tu menú</h2>

        {perfil.menu.map((seccion) => (
          <div key={seccion.nivel} style={{ marginBottom: 16 }}>
            <h3 style={estilos.nivel}>{seccion.etiqueta}</h3>
            <div style={estilos.chips}>
              {seccion.pantallas.map((pantalla) => (
                <span key={pantalla.clave} style={estilos.chip}>
                  {pantalla.titulo}
                </span>
              ))}
            </div>
          </div>
        ))}

        {perfil.equipos_a_cargo.length > 0 && (
          <p style={estilos.suave}>
            Equipos a cargo: {perfil.equipos_a_cargo.map((equipo) => equipo.name).join(', ')}
          </p>
        )}
      </section>
    </main>
  );
}

// Estilos provisionales (la versión final irá en archivos .css)
const estilos: Record<string, CSSProperties> = {
  pagina: { maxWidth: 880, margin: '48px auto', padding: '0 24px', display: 'grid', gap: 24 },
  tarjeta: {
    padding: 28,
    background: 'var(--rt-superficie)',
    borderRadius: 'var(--rt-radio)',
    boxShadow: 'var(--rt-sombra)',
  },
  fila: { display: 'flex', alignItems: 'center', gap: 16 },
  avatar: {
    width: 56,
    height: 56,
    display: 'grid',
    placeItems: 'center',
    borderRadius: '50%',
    color: '#fff',
    fontWeight: 700,
    fontSize: 20,
    background: 'linear-gradient(135deg, var(--rt-turquesa), var(--rt-indigo))',
  },
  titulo: { margin: 0, fontSize: 24, color: 'var(--rt-indigo)' },
  subtitulo: { margin: '0 0 16px', fontSize: 18, color: 'var(--rt-indigo)' },
  nivel: { margin: '0 0 8px', fontSize: 14, color: 'var(--rt-texto)' },
  suave: { margin: '4px 0 0', color: 'var(--rt-texto-suave)' },
  verificacion: { margin: '20px 0 0', fontWeight: 600 },
  chips: { display: 'flex', flexWrap: 'wrap', gap: 8 },
  chip: {
    padding: '6px 12px',
    fontSize: 13,
    fontWeight: 600,
    color: 'var(--rt-indigo)',
    background: 'rgba(46, 42, 114, 0.08)',
    borderRadius: 999,
  },
  botonSalir: {
    padding: '10px 18px',
    fontWeight: 600,
    color: 'var(--rt-indigo)',
    background: 'transparent',
    border: '1.5px solid var(--rt-borde)',
    borderRadius: 10,
  },
};