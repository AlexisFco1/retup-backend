const { createClient } = require('@supabase/supabase-js');

// Cargar variables de entorno
const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SECRET_KEY = process.env.SUPABASE_SECRET_KEY;

// Crear cliente de Supabase (con rol de servidor - usa SECRET_KEY)
const supabase = createClient(SUPABASE_URL, SUPABASE_SECRET_KEY, {
  auth: {
    autoRefreshToken: false,
    persistSession: false,
  },
});

module.exports = supabase;