// =====================================================================
// ACCESO AL DASHBOARD: perfil del usuario conectado, niveles y menú
// =====================================================================
const { db } = require('./db');

// Orden en que se muestran los niveles en el menú
const ORDEN_NIVELES = ['retup', 'rrhh_gerencia', 'jefatura', 'mantenimiento'];

// Pantallas de cada nivel (según el documento de necesidades del dashboard)
const MENU_POR_NIVEL = {
  retup: {
    etiqueta: 'RetUp · Centro de control',
    pantallas: [
      { clave: 'centro-control', titulo: 'Resumen' },
      { clave: 'duracion',       titulo: 'Duración por reto' },
      { clave: 'retencion',      titulo: 'Retención por sección' },
      { clave: 'horarios',       titulo: '¿A qué hora se conectan?' },
      { clave: 'diagnostico',    titulo: 'Diagnóstico por pantalla' },
    ],
  },
  rrhh_gerencia: {
    etiqueta: 'RRHH · Gerencia',
    pantallas: [
      { clave: 'resumen',    titulo: 'Resumen' },
      { clave: 'mapa-calor', titulo: 'Mapa de calor' },
      { clave: 'brechas',    titulo: 'Mapa de brechas' },
      { clave: 'activacion', titulo: 'Activación por área' },
      { clave: 'exportar',   titulo: 'Exportar datos' },
    ],
  },
  jefatura: {
    etiqueta: 'Jefatura',
    pantallas: [
      { clave: 'mi-equipo', titulo: 'Mi equipo' },
    ],
  },
  mantenimiento: {
    etiqueta: 'Mantenimiento',
    pantallas: [
      { clave: 'atencion',   titulo: 'Requiere atención' },
      { clave: 'directorio', titulo: 'Directorio de usuarios' },
    ],
  },
};

// Iniciales para el icono redondo de la cabecera (ej. "Gerente RRHH" -> "GR")
function calcularIniciales(u) {
  const partes = [u.first_name, u.last_name_1].filter(Boolean);
  const base = partes.length > 0
    ? partes
    : String(u.full_name || u.email || '?').trim().split(/\s+/);
  return base.slice(0, 2).map(p => p.charAt(0).toUpperCase()).join('');
}

// Carga todo lo que el dashboard necesita saber del usuario conectado
async function cargarPerfilDashboard(userId) {
  // 1) Datos del usuario
  const { data: user, error: errorUser } = await db
    .from('users')
    .select('id, email, full_name, first_name, last_name_1, job_title, company_id, is_active, status')
    .eq('id', userId)
    .maybeSingle();
  if (errorUser) throw errorUser;
  if (!user) return null;

  // 2) Niveles de acceso al dashboard
  const { data: accesos, error: errorAccesos } = await db
    .from('dashboard_access')
    .select('level')
    .eq('user_id', userId);
  if (errorAccesos) throw errorAccesos;

  const niveles = ORDEN_NIVELES.filter(n => accesos.some(a => a.level === n));

  // 3) Empresa y correo de soporte (el admin de RetUp no tiene empresa)
  let empresa = null;
  let soporteEmail = null;
  if (user.company_id) {
    const { data: company, error: errorCompany } = await db
      .from('companies')
      .select('id, name')
      .eq('id', user.company_id)
      .maybeSingle();
    if (errorCompany) throw errorCompany;
    empresa = company;

    const { data: ajustes, error: errorAjustes } = await db
      .from('company_settings')
      .select('support_email')
      .eq('company_id', user.company_id)
      .maybeSingle();
    if (errorAjustes) throw errorAjustes;
    soporteEmail = ajustes?.support_email || null;
  }

  // 4) Equipos que dirige (solo si tiene nivel Jefatura)
  let equiposACargo = [];
  if (niveles.includes('jefatura')) {
    const { data: equipos, error: errorEquipos } = await db
      .from('teams')
      .select('id, name, department_id')
      .eq('leader_user_id', userId)
      .eq('is_active', true);
    if (errorEquipos) throw errorEquipos;
    equiposACargo = equipos;
  }

  return {
    usuario: {
      id: user.id,
      email: user.email,
      nombre: user.full_name,
      iniciales: calcularIniciales(user),
      cargo: user.job_title,
    },
    empresa,
    niveles,
    equipos_a_cargo: equiposACargo,
    soporte_email: soporteEmail,
    menu: niveles.map(n => ({
      nivel: n,
      etiqueta: MENU_POR_NIVEL[n].etiqueta,
      pantallas: MENU_POR_NIVEL[n].pantallas,
    })),
    // Uso interno: para bloquear usuarios dados de baja o bloqueados
    _activo: user.is_active !== false && !['bloqueado', 'baja'].includes(user.status),
  };
}

// Devuelve el motivo por el que NO puede entrar, o null si puede
function motivoSinAcceso(perfil) {
  if (!perfil) return 'Usuario no encontrado';
  if (!perfil._activo) return 'Tu usuario está bloqueado o dado de baja';
  if (perfil.niveles.length === 0) return 'Tu usuario no tiene acceso al dashboard';
  return null;
}

// Quita los campos internos antes de enviar el perfil al navegador
function perfilPublico(perfil) {
  const { _activo, ...resto } = perfil;
  return resto;
}

// GUARDIÁN para las rutas del dashboard.
// Uso: exigirAccesoDashboard()                  -> cualquier nivel
//      exigirAccesoDashboard(['rrhh_gerencia']) -> solo ese nivel
function exigirAccesoDashboard(nivelesPermitidos = null) {
  return async (req, res, next) => {
    try {
      const perfil = await cargarPerfilDashboard(req.user.id);

      const motivo = motivoSinAcceso(perfil);
      if (motivo) {
        return res.status(403).json({ success: false, error: motivo });
      }

      if (nivelesPermitidos && !nivelesPermitidos.some(n => perfil.niveles.includes(n))) {
        return res.status(403).json({ success: false, error: 'No tienes acceso a esta sección' });
      }

      req.dashboard = perfil;
      next();
    } catch (error) {
      console.error('❌ Error en exigirAccesoDashboard:', error.message);
      res.status(500).json({ success: false, error: error.message });
    }
  };
}

module.exports = {
  cargarPerfilDashboard,
  motivoSinAcceso,
  perfilPublico,
  exigirAccesoDashboard,
};