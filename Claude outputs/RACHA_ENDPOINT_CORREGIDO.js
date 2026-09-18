// ===== ENDPOINT CORREGIDO: Estadísticas por Reto =====
// Este reemplaza el endpoint /api/racha/estadisticas-por-reto en server.js

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

    // Obtener progreso del mes PARA ESTE RETO desde racha_daily_progress
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

    // ============================================
    // 1. DIA PILDORA: Número secuencial del día laboral actual
    // ============================================
    const ahora = new Date();
    const today = ahora.toISOString().split('T')[0];

    // Contar cuántos días laborales han pasado hasta hoy (incluido hoy si es laboral)
    const dia_pildora = diasLaborales.filter(fechaStr => {
      const fecha = new Date(fechaStr);
      return fecha <= ahora;
    }).length;

    console.log(`📅 Día Píldora: ${dia_pildora} (de ${diasLaborales.length} días laborales)`);

    // ============================================
    // 2. CUMPLIDOS: Días donde AMBAS condiciones se cumplen
    //    login_hecho = true AND pildora_completada = true
    // ============================================
    const diasCumplidos = progreso.filter(p =>
      p.login_hecho === true && p.pildora_completada === true
    ).length;

    console.log(`✅ Días Cumplidos (login + píldora): ${diasCumplidos}`);

    // ============================================
    // 3. NO CUMPLIDOS: Días laborales pasados sin cumplir ambas condiciones
    // ============================================
    const diasNoCumplidos = diasLaborales.filter(fechaStr => {
      const registro = progreso.find(p => p.fecha === fechaStr);
      const fechaDate = new Date(fechaStr);
      // No cumplido si: no hay registro O si no se cumplieron AMBAS condiciones
      const noCumplio = !registro || !(registro.login_hecho && registro.pildora_completada);
      return noCumplio && fechaDate <= ahora;
    }).length;

    console.log(`❌ Días No Cumplidos: ${diasNoCumplidos}`);
    console.log(`🏆 Racha Máxima: ${racha_maxima}`);

    res.json({
      success: true,
      data: {
        reto_id,
        dia_pildora,
        racha_maxima,  // ✅ Cambio: Usa racha_maxima en lugar de racha_actual
        dias_cumplidos: diasCumplidos,  // ✅ Cambio: Cuenta AMBAS condiciones
        dias_no_cumplidos: diasNoCumplidos,  // ✅ Cambio: Verifica AMBAS condiciones
        dias_laborales_total: diasLaborales.length
      }
    });
  } catch (error) {
    console.error('❌ Error en estadisticas-por-reto:', error.message);
    res.status(400).json({ success: false, error: error.message });
  }
});
