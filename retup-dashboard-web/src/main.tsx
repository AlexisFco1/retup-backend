// ═══════════════════════════════════════════════════════════════════
// PUNTO DE ENTRADA DEL DASHBOARD
// Activa el enrutador y el gestor de consultas al backend.
// ═══════════════════════════════════════════════════════════════════
import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { BrowserRouter } from 'react-router';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { ErrorApi } from './api/cliente';
import { useSesion } from './auth/sesion';
import './index.css';
import App from './App.tsx';

const clienteConsultas = new QueryClient({
  defaultOptions: {
    queries: {
      // Un dato se considera "fresco" durante 1 minuto (no se vuelve a pedir)
      staleTime: 60_000,
      // No recargar todo cada vez que vuelves a la pestaña del navegador
      refetchOnWindowFocus: false,
      // Reintentar 1 vez solo si fue un fallo de conexión o del servidor (no de permisos)
      retry: (intentos, error) => {
        const esErrorDelUsuario =
          error instanceof ErrorApi && error.estado >= 400 && error.estado < 500;
        return !esErrorDelUsuario && intentos < 1;
      },
    },
  },
});

// Al cerrar sesión, se borran de memoria todos los datos consultados
useSesion.subscribe((estado, estadoAnterior) => {
  if (estadoAnterior.sesion && !estado.sesion) {
    clienteConsultas.clear();
  }
});

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <QueryClientProvider client={clienteConsultas}>
      <BrowserRouter>
        <App />
      </BrowserRouter>
    </QueryClientProvider>
  </StrictMode>,
);