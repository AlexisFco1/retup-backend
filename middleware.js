const supabase = require('./supabase');

// Middleware para verificar token JWT
const authenticateToken = async (req, res, next) => {
  try {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1]; // Bearer TOKEN

    if (!token) {
      return res.status(401).json({ success: false, error: 'Token requerido' });
    }

    // Verificar el token con Supabase
    const { data, error } = await supabase.auth.getUser(token);

    if (error || !data.user) {
      return res.status(403).json({ success: false, error: 'Token inválido' });
    }

    req.user = data.user;
    next();
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
};

// Middleware para verificar rol
const authorizeRole = (allowedRoles) => {
  return async (req, res, next) => {
    try {
      const { data, error } = await supabase
        .from('users')
        .select('role')
        .eq('id', req.user.id)
        .single();

      if (error || !data || !allowedRoles.includes(data.role)) {
        return res.status(403).json({ success: false, error: 'Acceso denegado' });
      }

      req.userRole = data.role;
      next();
    } catch (error) {
      res.status(500).json({ success: false, error: error.message });
    }
  };
};

module.exports = { authenticateToken, authorizeRole };