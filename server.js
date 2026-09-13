require('dotenv').config();
const { authenticateToken, authorizeRole } = require('./middleware');
const express = require('express');
const cors = require('cors');
const supabase = require('./supabase');
const app = express();
const PORT = process.env.PORT || 5000;

// Middleware
app.use(cors());
app.use(express.json());

// Rutas básicas (SIN protección)
app.get('/', (req, res) => {
  res.json({ message: 'RetUp API funcionando ✓' });
});

app.get('/health', (req, res) => {
  res.json({ status: 'OK', timestamp: new Date() });
});

// ===== ENDPOINTS DE AUTENTICACIÓN =====
app.post('/api/auth/register', async (req, res) => {
  try {
    console.log('DEBUG REGISTER - req.body:', req.body);
    console.log('DEBUG REGISTER - Headers:', req.headers);
    const { email, password, full_name, company_id, role } = req.body;

    console.log('PASO 1 - Intentando signUp en Supabase...');
    const { data: authData, error: authError } = await supabase.auth.signUp({
      email,
      password,
    });

    console.log('PASO 2 - Respuesta de Supabase:', { authData, authError });
    if (authError) {
      console.log('ERROR EN SUPABASE:', authError.message);
      throw authError;
    }

    console.log('PASO 3 - Intentando insertar usuario en tabla users...');
    const { data: userData, error: userError } = await supabase
      .from('users')
      .insert([{
        id: authData.user.id,
        company_id,
        email,
        full_name,
        role,
        is_active: true,
      }])
      .select();

    console.log('PASO 4 - Respuesta de insert:', { userData, userError });
    if (userError) {
      console.log('ERROR EN INSERT:', userError.message);
      throw userError;
    }

    console.log('PASO 5 - Registro exitoso');
    res.json({
      success: true,
      message: 'Usuario registrado exitosamente',
      user: userData[0]
    });
  } catch (error) {
    console.log('ERROR CAPTURADO:', error.message);
    res.status(400).json({ success: false, error: error.message });
  }
});

app.post('/api/auth/login', async (req, res) => {
  try {
    console.log('DEBUG - req.body:', req.body);
    console.log('DEBUG - Headers:', req.headers);

    const { email, password } = req.body;

    const { data, error } = await supabase.auth.signInWithPassword({
      email,
      password,
    });

    if (error) throw error;

    const { data: userData, error: userError } = await supabase
      .from('users')
      .select('*')
      .eq('id', data.user.id)
      .single();

    if (userError) throw userError;

    res.json({
      success: true,
      message: 'Login exitoso',
      token: data.session.access_token,
      user: userData,
    });
  } catch (error) {
    res.status(400).json({ success: false, error: error.message });
  }
});

app.post('/api/auth/logout', authenticateToken, async (req, res) => {
  try {
    res.json({ success: true, message: 'Logout exitoso' });
  } catch (error) {
    res.status(400).json({ success: false, error: error.message });
  }
});

// ===== ENDPOINTS DE COMPANIES (PROTEGIDOS) =====
app.get('/api/companies', authenticateToken, async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('companies')
      .select('*');

    if (error) throw error;
    res.json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.post('/api/companies', authenticateToken, authorizeRole(['super_admin']), async (req, res) => {
  try {
    const { name, subscription_level, max_employees } = req.body;

    const { data, error } = await supabase
      .from('companies')
      .insert([{ name, subscription_level, max_employees }])
      .select();

    if (error) throw error;
    res.json({ success: true, data: data[0] });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// ===== ENDPOINTS DE USERS (PROTEGIDOS) =====
app.get('/api/users', authenticateToken, async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('users')
      .select('*');

    if (error) throw error;
    res.json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.get('/api/users/:id', authenticateToken, async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('users')
      .select('*')
      .eq('id', req.params.id)
      .single();
    if (error) throw error;
    res.json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.get('/api/users/leaderboard', authenticateToken, async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('users')
      .select('*')
      .order('xp', { ascending: false });
    if (error) throw error;
    res.json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.post('/api/users', authenticateToken, authorizeRole(['super_admin', 'company_admin']), async (req, res) => {
  try {
    const { company_id, email, full_name, role } = req.body;
    const { data, error } = await supabase
      .from('users')
      .insert([{ company_id, email, full_name, role, is_active: true }])
      .select();
    if (error) throw error;
    res.json({ success: true, data: data[0] });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.put('/api/users/:id', authenticateToken, async (req, res) => {
  try {
    const { full_name, role, is_active } = req.body;
    const { data, error } = await supabase
      .from('users')
      .update({ full_name, role, is_active, updated_at: new Date() })
      .eq('id', req.params.id)
      .select();
    if (error) throw error;
    res.json({ success: true, data: data[0] });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.delete('/api/users/:id', authenticateToken, authorizeRole(['super_admin']), async (req, res) => {
  try {
    const { error } = await supabase
      .from('users')
      .delete()
      .eq('id', req.params.id);
    if (error) throw error;
    res.json({ success: true, message: 'Usuario eliminado' });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// ===== ENDPOINTS DE RETOS (PROTEGIDOS) =====
app.get('/api/retos', authenticateToken, async (req, res) => {
  try {
    console.log('🔍 GET /api/retos - Usuario:', req.user?.id);

    const { data: userData, error: userError } = await supabase
      .from('users')
      .select('company_id')
      .eq('id', req.user.id)
      .single();

    if (userError) {
      console.error('❌ Error obteniendo user:', userError);
      throw userError;
    }

    const company_id = userData.company_id;
    console.log('🏢 Filtrando retos por company_id:', company_id);

    let query = supabase.from('retos').select('*');
    if (company_id) {
      query = query.eq('company_id', company_id);
    }

    const { data, error } = await query;

    if (error) {
      console.error('❌ Error en query:', error);
      throw error;
    }

    console.log('📦 Retos encontrados:', data.length);
    res.json(data);
  } catch (error) {
    console.error('❌ Error en GET /retos:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

app.get('/api/retos/:id', authenticateToken, async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('retos')
      .select('*')
      .eq('id', req.params.id)
      .single();
    if (error) throw error;
    res.json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.get('/api/retos/:id/pills', authenticateToken, async (req, res) => {
  try {
    console.log('🔍 GET /api/retos/:id/pills - Reto ID:', req.params.id);

    const { data, error } = await supabase
      .from('pildoras')
      .select('*')
      .eq('reto_id', req.params.id);

    if (error) {
      console.error('❌ Error en query pills:', error);
      throw error;
    }

    console.log('💊 Píldoras encontradas:', data.length);
    res.json(data);
  } catch (error) {
    console.error('❌ Error en GET /pills:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

// ===== ENDPOINTS DE PILDORAS (PROTEGIDOS) =====
app.get('/api/pildoras/:pildoraId/secciones', authenticateToken, async (req, res) => {
  try {
    console.log('📺 GET /api/pildoras/:pildoraId/secciones - Píldora ID:', req.params.pildoraId);

    const { data, error } = await supabase
      .from('pantallas')
      .select('*')
      .eq('pildora_id', req.params.pildoraId)
      .order('screen_number', { ascending: true });

    if (error) {
      console.error('❌ Error en query secciones:', error);
      throw error;
    }

    console.log('✅ Secciones encontradas:', data.length);
    res.json(data);
  } catch (error) {
    console.error('❌ Error en GET /secciones:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

app.get('/api/pildoras', authenticateToken, async (req, res) => {
  try {
    const { reto_id } = req.query;
    let query = supabase.from('pildoras').select('*');
    if (reto_id) query = query.eq('reto_id', reto_id);
    const { data, error } = await query;
    if (error) throw error;
    res.json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.get('/api/pildoras/:id', authenticateToken, async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('pildoras')
      .select('*')
      .eq('id', req.params.id)
      .single();
    if (error) throw error;
    res.json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.post('/api/pildoras', authenticateToken, authorizeRole(['super_admin', 'company_admin']), async (req, res) => {
  try {
    const { reto_id, pill_number, title, key_skill, description, duration_minutes } = req.body;
    const { data, error } = await supabase
      .from('pildoras')
      .insert([{ reto_id, pill_number, title, key_skill, description, duration_minutes }])
      .select();
    if (error) throw error;
    res.json({ success: true, data: data[0] });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.put('/api/pildoras/:id', authenticateToken, authorizeRole(['super_admin', 'company_admin']), async (req, res) => {
  try {
    const { title, key_skill, description, duration_minutes } = req.body;
    const { data, error } = await supabase
      .from('pildoras')
      .update({ title, key_skill, description, duration_minutes, updated_at: new Date() })
      .eq('id', req.params.id)
      .select();
    if (error) throw error;
    res.json({ success: true, data: data[0] });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.delete('/api/pildoras/:id', authenticateToken, authorizeRole(['super_admin', 'company_admin']), async (req, res) => {
  try {
    const { error } = await supabase
      .from('pildoras')
      .delete()
      .eq('id', req.params.id);
    if (error) throw error;
    res.json({ success: true, message: 'Píldora eliminada' });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// ===== ENDPOINTS DE PANTALLAS (PROTEGIDOS) =====
app.get('/api/pantallas', authenticateToken, async (req, res) => {
  try {
    const { pildora_id } = req.query;
    let query = supabase.from('pantallas').select('*');
    if (pildora_id) query = query.eq('pildora_id', pildora_id);
    const { data, error } = await query;
    if (error) throw error;
    res.json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.get('/api/pantallas/:id', authenticateToken, async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('pantallas')
      .select('*')
      .eq('id', req.params.id)
      .single();
    if (error) throw error;
    res.json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.post('/api/pantallas', authenticateToken, authorizeRole(['super_admin', 'company_admin']), async (req, res) => {
  try {
    const { pildora_id, screen_number, screen_type, screen_name, screen_content, source_note } = req.body;
    const { data, error } = await supabase
      .from('pantallas')
      .insert([{ pildora_id, screen_number, screen_type, screen_name, screen_content, source_note }])
      .select();
    if (error) throw error;
    res.json({ success: true, data: data[0] });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.put('/api/pantallas/:id', authenticateToken, authorizeRole(['super_admin', 'company_admin']), async (req, res) => {
  try {
    const { screen_type, screen_name, screen_content, source_note } = req.body;
    const { data, error } = await supabase
      .from('pantallas')
      .update({ screen_type, screen_name, screen_content, source_note, updated_at: new Date() })
      .eq('id', req.params.id)
      .select();
    if (error) throw error;
    res.json({ success: true, data: data[0] });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.delete('/api/pantallas/:id', authenticateToken, authorizeRole(['super_admin', 'company_admin']), async (req, res) => {
  try {
    const { error } = await supabase
      .from('pantallas')
      .delete()
      .eq('id', req.params.id);
    if (error) throw error;
    res.json({ success: true, message: 'Pantalla eliminada' });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// ===== ENDPOINTS DE USER_PILL_PROGRESS (PROTEGIDOS) =====
app.get('/api/user-progress', authenticateToken, async (req, res) => {
  try {
    const { user_id, pill_id } = req.query;
    let query = supabase.from('user_pill_progress').select('*');
    if (user_id) query = query.eq('user_id', user_id);
    if (pill_id) query = query.eq('pill_id', pill_id);
    const { data, error } = await query;
    if (error) throw error;
    res.json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.get('/api/user-progress/user/:userId', authenticateToken, async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('user_pill_progress')
      .select('*')
      .eq('user_id', req.params.userId);
    if (error) throw error;
    res.json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.get('/api/user-progress/:id', authenticateToken, async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('user_pill_progress')
      .select('*')
      .eq('id', req.params.id)
      .single();
    if (error) throw error;
    res.json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.post('/api/user-progress', authenticateToken, async (req, res) => {
  try {
    const { user_id, pill_id, current_screen, self_assesment_score } = req.body;
    const { data, error } = await supabase
      .from('user_pill_progress')
      .insert([{ user_id, pill_id, current_screen, self_assesment_score, is_completed: false }])
      .select();
    if (error) throw error;
    res.json({ success: true, data: data[0] });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.put('/api/user-progress/:id', authenticateToken, async (req, res) => {
  try {
    const { current_screen, self_assesment_score, is_completed } = req.body;
    const update = { current_screen, self_assesment_score, is_completed, updated_at: new Date() };
    if (is_completed) update.completed_at = new Date();
    const { data, error } = await supabase
      .from('user_pill_progress')
      .update(update)
      .eq('id', req.params.id)
      .select();
    if (error) throw error;
    res.json({ success: true, data: data[0] });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.post('/api/user-progress/complete-pill/:pillId', authenticateToken, async (req, res) => {
  try {
    const { user_id } = req.body;
    const { data, error } = await supabase
      .from('user_pill_progress')
      .update({ is_completed: true, completed_at: new Date() })
      .eq('pill_id', req.params.pillId)
      .eq('user_id', user_id)
      .select();
    if (error) throw error;
    res.json({ success: true, data: data[0] });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.delete('/api/user-progress/:id', authenticateToken, async (req, res) => {
  try {
    const { error } = await supabase
      .from('user_pill_progress')
      .delete()
      .eq('id', req.params.id);
    if (error) throw error;
    res.json({ success: true, message: 'Progreso eliminado' });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// ===== HELPERS: Funciones auxiliares =====
function _obtenerUltimoDiaMes(mes, ano) {
  return new Date(ano, mes, 0).getDate();
}

function _obtenerDiasLaboralesMes(mes, ano) {
  const diasLaborales = [];
  const ultimoDia = _obtenerUltimoDiaMes(mes, ano);

  for (let dia = 1; dia <= ultimoDia; dia++) {
    const fecha = new Date(ano, mes - 1, dia);
    // Lunes (1) a Viernes (5)
    if (fecha.getDay() >= 1 && fecha.getDay() <= 5) {
      const fechaStr = fecha.toISOString().split('T')[0];
      diasLaborales.push(fechaStr);
    }
  }

  return diasLaborales;
}

function _esDialaboral(fecha) {
  const dia = fecha.getDay();
  return dia >= 1 && dia <= 5;
}

async function _actualizarRacha(user_id, reto_id, mes, ano) {
  try {
    console.log(`🔄 Actualizando racha para user: ${user_id}, reto: ${reto_id}`);

    const ultimoDiaDelMes = _obtenerUltimoDiaMes(mes, ano);
    const diasLaborales = _obtenerDiasLaboralesMes(mes, ano);

    // Obtener progreso del mes para este reto
    const { data: progreso, error: errorProgreso } = await supabase
      .from('racha_daily_progress')
      .select('*')
      .eq('user_id', user_id)
      .eq('reto_id', reto_id)
      .gte('fecha', `${ano}-${String(mes).padStart(2, '0')}-01`)
      .lte('fecha', `${ano}-${String(mes).padStart(2, '0')}-${String(ultimoDiaDelMes).padStart(2, '0')}`);

    if (errorProgreso) throw errorProgreso;

    // Calcular racha_actual (hacia atrás desde hoy)
    let racha_actual = 0;
    let fechaActual = new Date();

    while (racha_actual < 365) {
      if (fechaActual.getDay() === 0 || fechaActual.getDay() === 6) {
        fechaActual.setDate(fechaActual.getDate() - 1);
        continue;
      }

      const fechaStr = fechaActual.toISOString().split('T')[0];
      const registro = progreso.find(p => p.fecha === fechaStr);

      if (registro && registro.login_hecho === true && registro.pildora_completada === true) {
        racha_actual++;
        fechaActual.setDate(fechaActual.getDate() - 1);
      } else {
        break;
      }
    }

    // Obtener racha_maxima actual
    const { data: rachaActual, error: errorRachaActual } = await supabase
      .from('user_racha_stats')
      .select('racha_maxima')
      .eq('user_id', user_id)
      .eq('reto_id', reto_id)
      .eq('mes', mes)
      .eq('año', ano)
      .single();

    if (errorRachaActual && errorRachaActual.code !== 'PGRST116') {
      throw errorRachaActual;
    }

    const racha_maxima_anterior = rachaActual?.racha_maxima || 0;
    const racha_maxima_nueva = Math.max(racha_maxima_anterior, racha_actual);

    // Actualizar o crear registro en user_racha_stats
    const { data: existente, error: errorExistente } = await supabase
      .from('user_racha_stats')
      .select('id')
      .eq('user_id', user_id)
      .eq('reto_id', reto_id)
      .eq('mes', mes)
      .eq('año', ano)
      .single();

    if (errorExistente && errorExistente.code !== 'PGRST116') {
      throw errorExistente;
    }

    if (existente) {
      // Actualizar
      await supabase
        .from('user_racha_stats')
        .update({
          racha_actual,
          racha_maxima: racha_maxima_nueva,
          updated_at: new Date()
        })
        .eq('id', existente.id);
    } else {
      // Crear nuevo
      await supabase
        .from('user_racha_stats')
        .insert([{
          user_id,
          reto_id,
          mes,
          ano,
          racha_actual,
          racha_maxima: racha_maxima_nueva
        }]);
    }

    console.log(`✅ Racha actualizada - Actual: ${racha_actual}, Máxima: ${racha_maxima_nueva}`);
  } catch (error) {
    console.error('❌ Error en _actualizarRacha:', error.message);
  }
}

// ===== ENDPOINTS DE RACHAS (PROTEGIDOS) =====
app.post('/api/racha/registrar-login', authenticateToken, async (req, res) => {
  try {
    const { user_id, reto_id } = req.body;

    if (!user_id || !reto_id) {
      return res.status(400).json({
        success: false,
        error: 'Faltan parámetros: user_id, reto_id'
      });
    }

    const today = new Date().toISOString().split('T')[0];
    const mesNum = new Date().getMonth() + 1;
    const anoNum = new Date().getFullYear();

    console.log(`📍 POST /api/racha/registrar-login - User: ${user_id}, Reto: ${reto_id}, Fecha: ${today}`);

    // Buscar o crear registro del día
    const { data: existente, error: errorCheck } = await supabase
      .from('racha_daily_progress')
      .select('*')
      .eq('user_id', user_id)
      .eq('reto_id', reto_id)
      .eq('fecha', today)
      .single();

    if (errorCheck && errorCheck.code !== 'PGRST116') {
      throw errorCheck;
    }

    if (existente) {
      const { data, error } = await supabase
        .from('racha_daily_progress')
        .update({ login_hecho: true })
        .eq('id', existente.id)
        .select();

      if (error) throw error;

      // Actualizar racha en user_racha_stats
      await _actualizarRacha(user_id, reto_id, mesNum, anoNum);

      return res.json({ success: true, message: 'Login registrado', data: data[0] });
    }

    const { data, error } = await supabase
      .from('racha_daily_progress')
      .insert([{
        user_id,
        reto_id,
        fecha: today,
        pildora_completada: false,
        login_hecho: true,
        es_dia_laboral: _esDialaboral(new Date()),
      }])
      .select();

    if (error) throw error;

    // Actualizar racha en user_racha_stats
    await _actualizarRacha(user_id, reto_id, mesNum, anoNum);

    res.json({ success: true, message: 'Login registrado', data: data[0] });
  } catch (error) {
    console.error('❌ Error en registrar-login:', error.message);
    res.status(400).json({ success: false, error: error.message });
  }
});

app.post('/api/racha/registrar-pildora', authenticateToken, async (req, res) => {
  try {
    const { user_id, reto_id } = req.body;

    if (!user_id || !reto_id) {
      return res.status(400).json({
        success: false,
        error: 'Faltan parámetros: user_id, reto_id'
      });
    }

    const today = new Date().toISOString().split('T')[0];
    const mesNum = new Date().getMonth() + 1;
    const anoNum = new Date().getFullYear();

    console.log(`📍 POST /api/racha/registrar-pildora - User: ${user_id}, Reto: ${reto_id}, Fecha: ${today}`);

    // Buscar o crear registro del día
    const { data: existente, error: errorCheck } = await supabase
      .from('racha_daily_progress')
      .select('*')
      .eq('user_id', user_id)
      .eq('reto_id', reto_id)
      .eq('fecha', today)
      .single();

    if (errorCheck && errorCheck.code !== 'PGRST116') {
      throw errorCheck;
    }

    if (existente) {
      const { data, error } = await supabase
        .from('racha_daily_progress')
        .update({ pildora_completada: true })
        .eq('id', existente.id)
        .select();

      if (error) throw error;

      // Actualizar racha en user_racha_stats
      await _actualizarRacha(user_id, reto_id, mesNum, anoNum);

      return res.json({ success: true, message: 'Píldora registrada', data: data[0] });
    }

    const { data, error } = await supabase
      .from('racha_daily_progress')
      .insert([{
        user_id,
        reto_id,
        fecha: today,
        pildora_completada: true,
        login_hecho: false,
        es_dia_laboral: _esDialaboral(new Date()),
      }])
      .select();

    if (error) throw error;

    // Actualizar racha en user_racha_stats
    await _actualizarRacha(user_id, reto_id, mesNum, anoNum);

    res.json({ success: true, message: 'Píldora registrada', data: data[0] });
  } catch (error) {
    console.error('❌ Error en registrar-pildora:', error.message);
    res.status(400).json({ success: false, error: error.message });
  }
});

app.get('/api/racha/estadisticas-por-reto', authenticateToken, async (req, res) => {
  try {
    const { user_id, reto_id, mes, ano } = req.query;

    if (!user_id || !reto_id || !mes || !ano) {
      return res.status(400).json({
        success: false,
        error: 'Faltan parámetros: user_id, reto_id, mes, ano'
      });
    }

    console.log(`📊 GET /api/racha/estadisticas-por-reto - User: ${user_id}, Reto: ${reto_id}, Mes: ${mes}/${ano}`);

    const mesNum = parseInt(mes);
    const anoNum = parseInt(ano);
    const ultimoDiaDelMes = _obtenerUltimoDiaMes(mesNum, anoNum);

    // Obtener días laborales del mes
    const diasLaborales = _obtenerDiasLaboralesMes(mesNum, anoNum);

    // Obtener progreso del mes PARA ESTE RETO
    const { data: progreso, error: errorProgreso } = await supabase
      .from('racha_daily_progress')
      .select('*')
      .eq('user_id', user_id)
      .eq('reto_id', reto_id)
      .gte('fecha', `${anoNum}-${String(mesNum).padStart(2, '0')}-01`)
      .lte('fecha', `${anoNum}-${String(mesNum).padStart(2, '0')}-${String(ultimoDiaDelMes).padStart(2, '0')}`);

    if (errorProgreso) throw errorProgreso;

    // Obtener racha_maxima y racha_actual de user_racha_stats
    const { data: rachaStats, error: errorRachaStats } = await supabase
      .from('user_racha_stats')
      .select('racha_maxima, racha_actual')
      .eq('user_id', user_id)
      .eq('reto_id', reto_id)
      .eq('mes', mesNum)
      .eq('año', anoNum)
      .single();

    if (errorRachaStats && errorRachaStats.code !== 'PGRST116') {
      throw errorRachaStats;
    }

    const racha_maxima = rachaStats?.racha_maxima || 0;
    const racha_actual = rachaStats?.racha_actual || 0;

    // ============================================
    // 1. DIA PILDORA: Número secuencial del día laboral actual
    // ============================================
    const ahora = new Date();
    const today = ahora.toISOString().split('T')[0];
    const dia_pildora = diasLaborales.filter(fechaStr => {
      const fecha = new Date(fechaStr);
      return fecha <= ahora;
    }).length;

    console.log(`📅 Día Píldora: ${dia_pildora} (de ${diasLaborales.length} días laborales)`);

    // ============================================
    // 2. CUMPLIDOS: Total de píldoras completadas del reto en el mes
    // ============================================
    // Obtener todas las píldoras del reto
    const { data: pildoras, error: errorPildoras } = await supabase
      .from('pildoras')
      .select('id')
      .eq('reto_id', reto_id);

    if (errorPildoras) throw errorPildoras;

    const pildoraIds = pildoras.map(p => p.id);
    let dias_cumplidos = 0;

    if (pildoraIds.length > 0) {
      // Contar píldoras completadas para este usuario en este reto durante el mes
      const { data: completadas, error: errorCompletadas } = await supabase
        .from('user_pill_progress')
        .select('*')
        .eq('user_id', user_id)
        .in('pill_id', pildoraIds)
        .eq('is_completed', true)
        .gte('completed_at', `${anoNum}-${String(mesNum).padStart(2, '0')}-01`)
        .lte('completed_at', `${anoNum}-${String(mesNum).padStart(2, '0')}-${String(ultimoDiaDelMes).padStart(2, '0')}`);

      if (errorCompletadas) throw errorCompletadas;

      dias_cumplidos = completadas.length;
    }

    console.log(`✅ Días Cumplidos (Píldoras completadas): ${dias_cumplidos}`);

    // ============================================
    // 3. NO CUMPLIDOS: Días laborales pasados sin cumplir ambas condiciones
    // ============================================
    const diasNoCumplidos = diasLaborales.filter(fechaStr => {
      const registro = progreso.find(p => p.fecha === fechaStr);
      const fechaDate = new Date(fechaStr);
      const noCumplio = !registro || !(registro.login_hecho && registro.pildora_completada);
      return noCumplio && fechaDate <= ahora;
    }).length;

    console.log(`❌ Días No Cumplidos: ${diasNoCumplidos}`);
    console.log(`🔥 Racha Actual: ${racha_actual}`);
    console.log(`🏆 Racha Máxima: ${racha_maxima}`);

    res.json({
      success: true,
      data: {
        reto_id,
        dia_pildora,
        racha_actual,
        racha_maxima,
        dias_cumplidos: dias_cumplidos,
        dias_no_cumplidos: diasNoCumplidos,
        dias_laborales_total: diasLaborales.length
      }
    });
  } catch (error) {
    console.error('❌ Error en estadisticas-por-reto:', error.message);
    res.status(400).json({ success: false, error: error.message });
  }
});

app.get('/api/racha/progreso', authenticateToken, async (req, res) => {
  try {
    const { user_id, reto_id, mes, ano } = req.query;

    if (!user_id || !reto_id || !mes || !ano) {
      return res.status(400).json({ success: false, error: 'Faltan parámetros: user_id, reto_id, mes, ano' });
    }

    console.log(`📈 GET /api/racha/progreso - User: ${user_id}, Reto: ${reto_id}, Mes: ${mes}/${ano}`);

    const mesNum = parseInt(mes);
    const anoNum = parseInt(ano);
    const ultimoDiaDelMes = _obtenerUltimoDiaMes(mesNum, anoNum);

    const { data: progreso, error } = await supabase
      .from('racha_daily_progress')
      .select('fecha, login_hecho, pildora_completada, es_dia_laboral')
      .eq('user_id', user_id)
      .eq('reto_id', reto_id)
      .gte('fecha', `${anoNum}-${String(mesNum).padStart(2, '0')}-01`)
      .lte('fecha', `${anoNum}-${String(mesNum).padStart(2, '0')}-${String(ultimoDiaDelMes).padStart(2, '0')}`)
      .order('fecha', { ascending: true });

    if (error) throw error;

    res.json({
      success: true,
      data: progreso || []
    });
  } catch (error) {
    console.error('❌ Error en progreso:', error.message);
    res.status(400).json({ success: false, error: error.message });
  }
});

app.get('/api/racha/leaderboard', authenticateToken, async (req, res) => {
  try {
    const { mes, ano } = req.query;

    if (!mes || !ano) {
      return res.status(400).json({
        success: false,
        error: 'Faltan parámetros: mes, ano'
      });
    }

    console.log(`🏆 GET /api/racha/leaderboard - Mes: ${mes}/${ano}`);

    const mesNum = parseInt(mes);
    const anoNum = parseInt(ano);

    // Obtener todas las rachas del mes
    const { data: todasLasRachas, error: errorRachas } = await supabase
      .from('user_racha_stats')
      .select('*')
      .eq('mes', mesNum)
      .eq('año', anoNum);

    if (errorRachas) throw errorRachas;

    // Agrupar por usuario y obtener el MEJOR racha_maxima
    const usuariosMap = {};

    for (const racha of todasLasRachas) {
      if (!usuariosMap[racha.user_id]) {
        usuariosMap[racha.user_id] = {
          user_id: racha.user_id,
          mejor_racha: 0,
          retos_participados: 0
        };
      }

      // Actualizar con el máximo encontrado
      usuariosMap[racha.user_id].mejor_racha = Math.max(
        usuariosMap[racha.user_id].mejor_racha,
        racha.racha_maxima
      );
      usuariosMap[racha.user_id].retos_participados++;
    }

    // Convertir a array y ordenar por mejor_racha descendente
    let leaderboard = Object.values(usuariosMap);
    leaderboard.sort((a, b) => b.mejor_racha - a.mejor_racha);

    // Agregar posición y obtener info del usuario
    leaderboard = await Promise.all(leaderboard.map(async (item, index) => {
      const { data: usuario, error: errorUsuario } = await supabase
        .from('users')
        .select('id, full_name, email')
        .eq('id', item.user_id)
        .single();

      if (!errorUsuario && usuario) {
        return {
          posicion: index + 1,
          usuario_id: item.user_id,
          nombre: usuario.full_name || usuario.email,
          mejor_racha: item.mejor_racha,
          retos_participados: item.retos_participados
        };
      }

      return {
        posicion: index + 1,
        usuario_id: item.user_id,
        nombre: 'Usuario',
        mejor_racha: item.mejor_racha,
        retos_participados: item.retos_participados
      };
    }));

    console.log(`🏆 Leaderboard generado: ${leaderboard.length} usuarios`);

    res.json({
      success: true,
      data: {
        mes: mesNum,
        ano: anoNum,
        leaderboard
      }
    });
  } catch (error) {
    console.error('❌ Error en leaderboard:', error.message);
    res.status(400).json({ success: false, error: error.message });
  }
});

// Iniciar servidor
app.listen(PORT, () => {
  console.log(`🚀 Servidor corriendo en puerto ${PORT}`);
});