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
      console.error('❌ Error en insert:', error);
      throw error;
    }

    console.log('✅ Voto registrado exitosamente');
    res.status(201).json({ success: true, data: data[0] });
  } catch (error) {
    console.error('❌ Error en POST /nominations:', error.message);
    res.status(400).json({ success: false, error: error.message });
  }
});

app.get('/api/nominations/:userId/feedback-score', authenticateToken, async (req, res) => {
  try {
    console.log('📊 GET /api/nominations/:userId/feedback-score');
    console.log('   userId:', req.params.userId);

    const userId = req.params.userId;
    const { data: votes, error: votesError } = await supabase
      .from('anonymous_nominations')
      .select('*')
      .eq('nominated_user_id', userId);

    if (votesError) throw votesError;

    if (votes.length === 0) {
      return res.json({ 
        success: true, 
        feedbackScore: 0, 
        totalVoters: 0, 
        positiveVoters: 0,
        totalVotes: 0
      });
    }

    const votersMap = {};
    votes.forEach(vote => {
      const key = `${vote.respondent_user_id}-${vote.reto_id}`;
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

    res.json({
      success: true,
      feedbackScore: Math.round(feedbackScore * 100) / 100,
      totalVoters: totalValidVoters,
      positiveVoters: positiveVoters,
      totalVotes: votes.length
    });

  } catch (error) {
    console.error('❌ Error en feedback-score:', error.message);
    res.status(400).json({ success: false, error: error.message });
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
              console.log(`🔴 Hueco detectado entre ${registro.fecha} y ${diasLaborales[i + 1].fecha}`);
              break;
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

    // ========== PASO 6: NUEVO - Buscar MÁXIMA secuencia consecutiva verificando huecos ==========
    let racha_maxima_mes = 0;
    let racha_temporal = 0;

    for (let i = 0; i < diasLaborales.length; i++) {
      const registro = diasLaborales[i];
      
      // Verificar si hay un hueco con el registro anterior
      if (i > 0) {
        const diaActual = new Date(registro.fecha);
        const diaPrevio = new Date(diasLaborales[i - 1].fecha);
        const diffDias = (diaActual - diaPrevio) / (1000 * 60 * 60 * 24);
        
        // Si hay más de 1 día de diferencia, se rompe la secuencia
        if (diffDias > 1) {
          console.log(`🔴 Hueco detectado entre ${diasLaborales[i - 1].fecha} y ${registro.fecha}`);
          if (racha_temporal > racha_maxima_mes) {
            racha_maxima_mes = racha_temporal;
            console.log(`🏆 Nueva máxima encontrada: ${racha_maxima_mes}`);
          }
          racha_temporal = 0;
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
      const { data: stats, error: errorStats } = await supabase
        .from('user_racha_stats')
        .select('*')
        .eq('user_id', user_id)
        .eq('reto_id', retoId)
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
          .eq('reto_id', retoId);
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
    leaderboardRacha.sort((a, b) => b.mejor_racha - a.mejor_racha);

    leaderboardRacha = await Promise.all(leaderboardRacha.map(async (item, index) => {
      const { data: usuario } = await supabase
        .from('users')
        .select('full_name, email')
        .eq('id', item.user_id)
        .single();

      return {
        position: index + 1,
        full_name: usuario?.full_name || usuario?.email || 'Usuario',
        user_id: item.user_id,
        mejor_racha: item.mejor_racha,
        retos_participados: item.retos_participados
      };
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

       console.log(`🏆 Leaderboard Racha: ${leaderboardRacha.length} usuarios`);
    console.log(`🏆 Leaderboard Días Cumplidos: ${leaderboardDiasCumplidos.length} usuarios`);

    res.json({
      success: true,
      data: {
        leaderboard_racha: leaderboardRacha,
        leaderboard_dias_cumplidos: leaderboardDiasCumplidos,
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
// Iniciar servidor
app.listen(PORT, () => {
  console.log(`🚀 Servidor corriendo en puerto ${PORT}`);
});
// ========== INICIALIZAR CRON JOB ==========
// Ejecutar cada día a las 00:00 (UTC)
cron.schedule('0 0 * * *', () => {
  console.log(`⏰ [CRON] Ejecutando verificación de rachas rotas`);
  _verificarYResetearRachas();
});

console.log(`⏰ Cron Job registrado: Verificación de rachas rotas diariamente a las 00:00 UTC`);