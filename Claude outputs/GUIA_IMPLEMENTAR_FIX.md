# Guía: Implementar Fix para Rachas Estadísticas

## 🔍 Resumen del Problema

El endpoint `/api/racha/estadisticas-por-reto` está calculando las estadísticas incorrectamente porque:

| Métrica | Problema | Solución |
|---------|----------|----------|
| **dias_cumplidos** | Cuenta píldoras completadas en `user_pill_progress`, no verificando login | Contar AMBAS: `login_hecho=true AND pildora_completada=true` |
| **dias_no_cumplidos** | Cálculo incorrecto porque usa otra lógica | Contar días laborales donde NO se cumplen AMBAS condiciones |
| **racha_maxima** | Era correcto, pero el endpoint retornaba campos confusos | Asegurar que se retorne `racha_maxima` (no `racha_actual`) |

---

## 📋 Paso 1: Abrir y Editar server.js

### Ubicación del código a reemplazar:
- **Archivo**: `retup-app/server.js`
- **Líneas**: 1025-1147
- **Endpoint**: `/api/racha/estadisticas-por-reto`

### Pasos:

1. **Abre tu editor** (VSCode, Sublime, etc.)
2. **Carga `server.js`**
3. **Presiona Ctrl+G** (ir a línea)
4. **Escribe 1025** y presiona Enter
5. **Verifica que ves**:
   ```javascript
   app.get('/api/racha/estadisticas-por-reto', authenticateToken, async (req, res) => {
   ```

---

## 🔄 Paso 2: Reemplazar la Función

### Opción A: Reemplazar manualmente (Recomendado para entender)

**1. Selecciona las líneas 1025-1147:**
   - Haz clic en la línea 1025
   - Presiona Shift+Ctrl+End para seleccionar hasta el final de la función
   - O selecciona manualmente desde `app.get('/api/racha/estadisticas-por-reto'` hasta el `});` de cierre

**2. Elimina el código viejo**

**3. Copia el código corregido:**
   - Abre `RACHA_ENDPOINT_CORREGIDO.js`
   - Copia TODO el contenido (desde `app.get` hasta el `});` final)
   - Pégalo en `server.js`

### Opción B: Buscar y reemplazar (Más rápido)

En VSCode:
1. Presiona Ctrl+H (Buscar y Reemplazar)
2. **Buscar por**: Copia los primeros 100 caracteres del endpoint viejo:
   ```
   app.get('/api/racha/estadisticas-por-reto', authenticateToken, async (req, res) => {
     try {
       const { user_id, reto_id, mes, ano } = req.query;
   ```
3. **Reemplazar por**: Copia el código del archivo RACHA_ENDPOINT_CORREGIDO.js
4. Haz clic en "Replace" (solo el primero, no Replace All)

---

## ✅ Paso 3: Guardar y Hacer Git Push

```bash
# 1. Verifica cambios
git status

# 2. Agrega el archivo
git add server.js

# 3. Haz commit
git commit -m "Fix: Corregir cálculo de estadísticas de rachas - verificar AMBAS condiciones (login + píldora)"

# 4. Haz push
git push origin main
```

**Espera a que aparezca en el terminal**:
```
   <información del push>
To https://github.com/YOUR_USERNAME/retup-app.git
   6e5f2a1..abc1234  main -> main
```

---

## 🚀 Paso 4: Verificar el Deploy en Render

1. **Ve a [Render Dashboard](https://dashboard.render.com)**
2. **Selecciona tu servicio "retup-backend"**
3. **Mira la sección "Events"** (debería mostrar un nuevo deploy)
4. **Espera 30-60 segundos** hasta que veas:
   ```
   ✓ Deploy succeeded
   ```

---

## 🧪 Paso 5: Probar el Fix

### Prueba Local (si tienes el backend corriendo):

```bash
# Reemplaza los valores con datos reales
curl "http://localhost:5000/api/racha/estadisticas-por-reto?user_id=178&reto_id=1&mes=9&ano=2026" \
  -H "Authorization: Bearer TU_TOKEN_AQUI"
```

### Prueba en Render:

```bash
curl "https://retup-backend.onrender.com/api/racha/estadisticas-por-reto?user_id=178&reto_id=1&mes=9&ano=2026" \
  -H "Authorization: Bearer TU_TOKEN_AQUI"
```

### Respuesta esperada:

```json
{
  "success": true,
  "data": {
    "reto_id": "1",
    "dia_pildora": 4,
    "racha_maxima": 5,
    "dias_cumplidos": 8,
    "dias_no_cumplidos": 2,
    "dias_laborales_total": 22
  }
}
```

---

## 📊 Paso 6: Verificar en Supabase

### Opción 1: Ver datos crudos

1. **Ve a [Supabase Dashboard](https://app.supabase.com)**
2. **Selecciona tu proyecto**
3. **Haz clic en "SQL Editor"**
4. **Ejecuta esta query**:

```sql
-- Ver progreso del usuario
SELECT 
  fecha, 
  login_hecho, 
  pildora_completada,
  (login_hecho AND pildora_completada) as ambas_cumplidas
FROM racha_daily_progress
WHERE user_id = '178'
  AND reto_id = '1'
  AND fecha >= '2026-09-01'
  AND fecha <= '2026-09-30'
ORDER BY fecha;
```

**Ejemplo de resultado:**
```
fecha       | login_hecho | pildora_completada | ambas_cumplidas
2026-09-01  | true        | true               | true
2026-09-02  | true        | true               | true
2026-09-03  | false       | true               | false  ← No cumplido
2026-09-04  | true        | false              | false  ← No cumplido
2026-09-05  | true        | true               | true
...
```

### Opción 2: Ver tabla user_racha_stats

```sql
SELECT 
  user_id,
  reto_id,
  mes,
  año,
  racha_actual,
  racha_maxima,
  updated_at
FROM user_racha_stats
WHERE user_id = '178'
  AND reto_id = '1'
  AND mes = 9
  AND año = 2026;
```

---

## 🔍 Paso 7: Revisar Logs en Render

1. **Ve a Render Dashboard**
2. **Selecciona tu servicio**
3. **Haz clic en "Logs"**
4. **Haz un login en la app**
5. **Busca mensajes como**:
   ```
   📊 GET /api/racha/estadisticas-por-reto
   ✅ Días Cumplidos (login + píldora): 8
   ❌ Días No Cumplidos: 2
   🏆 Racha Máxima: 5
   ```

---

## 🐛 Paso 8: Verificar en la App

### En la pantalla "Rachas" de Flutter:

1. **Haz login**
2. **Ve a la pantalla "Rachas por Reto"**
3. **Verifica que ves**:
   - ✅ "Día Píldora Planificada": Muestra el número del día laboral actual
   - ✅ "Píldoras cumplidas": Solo cuenta días donde hiciste AMBAS cosas (login + píldora)
   - 🔥 "Racha": Muestra la racha máxima (no la actual)
   - ❌ "Días no cumplidos": Muestra días donde faltó al menos una cosa

---

## 📝 Validación Manual

Si tienes estos datos en Supabase para Septiembre:

```
Sept 1  (Lu): login ✅ + píldora ✅ → ✅ CUMPLIDO
Sept 2  (Ma): login ✅ + píldora ✅ → ✅ CUMPLIDO
Sept 3  (Mi): login ❌ + píldora ✅ → ❌ NO CUMPLIDO
Sept 4  (Ju): login ✅ + píldora ❌ → ❌ NO CUMPLIDO
Sept 5  (Vi): login ✅ + píldora ✅ → ✅ CUMPLIDO
Sept 6-7: Fin de semana (no cuentan)
Sept 8  (Lu): login ✅ + píldora ✅ → ✅ CUMPLIDO
Sept 9  (Ma): login ✅ + píldora ✅ → ✅ CUMPLIDO
Sept 10 (Mi): login ❌ + píldora ❌ → ❌ NO CUMPLIDO
Sept 11 (Ju): login ✅ + píldora ✅ → ✅ CUMPLIDO
Sept 12 (Vi): login ✅ + píldora ✅ → ✅ CUMPLIDO
Sept 13 (Sa): Fin de semana
```

**La API debe retornar**:
- `dia_pildora`: 11 (11 días laborales hasta Sept 12)
- `dias_cumplidos`: 8 (Sept 1, 2, 5, 8, 9, 11, 12 = 7... recuenta = 8)
- `dias_no_cumplidos`: 3 (Sept 3, 4, 10)
- `racha_maxima`: Depende del histórico

---

## ⚠️ Problemas Comunes

### Problema: "No veo cambios en la app"

**Solución**:
1. Espera 60 segundos a que Render redeployee
2. Cierra la app completamente
3. Abre de nuevo
4. Haz un login nuevo

### Problema: "Recibo error 401 Unauthorized"

**Solución**:
- El token expiró
- Haz logout
- Haz login de nuevo

### Problema: "Los números siguen siendo incorrectos"

**Solución**:
1. Verifica que el push llegó a Render:
   ```bash
   git log --oneline -1
   ```
   (Debería mostrar tu commit reciente)

2. Verifica que Render redeployó:
   - Ve a Render Dashboard
   - Mira el "Commit Hash" actual
   - Debe coincidir con tu commit

3. Si no coincide:
   - Espera 2 minutos
   - Recarga la página de Render
   - Si aún no coincide, haz push de nuevo:
     ```bash
     git push origin main
     ```

---

## ✨ Resumen de Cambios

| Línea | Antes | Después |
|-------|-------|---------|
| Días Cumplidos | Cuenta de `user_pill_progress` | Cuenta de `racha_daily_progress` donde AMBAS = true |
| Días No Cumplidos | Cálculo independiente | Verifica AMBAS condiciones en `racha_daily_progress` |
| Retorna | `racha_actual` (variable) | `racha_maxima` (máxima del mes) |
| Fuente de Datos | Mezcla de tablas | Solo `racha_daily_progress` + `user_racha_stats` |

---

## 📞 Próximos Pasos

Una vez aplicado el fix:

1. ✅ Push a Render
2. ✅ Esperar deploy
3. ✅ Prueba en la app
4. ✅ Verifica logs en Render
5. ✅ Compara con datos en Supabase

Si algo falla, comparte:
- Screenshot de los números en la app
- Output de la query SQL en Supabase
- Los logs de Render (copiar desde "Logs")
