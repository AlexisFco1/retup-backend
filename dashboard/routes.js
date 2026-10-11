// =====================================================================
// RUTAS DEL DASHBOARD WEB  ->  todas cuelgan de /api/dashboard
// =====================================================================
const express = require('express');
const { authenticateToken } = require('../middleware');
const { crearClienteAuth } = require('./db');
const {
  cargarPerfilDashboard,
  motivoSinAcceso,
  perfilPublico,
  exigirAccesoDashboard,
} = require('./acceso');

const router = express.Router();

// ---------------------------------------------------------------------
// POST /api/dashboard/auth/login
// Login del dashboard. A diferencia del login de la app, NO registra
// rachas y rechaza a quien no tenga un nivel de acceso al dashboard.
// Body: { email, password }
// ---------------------------------------------------------------------
router.post('/auth/login', async (req, res) => {
  try {
    const { email, password } = req.body || {};
    if (!email || !password) {
      return res.status(400).json({ success: false, error: 'Correo y contraseña son obligatorios' });
    }

    // Cliente desechable: la sesión no "contamina" a ningún otro cliente
    const clienteAuth = crearClienteAuth();
    const { data, error } = await clienteAuth.auth.signInWithPassword({ email, password });

    if (error || !data?.session) {
      return res.status(401).json({ success: false, error: 'Correo o contraseña incorrectos' });
    }

    const perfil = await cargarPerfilDashboard(data.user.id);
    const motivo = motivoSinAcceso(perfil);
    if (motivo) {
      return res.status(403).json({ success: false, error: motivo });
    }

    console.log(`🖥️ Dashboard login: ${perfil.usuario.email} -> [${perfil.niveles.join(', ')}]`);

    res.json({
      success: true,
      token: data.session.access_token,
      refresh_token: data.session.refresh_token,
      expires_at: data.session.expires_at, // segundos desde 1970 (dura ~1 hora)
      perfil: perfilPublico(perfil),
    });
  } catch (error) {
    console.error('❌ Error en dashboard login:', error.message);
    res.status(500).json({ success: false, error: error.message });
  }
});

// ---------------------------------------------------------------------
// POST /api/dashboard/auth/refresh
// Renueva el token antes de que caduque (el navegador lo llamará solo).
// Body: { refresh_token }
// ---------------------------------------------------------------------
router.post('/auth/refresh', async (req, res) => {
  try {
    const { refresh_token } = req.body || {};
    if (!refresh_token) {
      return res.status(400).json({ success: false, error: 'refresh_token es obligatorio' });
    }

    const clienteAuth = crearClienteAuth();
    const { data, error } = await clienteAuth.auth.refreshSession({ refresh_token });

    if (error || !data?.session) {
      return res.status(401).json({ success: false, error: 'Sesión caducada, vuelve a iniciar sesión' });
    }

    res.json({
      success: true,
      token: data.session.access_token,
      refresh_token: data.session.refresh_token,
      expires_at: data.session.expires_at,
    });
  } catch (error) {
    console.error('❌ Error en dashboard refresh:', error.message);
    res.status(500).json({ success: false, error: error.message });
  }
});

// ---------------------------------------------------------------------
// GET /api/dashboard/me
// "¿Quién soy?": datos para la cabecera y el menú según los niveles.
// ---------------------------------------------------------------------
router.get('/me', authenticateToken, exigirAccesoDashboard(), (req, res) => {
  res.json({ success: true, perfil: perfilPublico(req.dashboard) });
});

module.exports = router;