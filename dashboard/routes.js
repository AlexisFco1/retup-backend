// =====================================================================
// RUTAS DEL DASHBOARD WEB  ->  todas cuelgan de /api/dashboard
// =====================================================================
const express = require('express');
const { authenticateToken } = require('../middleware');
const { db, crearClienteAuth } = require('./db');
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

// ---------------------------------------------------------------------
// UTILIDAD: lee y valida el rango de fechas de los filtros
// Query: ?desde=YYYY-MM-DD&hasta=YYYY-MM-DD&comp_desde=...&comp_hasta=...
// ---------------------------------------------------------------------
const FECHA_RE = /^\d{4}-\d{2}-\d{2}$/;
const MAX_DIAS_RANGO = 400;

function leerRango(query) {
  const { desde, hasta, comp_desde, comp_hasta } = query;

  if (!FECHA_RE.test(desde || '') || !FECHA_RE.test(hasta || '')) {
    return { error: 'Las fechas "desde" y "hasta" son obligatorias (formato AAAA-MM-DD)' };
  }
  if (desde > hasta) {
    return { error: 'La fecha "desde" no puede ser posterior a "hasta"' };
  }
  const dias = (Date.parse(hasta) - Date.parse(desde)) / 86400000;
  if (dias > MAX_DIAS_RANGO) {
    return { error: `El rango máximo es de ${MAX_DIAS_RANGO} días` };
  }

  // La comparación es opcional: si no viene completa y válida, no se compara
  const hayComparacion =
    FECHA_RE.test(comp_desde || '') && FECHA_RE.test(comp_hasta || '') && comp_desde <= comp_hasta;

  return {
    desde,
    hasta,
    comp_desde: hayComparacion ? comp_desde : null,
    comp_hasta: hayComparacion ? comp_hasta : null,
  };
}

// ---------------------------------------------------------------------
// GET /api/dashboard/jefatura/mi-equipo
// Indicadores del equipo del jefe conectado. El jefe SIEMPRE sale del token.
// ---------------------------------------------------------------------
router.get(
  '/jefatura/mi-equipo',
  authenticateToken,
  exigirAccesoDashboard(['jefatura']),
  async (req, res) => {
    try {
      const rango = leerRango(req.query);
      if (rango.error) {
        return res.status(400).json({ success: false, error: rango.error });
      }

      const { data, error } = await db.rpc('dash_jefatura_mi_equipo', {
        p_lider: req.user.id, // ← del token, nunca del navegador
        p_desde: rango.desde,
        p_hasta: rango.hasta,
        p_comp_desde: rango.comp_desde,
        p_comp_hasta: rango.comp_hasta,
      });
      if (error) throw error;

      res.json({ success: true, datos: data });
    } catch (error) {
      console.error('❌ Error en /dashboard/jefatura/mi-equipo:', error.message);
      res.status(500).json({ success: false, error: 'No se pudieron calcular los indicadores del equipo' });
    }
  },
);

module.exports = router;