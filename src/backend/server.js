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

    console.log('💊 Pildoras encontradas:', data.length);
    res.json(data);
  } catch (error) {
    console.error('❌ Error en GET /pills:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

// ===== ENDPOINTS DE PILDORAS (PROTEGIDOS) =====
app.get('/api/pildoras/:pildoraId/secciones', authenticateToken, async (req, res) => {
  try {
    console.log('📺 GET /api/pildoras/:pildoraId/secciones - Pildora ID:', req.params.pildoraId);

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
    res.json({ success: true, message: 'Pildora eliminada' });
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
    console.log('📝 POST /api/user-progress');
    console.log('   Body:', req.body);

    const { user_id, pill_id, current_screen, self_assessment_score } = req.body;

    if (!user_id || !pill_id) {
      return res.status(400).json({ 
        success: false, 
        error: 'user_id y pill_id son requeridos' 
      });
    }

    const { data, error } = await supabase
      .from('user_pill_progress')
      .insert([{
        user_id,
        pill_id,
        current_screen: current_screen || 1,
        self_assessment_score: self_assessment_score || null,
        is_completed: false,
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      }])
      .select();

    if (error) {
      console.error('❌ Error en insert:', error.message);
      throw error;
    }

    if (!data || data.length === 0) {
      return res.status(500).json({ 
        success: false, 
        error: 'No se pudo crear el progreso' 
      });
    }

    console.log('✅ Progreso creado');
    res.status(201).json({ success: true, data: data[0] });
  } catch (error) {
    console.error('❌ Error en POST /api/user-progress:', error.message);
    res.status(500).json({ success: false, error: error.message });
  }
});

app.put('/api/user-progress/:id', authenticateToken, async (req, res) => {
  try {
    console.log(`📝 PUT /api/user-progress/:id - ID: ${req.params.id}`);
    console.log('   Body:', req.body);

    const { current_screen, self_assessment_score, is_completed } = req.body;
    
    // Construir el objeto update de forma defensiva (solo campos definidos)
    const update = { updated_at: new Date().toISOString() };
    
    if (current_screen !== undefined) {
      update.current_screen = current_screen;
    }
    if (self_assessment_score !== undefined) {
      update.self_assessment_score = self_assessment_score;
    }
    if (is_completed !== undefined) {
      update.is_completed = is_completed;
      if (is_completed) {
        update.completed_at = new Date().toISOString();
      }
    }

    console.log('   Update object:', update);

    const { data, error } = await supabase
      .from('user_pill_progress')
      .update(update)
      .eq('id', req.params.id)
      .select();

    if (error) {
      console.error('❌ Error en update:', error.message);
      throw error;
    }

    if (!data || data.length === 0) {
      console.warn('⚠️ No se encontró el registro con ID:', req.params.id);
      return res.status(404).json({ success: false, error: 'Progreso no encontrado' });
    }

    console.log('✅ Progreso actualizado');
    res.json({ success: true, data: data[0] });
  } catch (error) {
    console.error('❌ Error en PUT /api/user-progress/:id:', error.message);
    res.status(500).json({ success: false, error: error.message });
  }
});

app.post('/api/user-progress/complete-pill/:pillId', authenticateToken, async (req, res) => {
  try {
    console.log(`📝 POST /api/user-progress/complete-pill/:pillId - pillId: ${req.params.pillId}`);
    console.log('   Body:', req.body);

    const { user_id } = req.body;

    if (!user_id) {
      return res.status(400).json({ success: false, error: 'user_id es requerido' });
    }

    const { data, error } = await supabase
      .from('user_pill_progress')
      .update({ 
        is_completed: true, 
        completed_at: new Date().toISOString() 
      })
      .eq('pill_id', req.params.pillId)
      .eq('user_id', user_id)
      .select();

    if (error) {
      console.error('❌ Error en update:', error.message);
      throw error;
    }

    if (!data || data.length === 0) {
      return res.status(404).json({ success: false, error: 'Progreso no encontrado' });
    }

    console.log('✅ Pildora completada');
    res.json({ success: true, data: data[0] });
  } catch (error) {
    console.error('❌ Error en complete-pill:', error.message);
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

// ===== ENDPOINTS DE ANONYMOUS_NOMINATIONS (PROTEGIDOS) =====
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

    console.log('✅ Parametros recibidos:');
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

app.get('/api/nominations/:userId/feedback-score', authenticateToken, async (req, res) => {
  try {
    console.log('📊 GET /api/nominations/:userId/feedback-score');
    console.log('   userId:', req.params.userId);

    const userId = req.params.userId;

    const { data: votes, error: votesError } = await supabase
      .from('anonymous_nominations')
      .select('*')
      .eq('nominated_user_id', userId);

    if (votesError) {
      console.error('❌ Error obteniendo votos:', votesError);
      throw votesError;
    }

    console.log(`✅ Votos encontrados: ${votes.length}`);

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

    console.log(`📊 Votantes unicos (por reto): ${Object.keys(votersMap).length}`);

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
      }
    });

    console.log(`\n📈 Resumen:`);
    console.log(`   Votantes validos: ${totalValidVoters}`);
    console.log(`   Votantes positivos: ${positiveVoters}`);

    let feedbackScore = 0;
    if (totalValidVoters > 0) {
      feedbackScore = (100 / totalValidVoters) * positiveVoters;
    }

    console.log(`   Calificacion: ${feedbackScore.toFixed(2)}%`);

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

app.delete('/api/nominations/:id', authenticateToken, authorizeRole(['super_admin']), async (req, res) => {
  try {
    const { error } = await supabase
      .from('anonymous_nominations')
      .delete()
      .eq('id', req.params.id);
    if (error) throw error;
    res.json({ success: true, message: 'Nominacion eliminada' });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// ===== ENDPOINT PARA INSERTAR TODAS LAS SECCIONES (SOLO EJECUTAR UNA VEZ) =====
app.post('/api/seed/secciones', authenticateToken, authorizeRole(['super_admin']), async (req, res) => {
  try {
    console.log('🌱 Iniciando insercion de secciones...');

    const { data: pildoras, error: errorPildoras } = await supabase
      .from('pildoras')
      .select('id, title')
      .order('created_at', { ascending: true });

    if (errorPildoras) throw errorPildoras;

    if (pildoras.length === 0) {
      return res.status(400).json({ error: 'No hay pildoras en la BD' });
    }

    console.log(`📚 Encontradas ${pildoras.length} pildoras`);

    const estructuraBase = [
      { screen_number: 1, screen_name: 'Bienvenida + frase motivante', screen_type: 'welcome' },
      { screen_number: 2, screen_name: 'Dato/evento historico (gancho)', screen_type: 'fact' },
      { screen_number: 3, screen_name: 'Pregunta anonima: quien lo hace mejor?', screen_type: 'anonymous_question' },
      { screen_number: 4, screen_name: 'Por que importa (dato estadistico)', screen_type: 'statistic' },
      { screen_number: 5, screen_name: 'Autopercepcion (escala 1-5)', screen_type: 'self_assessment' },
      { screen_number: 6, screen_name: 'Que aprendiste + beneficio', screen_type: 'learning' },
      { screen_number: 7, screen_name: 'Pregunta anonima: quien podria mejorar?', screen_type: 'anonymous_question' },
      { screen_number: 8, screen_name: 'Practica social con un companero', screen_type: 'social_practice' },
      { screen_number: 9, screen_name: 'Mensaje de cierre gratificante', screen_type: 'closing' },
    ];

    let totalInserted = 0;
    let seccionesParaInsertar = [];

    for (let i = 0; i < pildoras.length; i++) {
      const pildora = pildoras[i];
      console.log(`📝 Procesando pildora ${i + 1}/${pildoras.length}: "${pildora.title}"`);

      estructuraBase.forEach((seccion) => {
        seccionesParaInsertar.push({
          pildora_id: pildora.id,
          screen_number: seccion.screen_number,
          screen_name: seccion.screen_name,
          screen_type: seccion.screen_type,
          screen_content: `[Contenido para completar]\n\nPildora: "${pildora.title}"\nSeccion: ${seccion.screen_number}/9 - ${seccion.screen_name}`,
          source_note: `RetUp - ${pildora.title}`,
        });
      });

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
        seccionesParaInsertar = [];
      }
    }

    console.log(`✅ Insercion completada: ${totalInserted} secciones en total`);
    res.json({
      success: true,
      message: `✅ ${totalInserted} secciones insertadas exitosamente`,
      totalInserted,
      pildorasProcessadas: pildoras.length,
    });
  } catch (error) {
    console.error('❌ Error en seed:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

// ===== ENDPOINTS DE RACHA (PROTEGIDOS) ✅ CORREGIDOS =====

function _esDialaboral(fecha) {
  const dia = fecha.getDay();
  return dia >= 1 && dia <= 5;
}

app.post('/api/racha/registrar-login', authenticateToken, async (req, res) => {
  try {
    const { user_id } = req.body;

    if (!user_id) {
      return res.status(400).json({ success: false, error: 'user_id es requerido' });
    }

    const hoy = new Date();
    const fechaHoy = hoy.toISOString().split('T')[0];
    const esLaboral = _esDialaboral(hoy);

    console.log(`📝 POST /api/racha/registrar-login - User: ${user_id}, Fecha: ${fechaHoy}, Laboral: ${esLaboral}`);

    if (!esLaboral) {
      return res.json({ success: true, message: 'No es un dia laboral', data: null });
    }

    const { data: existingRecord, error: checkError } = await supabase
      .from('racha_daily_progress')
      .select('*')
      .eq('user_id', user_id)
      .eq('fecha', fechaHoy);

    if (checkError) throw checkError;

    let result;
    if (existingRecord && existingRecord.length > 0) {
      const { data, error } = await supabase
        .from('racha_daily_progress')
        .update({ login_hecho: true, updated_at: new Date().toISOString() })
        .eq('id', existingRecord[0].id)
        .select();
      if (error) throw error;
      result = data[0];
    } else {
      const { data, error } = await supabase
        .from('racha_daily_progress')
        .insert([{
          user_id,
          fecha: fechaHoy,
          login_hecho: true,
          pildora_completada: false,
          es_dia_laboral: esLaboral,
        }])
        .select();
      if (error) throw error;
      result = data[0];
    }

    console.log('✅ Login registrado');
    res.status(201).json({ success: true, message: 'Login registrado', data: result });
  } catch (error) {
    console.error('❌ Error en registrar-login:', error.message);
    res.status(400).json({ success: false, error: error.message });
  }
});

app.post('/api/racha/registrar-pildora', authenticateToken, async (req, res) => {
  try {
    const { user_id } = req.body;

    if (!user_id) {
      return res.status(400).json({ success: false, error: 'user_id es requerido' });
    }

    const hoy = new Date();
    const fechaHoy = hoy.toISOString().split('T')[0];
    const esLaboral = _esDialaboral(hoy);

    console.log(`📝 POST /api/racha/registrar-pildora - User: ${user_id}, Fecha: ${fechaHoy}, Laboral: ${esLaboral}`);

    if (!esLaboral) {
      return res.json({ success: true, message: 'No es un dia laboral', data: null });
    }

    const { data: existingRecord, error: checkError } = await supabase
      .from('racha_daily_progress')
      .select('*')
      .eq('user_id', user_id)
      .eq('fecha', fechaHoy);

    if (checkError) throw checkError;

    let result;
    if (existingRecord && existingRecord.length > 0) {
      const { data, error } = await supabase
        .from('racha_daily_progress')
        .update({ pildora_completada: true, updated_at: new Date().toISOString() })
        .eq('id', existingRecord[0].id)
        .select();
      if (error) throw error;
      result = data[0];
    } else {
      const { data, error } = await supabase
        .from('racha_daily_progress')
        .insert([{
          user_id,
          fecha: fechaHoy,
          login_hecho: false,
          pildora_completada: true,
          es_dia_laboral: esLaboral,
        }])
        .select();
      if (error) throw error;
      result = data[0];
    }

    console.log('✅ Pildora registrada');
    res.status(201).json({ success: true, message: 'Pildora registrada', data: result });
  } catch (error) {
    console.error('❌ Error en registrar-pildora:', error.message);
    res.status(400).json({ success: false, error: error.message });
  }
});

app.get('/api/racha/estadisticas', authenticateToken, async (req, res) => {
  try {
    const { user_id, mes, ano } = req.query;

    if (!user_id || !mes || !ano) {
      return res.status(400).json({
        success: false,
        error: 'user_id, mes y ano son requeridos'
      });
    }

    console.log(`📊 GET /api/racha/estadisticas - User: ${user_id}, Mes: ${mes}/${ano}`);

    const { data, error } = await supabase
      .from('user_racha_stats')
      .select('*')
      .eq('user_id', user_id)
      .eq('mes', parseInt(mes))
      .eq('ano', parseInt(ano));

    if (error) throw error;

    res.json({ success: true, data: data && data.length > 0 ? data[0] : {} });
  } catch (error) {
    console.error('❌ Error en estadisticas:', error.message);
    res.status(400).json({ success: false, error: error.message });
  }
});

app.get('/api/racha/progreso', authenticateToken, async (req, res) => {
  try {
    const { user_id, mes, ano } = req.query;

    if (!user_id || !mes || !ano) {
      return res.status(400).json({
        success: false,
        error: 'user_id, mes y ano son requeridos'
      });
    }

    const primerDia = new Date(parseInt(ano), parseInt(mes) - 1, 1).toISOString().split('T')[0];
    const ultimoDia = new Date(parseInt(ano), parseInt(mes), 0).toISOString().split('T')[0];

    console.log(`📅 GET /api/racha/progreso - User: ${user_id}, Rango: ${primerDia} a ${ultimoDia}`);

    const { data, error } = await supabase
      .from('racha_daily_progress')
      .select('*')
      .eq('user_id', user_id)
      .gte('fecha', primerDia)
      .lte('fecha', ultimoDia)
      .order('fecha', { ascending: true });

    if (error) throw error;

    res.json({ success: true, data: data || [] });
  } catch (error) {
    console.error('❌ Error en progreso:', error.message);
    res.status(400).json({ success: false, error: error.message });
  }
});

app.listen(PORT, () => {
  console.log(`🚀 Servidor RetUp corriendo en puerto ${PORT}`);
});