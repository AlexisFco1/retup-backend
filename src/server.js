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
    await supabase.auth.signOut();
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
 
    // Obtener el user completo para acceder a company_id
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
    res.json(data);  // ✅ Responder SOLO el array
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
    res.json(data);  // ✅ Responder SOLO el array
  } catch (error) {
    console.error('❌ Error en GET /pills:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});
 
// ===== ENDPOINTS DE PILDORAS (PROTEGIDOS) =====
// ⚠️ RUTAS MÁS ESPECÍFICAS PRIMERO, LUEGO LAS MÁS GENÉRICAS
 
// ✅ RUTA ESPECÍFICA: Obtener secciones de una píldora
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
    res.json(data);  // ✅ Responder SOLO el array
  } catch (error) {
    console.error('❌ Error en GET /secciones:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});
 
// ✅ RUTA GENÉRICA: Obtener todas las píldoras
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
 
// ✅ RUTA GENÉRICA: Obtener una píldora por ID
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
// ===== ENDPOINTS DE RACHAS (PROTEGIDOS) =====
app.post('/api/racha/registrar-login', authenticateToken, async (req, res) => {
  try {
    const { user_id } = req.body;
    const today = new Date().toISOString().split('T')[0]; // Formato: YYYY-MM-DD
    
    console.log(`📍 POST /api/racha/registrar-login - User: ${user_id}, Fecha: ${today}`);

    // Verificar si ya existe un registro para hoy
    const { data: existente, error: errorCheck } = await supabase
      .from('racha_daily_progress')
      .select('*')
      .eq('user_id', user_id)
      .eq('fecha', today)
      .single();

    if (errorCheck && errorCheck.code !== 'PGRST116') { // PGRST116 = no rows
      throw errorCheck;
    }

    if (existente) {
      // Ya existe, actualizar login_hecho
      const { data, error } = await supabase
        .from('racha_daily_progress')
        .update({ login_hecho: true })
        .eq('id', existente.id)
        .select();

      if (error) throw error;
      return res.json({ success: true, message: 'Login registrado', data: data[0] });
    }

    // No existe, crear nuevo registro
    const { data, error } = await supabase
      .from('racha_daily_progress')
      .insert([{
        user_id,
        fecha: today,
        pildora_completada: false,
        login_hecho: true,
        es_dia_laboral: _esDialaboral(new Date()),
      }])
      .select();

    if (error) throw error;
    res.json({ success: true, message: 'Login registrado', data: data[0] });
  } catch (error) {
    console.error('❌ Error en registrar-login:', error.message);
    res.status(400).json({ success: false, error: error.message });
  }
});

app.post('/api/racha/registrar-pildora', authenticateToken, async (req, res) => {
  try {
    const { user_id } = req.body;
    const today = new Date().toISOString().split('T')[0]; // Formato: YYYY-MM-DD

    console.log(`📍 POST /api/racha/registrar-pildora - User: ${user_id}, Fecha: ${today}`);

    // Verificar si ya existe un registro para hoy
    const { data: existente, error: errorCheck } = await supabase
      .from('racha_daily_progress')
      .select('*')
      .eq('user_id', user_id)
      .eq('fecha', today)
      .single();

    if (errorCheck && errorCheck.code !== 'PGRST116') { // PGRST116 = no rows
      throw errorCheck;
    }

    if (existente) {
      // Ya existe, actualizar pildora_completada
      const { data, error } = await supabase
        .from('racha_daily_progress')
        .update({ pildora_completada: true })
        .eq('id', existente.id)
        .select();

      if (error) throw error;
      return res.json({ success: true, message: 'Píldora registrada', data: data[0] });
    }

    // No existe, crear nuevo registro
    const { data, error } = await supabase
      .from('racha_daily_progress')
      .insert([{
        user_id,
        fecha: today,
        pildora_completada: true,
        login_hecho: false,
        es_dia_laboral: _esDialaboral(new Date()),
      }])
      .select();

    if (error) throw error;
    res.json({ success: true, message: 'Píldora registrada', data: data[0] });
  } catch (error) {
    console.error('❌ Error en registrar-pildora:', error.message);
    res.status(400).json({ success: false, error: error.message });
  }
});

// Helper function para verificar si es día laboral
function _esDialaboral(fecha) {
  const dia = fecha.getDay();
  return dia >= 1 && dia <= 5; // Lunes (1) a Viernes (5)
}
 
// ===== ENDPOINTS DE ANONYMOUS_NOMINATIONS (PROTEGIDOS) ✅ ACTUALIZADO =====
app.get('/api/nominations', authenticateToken, async (req, res) => {
  try {
    const { reto_id, nominated_id } = req.query;
    let query = supabase.from('anonymous_nominations').select('*');
    if (reto_id) query = query.eq('reto_id', reto_id);
    if (nominated_id) query = query.eq('nominated_user_id', nominated_id);
    const { data, error } = await query;
    if (error) throw error;
    res.json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.post('/api/nominations', authenticateToken, async (req, res) => {
  try {
    console.log('📝 POST /api/nominations');
    console.log('   Body:', req.body);
    console.log('   User:', req.user.id);
    
    const { 
      respondent_user_id, 
      nominated_user_id, 
      reto_id, 
      pill_id, 
      section_number, 
      vote_type 
    } = req.body;

    console.log('✅ Parámetros recibidos:');
    console.log('   respondent_user_id:', respondent_user_id);
    console.log('   nominated_user_id:', nominated_user_id);
    console.log('   reto_id:', reto_id);
    console.log('   pill_id:', pill_id);
    console.log('   section_number:', section_number);
    console.log('   vote_type:', vote_type);

    const { data, error } = await supabase
      .from('anonymous_nominations')
      .insert([{
        respondent_user_id,
        nominated_user_id,
        reto_id,
        pill_id,
        section_number,
        vote_type,
        is_anonymous: false,
        created_at: new Date().toISOString(),
      }])
      .select();

    if (error) {
      console.error('❌ Error en insert:', error);
      throw error;
    }

    console.log('✅ Voto registrado exitosamente:', data[0].id);
    res.status(201).json({ success: true, data: data[0] });
  } catch (error) {
    console.error('❌ Error en POST /nominations:', error.message);
    res.status(400).json({ success: false, error: error.message });
  }
});

// ✅ NUEVO ENDPOINT: Calcular feedback score para un usuario
app.get('/api/nominations/:userId/feedback-score', authenticateToken, async (req, res) => {
  try {
    console.log('📊 GET /api/nominations/:userId/feedback-score');
    console.log('   userId:', req.params.userId);

    const userId = req.params.userId;

    // PASO 1: Obtener todos los votos donde este usuario fue nominado
    const { data: votes, error: votesError } = await supabase
      .from('anonymous_nominations')
      .select('*')
      .eq('nominated_user_id', userId);

    if (votesError) {
      console.error('❌ Error obteniendo votos:', votesError);
      throw votesError;
    }

    console.log(`✅ Votos encontrados: ${votes.length}`);

    // Si no hay votos, retornar 0
    if (votes.length === 0) {
      console.log('⚠️ No hay votos para este usuario');
      return res.json({ 
        success: true, 
        feedbackScore: 0, 
        totalVoters: 0, 
        positiveVoters: 0,
        totalVotes: 0
      });
    }

    // PASO 2: Agrupar votos por votante (respondent_user_id) y reto
    const votersMap = {};
    
    votes.forEach(vote => {
      const key = `${vote.respondent_user_id}-${vote.reto_id}`;
      if (!votersMap[key]) {
        votersMap[key] = {
          respondent_user_id: vote.respondent_user_id,
          reto_id: vote.reto_id,
          positive_votes: 0,
          negative_votes: 0,
          votes: []
        };
      }
      votersMap[key].votes.push(vote);
      
      if (vote.vote_type === 'positive') {
        votersMap[key].positive_votes++;
      } else if (vote.vote_type === 'negative') {
        votersMap[key].negative_votes++;
      }
    });

    console.log(`📊 Votantes únicos (por reto): ${Object.keys(votersMap).length}`);

    // PASO 3: Calcular voto neto por votante
    let totalValidVoters = 0;
    let positiveVoters = 0;

    Object.values(votersMap).forEach(voter => {
      console.log(`   Votante ${voter.respondent_user_id} en reto ${voter.reto_id}: ${voter.positive_votes} positivos, ${voter.negative_votes} negativos`);
      
      if (voter.positive_votes > voter.negative_votes) {
        console.log(`      ✅ Voto POSITIVO`);
        positiveVoters++;
        totalValidVoters++;
      } else if (voter.negative_votes > voter.positive_votes) {
        console.log(`      ❌ Voto NEGATIVO`);
        totalValidVoters++;
      } else {
        console.log(`      ⏸️ Voto ANULADO (empate)`);
        // No cuenta
      }
    });

    console.log(`\n📈 Resumen:`);
    console.log(`   Votantes válidos: ${totalValidVoters}`);
    console.log(`   Votantes positivos: ${positiveVoters}`);

    // PASO 4: Calcular porcentaje
    let feedbackScore = 0;
    if (totalValidVoters > 0) {
      feedbackScore = (100 / totalValidVoters) * positiveVoters;
    }

    console.log(`   Calificación: ${feedbackScore.toFixed(2)}%`);

    res.json({
      success: true,
      feedbackScore: Math.round(feedbackScore * 100) / 100, // Redondear a 2 decimales
      totalVoters: totalValidVoters,
      positiveVoters: positiveVoters,
      totalVotes: votes.length
    });

  } catch (error) {
    console.error('❌ Error en feedback-score:', error.message);
    res.status(400).json({ success: false, error: error.message });
  }
});
 
app.delete('/api/nominations/:id', authenticateToken, authorizeRole(['super_admin']), async (req, res) => {
  try {
    const { error } = await supabase
      .from('anonymous_nominations')
      .delete()
      .eq('id', req.params.id);
    if (error) throw error;
    res.json({ success: true, message: 'Nominación eliminada' });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});
 
// ===== ENDPOINT PARA INSERTAR TODAS LAS SECCIONES (SOLO EJECUTAR UNA VEZ) =====
app.post('/api/seed/secciones', authenticateToken, authorizeRole(['super_admin']), async (req, res) => {
  try {
    console.log('🌱 Iniciando inserción de secciones (20 píldoras x 9 secciones = 180 secciones)...');
 
    // Obtener todos los IDs de las píldoras
    const { data: pildoras, error: errorPildoras } = await supabase
      .from('pildoras')
      .select('id, title')
      .order('created_at', { ascending: true });
 
    if (errorPildoras) throw errorPildoras;
 
    if (pildoras.length === 0) {
      return res.status(400).json({ error: 'No hay píldoras en la BD' });
    }
 
    console.log(`📚 Encontradas ${pildoras.length} píldoras`);
 
    // Estructura estándar de 9 secciones (aplica a todas las píldoras)
    const estructuraBase = [
      { screen_number: 1, screen_name: 'Bienvenida + frase motivante', screen_type: 'welcome' },
      { screen_number: 2, screen_name: 'Dato/evento histórico (gancho)', screen_type: 'fact' },
      { screen_number: 3, screen_name: 'Pregunta anónima: ¿quién lo hace mejor?', screen_type: 'anonymous_question' },
      { screen_number: 4, screen_name: 'Por qué importa (dato estadístico)', screen_type: 'statistic' },
      { screen_number: 5, screen_name: 'Autopercepción (escala 1-5)', screen_type: 'self_assesment' },
      { screen_number: 6, screen_name: 'Qué aprendiste + beneficio', screen_type: 'learning' },
      { screen_number: 7, screen_name: 'Pregunta anónima: ¿quién podría mejorar?', screen_type: 'anonymous_question' },
      { screen_number: 8, screen_name: 'Práctica social con un compañero', screen_type: 'social_practice' },
      { screen_number: 9, screen_name: 'Mensaje de cierre gratificante', screen_type: 'closing' },
    ];
 
    let totalInserted = 0;
    let seccionesParaInsertar = [];
 
    // Para CADA píldora, crear 9 secciones con la estructura base y contenido genérico
    for (let i = 0; i < pildoras.length; i++) {
      const pildora = pildoras[i];
      console.log(`📝 Procesando píldora ${i + 1}/${pildoras.length}: "${pildora.title}"`);
 
      // Crear las 9 secciones para esta píldora
      estructuraBase.forEach((seccion) => {
        seccionesParaInsertar.push({
          pildora_id: pildora.id,
          screen_number: seccion.screen_number,
          screen_name: seccion.screen_name,
          screen_type: seccion.screen_type,
          screen_content: `[Contenido para completar]\n\nPíldora: "${pildora.title}"\nSección: ${seccion.screen_number}/9 - ${seccion.screen_name}`,
          source_note: `RetUp - ${pildora.title}`,
        });
      });
 
      // Insertar en lotes de 45 (5 píldoras × 9 secciones)
      if ((i + 1) % 5 === 0 || i === pildoras.length - 1) {
        console.log(`✅ Insertando lote de ${seccionesParaInsertar.length} secciones...`);
        const { error } = await supabase
          .from('pantallas')
          .insert(seccionesParaInsertar);
 
        if (error) {
          console.error(`❌ Error insertando secciones:`, error);
          throw error;
        }
 
        totalInserted += seccionesParaInsertar.length;
        seccionesParaInsertar = []; // Limpiar para el siguiente lote
      }
    }
 
    console.log(`✅ Inserción completada: ${totalInserted} secciones en total`);
    res.json({
      success: true,
      message: `✅ ${totalInserted} secciones insertadas exitosamente (${pildoras.length} píldoras × 9 secciones)`,
      totalInserted,
      pildorasProcessadas: pildoras.length,
    });
  } catch (error) {
    console.error('❌ Error en seed:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});
 
// Inicia servidor
app.listen(PORT, () => {
  console.log(`🚀 Servidor RetUp corriendo en puerto ${PORT}`);
});