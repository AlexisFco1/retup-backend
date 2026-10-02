require('dotenv').config();
const { authenticateToken, authorizeRole } = require('./middleware');
const express = require('express');
const cors = require('cors');
const supabase = require('./supabase');
const cron = require('node-cron'); 
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
        const { email, password, first_name, last_name_1, last_name_2, age, gender, department, company_id, role } = req.body;
    const full_name = [first_name, last_name_1, last_name_2].filter(Boolean).join(' ');

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
        first_name,
        last_name_1,
        last_name_2,
        age,
        gender,
        department,
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

    // ✅ NUEVO: Registrar login automáticamente para todos los retos
    registrarLoginAutomatico(data.user.id, userData.company_id).catch(err => {
      console.error('⚠️ Error registrando login automático:', err.message);
    });

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
// ===== GUARDAR PREFERENCIA DE REGALO POR RETO =====
app.post('/api/racha/guardar-preferencia-regalo', authenticateToken, async (req, res) => {
  try {
    const { user_id, reto_id, regalo_tipo } = req.body;

    // Validar que regalo_tipo sea uno de los permitidos
    const tiposValidos = ['social', 'restaurante', 'tarjeta'];
    if (!tiposValidos.includes(regalo_tipo)) {
      return res.status(400).json({ 
        success: false, 
        error: 'Tipo de regalo no válido' 
      });
    }

    // Guardar o actualizar en Supabase
    const { data, error } = await supabase
  .from('user_reto_gifts')
  .upsert([{
    user_id,
    reto_id,
    gift_type: regalo_tipo,
        updated_at: new Date(),
      }], {
        onConflict: 'user_id,reto_id'
      })
      .select();

    if (error) throw error;

    res.json({ 
      success: true, 
      message: 'Preferencia de regalo guardada',
      data: data[0]
    });
  } catch (error) {
    res.status(500).json({ 
      success: false, 
      error: error.message 
    });
  }
});

// ===== OBTENER PREFERENCIA DE REGALO BY RETO =====
app.get('/api/racha/preferencia-regalo/:userId/:retoId', authenticateToken, async (req, res) => {
  try {
    const { userId, retoId } = req.params;

    const { data, error } = await supabase
  .from('user_reto_gifts')
  .select('gift_type')
      .eq('user_id', userId)
      .eq('reto_id', retoId)
      .single();

    if (error && error.code !== 'PGRST116') {
      // PGRST116 = no row found, eso es normal
      throw error;
    }

    res.json({ 
      success: true, 
      data: data ? data.gift_type : null
    });
  } catch (error) {
    res.status(500).json({ 
      success: false, 
      error: error.message 
    });
  }
});
// ===== REGALO DEL MES (una elección por usuario y mes) =====
// Se guarda en user_regalo_mensual. Cada mes se puede elegir UNA vez;
// el mes siguiente queda libre de nuevo (se desbloquea solo).
const _REGALOS_VALIDOS = ['social', 'restaurante', 'tarjeta'];

// Año y mes actuales según la hora de Madrid
function _anioMesMadrid() {
  const [anio, mes] = _hoyMadrid().split('-').map(Number);
  return { anio, mes };
}

// ===== GUARDAR REGALO DEL MES =====
app.post('/api/racha/guardar-preferencia-regalo-global', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;
    const { regalo_tipo } = req.body;

    if (!_REGALOS_VALIDOS.includes(regalo_tipo)) {
      return res.status(400).json({ success: false, error: 'Tipo de regalo no válido' });
    }

    const { anio, mes } = _anioMesMadrid();
    console.log(`🎁 POST regalo del mes: user=${userId}, ${mes}/${anio}, tipo=${regalo_tipo}`);

    // ¿Ya eligió este mes?
    const { data: existente, error: errBuscar } = await supabase
      .from('user_regalo_mensual')
      .select('gift_type')
      .eq('user_id', userId)
      .eq('anio', anio)
      .eq('mes', mes)
      .maybeSingle();
    if (errBuscar) throw errBuscar;

    if (existente) {
      return res.status(400).json({
        success: false,
        error: 'Ya elegiste tu regalo de este mes',
        data: existente.gift_type,
      });
    }

    const { error } = await supabase
      .from('user_regalo_mensual')
      .insert({ user_id: userId, anio, mes, gift_type: regalo_tipo });

    if (error) {
      // 23505 = ya existe (dos envíos a la vez): se trata como "ya eligió"
      if (error.code === '23505') {
        return res.status(400).json({ success: false, error: 'Ya elegiste tu regalo de este mes' });
      }
      throw error;
    }

    res.json({ success: true, data: regalo_tipo, anio, mes });
  } catch (error) {
    console.error('❌ Error guardando regalo del mes:', error.message);
    res.status(400).json({ success: false, error: error.message });
  }
});

// ===== OBTENER REGALO DEL MES =====
// Devuelve null si aún no eligió este mes → la pantalla se desbloquea
app.get('/api/racha/preferencia-regalo-global/:userId', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;
    const { anio, mes } = _anioMesMadrid();

    const { data, error } = await supabase
      .from('user_regalo_mensual')
      .select('gift_type')
      .eq('user_id', userId)
      .eq('anio', anio)
      .eq('mes', mes)
      .maybeSingle();

    if (error) throw error;

    res.json({ success: true, data: data?.gift_type || null, anio, mes });
  } catch (error) {
    console.error('❌ Error obteniendo regalo del mes:', error.message);
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
        const { full_name, first_name, last_name_1, last_name_2, age, gender, department, role, is_active } = req.body;
    const updateData = { updated_at: new Date() };
    if (full_name !== undefined) updateData.full_name = full_name;
    if (first_name !== undefined) updateData.first_name = first_name;
    if (last_name_1 !== undefined) updateData.last_name_1 = last_name_1;
    if (last_name_2 !== undefined) updateData.last_name_2 = last_name_2;
    if (age !== undefined) updateData.age = age;
    if (gender !== undefined) updateData.gender = gender;
    if (department !== undefined) updateData.department = department;
    if (role !== undefined) updateData.role = role;
    if (is_active !== undefined) updateData.is_active = is_active;
    const { data, error } = await supabase
      .from('users')
      .update(updateData)
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
    const { current_screen, self_assesment_score, is_completed, pill_rating, pill_feedback_message } = req.body;
    const update = { current_screen, self_assesment_score, is_completed, updated_at: new Date() };
    if (is_completed) update.completed_at = new Date();
    if (pill_rating !== undefined) update.pill_rating = pill_rating;
    if (pill_feedback_message !== undefined) update.pill_feedback_message = pill_feedback_message;
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
// ===== ENDPOINTS DE NOMINATIONS (PROTEGIDOS) =====
app.post('/api/nominations', authenticateToken, async (req, res) => {
  try {
    console.log('📝 POST /api/nominations');
    console.log('   Body:', req.body);
    
    const { 
      respondent_user_id, 
      nominated_user_id, 
      reto_id, 
      pill_id, 
      section_number, 
      vote_type 
    } = req.body;

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
      // 23505 = violación de la regla "no duplicados" (uq_nomination_voto_unico).
      // Significa que este voto YA existía: devolvemos el existente como éxito.
      if (error.code === '23505') {
        console.log('ℹ️ Voto duplicado detectado, se devuelve el existente');

        const { data: existente, error: errorExistente } = await supabase
          .from('anonymous_nominations')
          .select('*')
          .eq('respondent_user_id', respondent_user_id)
          .eq('nominated_user_id', nominated_user_id)
          .eq('pill_id', pill_id)
          .eq('section_number', section_number)
          .single();

        if (errorExistente) throw errorExistente;

        return res.status(200).json({
          success: true,
          data: existente,
          nominationId: existente.id,
          alreadyExisted: true
        });
      }

      console.error('❌ Error en insert:', error);
      throw error;
    }

    console.log('✅ Voto registrado exitosamente');
    res.status(201).json({ 
      success: true, 
      data: data[0],
      nominationId: data[0].id,
      alreadyExisted: false
    });
  } catch (error) {
    console.error('❌ Error en POST /nominations:', error.message);
    res.status(400).json({ success: false, error: error.message });
  }
});
// ===== MIS ENVÍOS EN UNA PÍLDORA (votos secciones 3 y 7 + retos sección 8) =====
// Permite que la app recuerde lo que el usuario ya envió al volver a la píldora
app.get('/api/nominations/mis-envios/:pillId', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;         // Usuario autenticado (el que votó / retó)
    const pillId = req.params.pillId;

    console.log('📋 GET /api/nominations/mis-envios/:pillId');
    console.log('   User:', userId);
    console.log('   Píldora:', pillId);

    // 1) Votos que YA hizo este usuario en esta píldora (secciones 3 y 7)
    const { data: votos, error: errorVotos } = await supabase
      .from('anonymous_nominations')
      .select('id, nominated_user_id, section_number, vote_type, message')
      .eq('respondent_user_id', userId)
      .eq('pill_id', pillId);

    if (errorVotos) throw errorVotos;

    // 2) Retos que YA envió este usuario en esta píldora (sección 8)
    const { data: retos, error: errorRetos } = await supabase
      .from('practicalo')
      .select('id, recipient_user_id, status')
      .eq('sender_user_id', userId)
      .eq('pill_id', pillId)
      .eq('section_number', 8);

    if (errorRetos) throw errorRetos;

    console.log(`✅ Votos encontrados: ${votos.length} | Retos encontrados: ${retos.length}`);

    res.json({
      success: true,
      votos: votos || [],
      retos: retos || []
    });
  } catch (error) {
    console.error('❌ Error en GET /nominations/mis-envios:', error.message);
    res.status(500).json({ success: false, error: error.message });
  }
});
app.get('/api/nominations/:userId/feedback-score', authenticateToken, async (req, res) => {
  try {
    console.log('📊 GET /api/nominations/:userId/feedback-score');
    console.log('   userId:', req.params.userId);
    console.log('   retoId (query):', req.query.reto_id);

    const userId = req.params.userId;
    const retoId = req.query.reto_id; // Parámetro opcional

    // Construir query base
    let query = supabase
      .from('anonymous_nominations')
      .select('*')
      .eq('nominated_user_id', userId);

    // Si se proporciona reto_id, filtrar por ese reto
    if (retoId) {
      query = query.eq('reto_id', retoId);
      console.log(`   Filtrando por reto: ${retoId}`);
    } else {
      console.log('   Sin filtro de reto - obteniendo votos globales');
    }

    const { data: votes, error: votesError } = await query;

    if (votesError) throw votesError;

    if (votes.length === 0) {
      return res.json({ 
        success: true, 
        feedbackScore: 0, 
        totalVoters: 0, 
        positiveVoters: 0,
        totalVotes: 0,
        reto_id: retoId || null,
        scope: retoId ? 'por_reto' : 'global'
      });
    }

    const votersMap = {};
    votes.forEach(vote => {
      // Si es filtrado por reto, la clave es simple. Si es global, incluir reto_id
      const key = retoId 
        ? `${vote.respondent_user_id}` 
        : `${vote.respondent_user_id}-${vote.reto_id}`;
      
      if (!votersMap[key]) {
        votersMap[key] = {
          respondent_user_id: vote.respondent_user_id,
          reto_id: vote.reto_id,
          positive_votes: 0,
          negative_votes: 0
        };
      }
      if (vote.vote_type === 'positive') {
        votersMap[key].positive_votes++;
      } else if (vote.vote_type === 'negative') {
        votersMap[key].negative_votes++;
      }
    });

    let totalValidVoters = 0;
    let positiveVoters = 0;

    Object.values(votersMap).forEach(voter => {
      if (voter.positive_votes > voter.negative_votes) {
        positiveVoters++;
        totalValidVoters++;
      } else if (voter.negative_votes > voter.positive_votes) {
        totalValidVoters++;
      }
    });

    let feedbackScore = 0;
    if (totalValidVoters > 0) {
      feedbackScore = (100 / totalValidVoters) * positiveVoters;
    }

    console.log(`✅ Feedback Score Calculado:`);
    console.log(`   Score: ${feedbackScore.toFixed(2)}%`);
    console.log(`   Votantes válidos: ${totalValidVoters}`);
    console.log(`   Votantes positivos: ${positiveVoters}`);
    console.log(`   Total votos: ${votes.length}`);

    res.json({
      success: true,
      feedbackScore: Math.round(feedbackScore * 100) / 100,
      totalVoters: totalValidVoters,
      positiveVoters: positiveVoters,
      totalVotes: votes.length,
      reto_id: retoId || null,
      scope: retoId ? 'por_reto' : 'global'
    });

  } catch (error) {
    console.error('❌ Error en feedback-score:', error.message);
    res.status(400).json({ success: false, error: error.message });
  }
});
// 📨 Nuevo endpoint: Actualizar nominación con mensaje
app.put('/api/nominations/:nominationId/message', authenticateToken, async (req, res) => {
  try {
    const { message } = req.body;
    
    console.log('📝 PUT /api/nominations/:nominationId/message');
    console.log('   nominationId:', req.params.nominationId);
    console.log('   message:', message);
    
    const { data, error } = await supabase
      .from('anonymous_nominations')
      .update({ message, updated_at: new Date() })
      .eq('id', req.params.nominationId)
      .select();

    if (error) {
      console.error('❌ Error en update:', error);
      throw error;
    }

    console.log('✅ Mensaje actualizado exitosamente');
    res.json({ success: true, data: data[0] });
  } catch (error) {
    console.error('❌ Error en PUT /message:', error.message);
    res.status(400).json({ success: false, error: error.message });
  }
});
// ===== ENDPOINTS DE NOTIFICACIONES (PROTEGIDOS) =====
app.post('/api/notifications', authenticateToken, async (req, res) => {
  try {
    const { 
      recipient_user_id, 
      sender_user_id, 
      type, 
      message, 
      reto_id, 
      pill_id 
    } = req.body;

    console.log('🔔 POST /api/notifications');
    console.log('   recipient:', recipient_user_id);
    console.log('   sender:', sender_user_id);
    console.log('   message:', message);

    const { data, error } = await supabase
      .from('notifications')
      .insert([{
        recipient_user_id,
        sender_user_id,
        type,
        message,
        reto_id,
        pill_id,
        is_read: false
      }])
      .select();

    if (error) {
      console.error('❌ Error en insert notificación:', error);
      throw error;
    }

    console.log('✅ Notificación creada exitosamente');
    res.status(201).json({ success: true, data: data[0] });
  } catch (error) {
    console.error('❌ Error en POST /notifications:', error.message);
    res.status(400).json({ success: false, error: error.message });
  }
});

// Obtener notificaciones sin leer de un usuario
// Obtener TODAS las notificaciones de un usuario (leídas y no leídas)
app.get('/api/notifications/:userId/unread', authenticateToken, async (req, res) => {
  try {
    console.log('🔔 GET /api/notifications/:userId/unread');
    console.log('   userId:', req.params.userId);

    const { data, error } = await supabase
  .from('notifications')
  .select('*')
  .eq('recipient_user_id', req.params.userId)
  .eq('is_read', false)
  .order('created_at', { ascending: false });

    if (error) {
      console.error('❌ Error en query:', error);
      throw error;
    }

    console.log('✅ Notificaciones encontradas:', data.length);
    res.json({ success: true, data, count: data.length });
  } catch (error) {
    console.error('❌ Error en GET /unread:', error.message);
    res.status(500).json({ success: false, error: error.message });
  }
});
// 📥 OBTENER TODAS LAS NOTIFICACIONES (LEÍDAS Y SIN LEER)
app.get('/api/notifications/:userId/all', authenticateToken, async (req, res) => {
  try {
    console.log('🔔 GET /api/notifications/:userId/all');
    console.log('   userId:', req.params.userId);

    const { data, error } = await supabase
      .from('notifications')
      .select('*')
      .eq('recipient_user_id', req.params.userId)
      .order('created_at', { ascending: false });

    if (error) {
      console.error('❌ Error en query:', error);
      throw error;
    }

    console.log('✅ Todas las notificaciones encontradas:', data.length);
    res.json({ success: true, data, count: data.length });
  } catch (error) {
    console.error('❌ Error en GET /all:', error.message);
    res.status(500).json({ success: false, error: error.message });
  }
});
// Marcar notificación como leída
app.put('/api/notifications/:notificationId/read', authenticateToken, async (req, res) => {
  try {
    console.log('🔔 PUT /api/notifications/:notificationId/read');
    console.log('   notificationId:', req.params.notificationId);

    const { data, error } = await supabase
      .from('notifications')
      .update({ is_read: true, updated_at: new Date() })
      .eq('id', req.params.notificationId)
      .select();

    if (error) {
      console.error('❌ Error en update:', error);
      throw error;
    }

    console.log('✅ Notificación marcada como leída');
    res.json({ success: true, data: data[0] });
  } catch (error) {
    console.error('❌ Error en PUT /read:', error.message);
    res.status(500).json({ success: false, error: error.message });
  }
});
// 📥 MARCAR MÚLTIPLES NOTIFICACIONES COMO LEÍDAS (BATCH)
app.put('/api/notifications/batch/mark-as-read', authenticateToken, async (req, res) => {
  try {
    const { notification_ids } = req.body;
    
    console.log('🔔 PUT /api/notifications/batch/mark-as-read');
    console.log('   Count:', notification_ids?.length);

    if (!notification_ids || notification_ids.length === 0) {
      return res.status(400).json({ 
        success: false, 
        error: 'No notification IDs provided' 
      });
    }

    const { error } = await supabase
      .from('notifications')
      .update({ is_read: true, updated_at: new Date() })
      .in('id', notification_ids);

    if (error) {
      console.error('❌ Error en update:', error);
      throw error;
    }

    console.log(`✅ ${notification_ids.length} notificaciones marcadas como leídas`);
    res.json({ 
      success: true, 
      marked_count: notification_ids.length 
    });
  } catch (error) {
    console.error('❌ Error en batch mark-as-read:', error.message);
    res.status(400).json({ success: false, error: error.message });
  }
});
// ===== ENDPOINTS DE PRACTICALO (PROTEGIDOS) =====

// 1️⃣ CREAR INVITACIÓN DE PRACTICALO (Sección 8 de píldora)
app.post('/api/practicalo', authenticateToken, async (req, res) => {
  try {
    const { 
      recipient_user_id, 
      reto_id, 
      pill_id, 
      message 
    } = req.body;

    const sender_user_id = req.user.id; // Usuario autenticado es el que envía

    console.log('🤝 POST /api/practicalo - Crear Invitación Practicalo');
    console.log('   Sender:', sender_user_id);
    console.log('   Recipient:', recipient_user_id);
    console.log('   Reto ID:', reto_id);
    console.log('   Píldora ID:', pill_id);
    console.log('   Message:', message);

    // Validar que no sea a uno mismo
    if (sender_user_id === recipient_user_id) {
      return res.status(400).json({ 
        success: false, 
        error: 'No puedes enviar una invitación a ti mismo' 
      });
    }

    // Crear registro en practicalo
    const { data: practicalo, error: practicaloError } = await supabase
      .from('practicalo')
      .insert([{
        sender_user_id,
        recipient_user_id,
        reto_id,
        pill_id,
        section_number: 8,
        message,
        status: 'pending'
      }])
      .select();

       if (practicaloError) {
      // 23505 = violación de la regla "no duplicados" (uq_practicalo_reto_unico_s8).
      // Este reto YA se había enviado: devolvemos el existente y NO creamos otra notificación.
      if (practicaloError.code === '23505') {
        console.log('ℹ️ Reto duplicado detectado, se devuelve el existente');

        const { data: existente, error: errorExistente } = await supabase
          .from('practicalo')
          .select('*')
          .eq('sender_user_id', sender_user_id)
          .eq('recipient_user_id', recipient_user_id)
          .eq('pill_id', pill_id)
          .eq('section_number', 8)
          .single();

        if (errorExistente) throw errorExistente;

        return res.status(200).json({
          success: true,
          data: existente,
          alreadyExisted: true
        });
      }

      console.error('❌ Error creando practicalo:', practicaloError);
      throw practicaloError;
    }

    const practicaloId = practicalo[0].id;
    console.log('✅ Practicalo creado:', practicaloId);

    // Crear notificación para el receptor
    const { data: notification, error: notifError } = await supabase
      .from('notifications')
      .insert([{
        recipient_user_id,
        sender_user_id,
        type: 'practicalo_invitation',
        message: `Te han enviado una invitación de práctica: "${message}"`,
        reto_id,
        pill_id,
        is_read: false
      }])
      .select();

    if (notifError) {
      console.error('⚠️ Error creando notificación:', notifError);
      // No lancar error, la notificación es secundaria
    } else {
      console.log('✅ Notificación creada:', notification[0].id);
    }

    res.status(201).json({ 
      success: true, 
      data: practicalo[0] 
    });
  } catch (error) {
    console.error('❌ Error en POST /practicalo:', error.message);
    res.status(400).json({ success: false, error: error.message });
  }
});

// 2️⃣ OBTENER PRACTICALO RECIBIDAS (las que recibió el usuario)
app.get('/api/practicalo/received/:userId', authenticateToken, async (req, res) => {
  try {
    const userId = req.params.userId;

    console.log('📥 GET /api/practicalo/received/:userId');
    console.log('   userId:', userId);

    const { data, error } = await supabase
      .from('practicalo')
      .select(`
        *,
        sender_user:sender_user_id(id, full_name, email),
        reto:reto_id(id, title)
      `)
      .eq('recipient_user_id', userId)
      .order('created_at', { ascending: false });

    if (error) {
      console.error('❌ Error en query:', error);
      throw error;
    }

    console.log('✅ Practicalo recibidas encontradas:', data.length);
    res.json({ success: true, data });
  } catch (error) {
    console.error('❌ Error en GET /received:', error.message);
    res.status(500).json({ success: false, error: error.message });
  }
});

// 3️⃣ OBTENER PRACTICALO ENVIADAS (las que envió el usuario)
app.get('/api/practicalo/sent/:userId', authenticateToken, async (req, res) => {
  try {
    const userId = req.params.userId;

    console.log('📤 GET /api/practicalo/sent/:userId');
    console.log('   userId:', userId);

    const { data, error } = await supabase
      .from('practicalo')
      .select(`
        *,
        recipient_user:recipient_user_id(id, full_name, email),
        reto:reto_id(id, title)
      `)
      .eq('sender_user_id', userId)
      .order('created_at', { ascending: false });

    if (error) {
      console.error('❌ Error en query:', error);
      throw error;
    }

    console.log('✅ Practicalo enviadas encontradas:', data.length);
    res.json({ success: true, data });
  } catch (error) {
    console.error('❌ Error en GET /sent:', error.message);
    res.status(500).json({ success: false, error: error.message });
  }
});

// 4️⃣ RESPONDER INVITACIÓN DE PRACTICALO
app.put('/api/practicalo/:id/response', authenticateToken, async (req, res) => {
  try {
    const practicaloId = req.params.id;
    const { response } = req.body; // 'yes_today', 'yes_later', 'no_thanks'
    const userId = req.user.id;

    console.log('💬 PUT /api/practicalo/:id/response');
    console.log('   Practicalo ID:', practicaloId);
    console.log('   Response:', response);
    console.log('   User ID:', userId);

    // Obtener el registro
    const { data: practicalo, error: getError } = await supabase
      .from('practicalo')
      .select('*')
      .eq('id', practicaloId)
      .single();

    if (getError || !practicalo) {
      return res.status(404).json({ success: false, error: 'Practicalo no encontrado' });
    }

    // Validar que el usuario sea el receptor
    if (practicalo.recipient_user_id !== userId) {
      return res.status(403).json({ success: false, error: 'No autorizado' });
    }

    // Determinar el nuevo estado
    let newStatus = 'accepted';
    let isBlocked = false;
    
    if (response === 'no_thanks') {
      newStatus = 'rejected';
      isBlocked = true;
    }

    // Actualizar el registro
    const { data: updated, error: updateError } = await supabase
      .from('practicalo')
      .update({
        response,
        response_date: new Date().toISOString(),
        status: newStatus,
        is_blocked: isBlocked,
        updated_at: new Date().toISOString()
      })
      .eq('id', practicaloId)
      .select();

    if (updateError) {
      console.error('❌ Error actualizando:', updateError);
      throw updateError;
    }

    console.log('✅ Respuesta registrada:', response);

    // Crear notificación para el sender
    const { error: notifError } = await supabase
      .from('notifications')
      .insert([{
        recipient_user_id: practicalo.sender_user_id,
        sender_user_id: userId,
        type: 'practicalo_response',
        message: `Respondieron tu invitación de práctica: ${response === 'yes_today' ? 'Sí, hoy' : response === 'yes_later' ? 'Sí, después' : 'No, disculpa'}`,
        reto_id: practicalo.reto_id,
        pill_id: practicalo.pill_id,
        is_read: false
      }])
      .select();

    if (notifError) {
      console.error('⚠️ Error creando notificación de respuesta:', notifError);
    } else {
      console.log('✅ Notificación de respuesta enviada');
    }

    res.json({ success: true, data: updated[0] });
  } catch (error) {
    console.error('❌ Error en PUT /response:', error.message);
    res.status(400).json({ success: false, error: error.message });
  }
});

// 5️⃣ CONFIRMAR QUE SE REUNIERON (envía el sender)
app.put('/api/practicalo/:id/confirm', authenticateToken, async (req, res) => {
  try {
    const practicaloId = req.params.id;
    const userId = req.user.id;

    console.log('✅ PUT /api/practicalo/:id/confirm');
    console.log('   Practicalo ID:', practicaloId);
    console.log('   User ID:', userId);

    // Obtener el registro
    const { data: practicalo, error: getError } = await supabase
      .from('practicalo')
      .select('*')
      .eq('id', practicaloId)
      .single();

    if (getError || !practicalo) {
      return res.status(404).json({ success: false, error: 'Practicalo no encontrado' });
    }

    // Validar que el usuario sea el sender
    if (practicalo.sender_user_id !== userId) {
      return res.status(403).json({ success: false, error: 'Solo el que envió puede confirmar' });
    }

    // Actualizar
    const { data: updated, error: updateError } = await supabase
      .from('practicalo')
      .update({
        confirmed_by_sender: true,
        confirmed_date: new Date().toISOString(),
        status: 'completed',
        updated_at: new Date().toISOString()
      })
      .eq('id', practicaloId)
      .select();

    if (updateError) {
      console.error('❌ Error confirmando:', updateError);
      throw updateError;
    }

    console.log('✅ Reunión confirmada');

    // Crear notificación para el receptor
    const { error: notifError } = await supabase
      .from('notifications')
      .insert([{
        recipient_user_id: practicalo.recipient_user_id,
        sender_user_id: userId,
        type: 'practicalo_confirmed',
        message: `Confirmó que ya se reunieron. ¡Por favor califica!`,
        reto_id: practicalo.reto_id,
        pill_id: practicalo.pill_id,
        is_read: false
      }])
      .select();

    if (notifError) {
      console.error('⚠️ Error creando notificación de confirmación:', notifError);
    }

    res.json({ success: true, data: updated[0] });
  } catch (error) {
    console.error('❌ Error en PUT /confirm:', error.message);
    res.status(400).json({ success: false, error: error.message });
  }
});

// 6️⃣ CALIFICAR AL OTRO USUARIO (5 estrellas)
app.put('/api/practicalo/:id/rate', authenticateToken, async (req, res) => {
  try {
    const practicaloId = req.params.id;
    const { star_rating } = req.body; // 1-5
    const userId = req.user.id;

    console.log('⭐ PUT /api/practicalo/:id/rate');
    console.log('   Practicalo ID:', practicaloId);
    console.log('   Rating:', star_rating);
    console.log('   User ID:', userId);

    // Validar rating
    if (!star_rating || star_rating < 1 || star_rating > 5) {
      return res.status(400).json({ 
        success: false, 
        error: 'Rating debe ser entre 1 y 5' 
      });
    }

    // Obtener el registro
    const { data: practicalo, error: getError } = await supabase
      .from('practicalo')
      .select('*')
      .eq('id', practicaloId)
      .single();

    if (getError || !practicalo) {
      return res.status(404).json({ success: false, error: 'Practicalo no encontrado' });
    }

    // Validar que el usuario sea el receptor (quien califica es el que recibió la invitación)
    if (practicalo.recipient_user_id !== userId) {
      return res.status(403).json({ success: false, error: 'Solo el receptor puede calificar' });
    }

    // Actualizar con la calificación
    const { data: updated, error: updateError } = await supabase
      .from('practicalo')
      .update({
        star_rating,
        updated_at: new Date().toISOString()
      })
      .eq('id', practicaloId)
      .select();

    if (updateError) {
      console.error('❌ Error calificando:', updateError);
      throw updateError;
    }

    console.log('✅ Calificación registrada:', star_rating);

    // Crear notificación para el sender
    const { error: notifError } = await supabase
      .from('notifications')
      .insert([{
        recipient_user_id: practicalo.sender_user_id,
        sender_user_id: userId,
        type: 'practicalo_rated',
        message: `Te calificó con ${star_rating} ⭐ en la práctica`,
        reto_id: practicalo.reto_id,
        pill_id: practicalo.pill_id,
        is_read: false
      }])
      .select();

    if (notifError) {
      console.error('⚠️ Error creando notificación de calificación:', notifError);
    }

    res.json({ success: true, data: updated[0] });
  } catch (error) {
    console.error('❌ Error en PUT /rate:', error.message);
    res.status(400).json({ success: false, error: error.message });
  }
});

// 7️⃣ OBTENER PROMEDIO DE CALIFICACIÓN POR USUARIO Y RETO
app.get('/api/practicalo/rating/:userId/:retoId', authenticateToken, async (req, res) => {
  try {
    const userId = req.params.userId;
    const retoId = req.params.retoId;

    console.log('📊 GET /api/practicalo/rating/:userId/:retoId');
    console.log('   User ID:', userId);
    console.log('   Reto ID:', retoId);

    // Obtener todas las calificaciones del usuario en ese reto
    const { data: ratings, error } = await supabase
      .from('practicalo')
      .select('star_rating')
      .eq('sender_user_id', userId)
      .eq('reto_id', retoId)
      .not('star_rating', 'is', null);

    if (error) {
      console.error('❌ Error en query:', error);
      throw error;
    }

    // Calcular promedio
    let average = 0;
    let count = ratings.length;

    if (count > 0) {
      const sum = ratings.reduce((acc, r) => acc + (r.star_rating || 0), 0);
      average = sum / count;
    }

    console.log(`✅ Promedio calculado: ${average.toFixed(2)} (${count} calificaciones)`);

    res.json({ 
      success: true, 
      average: average.toFixed(2),
      count,
      data: {
        user_id: userId,
        reto_id: retoId,
        average_rating: parseFloat(average.toFixed(2)),
        total_ratings: count
      }
    });
  } catch (error) {
    console.error('❌ Error en GET /rating:', error.message);
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
  console.log(`🔄 Actualizando racha para user: ${user_id}, reto: ${reto_id}`);

  try {
    // ========== PASO 1: Calcular rango de fechas del mes ==========
    const primerDiaDelMes = `${ano}-${String(mes).padStart(2, '0')}-01`;
    const proximoMes = mes === 12 ? 1 : mes + 1;
    const proximoAno = mes === 12 ? ano + 1 : ano;
    const primerDiaProximoMes = `${proximoAno}-${String(proximoMes).padStart(2, '0')}-01`;

    // ========== PASO 2: Obtener racha_maxima anterior ==========
    const { data: rachaActual, error: errorRachaActual } = await supabase
      .from('user_racha_stats')
      .select('racha_maxima')
      .eq('user_id', user_id)
      .eq('reto_id', reto_id)
      .eq('mes', mes)
      .eq('año', ano)
      .single();

    if (errorRachaActual && errorRachaActual.code !== 'PGRST116') {
      console.error('❌ Error en SELECT racha_maxima:', errorRachaActual);
      throw errorRachaActual;
    }

    // ========== PASO 3: Obtener todos los días del mes con sus datos ==========
    const { data: diasDelMes, error: errorDias } = await supabase
      .from('racha_daily_progress')
      .select('fecha, login_hecho, pildora_completada, es_dia_laboral')
      .eq('user_id', user_id)
      .eq('reto_id', reto_id)
      .gte('fecha', primerDiaDelMes)
      .lt('fecha', primerDiaProximoMes)
      .order('fecha', { ascending: true });

    if (errorDias) {
      console.error('❌ Error en SELECT racha_daily_progress:', errorDias);
      throw errorDias;
    }

    // ========== PASO 4: Filtrar solo días laborales ==========
    const diasLaborales = diasDelMes.filter(d => d.es_dia_laboral === true);
    console.log(`📅 Días laborales encontrados: ${diasLaborales.length}`);

    // ========== HELPER: Verificar si hueco es solo fin de semana ==========
    const esHuecoSoloFinDeSemana = (diaPrevio, diaActual, diasDelMes) => {
      const diasEnHueco = diasDelMes.filter(d => {
        const fecha = new Date(d.fecha);
        return fecha > diaPrevio && fecha < diaActual && d.es_dia_laboral === true;
      });
      return diasEnHueco.length === 0; // Si no hay días laborales, es solo fin de semana
    };

    // ========== PASO 5: Calcular racha_actual ==========
    let racha_actual = 0;
    
    if (diasLaborales && diasLaborales.length > 0) {
      const hoy = new Date();
      const hoyString = `${hoy.getFullYear()}-${String(hoy.getMonth() + 1).padStart(2, '0')}-${String(hoy.getDate()).padStart(2, '0')}`;
      
      // Buscar el índice de hoy en la lista de días laborales
      let indicioHoy = -1;
      for (let i = 0; i < diasLaborales.length; i++) {
        if (diasLaborales[i].fecha === hoyString) {
          indicioHoy = i;
          break;
        }
      }

      // Si hoy no es un día laboral, se rompe la racha
      if (indicioHoy === -1) {
        racha_actual = 0;
        console.log(`🔴 Racha rota - Hoy (${hoyString}) no es día laboral`);
      } else {
        // Contar consecutivos desde hoy hacia atrás verificando AMBAS condiciones
        for (let i = indicioHoy; i >= 0; i--) {
          const registro = diasLaborales[i];
          
          // Verificar si hay un hueco con el registro siguiente (hacia el futuro)
          if (i < indicioHoy) {
            const diaActual = new Date(registro.fecha);
            const diaSiguiente = new Date(diasLaborales[i + 1].fecha);
            const diffDias = (diaSiguiente - diaActual) / (1000 * 60 * 60 * 24);
            
            if (diffDias > 1) {
              // Verificar si es solo fin de semana
              if (esHuecoSoloFinDeSemana(diaActual, diaSiguiente, diasDelMes)) {
                console.log(`⏭️ Fin de semana entre ${registro.fecha} y ${diasLaborales[i + 1].fecha} - racha continúa`);
              } else {
                console.log(`🔴 Hueco con días laborales faltantes entre ${registro.fecha} y ${diasLaborales[i + 1].fecha}`);
                break;
              }
            }
          }
          
          // ✅ VERIFICAR QUE AMBAS CONDICIONES SEAN TRUE
          if (registro.login_hecho === true && registro.pildora_completada === true) {
            racha_actual++;
            console.log(`✅ Día ${registro.fecha}: login ✓ + píldora ✓ → racha_actual = ${racha_actual}`);
          } else {
            // ❌ Si no cumple AMBAS condiciones, se rompe la racha
            console.log(`🔴 Racha rota en ${registro.fecha}: login = ${registro.login_hecho}, píldora = ${registro.pildora_completada}`);
            break;
          }
        }
      }
    } else {
      racha_actual = 0;
      console.log(`🔴 No hay días laborales registrados este mes`);
    }

    // ========== PASO 6: NUEVO - Buscar MÁXIMA secuencia verificando huecos (ignorando fines de semana) ==========
    let racha_maxima_mes = 0;
    let racha_temporal = 0;

    for (let i = 0; i < diasLaborales.length; i++) {
      const registro = diasLaborales[i];
      
      // Verificar si hay un hueco con el registro anterior
      if (i > 0) {
        const diaActual = new Date(registro.fecha);
        const diaPrevio = new Date(diasLaborales[i - 1].fecha);
        const diffDias = (diaActual - diaPrevio) / (1000 * 60 * 60 * 24);
        
        // Si hay más de 1 día de diferencia, verificar si son todos no-laborales
        if (diffDias > 1) {
          // Verificar si es solo fin de semana
          if (esHuecoSoloFinDeSemana(diaPrevio, diaActual, diasDelMes)) {
            console.log(`⏭️ Fin de semana entre ${diasLaborales[i - 1].fecha} y ${registro.fecha} - racha continúa`);
          } else {
            // Hay días laborales faltantes, se rompe la secuencia
            console.log(`🔴 Hueco con días laborales faltantes entre ${diasLaborales[i - 1].fecha} y ${registro.fecha}`);
            if (racha_temporal > racha_maxima_mes) {
              racha_maxima_mes = racha_temporal;
              console.log(`🏆 Nueva máxima encontrada: ${racha_maxima_mes}`);
            }
            racha_temporal = 0;
          }
        }
      }
      
      // Si ambas condiciones son true, sumamos a la racha temporal
      if (registro.login_hecho === true && registro.pildora_completada === true) {
        racha_temporal++;
        console.log(`📈 Secuencia en ${registro.fecha}: racha_temporal = ${racha_temporal}`);
      } else {
        // Si se rompe, comparamos si es la máxima
        if (racha_temporal > racha_maxima_mes) {
          racha_maxima_mes = racha_temporal;
          console.log(`🏆 Nueva máxima encontrada: ${racha_maxima_mes}`);
        }
        racha_temporal = 0;
      }
    }
    
    // Verificar la última secuencia (si termina el mes con racha)
    if (racha_temporal > racha_maxima_mes) {
      racha_maxima_mes = racha_temporal;
      console.log(`🏆 Nueva máxima al final del mes: ${racha_maxima_mes}`);
    }

    // ========== PASO 7: Calcular racha_maxima final (nunca disminuye) ==========
    const racha_maxima_anterior = rachaActual?.racha_maxima || 0;
    const racha_maxima_nueva = Math.max(racha_maxima_anterior, racha_maxima_mes);
    
    console.log(`📊 Racha anterior: ${racha_maxima_anterior}, Máxima del mes: ${racha_maxima_mes}, Final: ${racha_maxima_nueva}`);

    // ========== PASO 8: Verificar si el registro ya existe ==========
    const { data: existente, error: errorExistente } = await supabase
      .from('user_racha_stats')
      .select('id')
      .eq('user_id', user_id)
      .eq('reto_id', reto_id)
      .eq('mes', mes)
      .eq('año', ano)
      .single();

    if (errorExistente && errorExistente.code !== 'PGRST116') {
      console.error('❌ Error en SELECT existente:', errorExistente);
      throw errorExistente;
    }

    // ========== PASO 9: Actualizar o insertar el registro ==========
    if (existente) {
      // Actualizar registro existente
      const { error: updateError } = await supabase
        .from('user_racha_stats')
        .update({
          racha_actual,
          racha_maxima: racha_maxima_nueva,
          updated_at: new Date().toISOString()
        })
        .eq('id', existente.id);

      if (updateError) {
        console.error('❌ Error en UPDATE user_racha_stats:', updateError);
        throw updateError;
      }
      
      console.log(`✅ Registro actualizado: racha_actual = ${racha_actual}, racha_maxima = ${racha_maxima_nueva}`);
    } else {
      // Insertar nuevo registro
      const { error: insertError } = await supabase
        .from('user_racha_stats')
        .insert([{
          user_id,
          reto_id,
          mes,
          año: ano,
          racha_actual,
          racha_maxima: racha_maxima_nueva
        }]);

      if (insertError) {
        console.error('❌ Error en INSERT user_racha_stats:', insertError);
        throw insertError;
      }
      
      console.log(`✅ Registro insertado: racha_actual = ${racha_actual}, racha_maxima = ${racha_maxima_nueva}`);
    }

    console.log(`🎯 Racha finalizada - Actual: ${racha_actual}, Máxima: ${racha_maxima_nueva}`);
  } catch (error) {
    console.error('❌ Error en _actualizarRacha:', error.message);
  }
}
// ========== CRON JOB: Verificar y resetear rachas rotas diariamente ==========
async function _verificarYResetearRachas() {
  console.log(`🔄 [CRON] Iniciando verificación de rachas rotas a las ${new Date().toISOString()}`);

  try {
    // Obtener todos los registros de user_racha_stats del mes actual
    const hoy = new Date();
    const mesActual = hoy.getMonth() + 1;
    const anoActual = hoy.getFullYear();

    const { data: allRachas, error: errorAllRachas } = await supabase
      .from('user_racha_stats')
      .select('user_id, reto_id, mes, año, racha_actual, racha_maxima')
      .eq('mes', mesActual)
      .eq('año', anoActual);

    if (errorAllRachas) {
      console.error('❌ [CRON] Error obteniendo user_racha_stats:', errorAllRachas);
      return;
    }

    if (!allRachas || allRachas.length === 0) {
      console.log(`ℹ️ [CRON] No hay rachas registradas para ${mesActual}/${anoActual}`);
      return;
    }

    console.log(`📊 [CRON] Verificando ${allRachas.length} registros de racha`);

    let rachasResetadas = 0;

    // Para cada registro de racha, verificar si se debe resetear
    for (const racha of allRachas) {
      const { user_id, reto_id, mes, año, racha_actual, racha_maxima } = racha;

      // Obtener el último día laboral (anterior a hoy)
      const primerDiaDelMes = `${año}-${String(mes).padStart(2, '0')}-01`;
      const proximoMes = mes === 12 ? 1 : mes + 1;
      const proximoAno = mes === 12 ? año + 1 : año;
      const primerDiaProximoMes = `${proximoAno}-${String(proximoMes).padStart(2, '0')}-01`;

      const { data: diasDelMes, error: errorDias } = await supabase
        .from('racha_daily_progress')
        .select('fecha, login_hecho, pildora_completada, es_dia_laboral')
        .eq('user_id', user_id)
        .eq('reto_id', reto_id)
        .gte('fecha', primerDiaDelMes)
        .lt('fecha', primerDiaProximoMes)
        .order('fecha', { ascending: false });

      if (errorDias) {
        console.error(`❌ [CRON] Error para usuario ${user_id}:`, errorDias);
        continue;
      }

      // Filtrar solo días laborales
      const diasLaborales = diasDelMes.filter(d => d.es_dia_laboral === true);

      if (!diasLaborales || diasLaborales.length === 0) {
        console.log(`⚠️ [CRON] Usuario ${user_id} - No hay días laborales`);
        continue;
      }

      // Obtener el último día laboral
      const ultimoDiaLaboral = diasLaborales[0]; // Ya está ordenado descendente
      const ultimoDiaLaboralFecha = new Date(ultimoDiaLaboral.fecha);
      const hoyFecha = new Date();
      hoyFecha.setHours(0, 0, 0, 0);

      // Si el último día laboral es anterior a hoy, verificar si cumple condiciones
      if (ultimoDiaLaboralFecha < hoyFecha) {
        const tieneAmbas = ultimoDiaLaboral.login_hecho === true && ultimoDiaLaboral.pildora_completada === true;

        if (!tieneAmbas && racha_actual > 0) {
          // La racha se rompió, resetear racha_actual a 0
          const { error: updateError } = await supabase
            .from('user_racha_stats')
            .update({
              racha_actual: 0,
              updated_at: new Date().toISOString()
            })
            .eq('user_id', user_id)
            .eq('reto_id', reto_id)
            .eq('mes', mes)
            .eq('año', año);

          if (updateError) {
            console.error(`❌ [CRON] Error reseteando racha para ${user_id}:`, updateError);
          } else {
            console.log(`🔴 [CRON] Racha rota para usuario ${user_id} - Actual: 0, Máxima: ${racha_maxima}`);
            rachasResetadas++;
          }
        }
      }
    }

    console.log(`✅ [CRON] Verificación completada - ${rachasResetadas} rachas reseteadas`);
  } catch (error) {
    console.error('❌ [CRON] Error en _verificarYResetearRachas:', error.message);
  }
}
// ✅ NUEVA FUNCIÓN: Registrar login automático para todos los retos
async function registrarLoginAutomatico(user_id, company_id) {
  try {
    console.log(`🔐 Registrando login automático para user: ${user_id}, company: ${company_id}`);
    
    if (!company_id) {
      console.log('⚠️ Usuario sin company_id, no se registra login');
      return;
    }

    // Obtener todos los retos de la compañía
    const { data: retos, error: errorRetos } = await supabase
      .from('retos')
      .select('id')
      .eq('company_id', company_id);

    if (errorRetos) {
      console.error('❌ Error obteniendo retos:', errorRetos.message);
      return;
    }

    console.log(`📋 Retos encontrados: ${retos.length}`);

    // Registrar login para cada reto
    const today = new Date().toISOString().split('T')[0];
    const mesNum = new Date().getMonth() + 1;
    const anoNum = new Date().getFullYear();

    for (const reto of retos) {
      try {
        // Buscar si ya existe registro para hoy
        const { data: existente, error: errorCheck } = await supabase
          .from('racha_daily_progress')
          .select('id')
          .eq('user_id', user_id)
          .eq('reto_id', reto.id)
          .eq('fecha', today)
          .single();

        if (errorCheck && errorCheck.code !== 'PGRST116') {
          console.error('❌ Error en check:', errorCheck.message);
          continue;
        }

        if (existente) {
          // Actualizar login_hecho
          await supabase
            .from('racha_daily_progress')
            .update({ login_hecho: true })
            .eq('id', existente.id);
          console.log(`✅ Login actualizado para reto: ${reto.id}`);
        } else {
          // Crear nuevo registro
          await supabase
            .from('racha_daily_progress')
            .insert([{
              user_id,
              reto_id: reto.id,
              fecha: today,
              login_hecho: true,
              pildora_completada: false,
              es_dia_laboral: _esDialaboral(new Date()),
            }]);
          console.log(`✅ Login registrado para reto: ${reto.id}`);
        }

        // Actualizar racha
        await _actualizarRacha(user_id, reto.id, mesNum, anoNum);
      } catch (err) {
        console.error(`⚠️ Error registrando login para reto ${reto.id}:`, err.message);
      }
    }
  } catch (error) {
    console.error('❌ Error en registrarLoginAutomatico:', error.message);
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

app.post('/api/racha/verificar-racha', authenticateToken, async (req, res) => {
  try {
    const { user_id } = req.body;
    
    if (!user_id) {
      return res.status(400).json({
        success: false,
        error: 'Falta parámetro: user_id'
      });
    }

    console.log(`🔍 POST /api/racha/verificar-racha - User: ${user_id}`);

    const today = new Date().toISOString().split('T')[0];
    const yesterday = new Date(Date.now() - 86400000).toISOString().split('T')[0];

    // Obtener TODOS los retos del usuario
    const { data: userRetos, error: errorRetos } = await supabase
      .from('user_pill_progress')
      .select('pill_id(reto_id)')
      .eq('user_id', user_id)
      

    if (errorRetos) throw errorRetos;

    const retoIds = [...new Set(userRetos.map(r => r.pill_id?.reto_id))].filter(Boolean);

    // Para cada reto, verificar y resetear si es necesario
    for (const retoId of retoIds) {
            const mesActual = new Date().getMonth() + 1;
      const anoActual = new Date().getFullYear();

      const { data: stats, error: errorStats } = await supabase
        .from('user_racha_stats')
        .select('*')
        .eq('user_id', user_id)
        .eq('reto_id', retoId)
        .eq('mes', mesActual)
        .eq('año', anoActual)
        .single();

      if (errorStats && errorStats.code !== 'PGRST116') {
        throw errorStats;
      }

      if (!stats) continue;

      // Verificar si ayer cumplió AMBAS condiciones
      const { data: ayer, error: errorAyer } = await supabase
        .from('racha_daily_progress')
        .select('*')
        .eq('user_id', user_id)
        .eq('reto_id', retoId)
        .eq('fecha', yesterday)
        .single();

      const cumplioAyer = ayer && ayer.login_hecho && ayer.pildora_completada;

      if (!cumplioAyer && stats.racha_actual > 0) {
        console.log(`🔌 RACHA ROTA para user ${user_id}, reto ${retoId}. Reseteando a 0`);
        
               await supabase
          .from('user_racha_stats')
          .update({
            racha_actual: 0,
            fecha_ultima_racha: yesterday
          })
          .eq('user_id', user_id)
          .eq('reto_id', retoId)
          .eq('mes', mesActual)
          .eq('año', anoActual);
      }
    }

    res.json({ 
      success: true, 
      message: 'Verificación de racha completada',
      retos_verificados: retoIds.length 
    });

  } catch (error) {
    console.error('❌ Error en verificar-racha:', error.message);
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

// ===== ENDPOINT CORREGIDO: Leaderboard con Días Cumplidos Y Racha =====
app.get('/api/racha/leaderboard-dias-cumplidos', authenticateToken, async (req, res) => {
  try {
    const { mes, ano } = req.query;

    if (!mes || !ano) {
      return res.status(400).json({
        success: false,
        error: 'Faltan parámetros: mes, ano'
      });
    }

    console.log(`🏆 GET /api/racha/leaderboard-dias-cumplidos - Mes: ${mes}/${ano}`);

    const mesNum = parseInt(mes);
    const anoNum = parseInt(ano);
    const ultimoDiaDelMes = new Date(anoNum, mesNum, 0).getDate();

    // ===== LEADERBOARD 1: Por RACHA MÁXIMA =====
    const { data: todasLasRachas, error: errorRachas } = await supabase
      .from('user_racha_stats')
      .select('*')
      .eq('mes', mesNum)
      .eq('año', anoNum);

    if (errorRachas) throw errorRachas;

    const usuariosRacha = {};
    for (const racha of todasLasRachas) {
      if (!usuariosRacha[racha.user_id]) {
        usuariosRacha[racha.user_id] = {
          user_id: racha.user_id,
          mejor_racha: 0,
          retos_participados: 0
        };
      }
      usuariosRacha[racha.user_id].mejor_racha = Math.max(
        usuariosRacha[racha.user_id].mejor_racha,
        racha.racha_maxima
      );
      usuariosRacha[racha.user_id].retos_participados++;
    }

    let leaderboardRacha = Object.values(usuariosRacha);
    // Filtrar solo usuarios con racha > 0
leaderboardRacha = leaderboardRacha.filter(u => u.mejor_racha > 0);
    leaderboardRacha.sort((a, b) => b.mejor_racha - a.mejor_racha);

       leaderboardRacha = (await Promise.all(leaderboardRacha.map(async (item) => {
      const { data: usuario, error: errorUsuario } = await supabase
        .from('users')
        .select('full_name, email')
        .eq('id', item.user_id)
        .single();

      if (errorUsuario || !usuario) {
        console.warn(`⚠️ Usuario ${item.user_id} no encontrado en tabla users - OMITIDO del leaderboard`);
        return null;
      }

      return {
        full_name: usuario.full_name || 'Sin nombre',
        email: usuario.email || 'N/A',
        user_id: item.user_id,
        mejor_racha: item.mejor_racha || 0,
        racha_actual: item.racha_actual || 0,
        pildoras_cumplidas: 0
      };
    }))).filter(item => item !== null).map((item, index) => ({
      ...item,
      position: index + 1
    }));

    // ===== LEADERBOARD 2: Por DÍAS CUMPLIDOS =====
    const { data: todasCompletadas, error: errorCompletadas } = await supabase
      .from('user_pill_progress')
      .select('user_id')
      .eq('is_completed', true)
      .gte('completed_at', `${anoNum}-${String(mesNum).padStart(2, '0')}-01`)
      .lte('completed_at', `${anoNum}-${String(mesNum).padStart(2, '0')}-${String(ultimoDiaDelMes).padStart(2, '0')}`);

    if (errorCompletadas) throw errorCompletadas;

    const usuariosCumplidos = {};
    for (const item of todasCompletadas) {
      if (!usuariosCumplidos[item.user_id]) {
        usuariosCumplidos[item.user_id] = 0;
      }
      usuariosCumplidos[item.user_id]++;
    }

    let leaderboardDiasCumplidos = [];
    for (const [user_id, dias_cumplidos] of Object.entries(usuariosCumplidos)) {
      const { data: usuario } = await supabase
        .from('users')
        .select('full_name, email')
        .eq('id', user_id)
        .single();

      if (usuario) {
        leaderboardDiasCumplidos.push({
          user_id,
          full_name: usuario.full_name || usuario.email || 'Usuario',
          dias_cumplidos_total: parseInt(dias_cumplidos)
        });
      }
    }

    leaderboardDiasCumplidos.sort((a, b) => b.dias_cumplidos_total - a.dias_cumplidos_total);
    leaderboardDiasCumplidos = leaderboardDiasCumplidos.map((item, index) => ({
      position: index + 1,
      ...item
    }));
    // ===== LEADERBOARD UNIFICADO: Racha + Píldoras Cumplidas =====
    const unificadoMap = {};
    for (const item of leaderboardRacha) {
      unificadoMap[item.user_id] = {
        user_id: item.user_id,
        full_name: item.full_name,
        mejor_racha: item.mejor_racha,
        pildoras_cumplidas: 0
      };
    }
    for (const item of leaderboardDiasCumplidos) {
      if (unificadoMap[item.user_id]) {
        unificadoMap[item.user_id].pildoras_cumplidas = item.dias_cumplidos_total;
      } else {
        unificadoMap[item.user_id] = {
          user_id: item.user_id,
          full_name: item.full_name,
          mejor_racha: 0,
          pildoras_cumplidas: item.dias_cumplidos_total
        };
      }
    }
    let leaderboardUnificado = Object.values(unificadoMap);
    leaderboardUnificado.sort((a, b) => {
      if (b.mejor_racha !== a.mejor_racha) return b.mejor_racha - a.mejor_racha;
      return b.pildoras_cumplidas - a.pildoras_cumplidas;
    });
    leaderboardUnificado = leaderboardUnificado.map((item, index) => ({
      position: index + 1,
      ...item
    }));
       console.log(`🏆 Leaderboard Racha: ${leaderboardRacha.length} usuarios`);
    console.log(`🏆 Leaderboard Días Cumplidos: ${leaderboardDiasCumplidos.length} usuarios`);

    res.json({
      success: true,
      data: {
        leaderboard_racha: leaderboardRacha,
        leaderboard_dias_cumplidos: leaderboardDiasCumplidos,
        leaderboard_unificado: leaderboardUnificado,
        mes: mesNum,
        ano: anoNum
      }
    });
  } catch (error) {
    console.error('❌ Error en leaderboard-dias-cumplidos:', error.message);
    res.status(400).json({ success: false, error: error.message });
  }
});
// ===== ENDPOINTS DE TEST (SOLO PARA DESARROLLO) =====
app.get('/api/racha/test-cron', async (req, res) => {
  try {
    console.log('🧪 TEST: Ejecutando verificación manual de rachas...');
    await _verificarYResetearRachas();
    res.json({ 
      success: true, 
      mensaje: '✅ Verificación de rachas completada exitosamente',
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    console.error('❌ Error en test-cron:', error);
    res.status(500).json({ 
      success: false, 
      error: error.message 
    });
  }
});
app.get('/api/racha/test-user/:user_id/:reto_id', async (req, res) => {
  try {
    const { user_id, reto_id } = req.params;
    const hoy = new Date().toISOString().split('T')[0];
    const mes = new Date().getMonth() + 1;
    const ano = new Date().getFullYear();

    console.log(`🧪 TEST: Verificando racha para user_id: ${user_id}, reto_id: ${reto_id}, mes: ${mes}, año: ${ano}`);

    // Primero actualizamos la racha con el reto_id correcto
    await _actualizarRacha(user_id, reto_id, mes, ano);

    // Luego obtenemos los datos actualizados
    const { data, error } = await supabase
      .from('user_racha_stats')
      .select('*')
      .eq('user_id', user_id)
      .eq('reto_id', reto_id)
      .eq('mes', mes)
      .eq('año', ano)
      .single();

    if (error) {
      return res.status(404).json({ 
        success: false, 
        error: 'Racha no encontrada en user_racha_stats',
        detalle: error.message
      });
    }

    // También traemos los registros diarios del usuario
    const primerDiaDelMes = `${ano}-${String(mes).padStart(2, '0')}-01`;
    const proximoMes = mes === 12 ? 1 : mes + 1;
    const proximoAno = mes === 12 ? ano + 1 : ano;
    const primerDiaProximoMes = `${proximoAno}-${String(proximoMes).padStart(2, '0')}-01`;

    const { data: registrosDiarios } = await supabase
      .from('racha_daily_progress')
      .select('fecha, login_hecho, pildora_completada, es_dia_laboral')
      .eq('user_id', user_id)
      .eq('reto_id', reto_id)
      .gte('fecha', primerDiaDelMes)
      .lt('fecha', primerDiaProximoMes)
      .order('fecha', { ascending: true });

    console.log(`✅ Racha encontrada - Actual: ${data.racha_actual}, Máxima: ${data.racha_maxima}`);

    res.json({
      success: true,
      racha_stats: data,
      ultimos_dias: registrosDiarios ? registrosDiarios : []
    });
  } catch (error) {
    console.error('❌ Error en test-user:', error);
    res.status(500).json({ 
      success: false, 
      error: error.message 
    });
  }
});
// ===== PLANIFICACIÓN DE RETOS: HELPERS =====
const MESES_ES = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
  'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];

// Fecha de hoy en Madrid como 'YYYY-MM-DD' (Render corre en UTC)
function _hoyMadrid() {
  return new Date().toLocaleDateString('en-CA', { timeZone: 'Europe/Madrid' });
}

function _pad2(n) {
  return String(n).padStart(2, '0');
}

// Clave numérica para comparar meses: 2026-09 -> 202609
function _claveMes(anio, mes) {
  return anio * 100 + mes;
}

function _mesSiguiente(anio, mes) {
  return mes === 12 ? { anio: anio + 1, mes: 1 } : { anio, mes: mes + 1 };
}

function _mesAnterior(anio, mes) {
  return mes === 1 ? { anio: anio - 1, mes: 12 } : { anio, mes: mes - 1 };
}

// Primer día laboral (lunes a viernes, sin festivos) de un mes -> 'YYYY-MM-DD'
function _primerDiaLaboral(anio, mes, festivosSet) {
  const ultimoDia = new Date(Date.UTC(anio, mes, 0)).getUTCDate();
  for (let d = 1; d <= ultimoDia; d++) {
    const diaSemana = new Date(Date.UTC(anio, mes - 1, d)).getUTCDay();
    const fechaStr = `${anio}-${_pad2(mes)}-${_pad2(d)}`;
    if (diaSemana >= 1 && diaSemana <= 5 && !festivosSet.has(fechaStr)) {
      return fechaStr;
    }
  }
  return `${anio}-${_pad2(mes)}-01`;
}

async function _cargarFestivos(desdeAnio, hastaAnio) {
  const { data, error } = await supabase
    .from('dias_festivos')
    .select('fecha')
    .gte('fecha', `${desdeAnio}-01-01`)
    .lte('fecha', `${hastaAnio}-12-31`);
  if (error) throw error;
  return new Set((data || []).map(f => f.fecha));
}

// Calcula el mes vigente y la lista de meses visibles con su estado de bloqueo
async function _calcularCalendarioPlanificacion() {
  const hoy = _hoyMadrid();
  const anioHoy = parseInt(hoy.slice(0, 4), 10);
  const mesHoy = parseInt(hoy.slice(5, 7), 10);

  const festivos = await _cargarFestivos(anioHoy - 1, anioHoy + 1);

  // Mes vigente = último mes cuyo primer día laboral ya llegó
  let vigente = { anio: anioHoy, mes: mesHoy };
  if (hoy < _primerDiaLaboral(anioHoy, mesHoy, festivos)) {
    vigente = _mesAnterior(anioHoy, mesHoy);
  }

  // Hasta diciembre de este año; si estamos en diciembre, hasta diciembre del año siguiente
  const anioFin = mesHoy === 12 ? anioHoy + 1 : anioHoy;

  const meses = [];
  let m = { ...vigente };
  while (_claveMes(m.anio, m.mes) <= _claveMes(anioFin, 12)) {
    const fechaBloqueo = _primerDiaLaboral(m.anio, m.mes, festivos);
    meses.push({
      anio: m.anio,
      mes: m.mes,
      nombre: `${MESES_ES[m.mes - 1]} ${m.anio}`,
      fecha_bloqueo: fechaBloqueo,
      bloqueado: hoy >= fechaBloqueo,
    });
    m = _mesSiguiente(m.anio, m.mes);
  }

  return { hoy, vigente, meses };
}

// Retos de la empresa del usuario
async function _retosDeEmpresa(userId) {
  const { data: userData, error: userError } = await supabase
    .from('users')
    .select('company_id')
    .eq('id', userId)
    .single();
  if (userError) throw userError;

  let query = supabase.from('retos').select('*').order('title');
  if (userData.company_id) {
    query = query.eq('company_id', userData.company_id);
  }
  const { data, error } = await query;
  if (error) throw error;
  return data || [];
}

// Devuelve un Set con los ids de retos que el usuario ya completó (todas sus píldoras)
async function _retosCompletadosDeUsuario(userId, retoIds) {
  if (!retoIds || retoIds.length === 0) return new Set();

  const { data: pills, error: pillsError } = await supabase
    .from('pildoras')
    .select('id, reto_id')
    .in('reto_id', retoIds);
  if (pillsError) throw pillsError;

  const { data: progreso, error: progError } = await supabase
    .from('user_pill_progress')
    .select('pill_id')
    .eq('user_id', userId)
    .eq('is_completed', true);
  if (progError) throw progError;

  const pildorasHechas = new Set((progreso || []).map(p => p.pill_id));
  const conteo = {};
  (pills || []).forEach(p => {
    if (!conteo[p.reto_id]) conteo[p.reto_id] = { total: 0, hechas: 0 };
    conteo[p.reto_id].total++;
    if (pildorasHechas.has(p.id)) conteo[p.reto_id].hechas++;
  });

  return new Set(
    Object.entries(conteo)
      .filter(([, v]) => v.total > 0 && v.hechas >= v.total)
      .map(([retoId]) => retoId)
  );
}
// ===== PLANIFICACIÓN DE RETOS: OBTENER =====
app.get('/api/planificacion', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;
    console.log('🗓️ GET /api/planificacion - Usuario:', userId);

    const { hoy, vigente, meses } = await _calcularCalendarioPlanificacion();
    const retos = await _retosDeEmpresa(userId);
    const completados = await _retosCompletadosDeUsuario(userId, retos.map(r => r.id));

    const { data: planes, error: planesError } = await supabase
      .from('planificacion_retos')
      .select('anio, mes, slot, reto_id')
      .eq('user_id', userId);
    if (planesError) throw planesError;

    // Solo nos interesan los planes desde el mes vigente en adelante
    const primero = meses[0];
    const ultimo = meses[meses.length - 1];
    const planesEnRango = (planes || []).filter(p => {
      const k = _claveMes(p.anio, p.mes);
      return k >= _claveMes(primero.anio, primero.mes) && k <= _claveMes(ultimo.anio, ultimo.mes);
    });
    // Si el usuario no planificó nada para el mes vigente, se le asigna un reto al azar
    const tienePlanVigente = planesEnRango.some(
      p => p.anio === vigente.anio && p.mes === vigente.mes
    );

    if (!tienePlanVigente) {
      const retosYaPlanificados = new Set(planesEnRango.map(p => p.reto_id));
      const candidatos = retos.filter(
        r => !completados.has(r.id) && !retosYaPlanificados.has(r.id)
      );

      if (candidatos.length > 0) {
        const elegido = candidatos[Math.floor(Math.random() * candidatos.length)];

        const { error: insertError } = await supabase
          .from('planificacion_retos')
          .upsert(
            {
              user_id: userId,
              reto_id: elegido.id,
              anio: vigente.anio,
              mes: vigente.mes,
              slot: 1,
            },
            { onConflict: 'user_id,anio,mes,slot', ignoreDuplicates: true }
          );
        if (insertError) throw insertError;

        planesEnRango.push({
          anio: vigente.anio,
          mes: vigente.mes,
          slot: 1,
          reto_id: elegido.id,
        });
        console.log(`🎲 Reto asignado al azar para ${vigente.mes}/${vigente.anio}:`, elegido.title);
      } else {
        console.log('ℹ️ No hay retos disponibles para asignar al azar');
      }
    }
    // Meses con sus planes. Un mes bloqueado solo se muestra si tiene retos inscritos
    const mesesRespuesta = meses
      .map(m => ({
        ...m,
        planes: planesEnRango
          .filter(p => p.anio === m.anio && p.mes === m.mes)
          .sort((a, b) => a.slot - b.slot)
          .map(p => ({ slot: p.slot, reto_id: p.reto_id })),
      }))
      .filter(m => !m.bloqueado || m.planes.length > 0);

    // Retos inscritos en el mes vigente
    const retosDelMes = planesEnRango
      .filter(p => p.anio === vigente.anio && p.mes === vigente.mes)
      .sort((a, b) => a.slot - b.slot)
      .map(p => retos.find(r => r.id === p.reto_id))
      .filter(Boolean);

    res.json({
      success: true,
      hoy,
      mes_vigente: {
        anio: vigente.anio,
        mes: vigente.mes,
        nombre: `${MESES_ES[vigente.mes - 1]} ${vigente.anio}`,
      },
      meses: mesesRespuesta,
      retos,
      retos_completados: [...completados],
      retos_del_mes: retosDelMes,
    });
  } catch (error) {
    console.error('❌ Error en GET /api/planificacion:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});
// ===== PLANIFICACIÓN DE RETOS: GUARDAR / QUITAR =====
// Body: { anio, mes, slot (1|2), reto_id (uuid o null para quitar) }
app.put('/api/planificacion', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;
    const anio = parseInt(req.body.anio, 10);
    const mes = parseInt(req.body.mes, 10);
    const slot = parseInt(req.body.slot, 10);
    const retoId = req.body.reto_id || null;

    console.log('🗓️ PUT /api/planificacion', { userId, anio, mes, slot, retoId });

    if (!anio || !mes || ![1, 2].includes(slot)) {
      return res.status(400).json({ success: false, error: 'Datos incompletos' });
    }

    // 1) El mes debe estar en el rango visible y no estar bloqueado
    const { meses } = await _calcularCalendarioPlanificacion();
    const mesInfo = meses.find(m => m.anio === anio && m.mes === mes);
    if (!mesInfo) {
      return res.status(400).json({ success: false, error: 'Ese mes no se puede planificar' });
    }
    if (mesInfo.bloqueado) {
      return res.status(403).json({ success: false, error: 'Este mes ya está bloqueado' });
    }

    // 2) Quitar el reto del desplegable
    if (!retoId) {
      const { error: delError } = await supabase
        .from('planificacion_retos')
        .delete()
        .eq('user_id', userId)
        .eq('anio', anio)
        .eq('mes', mes)
        .eq('slot', slot);
      if (delError) throw delError;
      return res.json({ success: true, message: 'Reto quitado' });
    }

    // 3) El reto debe ser de la empresa del usuario
    const retos = await _retosDeEmpresa(userId);
    if (!retos.some(r => r.id === retoId)) {
      return res.status(400).json({ success: false, error: 'Reto no disponible para tu empresa' });
    }

    // 4) No puede estar completado
    const completados = await _retosCompletadosDeUsuario(userId, [retoId]);
    if (completados.has(retoId)) {
      return res.status(400).json({ success: false, error: 'Ya completaste este reto' });
    }

    // 5) No puede estar elegido en otro mes / desplegable (desde el mes vigente en adelante)
    const primero = meses[0];
    const { data: usosReto, error: usosError } = await supabase
      .from('planificacion_retos')
      .select('anio, mes, slot')
      .eq('user_id', userId)
      .eq('reto_id', retoId);
    if (usosError) throw usosError;

    const repetido = (usosReto || []).some(p =>
      _claveMes(p.anio, p.mes) >= _claveMes(primero.anio, primero.mes) &&
      !(p.anio === anio && p.mes === mes && p.slot === slot)
    );
    if (repetido) {
      return res.status(400).json({ success: false, error: 'Ya elegiste este reto en otro mes' });
    }

    // 6) Guardar (crea o reemplaza el reto de ese desplegable)
    const { error: upsertError } = await supabase
      .from('planificacion_retos')
      .upsert(
        {
          user_id: userId,
          reto_id: retoId,
          anio,
          mes,
          slot,
          updated_at: new Date().toISOString(),
        },
        { onConflict: 'user_id,anio,mes,slot' }
      );
    if (upsertError) throw upsertError;

       res.json({ success: true, message: 'Planificación guardada' });
  } catch (error) {
    console.error('❌ Error en PUT /api/planificacion:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

// ═══════════════ HOME: DESTACADOS ═══════════════

// Supabase devuelve máximo 1000 filas por consulta: esta función pide por páginas hasta traer todo
async function _traerTodo(crearQuery) {
  const tam = 1000;
  let desde = 0;
  let todo = [];
  while (true) {
    const { data, error } = await crearQuery().range(desde, desde + tam - 1);
    if (error) throw error;
    todo = todo.concat(data || []);
    if (!data || data.length < tam) break;
    desde += tam;
  }
  return todo;
}

// GET: Top 10 píldoras mejor calificadas, Top 10 retos más inscritos y Top 10 retos mejor calificados
app.get('/api/home/destacados', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;
    console.log('🏠 GET /api/home/destacados - Usuario:', userId);

    // 1) Retos y píldoras de la empresa del usuario
    const retos = await _retosDeEmpresa(userId);
    const retoIds = retos.map(r => r.id);
    if (retoIds.length === 0) {
      return res.json({ success: true, top_pildoras: [], top_inscritos: [], top_calificados: [] });
    }

    const retoPorId = {};
    retos.forEach(r => { retoPorId[r.id] = r; });

    const pildoras = await _traerTodo(() =>
      supabase
        .from('pildoras')
        .select('id, reto_id, pill_number, title, key_skill, description, duration_minutes')
        .in('reto_id', retoIds)
        .order('id')
    );

    const pildoraPorId = {};
    const totalPildorasPorReto = {};
    pildoras.forEach(p => {
      pildoraPorId[p.id] = p;
      totalPildorasPorReto[p.reto_id] = (totalPildorasPorReto[p.reto_id] || 0) + 1;
    });

    // 2) Calificaciones de píldoras (solo de píldoras de la empresa, 1 por usuario+píldora)
    const filasCalificadas = await _traerTodo(() =>
      supabase
        .from('user_pill_progress')
        .select('id, user_id, pill_id, pill_rating')
        .not('pill_rating', 'is', null)
        .order('id')
    );

    const calificacionUnica = {}; // "userId_pillId" -> { user_id, pill_id, rating }
    filasCalificadas.forEach(c => {
      const rating = Number(c.pill_rating);
      if (!pildoraPorId[c.pill_id] || !(rating > 0)) return;
      calificacionUnica[`${c.user_id}_${c.pill_id}`] = {
        user_id: c.user_id,
        pill_id: c.pill_id,
        rating,
      };
    });
        // También cuentan las estrellas de las píldoras sueltas.
    // Si el usuario calificó la misma píldora dentro del reto, se queda la del reto (no se duplica).
    const sueltasCalificadas = await _traerTodo(() =>
      supabase
        .from('pildoras_sueltas')
        .select('id, user_id, pill_id, pill_rating')
        .eq('is_completed', true)
        .not('pill_rating', 'is', null)
        .order('id')
    );

    sueltasCalificadas.forEach(c => {
      const rating = Number(c.pill_rating);
      const clave = `${c.user_id}_${c.pill_id}`;
      if (!pildoraPorId[c.pill_id] || !(rating > 0) || calificacionUnica[clave]) return;
      calificacionUnica[clave] = {
        user_id: c.user_id,
        pill_id: c.pill_id,
        rating,
      };
    });

    const calificaciones = Object.values(calificacionUnica);

        // 3) TOP 20 PÍLDORAS MEJOR CALIFICADAS (promedio de estrellas)
    const porPildora = {};
    calificaciones.forEach(c => {
      if (!porPildora[c.pill_id]) porPildora[c.pill_id] = { suma: 0, votos: 0 };
      porPildora[c.pill_id].suma += c.rating;
      porPildora[c.pill_id].votos++;
    });

    const topPildoras = Object.entries(porPildora)
      .map(([pillId, v]) => {
        const p = pildoraPorId[pillId];
        return {
          ...p,
          reto_title: retoPorId[p.reto_id] ? retoPorId[p.reto_id].title : '',
          promedio: Number((v.suma / v.votos).toFixed(2)),
          total_calificaciones: v.votos,
        };
      })
            .sort((a, b) => b.promedio - a.promedio || b.total_calificaciones - a.total_calificaciones)
      .slice(0, 20);

    // 4) TOP 10 RETOS MÁS INSCRITOS (usuarios distintos en planificacion_retos)
    const planes = await _traerTodo(() =>
      supabase
        .from('planificacion_retos')
        .select('user_id, reto_id, anio, mes, slot')
        .in('reto_id', retoIds)
        .order('user_id')
        .order('anio')
        .order('mes')
        .order('slot')
    );

    const inscritosPorReto = {};
    planes.forEach(p => {
      if (!inscritosPorReto[p.reto_id]) inscritosPorReto[p.reto_id] = new Set();
      inscritosPorReto[p.reto_id].add(p.user_id);
    });

    const topInscritos = retos
      .map(r => ({
        ...r,
        total_pildoras: totalPildorasPorReto[r.id] || 0,
        inscritos: inscritosPorReto[r.id] ? inscritosPorReto[r.id].size : 0,
      }))
      .filter(r => r.inscritos > 0)
      .sort((a, b) => b.inscritos - a.inscritos)
      .slice(0, 10);

    // 5) TOP 10 RETOS MEJOR CALIFICADOS
    //    Por usuario: suma de sus estrellas en el reto / total de píldoras del reto (no hechas = 0)
    //    Luego: promedio entre todos los usuarios que calificaron alguna píldora del reto
    const sumaPorRetoUsuario = {}; // retoId -> { userId -> suma de estrellas }
    calificaciones.forEach(c => {
      const retoId = pildoraPorId[c.pill_id].reto_id;
      if (!sumaPorRetoUsuario[retoId]) sumaPorRetoUsuario[retoId] = {};
      sumaPorRetoUsuario[retoId][c.user_id] =
        (sumaPorRetoUsuario[retoId][c.user_id] || 0) + c.rating;
    });

    const topCalificados = retos
      .filter(r => sumaPorRetoUsuario[r.id] && totalPildorasPorReto[r.id])
      .map(r => {
        const totalPildoras = totalPildorasPorReto[r.id];
        const sumasUsuarios = Object.values(sumaPorRetoUsuario[r.id]);
        const promediosUsuario = sumasUsuarios.map(suma => suma / totalPildoras);
        const promedio =
          promediosUsuario.reduce((acc, x) => acc + x, 0) / promediosUsuario.length;
        return {
          ...r,
          total_pildoras: totalPildoras,
          promedio: Number(promedio.toFixed(2)),
          total_usuarios: sumasUsuarios.length,
        };
      })
      .sort((a, b) => b.promedio - a.promedio || b.total_usuarios - a.total_usuarios)
      .slice(0, 10);

    console.log(`✅ Destacados: ${topPildoras.length} píldoras, ${topInscritos.length} inscritos, ${topCalificados.length} calificados`);

    res.json({
      success: true,
      top_pildoras: topPildoras,
      top_inscritos: topInscritos,
      top_calificados: topCalificados,
    });
   } catch (error) {
    console.error('❌ Error en GET /api/home/destacados:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

// ═══════════════ PÍLDORAS SUELTAS (desde Inicio) ═══════════════
// No escriben en user_pill_progress ni en racha → no afectan Rachas ni rankings

// ¿El usuario ya completó esta píldora dentro de su reto?
async function _completadaEnReto(userId, pillId) {
  const { data, error } = await supabase
    .from('user_pill_progress')
    .select('id')
    .eq('user_id', userId)
    .eq('pill_id', pillId)
    .eq('is_completed', true)
    .limit(1);
  if (error) throw error;
  return (data || []).length > 0;
}

// Fila de pildoras_sueltas del usuario para esa píldora (o null)
async function _filaSuelta(userId, pillId) {
  const { data, error } = await supabase
    .from('pildoras_sueltas')
    .select('*')
    .eq('user_id', userId)
    .eq('pill_id', pillId)
    .maybeSingle();
  if (error) throw error;
  return data;
}

// GET: Estado de la píldora suelta para el usuario
app.get('/api/pildoras-sueltas/:pillId', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;
    const { pillId } = req.params;

    const fila = await _filaSuelta(userId, pillId);
    const completadaEnReto = await _completadaEnReto(userId, pillId);

    res.json({
      success: true,
      data: {
        self_assesment_score: fila ? fila.self_assesment_score : null,
        is_completed: fila ? fila.is_completed === true : false,
        completada_en_reto: completadaEnReto,
      },
    });
  } catch (error) {
    console.error('❌ Error en GET /api/pildoras-sueltas/:pillId:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

// PUT: Guardar autopercepción (sección 5) de una píldora suelta
app.put('/api/pildoras-sueltas/:pillId/autopercepcion', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;
    const { pillId } = req.params;
    const score = parseInt(req.body.self_assesment_score, 10);

    if (!score || score < 1 || score > 5) {
      return res.status(400).json({ success: false, error: 'Autopercepción no válida' });
    }

    const fila = await _filaSuelta(userId, pillId);
    if (fila && fila.is_completed) {
      return res.status(400).json({ success: false, error: 'Ya hiciste esta píldora' });
    }

    const { error } = await supabase
      .from('pildoras_sueltas')
      .upsert(
        {
          user_id: userId,
          pill_id: pillId,
          self_assesment_score: score,
          updated_at: new Date().toISOString(),
        },
        { onConflict: 'user_id,pill_id' }
      );
    if (error) throw error;

    console.log(`💊 Autopercepción suelta guardada - User: ${userId}, Píldora: ${pillId}, Score: ${score}`);
    res.json({ success: true });
  } catch (error) {
    console.error('❌ Error en PUT /api/pildoras-sueltas/autopercepcion:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

// POST: Terminar una píldora suelta (con estrellas y mensaje opcional)
app.post('/api/pildoras-sueltas/:pillId/completar', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;
    const { pillId } = req.params;
     // La calificación es opcional: null = no calificó
    const ratingRaw = req.body.pill_rating;
    const rating = ratingRaw == null ? null : parseInt(ratingRaw, 10);
    const mensaje = req.body.pill_feedback_message || null;

    if (rating !== null && (isNaN(rating) || rating < 1 || rating > 5)) {
      return res.status(400).json({ success: false, error: 'La calificación debe ser de 1 a 5 estrellas' });
    }

    const fila = await _filaSuelta(userId, pillId);
    if (fila && fila.is_completed) {
      return res.status(400).json({ success: false, error: 'Ya hiciste esta píldora' });
    }
    if (await _completadaEnReto(userId, pillId)) {
      return res.status(400).json({ success: false, error: 'Ya hiciste esta píldora en tu reto' });
    }

    const ahora = new Date().toISOString();
    const { error } = await supabase
      .from('pildoras_sueltas')
      .upsert(
        {
          user_id: userId,
          pill_id: pillId,
          pill_rating: rating,
          pill_feedback_message: mensaje,
          is_completed: true,
          completed_at: ahora,
          updated_at: ahora,
        },
        { onConflict: 'user_id,pill_id' }
      );
    if (error) throw error;

    console.log(`💊 Píldora suelta completada - User: ${userId}, Píldora: ${pillId}, ⭐ ${rating}`);
    res.json({ success: true });
  } catch (error) {
    console.error('❌ Error en POST /api/pildoras-sueltas/completar:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});
// ═══════════════ FAVORITOS ═══════════════

// GET: Obtener favoritos de un usuario
app.get('/api/favoritos', authenticateToken, async (req, res) => {
  try {
    const { user_id } = req.query;
    if (!user_id) {
      return res.status(400).json({ success: false, error: 'user_id es requerido' });
    }
    const { data, error } = await supabase
      .from('favoritos')
      .select('*')
      .eq('user_id', user_id);
    if (error) throw error;
    res.json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// POST: Agregar favorito
app.post('/api/favoritos', authenticateToken, async (req, res) => {
  try {
    const { user_id, pill_id } = req.body;
    const { data, error } = await supabase
      .from('favoritos')
      .insert([{ user_id, pill_id }])
      .select();
    if (error) throw error;
    res.json({ success: true, data: data[0] });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// DELETE: Quitar favorito
app.delete('/api/favoritos', authenticateToken, async (req, res) => {
  try {
    const { user_id, pill_id } = req.query;
    const { error } = await supabase
      .from('favoritos')
      .delete()
      .eq('user_id', user_id)
      .eq('pill_id', pill_id);
    if (error) throw error;
    res.json({ success: true, message: 'Favorito eliminado' });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});
// ===== ENDPOINTS DE SOCIAL =====

// OBTENER TODOS LOS POSTS (ACTUALIZADO con vistas, comentarios y pins)
app.get('/api/social/posts', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;

    // Obtener los posts que el usuario tiene anclados
    const { data: userPins } = await supabase
      .from('social_pins')
      .select('post_id')
      .eq('user_id', userId);

    const pinnedPostIds = (userPins || []).map(p => p.post_id);

    const { data: posts, error } = await supabase
      .from('social_posts')
      .select('*')
      .order('created_at', { ascending: false });

    if (error) throw error;

    const enrichedPosts = await Promise.all(posts.map(async (post) => {
      // Info del usuario
      const { data: userData } = await supabase
        .from('users')
        .select('id, first_name, last_name_1, last_name_2, full_name, email')
        .eq('id', post.user_id)
        .single();

      // Contar likes
      const { count: likesCount } = await supabase
        .from('social_likes')
        .select('*', { count: 'exact', head: true })
        .eq('post_id', post.id);

      // Verificar si el usuario actual dio like
      const { data: userLike } = await supabase
        .from('social_likes')
        .select('id')
        .eq('post_id', post.id)
        .eq('user_id', userId)
        .single();

      // Contar comentarios
      const { count: commentsCount } = await supabase
        .from('social_comments')
        .select('*', { count: 'exact', head: true })
        .eq('post_id', post.id);

      // Contar vistas
      const { count: viewsCount } = await supabase
        .from('social_views')
        .select('*', { count: 'exact', head: true })
        .eq('post_id', post.id);

      let pollOptions = null;
      let userVote = null;

            if (post.content_type === 'poll') {
        // 1) PRIMERO: ¿qué opción votó el usuario actual? (null si no votó)
        const { data: voteData } = await supabase
          .from('social_poll_votes')
          .select('poll_option_id')
          .eq('post_id', post.id)
          .eq('user_id', userId)
          .maybeSingle();

        if (voteData) userVote = voteData.poll_option_id;

        // 2) DESPUÉS: opciones con su conteo y si el usuario la votó
        const { data: options } = await supabase
          .from('social_poll_options')
          .select('*')
          .eq('post_id', post.id);

        if (options) {
          pollOptions = await Promise.all(options.map(async (opt) => {
            const { count } = await supabase
              .from('social_poll_votes')
              .select('*', { count: 'exact', head: true })
              .eq('poll_option_id', opt.id);
            return {
              ...opt,
              votes: count || 0,               // nombre antiguo (se mantiene)
              vote_count: count || 0,          // ← el que lee Flutter
              voted_by_me: opt.id === userVote // ← el que lee Flutter
            };
          }));
        }
      }

      const userName = userData
  ? (`${userData.first_name || ''} ${userData.last_name_1 || ''}`.trim() || userData.full_name || userData.email?.split('@')[0] || 'Usuario')
  : 'Usuario';

      return {
        ...post,
        user_name: userName,
        likes_count: likesCount || 0,
        liked_by_user: !!userLike,
        comments_count: commentsCount || 0,
        views_count: viewsCount || 0,
        is_pinned: pinnedPostIds.includes(post.id),
        is_own_post: post.user_id === userId,
        poll_options: pollOptions,
        user_vote: userVote,
      };
    }));

    // Ordenar: posts anclados del usuario primero, luego el resto por fecha
    enrichedPosts.sort((a, b) => {
      if (a.is_pinned && !b.is_pinned) return -1;
      if (!a.is_pinned && b.is_pinned) return 1;
      return new Date(b.created_at) - new Date(a.created_at);
    });

    res.json({ success: true, data: enrichedPosts });
  } catch (error) {
    console.error('Error obteniendo posts:', error);
    res.status(500).json({ success: false, message: error.message });
  }
});

// Crear un post
app.post('/api/social/posts', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;
    const { content_type, text_content, media_url, poll_options } = req.body;

    // Obtener company_id del usuario
    const { data: userData } = await supabase
      .from('users')
      .select('company_id')
      .eq('id', userId)
      .single();

    // Insertar el post
    const { data: post, error } = await supabase
      .from('social_posts')
      .insert([{
        user_id: userId,
        company_id: userData?.company_id,
        content_type,
        text_content: text_content || null,
        media_url: media_url || null,
        is_system_post: false,
      }])
      .select()
      .single();

    if (error) throw error;

    // Si es encuesta, crear las opciones
    if (content_type === 'poll' && poll_options && poll_options.length > 0) {
      const optionsToInsert = poll_options.map(opt => ({
        post_id: post.id,
        option_text: opt,
      }));

      const { error: optError } = await supabase
        .from('social_poll_options')
        .insert(optionsToInsert);

      if (optError) throw optError;
    }

    console.log('✅ Post creado:', post.id);
    res.status(201).json({ success: true, post });
  } catch (error) {
    console.error('❌ Error creando post:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

// Votar en encuesta
app.post('/api/social/polls/vote', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;
    const { post_id, poll_option_id } = req.body;

    // Verificar si ya votó en este post
    const { data: existingVote } = await supabase
      .from('social_poll_votes')
      .select('id')
      .eq('post_id', post_id)
      .eq('user_id', userId)
      .maybeSingle();

    if (existingVote) {
      return res.status(400).json({ success: false, error: 'Ya has votado en esta encuesta' });
    }

    const { error } = await supabase
      .from('social_poll_votes')
      .insert([{
        post_id,
        poll_option_id,
        user_id: userId,
      }]);

    if (error) throw error;

    res.json({ success: true, message: 'Voto registrado' });
  } catch (error) {
    console.error('❌ Error votando:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

// Like / Unlike toggle
app.post('/api/social/posts/:postId/like', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;
    const { postId } = req.params;

    // Verificar si ya tiene like
    const { data: existingLike } = await supabase
      .from('social_likes')
      .select('id')
      .eq('post_id', postId)
      .eq('user_id', userId)
      .maybeSingle();

    if (existingLike) {
      // Quitar like
      await supabase
        .from('social_likes')
        .delete()
        .eq('id', existingLike.id);

      res.json({ success: true, liked: false });
    } else {
      // Dar like
      await supabase
        .from('social_likes')
        .insert([{ post_id: postId, user_id: userId }]);

      res.json({ success: true, liked: true });
    }
  } catch (error) {
    console.error('❌ Error en like:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});


// =============================================
// ENDPOINTS DE SOCIAL
// =============================================



// CREAR UN POST
app.post('/api/social/posts', authenticateToken, async (req, res) => {
  try {
    const { content_type, text_content, media_url, poll_options } = req.body;
    const userId = req.user.id;

    // Obtener company_id del usuario
    const { data: userData } = await supabase
      .from('users')
      .select('company_id')
      .eq('id', userId)
      .single();

    const { data: post, error } = await supabase
      .from('social_posts')
      .insert({
        user_id: userId,
        company_id: userData?.company_id || null,
        content_type,
        text_content: text_content || null,
        media_url: media_url || null,
        is_system_post: false,
      })
      .select()
      .single();

    if (error) throw error;

    // Si es encuesta, crear las opciones
    if (content_type === 'poll' && poll_options && poll_options.length > 0) {
      const optionsToInsert = poll_options.map(opt => ({
        post_id: post.id,
        option_text: opt,
      }));

      const { error: optError } = await supabase
        .from('social_poll_options')
        .insert(optionsToInsert);

      if (optError) throw optError;
    }

    res.json({ success: true, data: post });
  } catch (error) {
    console.error('Error creando post:', error);
    res.status(500).json({ success: false, message: error.message });
  }
});

// VOTAR EN UNA ENCUESTA
app.post('/api/social/polls/vote', authenticateToken, async (req, res) => {
  try {
    const { post_id, poll_option_id } = req.body;
    const userId = req.user.id;

    const { data, error } = await supabase
      .from('social_poll_votes')
      .insert({
        post_id,
        poll_option_id,
        user_id: userId,
      })
      .select()
      .single();

    if (error) {
      if (error.code === '23505') {
        return res.status(400).json({ success: false, message: 'Ya votaste en esta encuesta' });
      }
      throw error;
    }

    res.json({ success: true, data });
  } catch (error) {
    console.error('Error votando:', error);
    res.status(500).json({ success: false, message: error.message });
  }
});

// TOGGLE LIKE
app.post('/api/social/posts/:postId/like', authenticateToken, async (req, res) => {
  try {
    const { postId } = req.params;
    const userId = req.user.id;

    // Verificar si ya existe el like
    const { data: existingLike } = await supabase
      .from('social_likes')
      .select('id')
      .eq('post_id', postId)
      .eq('user_id', userId)
      .single();

    if (existingLike) {
      // Quitar like
      await supabase
        .from('social_likes')
        .delete()
        .eq('id', existingLike.id);
      res.json({ success: true, liked: false });
    } else {
      // Dar like
      await supabase
        .from('social_likes')
        .insert({ post_id: postId, user_id: userId });
      res.json({ success: true, liked: true });
    }
  } catch (error) {
    console.error('Error en like:', error);
    res.status(500).json({ success: false, message: error.message });
  }
});
// =============================================
// GANADOR DE RACHAS DEL MES → post automático en Social
// =============================================
// Mismo criterio que el ranking unificado de Rachas:
// 1º mayor racha máxima del mes; si hay empate, más píldoras cumplidas en el mes.
async function _publicarGanadorRachas(anio, mes) {
  const nombreMes = MESES_ES[mes - 1];
  const etiqueta = `${nombreMes} ${anio}`;

  // 1) ¿Ya se publicó? (evita duplicados si el servidor se reinicia)
  const { data: yaPublicado, error: errPub } = await supabase
    .from('social_posts')
    .select('id')
    .eq('content_type', 'streak_winner')
    .ilike('text_content', `%${etiqueta}%`)
    .limit(1);
  if (errPub) throw errPub;
  if (yaPublicado && yaPublicado.length > 0) {
    console.log(`ℹ️ El ganador de rachas de ${etiqueta} ya estaba publicado`);
    return;
  }

  // 2) Mejor racha de cada usuario en ese mes (mes y año son números)
  const { data: stats, error: errStats } = await supabase
    .from('user_racha_stats')
    .select('user_id, racha_maxima')
    .eq('mes', mes)
    .eq('año', anio);
  if (errStats) throw errStats;

  const mejorRacha = {};
  (stats || []).forEach(s => {
    const r = Number(s.racha_maxima) || 0;
    if (!mejorRacha[s.user_id] || r > mejorRacha[s.user_id]) {
      mejorRacha[s.user_id] = r;
    }
  });

  const maxRacha = Math.max(0, ...Object.values(mejorRacha));
  if (maxRacha <= 0) {
    console.log(`⚠️ No hubo rachas en ${etiqueta}, no se publica ganador`);
    return;
  }

  const candidatos = Object.keys(mejorRacha).filter(id => mejorRacha[id] === maxRacha);

  // 3) Desempate: píldoras cumplidas en el mes (igual que el ranking de Rachas)
  const ultimoDia = new Date(anio, mes, 0).getDate();
  const desde = `${anio}-${_pad2(mes)}-01`;
  const hasta = `${anio}-${_pad2(mes)}-${_pad2(ultimoDia)}T23:59:59`;

  const { data: completadas, error: errComp } = await supabase
    .from('user_pill_progress')
    .select('user_id')
    .in('user_id', candidatos)
    .eq('is_completed', true)
    .gte('completed_at', desde)
    .lte('completed_at', hasta);
  if (errComp) throw errComp;

  const pildoras = {};
  candidatos.forEach(id => { pildoras[id] = 0; });
  (completadas || []).forEach(c => { pildoras[c.user_id]++; });

  const maxPildoras = Math.max(...candidatos.map(id => pildoras[id]));
  const ganadores = candidatos.filter(id => pildoras[id] === maxPildoras);

  // 4) Nombres de los ganadores
  const { data: usuarios, error: errUsers } = await supabase
    .from('users')
    .select('id, full_name, first_name, last_name_1, email, company_id')
    .in('id', ganadores);
  if (errUsers) throw errUsers;
  if (!usuarios || usuarios.length === 0) return;

  const nombreDe = u =>
    `${u.first_name || ''} ${u.last_name_1 || ''}`.trim() ||
    u.full_name ||
    (u.email || '').split('@')[0] ||
    'Usuario';

  const nombres = usuarios.map(nombreDe);
  const listaNombres = nombres.length === 1
    ? nombres[0]
    : `${nombres.slice(0, -1).join(', ')} y ${nombres[nombres.length - 1]}`;

  const texto = nombres.length === 1
    ? `🏆🔥 ¡Ganador de rachas de ${etiqueta}! 🔥🏆\n\n¡Felicidades a ${listaNombres}! Logró la racha más alta del mes con ${maxRacha} días consecutivos y ${maxPildoras} píldoras cumplidas.\n\n¡Sigue así, eres una inspiración para todos! 💪`
    : `🏆🔥 ¡Ganadores de rachas de ${etiqueta}! 🔥🏆\n\n¡Felicidades a ${listaNombres}! Empataron con la racha más alta del mes: ${maxRacha} días consecutivos y ${maxPildoras} píldoras cumplidas.\n\n¡Sigan así, son una inspiración para todos! 💪`;

  // 5) Publicar el post del sistema
  const principal = usuarios[0];
  const { error: postError } = await supabase
    .from('social_posts')
    .insert({
      user_id: principal.id,
      company_id: principal.company_id || null,
      content_type: 'streak_winner',
      text_content: texto,
      is_system_post: true,
    });
  if (postError) throw postError;

  console.log(`✅ Post de ganador de rachas de ${etiqueta} publicado: ${listaNombres}`);
}

// Publica el ganador del MES ANTERIOR (según la fecha de Madrid)
async function _publicarGanadorMesAnterior() {
  try {
    const [anioHoy, mesHoy] = _hoyMadrid().split('-').map(Number);
    const mes = mesHoy === 1 ? 12 : mesHoy - 1;
    const anio = mesHoy === 1 ? anioHoy - 1 : anioHoy;
    console.log(`🏆 Revisando ganador de rachas de ${MESES_ES[mes - 1]} ${anio}...`);
    await _publicarGanadorRachas(anio, mes);
  } catch (error) {
    console.error('❌ Error publicando ganador de rachas:', error);
  }
}

// Día 1 de cada mes a las 00:05, hora de Madrid
cron.schedule('5 0 1 * *', _publicarGanadorMesAnterior, {
  timezone: 'Europe/Madrid',
});
// =============================================
// ENDPOINTS ADICIONALES DE SOCIAL
// =============================================

// EDITAR UN POST (solo el autor puede editar)
app.put('/api/social/posts/:postId', authenticateToken, async (req, res) => {
  try {
    const { postId } = req.params;
    const { text_content } = req.body;
    const userId = req.user.id;

    // Verificar que el post pertenece al usuario
    const { data: post } = await supabase
      .from('social_posts')
      .select('user_id')
      .eq('id', postId)
      .single();

    if (!post || post.user_id !== userId) {
      return res.status(403).json({ success: false, message: 'No puedes editar este post' });
    }

    const { data, error } = await supabase
      .from('social_posts')
      .update({ text_content, updated_at: new Date().toISOString() })
      .eq('id', postId)
      .select()
      .single();

    if (error) throw error;
    res.json({ success: true, data });
  } catch (error) {
    console.error('Error editando post:', error);
    res.status(500).json({ success: false, message: error.message });
  }
});

// BORRAR UN POST (solo el autor puede borrar)
app.delete('/api/social/posts/:postId', authenticateToken, async (req, res) => {
  try {
    const { postId } = req.params;
    const userId = req.user.id;

    const { data: post } = await supabase
      .from('social_posts')
      .select('user_id')
      .eq('id', postId)
      .single();

    if (!post || post.user_id !== userId) {
      return res.status(403).json({ success: false, message: 'No puedes borrar este post' });
    }

    const { error } = await supabase
      .from('social_posts')
      .delete()
      .eq('id', postId);

    if (error) throw error;
    res.json({ success: true, message: 'Post eliminado' });
  } catch (error) {
    console.error('Error borrando post:', error);
    res.status(500).json({ success: false, message: error.message });
  }
});

// OBTENER COMENTARIOS DE UN POST
app.get('/api/social/posts/:postId/comments', authenticateToken, async (req, res) => {
  try {
    const { postId } = req.params;

    const { data: comments, error } = await supabase
      .from('social_comments')
      .select('*')
      .eq('post_id', postId)
      .order('created_at', { ascending: true });

    if (error) throw error;

    // Enriquecer con nombre del usuario
    const enriched = await Promise.all(comments.map(async (c) => {
      const { data: userData } = await supabase
        .from('users')
               .select('first_name, last_name_1, full_name, email')
        .eq('id', c.user_id)
        .single();

      return {
        ...c,
        user_name: userData
          ? (`${userData.first_name || ''} ${userData.last_name_1 || ''}`.trim() ||
             userData.full_name ||
             userData.email?.split('@')[0] ||
             'Usuario')
          : 'Usuario',
      };
    }));

    res.json({ success: true, data: enriched });
  } catch (error) {
    console.error('Error obteniendo comentarios:', error);
    res.status(500).json({ success: false, message: error.message });
  }
});

// CREAR COMENTARIO
app.post('/api/social/posts/:postId/comments', authenticateToken, async (req, res) => {
  try {
    const { postId } = req.params;
    const { comment_text } = req.body;
    const userId = req.user.id;

    const { data, error } = await supabase
      .from('social_comments')
      .insert({ post_id: postId, user_id: userId, comment_text })
      .select()
      .single();

    if (error) throw error;

    // Devolver con nombre del usuario
    const { data: userData } = await supabase
      .from('users')
           .select('first_name, last_name_1, full_name, email')
      .eq('id', userId)
      .single();

    res.json({
      success: true,
      data: {
        ...data,
        user_name: userData
          ? (`${userData.first_name || ''} ${userData.last_name_1 || ''}`.trim() ||
             userData.full_name ||
             userData.email?.split('@')[0] ||
             'Usuario')
          : 'Usuario',
      },
    });
  } catch (error) {
    console.error('Error creando comentario:', error);
    res.status(500).json({ success: false, message: error.message });
  }
});

// REGISTRAR VISTA DE UN POST
app.post('/api/social/posts/:postId/view', authenticateToken, async (req, res) => {
  try {
    const { postId } = req.params;
    const userId = req.user.id;

    // Insertar vista (ignora si ya existe por el UNIQUE)
    await supabase
      .from('social_views')
      .upsert(
        { post_id: postId, user_id: userId },
        { onConflict: 'post_id,user_id', ignoreDuplicates: true }
      );

    // Contar total de vistas
    const { count } = await supabase
      .from('social_views')
      .select('*', { count: 'exact', head: true })
      .eq('post_id', postId);

    res.json({ success: true, views_count: count || 0 });
  } catch (error) {
    console.error('Error registrando vista:', error);
    res.status(500).json({ success: false, message: error.message });
  }
});

// TOGGLE PIN (anclar/desanclar post para el usuario)
app.post('/api/social/posts/:postId/pin', authenticateToken, async (req, res) => {
  try {
    const { postId } = req.params;
    const userId = req.user.id;

    const { data: existingPin } = await supabase
      .from('social_pins')
      .select('id')
      .eq('post_id', postId)
      .eq('user_id', userId)
      .single();

    if (existingPin) {
      await supabase
        .from('social_pins')
        .delete()
        .eq('id', existingPin.id);
      res.json({ success: true, pinned: false });
    } else {
      await supabase
        .from('social_pins')
        .insert({ post_id: postId, user_id: userId });
      res.json({ success: true, pinned: true });
    }
  } catch (error) {
    console.error('Error en pin:', error);
    res.status(500).json({ success: false, message: error.message });
  }
});
// Iniciar servidor
app.listen(PORT, () => {
  console.log(`🚀 Servidor corriendo en puerto ${PORT}`);
  // Si el servidor estaba dormido el día 1, publica ahora el ganador pendiente
  _publicarGanadorMesAnterior();
});
// ========== INICIALIZAR CRON JOB ==========
// Ejecutar cada día a las 00:00 (UTC)
cron.schedule('0 0 * * *', () => {
  console.log(`⏰ [CRON] Ejecutando verificación de rachas rotas`);
  _verificarYResetearRachas();
});

console.log(`⏰ Cron Job registrado: Verificación de rachas rotas diariamente a las 00:00 UTC`);