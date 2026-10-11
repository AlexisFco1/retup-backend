// =====================================================================
// EVENTOS DE ACTIVIDAD DE LA APP  ->  todas cuelgan de /api/eventos
// La app Flutter envía aquí lo que hace el usuario para que el dashboard
// pueda calcular tiempos, embudos, abandono y horarios de conexión.
// =====================================================================
const express = require('express');
const { authenticateToken } = require('../middleware');
const { db } = require('../dashboard/db'); // cliente que nunca inicia sesión (tablas con RLS)

const router = express.Router();

const TIPOS_ACTIVIDAD = ['app_open', 'app_resume', 'login', 'pill_start', 'pill_complete'];
const TIPOS_SALIDA = ['siguiente', 'anterior', 'enviar', 'salir'];
const ORIGENES = ['reto', 'suelta'];
const MAX_LOTE = 50;                                // máximo de secciones por envío
const MAX_DURACION_MS = 3 * 60 * 60 * 1000;         // 3 horas
const MARGEN_FUTURO_MS = 5 * 60 * 1000;             // tolera relojes de móvil adelantados 5 min

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const esUuid = (v) => typeof v === 'string' && UUID_RE.test(v);
const uuidOpcional = (v) => (esUuid(v) ? v : null);

// La empresa SIEMPRE se toma de la tabla users (nunca de lo que envía la app)
async function empresaDe(userId) {
  const { data, error } = await db
    .from('users')
    .select('company_id')
    .eq('id', userId)
    .maybeSingle();
  if (error) throw error;
  return data?.company_id || null;
}

// ---------------------------------------------------------------------
// POST /api/eventos/actividad
// Body: { event_type, reto_id?, pill_id?, origen? }
// La hora la pone el servidor (occurred_at = now()).
// ---------------------------------------------------------------------
router.post('/actividad', authenticateToken, async (req, res) => {
  try {
    const { event_type, reto_id, pill_id, origen } = req.body || {};

    if (!TIPOS_ACTIVIDAD.includes(event_type)) {
      return res.status(400).json({ success: false, error: 'event_type no válido' });
    }

    const company_id = await empresaDe(req.user.id);

    const { error } = await db.from('user_activity_events').insert({
      user_id: req.user.id,
      company_id,
      event_type,
      reto_id: uuidOpcional(reto_id),
      pill_id: uuidOpcional(pill_id),
      origen: ORIGENES.includes(origen) ? origen : null,
    });
    if (error) throw error;

    res.status(201).json({ success: true });
  } catch (error) {
    console.error('❌ Error en POST /api/eventos/actividad:', error.message);
    res.status(500).json({ success: false, error: error.message });
  }
});

// ---------------------------------------------------------------------
// POST /api/eventos/secciones
// Body: { eventos: [ { pill_id, reto_id?, origen?, pill_session_id,
//                      section_number, entered_at, left_at?, exit_type? } ] }
// Guarda los válidos y cuenta los descartados (no falla todo el lote).
// ---------------------------------------------------------------------
router.post('/secciones', authenticateToken, async (req, res) => {
  try {
    const lista = Array.isArray(req.body?.eventos) ? req.body.eventos : [];

    if (lista.length === 0) {
      return res.status(400).json({ success: false, error: 'No se enviaron eventos' });
    }
    if (lista.length > MAX_LOTE) {
      return res.status(400).json({ success: false, error: `Máximo ${MAX_LOTE} eventos por envío` });
    }

    const company_id = await empresaDe(req.user.id);
    const ahora = Date.now();
    const filas = [];
    let descartados = 0;

    for (const e of lista) {
      const entrada = Date.parse(e?.entered_at);
      const salida = e?.left_at ? Date.parse(e.left_at) : null;
      const seccion = Number(e?.section_number);

      const valido =
        esUuid(e?.pill_id) &&
        esUuid(e?.pill_session_id) &&
        Number.isInteger(seccion) && seccion >= 1 && seccion <= 20 &&
        !isNaN(entrada) && entrada <= ahora + MARGEN_FUTURO_MS &&
        (salida === null || (!isNaN(salida) && salida >= entrada)) &&
        (e?.exit_type == null || TIPOS_SALIDA.includes(e.exit_type));

      if (!valido) {
        descartados++;
        continue;
      }

      // Sección abierta demasiado tiempo: cuenta para el embudo, pero sin duración
      const salidaFinal =
        salida !== null && salida - entrada <= MAX_DURACION_MS
          ? new Date(salida).toISOString()
          : null;

      filas.push({
        user_id: req.user.id,
        company_id,
        reto_id: uuidOpcional(e.reto_id),
        pill_id: e.pill_id,
        origen: ORIGENES.includes(e.origen) ? e.origen : 'reto',
        pill_session_id: e.pill_session_id,
        section_number: seccion,
        entered_at: new Date(entrada).toISOString(),
        left_at: salidaFinal,
        exit_type: e.exit_type || null,
      });
    }

    if (filas.length > 0) {
      const { error } = await db.from('pill_section_events').insert(filas);
      if (error) throw error;
    }

    res.status(201).json({ success: true, guardados: filas.length, descartados });
  } catch (error) {
    console.error('❌ Error en POST /api/eventos/secciones:', error.message);
    res.status(500).json({ success: false, error: error.message });
  }
});

module.exports = router;