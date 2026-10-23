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
        debe_cambiar_password: true,
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

// ===================== MANTENIMIENTO · ACCIONES SOBRE UNA PERSONA =====================

// Carga a la persona SOLO si es de la empresa del administrador.
// Devuelve { empresaId, persona } o null (y ya ha respondido con el error).
async function personaDeMiEmpresa(req, res) {
  const empresaId = empresaDelPerfil(req, res);
  if (!empresaId) return null;

  const id = req.params.id;
  if (!FORMATO_UUID.test(id)) {
    errorDatos(res, 'Usuario no válido.');
    return null;
  }

  const { data, error } = await db
    .from('users')
    .select('id, email, full_name, status, is_active')
    .eq('id', id)
    .eq('company_id', empresaId)
    .maybeSingle();
  if (error) throw error;

  if (!data) {
    res.status(404).json({ success: false, error: 'Esa persona no existe en tu empresa.' });
    return null;
  }
  return { empresaId, persona: data };
}

// Estado "real" de una persona (igual que en el directorio)
function estadoActual(persona) {
  return persona.is_active === false ? 'baja' : persona.status;
}

// Comprueba que departamento y equipo sean de la empresa. Si solo llega el equipo,
// el departamento se toma del equipo. Devuelve { departamento } o { error }.
async function resolverDepartamentoEquipo(empresaId, department_id, team_id) {
  let departamento = null;

  if (department_id) {
    const { data, error } = await db
      .from('departments')
      .select('id, name')
      .eq('id', department_id)
      .eq('company_id', empresaId)
      .maybeSingle();
    if (error) throw error;
    if (!data) return { error: 'Ese departamento no existe en tu empresa.' };
    departamento = data;
  }

  if (team_id) {
    const { data: equipo, error } = await db
      .from('teams')
      .select('id, department_id')
      .eq('id', team_id)
      .maybeSingle();
    if (error) throw error;
    if (!equipo) return { error: 'Ese equipo no existe.' };

    if (departamento && equipo.department_id !== departamento.id) {
      return { error: 'El equipo elegido no pertenece a ese departamento.' };
    }
    if (!departamento) {
      const { data: depEquipo, error: errDep } = await db
        .from('departments')
        .select('id, name')
        .eq('id', equipo.department_id)
        .eq('company_id', empresaId)
        .maybeSingle();
      if (errDep) throw errDep;
      if (!depEquipo) return { error: 'Ese equipo no existe en tu empresa.' };
      departamento = depEquipo;
    }
  }

  return { departamento };
}

// ── 1) Restablecer contraseña (contraseña temporal nueva, se muestra una vez) ──
router.post('/mantenimiento/usuarios/:id/restablecer-password', authenticateToken, exigirAccesoDashboard(['mantenimiento']), async (req, res) => {
  try {
    const encontrado = await personaDeMiEmpresa(req, res);
    if (!encontrado) return;
    const { persona } = encontrado;

    if (estadoActual(persona) === 'baja') {
      return errorDatos(res, 'Esta persona está de baja. Reactívala antes de restablecer su contraseña.');
    }

    const passwordTemporal = generarPasswordTemporal();
    const { error: errAuth } = await db.auth.admin.updateUserById(persona.id, { password: passwordTemporal });
    if (errAuth) throw errAuth;

    // Ya está atendido: se quita el aviso de "Pidió restablecer contraseña"
    const { error: errFila } = await db
      .from('users')
            .update({ password_reset_requested_at: null, debe_cambiar_password: true })
      .eq('id', persona.id);
    if (errFila) throw errFila;

    console.log(`Contraseña restablecida para ${persona.email} por el administrador ${req.user.id}`);
    res.set('Cache-Control', 'no-store');
    res.json({
      success: true,
      usuario: { id: persona.id, email: persona.email, nombre: persona.full_name },
      password_temporal: passwordTemporal,
    });
  } catch (err) {
    console.error('Error al restablecer contraseña:', err.message);
    res.status(500).json({ success: false, error: `No se pudo restablecer la contraseña: ${err.message}` });
  }
});

// ── 2) Cambiar estado: bloquear / desbloquear / baja / reactivar ──
// "desde": estados en los que se permite la acción. "ban": bloqueo en Supabase Auth.
const ACCIONES_ESTADO = {
  bloquear: { desde: ['activo', 'invitado'], status: 'bloqueado', is_active: true, ban: '876000h' },
  desbloquear: { desde: ['bloqueado'], status: 'activo', is_active: true, ban: 'none' },
  baja: { desde: ['activo', 'invitado', 'bloqueado'], status: 'baja', is_active: false, ban: '876000h' },
  reactivar: { desde: ['baja'], status: 'activo', is_active: true, ban: 'none' },
};

router.post('/mantenimiento/usuarios/:id/estado', authenticateToken, exigirAccesoDashboard(['mantenimiento']), async (req, res) => {
  try {
    const accion = req.body && req.body.accion;
    const cambio = ACCIONES_ESTADO[accion];
    if (!cambio) return errorDatos(res, 'Acción no válida.');

    const encontrado = await personaDeMiEmpresa(req, res);
    if (!encontrado) return;
    const { persona } = encontrado;

    if (persona.id === req.user.id) {
      return errorDatos(res, 'No puedes cambiar tu propio estado.');
    }

    const actual = estadoActual(persona);
    if (!cambio.desde.includes(actual)) {
      return errorDatos(res, `No se puede ${accion === 'baja' ? 'dar de baja' : accion} a una persona en estado "${actual}".`);
    }

    // a) Fila en users
    const { error: errFila } = await db
      .from('users')
      .update({ status: cambio.status, is_active: cambio.is_active })
      .eq('id', persona.id);
    if (errFila) throw errFila;

    // b) Supabase Auth: impedir (o volver a permitir) el inicio de sesión
    const { error: errAuth } = await db.auth.admin.updateUserById(persona.id, { ban_duration: cambio.ban });
    if (errAuth) {
      // Si Auth falla, la fila vuelve a como estaba para que no se contradigan
      await db.from('users').update({ status: persona.status, is_active: persona.is_active }).eq('id', persona.id);
      throw errAuth;
    }

    console.log(`Estado de ${persona.email}: ${actual} -> ${cambio.status} (acción "${accion}") por ${req.user.id}`);
    res.json({ success: true, usuario: { id: persona.id, email: persona.email, estado: cambio.status } });
  } catch (err) {
    console.error('Error al cambiar estado:', err.message);
    res.status(500).json({ success: false, error: `No se pudo cambiar el estado: ${err.message}` });
  }
});

// ── 3) Editar datos de una persona ──
router.put('/mantenimiento/usuarios/:id', authenticateToken, exigirAccesoDashboard(['mantenimiento']), async (req, res) => {
  try {
    const encontrado = await personaDeMiEmpresa(req, res);
    if (!encontrado) return;
    const { empresaId, persona } = encontrado;

    const cuerpo = req.body || {};
    const first_name = textoLimpio(cuerpo.first_name, 60);
    const last_name_1 = textoLimpio(cuerpo.last_name_1, 60);
    const last_name_2 = textoLimpio(cuerpo.last_name_2, 60);
    const job_title = textoLimpio(cuerpo.job_title, 120);
    const department_id = cuerpo.department_id || null;
    const team_id = cuerpo.team_id || null;
    const hire_date = cuerpo.hire_date || null;

    if (!first_name || !last_name_1) return errorDatos(res, 'El nombre y el primer apellido son obligatorios.');
    if (department_id && !FORMATO_UUID.test(department_id)) return errorDatos(res, 'Departamento no válido.');
    if (team_id && !FORMATO_UUID.test(team_id)) return errorDatos(res, 'Equipo no válido.');
    if (hire_date && (!FORMATO_FECHA.test(hire_date) || Number.isNaN(Date.parse(hire_date)))) {
      return errorDatos(res, 'La fecha de ingreso debe tener el formato AAAA-MM-DD.');
    }

    const resuelto = await resolverDepartamentoEquipo(empresaId, department_id, team_id);
    if (resuelto.error) return errorDatos(res, resuelto.error);
    const departamento = resuelto.departamento;

    const { data: fila, error } = await db
      .from('users')
      .update({
        first_name,
        last_name_1,
        last_name_2,
        full_name: [first_name, last_name_1, last_name_2].filter(Boolean).join(' '),
        job_title,
        hire_date,
        department: departamento ? departamento.name : null,
        department_id: departamento ? departamento.id : null,
        team_id,
      })
      .eq('id', persona.id)
      .select('id, email, full_name, job_title, department_id, team_id, hire_date')
      .single();
    if (error) throw error;

    console.log(`Datos de ${persona.email} editados por ${req.user.id}`);
    res.json({ success: true, usuario: fila });
  } catch (err) {
    console.error('Error al editar usuario:', err.message);
    res.status(500).json({ success: false, error: `No se pudieron guardar los cambios: ${err.message}` });
  }
});

// ===================== MANTENIMIENTO · DEPARTAMENTOS Y EQUIPOS =====================

// Departamento SOLO si es de la empresa (o null)
async function departamentoDeMiEmpresa(id, empresaId) {
  const { data, error } = await db
    .from('departments')
    .select('id, name, is_active')
    .eq('id', id)
    .eq('company_id', empresaId)
    .maybeSingle();
  if (error) throw error;
  return data;
}

// Equipo SOLO si es de la empresa (o null)
async function equipoDeMiEmpresa(id, empresaId) {
  const { data, error } = await db
    .from('teams')
    .select('id, name, is_active, department_id')
    .eq('id', id)
    .eq('company_id', empresaId)
    .maybeSingle();
  if (error) throw error;
  return data;
}

// ¿Ya existe ese nombre entre los "hermanos"? (sin distinguir mayúsculas)
async function nombreRepetido(tabla, campoPadre, idPadre, nombre, idExcluido) {
  const { data, error } = await db.from(tabla).select('id, name').eq(campoPadre, idPadre);
  if (error) throw error;
  const buscado = nombre.toLocaleLowerCase('es');
  return data.some((fila) => fila.id !== idExcluido && fila.name.toLocaleLowerCase('es') === buscado);
}

// Personas que NO están de baja asignadas a un departamento o equipo
async function contarPersonasActivas(campo, id) {
  const { count, error } = await db
    .from('users')
    .select('id', { count: 'exact', head: true })
    .eq(campo, id)
    .eq('is_active', true)
    .neq('status', 'baja');
  if (error) throw error;
  return count || 0;
}

function textoPersonas(n) {
  return n === 1 ? '1 persona activa' : `${n} personas activas`;
}

function respuestaNombreRepetido(res, que) {
  return res.status(409).json({ success: false, error: `Ya existe ${que} con ese nombre.` });
}

// ── Crear departamento ──
router.post('/mantenimiento/departamentos', authenticateToken, exigirAccesoDashboard(['mantenimiento']), async (req, res) => {
  try {
    const empresaId = empresaDelPerfil(req, res);
    if (!empresaId) return;

    const nombre = textoLimpio((req.body || {}).nombre, 80);
    if (!nombre) return errorDatos(res, 'El nombre del departamento es obligatorio.');
    if (await nombreRepetido('departments', 'company_id', empresaId, nombre, null)) {
      return respuestaNombreRepetido(res, 'un departamento');
    }

    const { data, error } = await db
      .from('departments')
      .insert([{ company_id: empresaId, name: nombre }])
      .select('id, name, is_active')
      .single();
    if (error) {
      if (error.code === '23505') return respuestaNombreRepetido(res, 'un departamento');
      throw error;
    }

    console.log(`Departamento "${nombre}" creado por ${req.user.id}`);
    res.status(201).json({ success: true, departamento: data });
  } catch (err) {
    console.error('Error al crear departamento:', err.message);
    res.status(500).json({ success: false, error: `No se pudo crear el departamento: ${err.message}` });
  }
});

// ── Renombrar / desactivar / reactivar departamento ──
router.put('/mantenimiento/departamentos/:id', authenticateToken, exigirAccesoDashboard(['mantenimiento']), async (req, res) => {
  try {
    const empresaId = empresaDelPerfil(req, res);
    if (!empresaId) return;
    if (!FORMATO_UUID.test(req.params.id)) return errorDatos(res, 'Departamento no válido.');

    const dep = await departamentoDeMiEmpresa(req.params.id, empresaId);
    if (!dep) return res.status(404).json({ success: false, error: 'Ese departamento no existe en tu empresa.' });

    const cuerpo = req.body || {};
    const cambios = {};

    if (cuerpo.nombre !== undefined) {
      const nombre = textoLimpio(cuerpo.nombre, 80);
      if (!nombre) return errorDatos(res, 'El nombre no puede estar vacío.');
      if (await nombreRepetido('departments', 'company_id', empresaId, nombre, dep.id)) {
        return respuestaNombreRepetido(res, 'un departamento');
      }
      cambios.name = nombre;
    }

    if (cuerpo.activo !== undefined) {
      if (typeof cuerpo.activo !== 'boolean') return errorDatos(res, 'Valor de "activo" no válido.');
      if (cuerpo.activo === false && dep.is_active) {
        const personas = await contarPersonasActivas('department_id', dep.id);
        if (personas > 0) {
          return errorDatos(res, `No se puede desactivar: tiene ${textoPersonas(personas)}. Muévelas antes a otro departamento.`);
        }
        const { count: equiposActivos, error: errEq } = await db
          .from('teams')
          .select('id', { count: 'exact', head: true })
          .eq('department_id', dep.id)
          .eq('is_active', true);
        if (errEq) throw errEq;
        if (equiposActivos > 0) {
          return errorDatos(res, `No se puede desactivar: tiene ${equiposActivos} ${equiposActivos === 1 ? 'equipo activo' : 'equipos activos'}. Desactívalos antes.`);
        }
      }
      cambios.is_active = cuerpo.activo;
    }

    if (Object.keys(cambios).length === 0) return errorDatos(res, 'No hay cambios que guardar.');

    const { data, error } = await db
      .from('departments')
      .update(cambios)
      .eq('id', dep.id)
      .select('id, name, is_active')
      .single();
    if (error) {
      if (error.code === '23505') return respuestaNombreRepetido(res, 'un departamento');
      throw error;
    }

    // La app móvil muestra users.department (texto): se mantiene igual al nombre nuevo
    if (cambios.name && cambios.name !== dep.name) {
      const { error: errUsu } = await db.from('users').update({ department: cambios.name }).eq('department_id', dep.id);
      if (errUsu) throw errUsu;
    }

    console.log(`Departamento "${dep.name}" modificado por ${req.user.id}:`, cambios);
    res.json({ success: true, departamento: data });
  } catch (err) {
    console.error('Error al modificar departamento:', err.message);
    res.status(500).json({ success: false, error: `No se pudo modificar el departamento: ${err.message}` });
  }
});

// ── Crear equipo ──
router.post('/mantenimiento/equipos', authenticateToken, exigirAccesoDashboard(['mantenimiento']), async (req, res) => {
  try {
    const empresaId = empresaDelPerfil(req, res);
    if (!empresaId) return;

    const cuerpo = req.body || {};
    const nombre = textoLimpio(cuerpo.nombre, 80);
    if (!nombre) return errorDatos(res, 'El nombre del equipo es obligatorio.');
    if (!FORMATO_UUID.test(cuerpo.department_id || '')) return errorDatos(res, 'Elige un departamento válido.');

    const dep = await departamentoDeMiEmpresa(cuerpo.department_id, empresaId);
    if (!dep) return errorDatos(res, 'Ese departamento no existe en tu empresa.');
    if (!dep.is_active) return errorDatos(res, 'Ese departamento está desactivado. Reactívalo antes de crear equipos.');

    if (await nombreRepetido('teams', 'department_id', dep.id, nombre, null)) {
      return respuestaNombreRepetido(res, 'un equipo en ese departamento');
    }

    const { data, error } = await db
      .from('teams')
      .insert([{ company_id: empresaId, department_id: dep.id, name: nombre }])
      .select('id, name, is_active, department_id')
      .single();
    if (error) {
      if (error.code === '23505') return respuestaNombreRepetido(res, 'un equipo en ese departamento');
      throw error;
    }

    console.log(`Equipo "${nombre}" creado en "${dep.name}" por ${req.user.id}`);
    res.status(201).json({ success: true, equipo: data });
  } catch (err) {
    console.error('Error al crear equipo:', err.message);
    res.status(500).json({ success: false, error: `No se pudo crear el equipo: ${err.message}` });
  }
});

// ── Renombrar / desactivar / reactivar equipo ──
router.put('/mantenimiento/equipos/:id', authenticateToken, exigirAccesoDashboard(['mantenimiento']), async (req, res) => {
  try {
    const empresaId = empresaDelPerfil(req, res);
    if (!empresaId) return;
    if (!FORMATO_UUID.test(req.params.id)) return errorDatos(res, 'Equipo no válido.');

    const equipo = await equipoDeMiEmpresa(req.params.id, empresaId);
    if (!equipo) return res.status(404).json({ success: false, error: 'Ese equipo no existe en tu empresa.' });

    const cuerpo = req.body || {};
    const cambios = {};

    if (cuerpo.nombre !== undefined) {
      const nombre = textoLimpio(cuerpo.nombre, 80);
      if (!nombre) return errorDatos(res, 'El nombre no puede estar vacío.');
      if (await nombreRepetido('teams', 'department_id', equipo.department_id, nombre, equipo.id)) {
        return respuestaNombreRepetido(res, 'un equipo en ese departamento');
      }
      cambios.name = nombre;
    }

    if (cuerpo.activo !== undefined) {
      if (typeof cuerpo.activo !== 'boolean') return errorDatos(res, 'Valor de "activo" no válido.');
      if (cuerpo.activo === false && equipo.is_active) {
        const personas = await contarPersonasActivas('team_id', equipo.id);
        if (personas > 0) {
          return errorDatos(res, `No se puede desactivar: tiene ${textoPersonas(personas)}. Muévelas antes a otro equipo.`);
        }
      }
      if (cuerpo.activo === true && !equipo.is_active) {
        const dep = await departamentoDeMiEmpresa(equipo.department_id, empresaId);
        if (!dep || !dep.is_active) {
          return errorDatos(res, 'Su departamento está desactivado. Reactiva antes el departamento.');
        }
      }
      cambios.is_active = cuerpo.activo;
    }

    if (Object.keys(cambios).length === 0) return errorDatos(res, 'No hay cambios que guardar.');

    const { data, error } = await db
      .from('teams')
      .update(cambios)
      .eq('id', equipo.id)
      .select('id, name, is_active, department_id')
      .single();
    if (error) {
      if (error.code === '23505') return respuestaNombreRepetido(res, 'un equipo en ese departamento');
      throw error;
    }

    console.log(`Equipo "${equipo.name}" modificado por ${req.user.id}:`, cambios);
    res.json({ success: true, equipo: data });
  } catch (err) {
    console.error('Error al modificar equipo:', err.message);
    res.status(500).json({ success: false, error: `No se pudo modificar el equipo: ${err.message}` });
  }
});

// ===================== MANTENIMIENTO · ALTA MASIVA POR CSV =====================
const MAX_FILAS_CSV = 300;

// Minúsculas y sin tildes, para comparar "logistica" con "Logística"
function normalizarClave(texto) {
  return texto.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLocaleLowerCase('es').trim();
}

// Acepta AAAA-MM-DD, DD/MM/AAAA o DD-MM-AAAA.
// Devuelve 'AAAA-MM-DD', null si está vacía, o false si no es una fecha real.
function leerFechaCsv(valor) {
  const texto = typeof valor === 'string' ? valor.trim() : '';
  if (!texto) return null;

  let anio;
  let mes;
  let dia;
  let partes = texto.match(/^(\d{4})-(\d{1,2})-(\d{1,2})$/);
  if (partes) {
    [, anio, mes, dia] = partes;
  } else {
    partes = texto.match(/^(\d{1,2})[/-](\d{1,2})[/-](\d{4})$/);
    if (!partes) return false;
    [, dia, mes, anio] = partes;
  }

  const iso = `${anio}-${mes.padStart(2, '0')}-${dia.padStart(2, '0')}`;
  const fecha = new Date(`${iso}T00:00:00Z`);
  // Si la fecha no existe (31/02), JavaScript la "corrige" a otro día: así lo detectamos
  if (Number.isNaN(fecha.getTime()) || fecha.toISOString().slice(0, 10) !== iso) return false;
  return iso;
}

// Revisa todas las filas SIN crear nada. Devuelve el resultado de cada fila
// y los departamentos/equipos que habría que crear.
async function validarFilasCsv(empresaId, filas) {
  // Catálogo actual de la empresa
  const { data: departamentos, error: errDep } = await db
    .from('departments')
    .select('id, name, is_active')
    .eq('company_id', empresaId);
  if (errDep) throw errDep;

  const { data: equipos, error: errEq } = await db
    .from('teams')
    .select('id, name, is_active, department_id')
    .eq('company_id', empresaId);
  if (errEq) throw errEq;

  const departamentoPorClave = new Map(departamentos.map((d) => [normalizarClave(d.name), d]));
  const equipoPorClave = new Map(equipos.map((t) => [`${t.department_id}|${normalizarClave(t.name)}`, t]));

  // Emails que ya existen en RetUp (se consultan de 100 en 100)
  const emails = [
    ...new Set(
      filas
        .map((f) => (typeof f.email === 'string' ? f.email.trim().toLowerCase() : ''))
        .filter(Boolean),
    ),
  ];
  const emailsExistentes = new Set();
  for (let i = 0; i < emails.length; i += 100) {
    const { data, error } = await db.from('users').select('email').in('email', emails.slice(i, i + 100));
    if (error) throw error;
    data.forEach((u) => emailsExistentes.add(String(u.email).toLowerCase()));
  }

  const emailsVistos = new Set();
  const departamentosNuevos = new Map(); // clave -> nombre tal como viene en el CSV
  const equiposNuevos = new Map(); // "claveDep|claveEq" -> { claveDep, nombre }

  const resultados = filas.map((fila, indice) => {
    const errores = [];
    const first_name = textoLimpio(fila.nombre, 60);
    const last_name_1 = textoLimpio(fila.apellido1, 60);
    const last_name_2 = textoLimpio(fila.apellido2, 60);
    const job_title = textoLimpio(fila.cargo, 120);
    const email = typeof fila.email === 'string' ? fila.email.trim().toLowerCase() : '';
    const nombreDepartamento = textoLimpio(fila.departamento, 80);
    const nombreEquipo = textoLimpio(fila.equipo, 80);
    const hire_date = leerFechaCsv(fila.fecha_ingreso);

    if (!first_name) errores.push('Falta el nombre');
    if (!last_name_1) errores.push('Falta el primer apellido');
    if (!FORMATO_EMAIL.test(email)) {
      errores.push('Email no válido');
    } else if (emailsVistos.has(email)) {
      errores.push('Email repetido en el archivo');
    } else if (emailsExistentes.has(email)) {
      errores.push('Ya existe una persona con ese email');
    }
    if (FORMATO_EMAIL.test(email)) emailsVistos.add(email);
    if (hire_date === false) errores.push('Fecha de ingreso no válida (usa DD/MM/AAAA)');
    if (nombreEquipo && !nombreDepartamento) errores.push('Tiene equipo pero falta el departamento');

    let departamento = null;
    let equipo = null;

    if (nombreDepartamento) {
      const claveDep = normalizarClave(nombreDepartamento);
      const existente = departamentoPorClave.get(claveDep);
      if (existente) {
        if (!existente.is_active) errores.push(`El departamento "${existente.name}" está desactivado`);
        departamento = { id: existente.id, nombre: existente.name, clave: claveDep, nuevo: false };
      } else {
        if (!departamentosNuevos.has(claveDep)) departamentosNuevos.set(claveDep, nombreDepartamento);
        departamento = { id: null, nombre: departamentosNuevos.get(claveDep), clave: claveDep, nuevo: true };
      }

      if (nombreEquipo) {
        const claveEq = normalizarClave(nombreEquipo);
        const existenteEq = departamento.id ? equipoPorClave.get(`${departamento.id}|${claveEq}`) : null;
        if (existenteEq) {
          if (!existenteEq.is_active) errores.push(`El equipo "${existenteEq.name}" está desactivado`);
          equipo = { id: existenteEq.id, nombre: existenteEq.name, clave: null, nuevo: false };
        } else {
          const claveCompleta = `${claveDep}|${claveEq}`;
                  if (!equiposNuevos.has(claveCompleta)) {
            equiposNuevos.set(claveCompleta, { claveDep, nombre: nombreEquipo, departamento: departamento.nombre });
          }
          equipo = { id: null, nombre: equiposNuevos.get(claveCompleta).nombre, clave: claveCompleta, nuevo: true };
        }
      }
    }

    return {
      fila: indice + 2, // la fila 1 del archivo son los títulos
      datos: { first_name, last_name_1, last_name_2, email, job_title, hire_date: hire_date || null },
      departamento,
      equipo,
      errores,
    };
  });

  return { resultados, departamentosNuevos, equiposNuevos };
}

// Crea la cuenta (Auth) y la fila (users) de una persona invitada.
// Si la fila falla, borra la cuenta para no dejarla huérfana.
async function crearPersonaInvitada(empresaId, p) {
  const password = generarPasswordTemporal();
  const { data: creado, error: errAuth } = await db.auth.admin.createUser({
    email: p.email,
    password,
    email_confirm: true,
  });
  if (errAuth) {
    if (/already|registered|exists/i.test(errAuth.message)) throw new Error('Ya existe una cuenta con ese email');
    throw errAuth;
  }

  const id = creado.user.id;
  const { error: errFila } = await db.from('users').insert([{
    id,
    company_id: empresaId,
    email: p.email,
    full_name: [p.first_name, p.last_name_1, p.last_name_2].filter(Boolean).join(' '),
    first_name: p.first_name,
    last_name_1: p.last_name_1,
    last_name_2: p.last_name_2,
    department: p.department_name,
    department_id: p.department_id,
    team_id: p.team_id,
    job_title: p.job_title,
    hire_date: p.hire_date,
        role: 'collaborator',
    is_active: true,
    status: 'invitado',
    debe_cambiar_password: true,
  }]);
  if (errFila) {
    await db.auth.admin.deleteUser(id);
    throw errFila;
  }
  return { id, password };
}

router.post('/mantenimiento/usuarios/csv', authenticateToken, exigirAccesoDashboard(['mantenimiento']), async (req, res) => {
  try {
    const empresaId = empresaDelPerfil(req, res);
    if (!empresaId) return;

    const cuerpo = req.body || {};
    const filas = cuerpo.filas;
    // Por seguridad, si no se dice lo contrario, SOLO se simula
    const simular = cuerpo.simular !== false;

    if (!Array.isArray(filas) || filas.length === 0) return errorDatos(res, 'El archivo no tiene filas.');
    if (filas.length > MAX_FILAS_CSV) {
      return errorDatos(res, `Máximo ${MAX_FILAS_CSV} personas por archivo. Divide el archivo en partes.`);
    }

    // 1) Revisar todo (en simulación y también antes de importar)
    const revision = await validarFilasCsv(empresaId, filas);
    const conErrores = revision.resultados.filter((r) => r.errores.length > 0).length;

    const resumen = {
      total: filas.length,
      validas: filas.length - conErrores,
      con_errores: conErrores,
      departamentos_nuevos: [...revision.departamentosNuevos.values()],
           equipos_nuevos: [...revision.equiposNuevos.values()].map((eq) => `${eq.departamento} / ${eq.nombre}`),
    };

    const nombreCompleto = (d) => [d.first_name, d.last_name_1, d.last_name_2].filter(Boolean).join(' ');

    const vistaPrevia = revision.resultados.map((r) => ({
      fila: r.fila,
      nombre: nombreCompleto(r.datos),
      email: r.datos.email,
      departamento: r.departamento ? r.departamento.nombre : null,
      departamento_nuevo: Boolean(r.departamento && r.departamento.nuevo),
      equipo: r.equipo ? r.equipo.nombre : null,
      equipo_nuevo: Boolean(r.equipo && r.equipo.nuevo),
      errores: r.errores,
    }));

    if (simular) {
      return res.json({ success: true, simulacion: true, resumen, filas: vistaPrevia });
    }
    if (conErrores > 0) {
      return res.status(400).json({
        success: false,
        error: 'El archivo tiene errores. Corrígelos antes de importar.',
        resumen,
        filas: vistaPrevia,
      });
    }

    // 2) Crear departamentos nuevos
    const idDepartamento = new Map(); // claveDep -> id
    revision.resultados.forEach((r) => {
      if (r.departamento && !r.departamento.nuevo) idDepartamento.set(r.departamento.clave, r.departamento.id);
    });
    for (const [clave, nombre] of revision.departamentosNuevos) {
      const { data, error } = await db
        .from('departments')
        .insert([{ company_id: empresaId, name: nombre }])
        .select('id')
        .single();
      if (error) throw error;
      idDepartamento.set(clave, data.id);
    }

    // 3) Crear equipos nuevos
    const idEquipo = new Map(); // "claveDep|claveEq" -> id
    for (const [clave, eq] of revision.equiposNuevos) {
      const { data, error } = await db
        .from('teams')
        .insert([{ company_id: empresaId, department_id: idDepartamento.get(eq.claveDep), name: eq.nombre }])
        .select('id')
        .single();
      if (error) throw error;
      idEquipo.set(clave, data.id);
    }

    // 4) Crear a las personas, de una en una (si una falla, las demás siguen)
    const resultado = [];
    for (const r of revision.resultados) {
      const base = { fila: r.fila, nombre: nombreCompleto(r.datos), email: r.datos.email };
      try {
        const { password } = await crearPersonaInvitada(empresaId, {
          ...r.datos,
          department_id: r.departamento ? idDepartamento.get(r.departamento.clave) : null,
          department_name: r.departamento ? r.departamento.nombre : null,
          team_id: r.equipo ? (r.equipo.nuevo ? idEquipo.get(r.equipo.clave) : r.equipo.id) : null,
        });
        resultado.push({ ...base, estado: 'creada', password_temporal: password });
      } catch (errFila) {
        resultado.push({ ...base, estado: 'error', error: errFila.message });
      }
    }

    const creadas = resultado.filter((r) => r.estado === 'creada').length;
    console.log(`Importación CSV por ${req.user.id}: ${creadas} de ${filas.length} personas creadas`);

    res.set('Cache-Control', 'no-store');
    res.status(201).json({
      success: true,
      simulacion: false,
      resumen: { ...resumen, creadas, fallidas: filas.length - creadas },
      filas: resultado,
    });
  } catch (err) {
    console.error('Error en importación CSV:', err.message);
    res.status(500).json({ success: false, error: `No se pudo procesar el archivo: ${err.message}` });
  }
});

// ===================== CUENTA · CAMBIAR LA CONTRASEÑA TEMPORAL =====================
// La usa la APP (cualquier persona con sesión, no hace falta nivel de dashboard)
// tras entrar con una contraseña temporal: alta nueva o restablecimiento.
router.post('/cuenta/cambiar-password-temporal', authenticateToken, async (req, res) => {
  try {
    const passwordNueva =
      req.body && typeof req.body.password_nueva === 'string' ? req.body.password_nueva : '';
    if (!passwordNueva) {
      return res.status(400).json({ success: false, error: 'Escribe tu nueva contraseña.' });
    }

    const { data: usuario, error } = await db
      .from('users')
      .select('id, email, status, debe_cambiar_password')
      .eq('id', req.user.id)
      .maybeSingle();
    if (error) throw error;
    if (!usuario) return res.status(404).json({ success: false, error: 'Usuario no encontrado.' });

    // Solo si tiene un cambio pendiente: no sirve para cambiar la contraseña sin conocer la actual
    if (!usuario.debe_cambiar_password) {
      return res.status(400).json({ success: false, error: 'No tienes ningún cambio de contraseña pendiente.' });
    }

    const { error: errAuth } = await db.auth.admin.updateUserById(usuario.id, { password: passwordNueva });
    if (errAuth) {
      if (/at least/i.test(errAuth.message)) {
        return res.status(400).json({ success: false, error: 'La contraseña es demasiado corta (mínimo 6 caracteres).' });
      }
      if (/same|different/i.test(errAuth.message)) {
        return res.status(400).json({ success: false, error: 'La contraseña nueva debe ser distinta de la temporal.' });
      }
      throw errAuth;
    }

    // Ya tiene su propia contraseña: si era invitado, pasa a activo
    const cambios = { debe_cambiar_password: false };
    if (usuario.status === 'invitado') cambios.status = 'activo';

    const { error: errFila } = await db.from('users').update(cambios).eq('id', usuario.id);
    if (errFila) throw errFila;

    console.log(`Contraseña temporal cambiada por ${usuario.email}`);
    res.json({ success: true, message: 'Contraseña actualizada.', status: cambios.status || usuario.status });
  } catch (err) {
    console.error('Error al cambiar la contraseña temporal:', err.message);
    res.status(500).json({ success: false, error: 'No se pudo cambiar la contraseña. Inténtalo de nuevo.' });
  }
});

// ===================== RRHH · GERENCIA =====================
// Siempre la empresa del perfil conectado y SOLO datos agregados
// (nunca datos de una persona concreta).

// ── Resumen: activos, finalización de retos, inscritos y retos del mes ──
router.get('/rrhh/resumen', authenticateToken, exigirAccesoDashboard(['rrhh_gerencia']), async (req, res) => {
  try {
    const empresaId = empresaDelPerfil(req, res);
    if (!empresaId) return;

    const rango = leerRango(req.query);
    if (rango.error) {
      return res.status(400).json({ success: false, error: rango.error });
    }

    const { data, error } = await db.rpc('dash_rrhh_resumen', {
      p_empresa: empresaId, // ← del perfil, nunca del navegador
      p_desde: rango.desde,
      p_hasta: rango.hasta,
      p_comp_desde: rango.comp_desde,
      p_comp_hasta: rango.comp_hasta,
    });
    if (error) throw error;

    res.json({ success: true, datos: data });
  } catch (err) {
    console.error('❌ Error en /dashboard/rrhh/resumen:', err.message);
    res.status(500).json({ success: false, error: 'No se pudieron calcular los indicadores' });
  }
});

// ── Activación por área: activación global y por departamento, finalización ──
router.get('/rrhh/activacion', authenticateToken, exigirAccesoDashboard(['rrhh_gerencia']), async (req, res) => {
  try {
    const empresaId = empresaDelPerfil(req, res);
    if (!empresaId) return;

    const rango = leerRango(req.query);
    if (rango.error) {
      return res.status(400).json({ success: false, error: rango.error });
    }

    const { data, error } = await db.rpc('dash_rrhh_activacion', {
      p_empresa: empresaId,
      p_desde: rango.desde,
      p_hasta: rango.hasta,
      p_comp_desde: rango.comp_desde,
      p_comp_hasta: rango.comp_hasta,
    });
    if (error) throw error;

    res.json({ success: true, datos: data });
  } catch (err) {
    console.error('❌ Error en /dashboard/rrhh/activacion:', err.message);
    res.status(500).json({ success: false, error: 'No se pudieron calcular los indicadores' });
  }
});

// ── Scores (siempre agregados y con umbral de privacidad): empresa, habilidades,
//    matriz departamento × habilidad, celdas sobre el umbral y evolución ──
router.get('/rrhh/scores', authenticateToken, exigirAccesoDashboard(['rrhh_gerencia']), async (req, res) => {
  try {
    const empresaId = empresaDelPerfil(req, res);
    if (!empresaId) return;

    const rango = leerRango(req.query);
    if (rango.error) {
      return res.status(400).json({ success: false, error: rango.error });
    }

    const frecuencia = ['dia', 'semana', 'mes'].includes(req.query.frecuencia)
      ? req.query.frecuencia
      : 'semana';

    const { data, error } = await db.rpc('dash_rrhh_scores', {
      p_empresa: empresaId,
      p_desde: rango.desde,
      p_hasta: rango.hasta,
      p_frecuencia: frecuencia,
    });
    if (error) throw error;

    res.json({ success: true, datos: data });
  } catch (err) {
    console.error('❌ Error en /dashboard/rrhh/scores:', err.message);
    res.status(500).json({ success: false, error: 'No se pudieron calcular los scores' });
  }
});

module.exports = router;