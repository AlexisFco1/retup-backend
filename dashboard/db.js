// =====================================================================
// CLIENTES DE SUPABASE EXCLUSIVOS DEL DASHBOARD
// ---------------------------------------------------------------------
// Por qué no usamos el cliente de ../supabase.js:
// si un cliente de Supabase inicia sesión (signInWithPassword), guarda
// esa sesión y sus consultas siguientes se hacen COMO ESE USUARIO en vez
// de con la clave secreta. Las tablas del dashboard tienen RLS activado,
// así que eso haría que devolvieran vacío.
// =====================================================================
const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SECRET_KEY = process.env.SUPABASE_SECRET_KEY;

const opciones = {
  auth: {
    autoRefreshToken: false,
    persistSession: false,
    detectSessionInUrl: false,
  },
};

// Cliente de DATOS: nunca inicia sesión, siempre usa la clave secreta
const db = createClient(SUPABASE_URL, SUPABASE_SECRET_KEY, opciones);

// Cliente de LOGIN: se crea uno nuevo y desechable en cada inicio de sesión
function crearClienteAuth() {
  return createClient(SUPABASE_URL, SUPABASE_SECRET_KEY, opciones);
}

module.exports = { db, crearClienteAuth };