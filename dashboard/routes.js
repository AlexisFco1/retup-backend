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

         // Frecuencia del gráfico de evolución: dia | semana | mes (por defecto, semana)
      const frecuencia = ['dia', 'semana', 'mes'].includes(req.query.frecuencia)
        ? req.query.frecuencia
        : 'semana';

      const { data, error } = await db.rpc('dash_jefatura_mi_equipo', {
        p_lider: req.user.id, // ← del token, nunca del navegador
        p_desde: rango.desde,
        p_hasta: rango.hasta,
        p_comp_desde: rango.comp_desde,
        p_comp_hasta: rango.comp_hasta,
        p_frecuencia: frecuencia,
      });
      if (error) throw error;

      res.json({ success: true, datos: data });
    } catch (error) {
      console.error('❌ Error en /dashboard/jefatura/mi-equipo:', error.message);
      res.status(500).json({ success: false, error: 'No se pudieron calcular los indicadores del equipo' });
    }
  },
);

// ===================== MANTENIMIENTO · LECTURA =====================
// La empresa SIEMPRE sale del perfil del usuario conectado (nunca del navegador).
function empresaDelPerfil(req, res) {
  const empresaId = req.dashboard && req.dashboard.empresa && req.dashboard.empresa.id;
  if (!empresaId) {
        res.status(403).json({ success: false, error: 'Tu usuario no tiene una empresa asignada.' });
    return null;
  }
  return empresaId;
}

// Fabrica una ruta que llama a una función SQL de Mantenimiento con la empresa del perfil
function rutaLecturaMantenimiento(funcionSql) {
  return async (req, res) => {
    try {
      const empresaId = empresaDelPerfil(req, res);
      if (!empresaId) return;

      const { data, error } = await db.rpc(funcionSql, { p_empresa: empresaId });
      if (error) throw error;

      res.json({ success: true, datos: data });
    } catch (err) {
      console.error(`Error en ${funcionSql}:`, err.message);
            res.status(500).json({ success: false, error: 'No se pudieron cargar los datos.' });
    }
  };
}

router.get('/mantenimiento/directorio', authenticateToken, exigirAccesoDashboard(['mantenimiento']), rutaLecturaMantenimiento('dash_mant_directorio'));
router.get('/mantenimiento/alertas', authenticateToken, exigirAccesoDashboard(['mantenimiento']), rutaLecturaMantenimiento('dash_mant_alertas'));
router.get('/mantenimiento/catalogo', authenticateToken, exigirAccesoDashboard(['mantenimiento']), rutaLecturaMantenimiento('dash_mant_catalogo'));

// ===================== MANTENIMIENTO · ALTA DE USUARIOS =====================
const nodeCrypto = require('crypto');

const FORMATO_EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const FORMATO_UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const FORMATO_FECHA = /^\d{4}-\d{2}-\d{2}$/;

// Contraseña temporal de 12 caracteres, sin los que se confunden (0/O, 1/l/I).
// Siempre lleva al menos una minúscula, una mayúscula y un número.
function generarPasswordTemporal() {
  const minusculas = 'abcdefghjkmnpqrstuvwxyz';
  const mayusculas = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
  const numeros = '23456789';
  const todos = minusculas + mayusculas + numeros;
  const elegir = (texto) => texto[nodeCrypto.randomInt(texto.length)];

  const caracteres = [elegir(minusculas), elegir(mayusculas), elegir(numeros)];
  while (caracteres.length < 12) caracteres.push(elegir(todos));

  // Mezclar para que la mayúscula y el número no estén siempre al principio
  for (let i = caracteres.length - 1; i > 0; i--) {
    const j = nodeCrypto.randomInt(i + 1);
    [caracteres[i], caracteres[j]] = [caracteres[j], caracteres[i]];
  }
  return caracteres.join('');
}

// Quita espacios sobrantes; devuelve null si queda vacío
function textoLimpio(valor, maximo = 120) {
  if (typeof valor !== 'string') return null;
  const limpio = valor.trim().replace(/\s+/g, ' ');
  return limpio ? limpio.slice(0, maximo) : null;
}

function errorDatos(res, mensaje) {
  return res.status(400).json({ success: false, error: mensaje });
}

router.post('/mantenimiento/usuarios', authenticateToken, exigirAccesoDashboard(['mantenimiento']), async (req, res) => {
  try {
    const empresaId = empresaDelPerfil(req, res);
    if (!empresaId) return;

    // 1) Leer y limpiar los datos del formulario
    const cuerpo = req.body || {};
    const first_name = textoLimpio(cuerpo.first_name, 60);
    const last_name_1 = textoLimpio(cuerpo.last_name_1, 60);
    const last_name_2 = textoLimpio(cuerpo.last_name_2, 60);
    const job_title = textoLimpio(cuerpo.job_title, 120);
    const email = typeof cuerpo.email === 'string' ? cuerpo.email.trim().toLowerCase() : '';
    const department_id = cuerpo.department_id || null;
    const team_id = cuerpo.team_id || null;
    const hire_date = cuerpo.hire_date || null;

    // 2) Validaciones
    if (!first_name || !last_name_1) return errorDatos(res, 'El nombre y el primer apellido son obligatorios.');
    if (!FORMATO_EMAIL.test(email)) return errorDatos(res, 'El email no es válido.');
    if (department_id && !FORMATO_UUID.test(department_id)) return errorDatos(res, 'Departamento no válido.');
    if (team_id && !FORMATO_UUID.test(team_id)) return errorDatos(res, 'Equipo no válido.');
    if (hire_date && (!FORMATO_FECHA.test(hire_date) || Number.isNaN(Date.parse(hire_date)))) {
      return errorDatos(res, 'La fecha de ingreso debe tener el formato AAAA-MM-DD.');
    }

    // 3) El departamento y el equipo tienen que ser de la empresa del administrador
    let departamento = null;
    if (department_id) {
      const { data, error } = await db
        .from('departments')
        .select('id, name')
        .eq('id', department_id)
        .eq('company_id', empresaId)
        .maybeSingle();
      if (error) throw error;
      if (!data) return errorDatos(res, 'Ese departamento no existe en tu empresa.');
      departamento = data;
    }

    if (team_id) {
      const { data: equipo, error } = await db
        .from('teams')
        .select('id, department_id')
        .eq('id', team_id)
        .maybeSingle();
      if (error) throw error;
      if (!equipo) return errorDatos(res, 'Ese equipo no existe.');

      if (departamento && equipo.department_id !== departamento.id) {
        return errorDatos(res, 'El equipo elegido no pertenece a ese departamento.');
      }
      if (!departamento) {
        // Sin departamento elegido: se toma el del equipo (comprobando que sea de la empresa)
        const { data: depEquipo, error: errDep } = await db
          .from('departments')
          .select('id, name')
          .eq('id', equipo.department_id)
          .eq('company_id', empresaId)
          .maybeSingle();
        if (errDep) throw errDep;
        if (!depEquipo) return errorDatos(res, 'Ese equipo no existe en tu empresa.');
        departamento = depEquipo;
      }
    }

    // 4) El email no puede estar ya registrado
    const { data: existentes, error: errExiste } = await db
      .from('users')
      .select('id')
      .eq('email', email)
      .limit(1);
    if (errExiste) throw errExiste;
    if (existentes.length > 0) {
      return res.status(409).json({ success: false, error: 'Ya existe una persona con ese email.' });
    }

    // 5) Crear la cuenta en Supabase Auth, ya confirmada, con contraseña temporal
    const passwordTemporal = generarPasswordTemporal();
    const { data: creado, error: errAuth } = await db.auth.admin.createUser({
      email,
      password: passwordTemporal,
      email_confirm: true,
    });
    if (errAuth) {
      if (/already|registered|exists/i.test(errAuth.message)) {
        return res.status(409).json({ success: false, error: 'Ya existe una cuenta con ese email.' });
      }
      throw errAuth;
    }
    const nuevoId = creado.user.id;

    // 6) Fila en users: mismos campos que el registro de la app + los nuevos
    const full_name = [first_name, last_name_1, last_name_2].filter(Boolean).join(' ');
    const { data: fila, error: errFila } = await db
      .from('users')
      .insert([{
        id: nuevoId,
        company_id: empresaId,
        email,
        full_name,
        first_name,
        last_name_1,
        last_name_2,
        department: departamento ? departamento.name : null,
        department_id: departamento ? departamento.id : null,
        team_id,
        job_title,
        hire_date,
        role: 'collaborator',
        is_active: true,
        status: 'invitado',
      }])
      .select('id, email, full_name, status')
      .single();

    if (errFila) {
      // 7) Deshacer: sin fila en users, se borra la cuenta de Auth para no dejarla huérfana
      await db.auth.admin.deleteUser(nuevoId);
      throw errFila;
    }

    // 8) Respuesta. La contraseña solo viaja aquí, una vez; nunca se escribe en el log
    console.log(`Alta de usuario ${email} por el administrador ${req.user.id}`);
    res.set('Cache-Control', 'no-store');
    res.status(201).json({
      success: true,
      usuario: { id: fila.id, email: fila.email, nombre: fila.full_name, estado: fila.status },
      password_temporal: passwordTemporal,
    });
  } catch (err) {
    console.error('Error en alta de usuario:', err.message);
    res.status(500).json({ success: false, error: `No se pudo crear el usuario: ${err.message}` });
  }
});

module.exports = router;