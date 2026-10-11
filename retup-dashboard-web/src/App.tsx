import { useEffect, useState } from 'react';
import { API_URL } from './config';

type EstadoConexion = 'comprobando' | 'ok' | 'error';

/**
 * PANTALLA PROVISIONAL
 * Solo comprueba que el dashboard se comunica con el backend.
 * En el siguiente paso se reemplaza por el login real.
 */
export default function App() {
  const [estado, setEstado] = useState<EstadoConexion>('comprobando');

  useEffect(() => {
    fetch(`${API_URL}/health`)
      .then((respuesta) => setEstado(respuesta.ok ? 'ok' : 'error'))
      .catch(() => setEstado('error'));
  }, []);

  const textoEstado = {
    comprobando: '⏳ Comprobando conexión…',
    ok: '✅ Backend conectado',
    error: '❌ No se pudo conectar con el backend',
  }[estado];

  const colorEstado = {
    comprobando: 'var(--rt-texto-suave)',
    ok: 'var(--rt-exito)',
    error: 'var(--rt-error)',
  }[estado];

  return (
    <main style={{ minHeight: '100vh', display: 'grid', placeItems: 'center' }}>
      <section
        style={{
          width: 440,
          padding: 40,
          textAlign: 'center',
          background: 'var(--rt-superficie)',
          borderRadius: 'var(--rt-radio)',
          boxShadow: 'var(--rt-sombra)',
        }}
      >
        <h1 style={{ margin: 0, color: 'var(--rt-indigo)', fontSize: 32 }}>
          RetUp <span style={{ color: 'var(--rt-turquesa)' }}>Dashboard</span>
        </h1>
        <p style={{ color: 'var(--rt-texto-suave)', marginTop: 8 }}>
          Backend: <code>{API_URL}</code>
        </p>
        <p style={{ color: colorEstado, fontWeight: 600, fontSize: 18 }}>{textoEstado}</p>
      </section>
    </main>
  );
}