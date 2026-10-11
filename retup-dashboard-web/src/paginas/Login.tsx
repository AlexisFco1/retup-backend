// ═══════════════════════════════════════════════════════════════════
// PANTALLA DE LOGIN DEL DASHBOARD
// Usa /api/dashboard/auth/login (NO registra rachas y rechaza a quien
// no tenga un nivel de acceso al dashboard).
// ═══════════════════════════════════════════════════════════════════
import { useEffect, useRef, useState } from 'react';
import type { FormEvent } from 'react';
import { useNavigate } from 'react-router';
import { apiFetch, ErrorApi } from '../api/cliente';
import { useSesion } from '../auth/sesion';
import type { PerfilDashboard } from '../auth/sesion';
import './Login.css';

/** Lo que devuelve POST /api/dashboard/auth/login */
interface RespuestaLogin {
  success: boolean;
  token: string;
  refresh_token: string;
  expires_at: number;
  perfil: PerfilDashboard;
}

/** Si el servidor tarda más que esto, avisamos de que puede estar "despertando" */
const MS_AVISO_SERVIDOR_LENTO = 5000;

export default function Login() {
  const navegar = useNavigate();
  const iniciarSesion = useSesion((estado) => estado.iniciarSesion);

  const [correo, setCorreo] = useState('');
  const [clave, setClave] = useState('');
  const [verClave, setVerClave] = useState(false);
  const [cargando, setCargando] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [servidorLento, setServidorLento] = useState(false);

  // Temporizador del aviso "servidor despertando"
  const temporizador = useRef<number | null>(null);

  // Si la pantalla se cierra, se cancela el temporizador
  useEffect(() => {
    return () => {
      if (temporizador.current) window.clearTimeout(temporizador.current);
    };
  }, []);

  async function manejarEnvio(evento: FormEvent<HTMLFormElement>) {
    evento.preventDefault(); // Evita que el navegador recargue la página
    setError(null);
    setServidorLento(false);
    setCargando(true);

    temporizador.current = window.setTimeout(
      () => setServidorLento(true),
      MS_AVISO_SERVIDOR_LENTO,
    );

    try {
      const respuesta = await apiFetch<RespuestaLogin>('/dashboard/auth/login', {
        metodo: 'POST',
        cuerpo: { email: correo.trim(), password: clave },
        conToken: false,
      });

      iniciarSesion({
        token: respuesta.token,
        refreshToken: respuesta.refresh_token,
        expiraEn: respuesta.expires_at,
        perfil: respuesta.perfil,
      });

      // replace: al pulsar "Atrás" no se vuelve al login
      navegar('/', { replace: true });
    } catch (e) {
      setError(
        e instanceof ErrorApi ? e.message : 'Ocurrió un error inesperado. Inténtalo de nuevo.',
      );
    } finally {
      if (temporizador.current) window.clearTimeout(temporizador.current);
      setServidorLento(false);
      setCargando(false);
    }
  }

  return (
    <div className="login">
      {/* ── Panel de marca (izquierda) ── */}
      <aside className="login__marca">
        <div className="login__logo">
          Ret<span>Up</span>
        </div>
        <h1 className="login__lema">
          Convierte las habilidades blandas en <span>datos accionables</span>.
        </h1>
        <p className="login__descripcion">
          Panel de seguimiento para RetUp, RRHH, Gerencia y Jefaturas.
        </p>
      </aside>

      {/* ── Formulario (derecha) ── */}
      <main className="login__panel">
        <form className="login__formulario" onSubmit={manejarEnvio} noValidate={false}>
          <h2 className="login__titulo">Iniciar sesión</h2>
          <p className="login__subtitulo">Accede con tu correo corporativo</p>

          <label className="login__campo">
            <span>Correo</span>
            <input
              type="email"
              autoComplete="username"
              placeholder="nombre@empresa.com"
              value={correo}
              onChange={(e) => setCorreo(e.target.value)}
              required
              disabled={cargando}
            />
          </label>

          <label className="login__campo">
            <span>Contraseña</span>
            <div className="login__clave">
              <input
                type={verClave ? 'text' : 'password'}
                autoComplete="current-password"
                placeholder="••••••••"
                value={clave}
                onChange={(e) => setClave(e.target.value)}
                required
                disabled={cargando}
              />
              <button
                type="button"
                className="login__ver-clave"
                onClick={() => setVerClave((valor) => !valor)}
                aria-label={verClave ? 'Ocultar contraseña' : 'Mostrar contraseña'}
              >
                {verClave ? 'Ocultar' : 'Mostrar'}
              </button>
            </div>
          </label>

          {error && (
            <div className="login__mensaje login__mensaje--error" role="alert">
              {error}
            </div>
          )}

          {servidorLento && !error && (
            <div className="login__mensaje login__mensaje--aviso" role="status">
              El servidor se está activando, puede tardar hasta un minuto…
            </div>
          )}

          <button type="submit" className="login__boton" disabled={cargando}>
            {cargando ? 'Entrando…' : 'Entrar'}
          </button>
        </form>
      </main>
    </div>
  );
}