#!/bin/bash

# Script de Verificación: Estadísticas de Rachas
# Este script te ayuda a verificar si el fix está funcionando correctamente

echo "=================================="
echo "🔍 VERIFICACIÓN DE FIX - RACHAS"
echo "=================================="
echo ""

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Variables que necesitas cambiar
read -p "👤 Ingresa tu USER_ID (ej: 178): " USER_ID
read -p "🎯 Ingresa tu RETO_ID (ej: 1): " RETO_ID
read -p "📅 Ingresa el MES (ej: 9): " MES
read -p "📅 Ingresa el AÑO (ej: 2026): " ANO
read -p "🔑 Ingresa tu TOKEN (Bearer token): " TOKEN

echo ""
echo "=================================="
echo "✅ Verificación 1: Deploy Status"
echo "=================================="
echo ""

# Verificar que el backend está disponible
echo -n "Verificando que Render está disponible..."
RENDER_STATUS=$(curl -s -w "%{http_code}" -o /dev/null "https://retup-backend.onrender.com/health")

if [ "$RENDER_STATUS" = "200" ]; then
  echo -e " ${GREEN}✓ OK${NC}"
else
  echo -e " ${RED}✗ ERROR (HTTP $RENDER_STATUS)${NC}"
  echo "El backend no está respondiendo. Espera 60 segundos y intenta de nuevo."
  exit 1
fi

echo ""
echo "=================================="
echo "✅ Verificación 2: Endpoint Response"
echo "=================================="
echo ""

# Llamar al endpoint
echo "Llamando a: /api/racha/estadisticas-por-reto"
echo "  user_id: $USER_ID"
echo "  reto_id: $RETO_ID"
echo "  mes: $MES"
echo "  año: $ANO"
echo ""

RESPONSE=$(curl -s -X GET \
  "https://retup-backend.onrender.com/api/racha/estadisticas-por-reto?user_id=$USER_ID&reto_id=$RETO_ID&mes=$MES&ano=$ANO" \
  -H "Authorization: Bearer $TOKEN")

echo "Respuesta del servidor:"
echo "$RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE"

echo ""
echo "=================================="
echo "✅ Verificación 3: Validar Estructura"
echo "=================================="
echo ""

# Verificar que la respuesta tiene la estructura correcta
if echo "$RESPONSE" | grep -q "dia_pildora"; then
  echo -e "${GREEN}✓${NC} Contiene: dia_pildora"
else
  echo -e "${RED}✗${NC} Falta: dia_pildora"
fi

if echo "$RESPONSE" | grep -q "dias_cumplidos"; then
  echo -e "${GREEN}✓${NC} Contiene: dias_cumplidos"
else
  echo -e "${RED}✗${NC} Falta: dias_cumplidos"
fi

if echo "$RESPONSE" | grep -q "dias_no_cumplidos"; then
  echo -e "${GREEN}✓${NC} Contiene: dias_no_cumplidos"
else
  echo -e "${RED}✗${NC} Falta: dias_no_cumplidos"
fi

if echo "$RESPONSE" | grep -q "racha_maxima"; then
  echo -e "${GREEN}✓${NC} Contiene: racha_maxima"
  echo -e "  ${YELLOW}⚠️ Importante: Debe ser racha_maxima, NO racha_actual${NC}"
else
  echo -e "${RED}✗${NC} Falta: racha_maxima"
  if echo "$RESPONSE" | grep -q "racha_actual"; then
    echo -e "  ${RED}ERROR: Tiene racha_actual en lugar de racha_maxima${NC}"
  fi
fi

echo ""
echo "=================================="
echo "✅ Verificación 4: Validar Valores"
echo "=================================="
echo ""

# Extraer valores
DIA_PILDORA=$(echo "$RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('data', {}).get('dia_pildora', 'N/A'))" 2>/dev/null || echo "N/A")
DIAS_CUMPLIDOS=$(echo "$RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('data', {}).get('dias_cumplidos', 'N/A'))" 2>/dev/null || echo "N/A")
DIAS_NO_CUMPLIDOS=$(echo "$RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('data', {}).get('dias_no_cumplidos', 'N/A'))" 2>/dev/null || echo "N/A")
RACHA_MAXIMA=$(echo "$RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('data', {}).get('racha_maxima', 'N/A'))" 2>/dev/null || echo "N/A")
DIAS_LABORALES=$(echo "$RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('data', {}).get('dias_laborales_total', 'N/A'))" 2>/dev/null || echo "N/A")

echo "Día Píldora:          $DIA_PILDORA (debe ser entre 1 y $DIAS_LABORALES)"
echo "Días Cumplidos:       $DIAS_CUMPLIDOS (ambas: login + píldora)"
echo "Días No Cumplidos:    $DIAS_NO_CUMPLIDOS"
echo "Racha Máxima:         $RACHA_MAXIMA"
echo "Días Laborales Total: $DIAS_LABORALES"

echo ""

# Validar sumas
if [[ "$DIAS_CUMPLIDOS" != "N/A" && "$DIAS_NO_CUMPLIDOS" != "N/A" && "$DIA_PILDORA" != "N/A" ]]; then
  CUMPLIDOS_INT=$(echo "$DIAS_CUMPLIDOS" | grep -oE '[0-9]+')
  NO_CUMPLIDOS_INT=$(echo "$DIAS_NO_CUMPLIDOS" | grep -oE '[0-9]+')
  DIA_PILDORA_INT=$(echo "$DIA_PILDORA" | grep -oE '[0-9]+')
  SUMA=$((CUMPLIDOS_INT + NO_CUMPLIDOS_INT))

  echo "Validación de suma:"
  echo "  Cumplidos ($CUMPLIDOS_INT) + No Cumplidos ($NO_CUMPLIDOS_INT) = $SUMA"
  echo "  Días laborales hasta hoy: $DIA_PILDORA_INT"

  if [ "$SUMA" -eq "$DIA_PILDORA_INT" ]; then
    echo -e "  ${GREEN}✓ La suma es correcta${NC}"
  else
    echo -e "  ${YELLOW}⚠️ Puede haber días sin registrar (son $((DIA_PILDORA_INT - SUMA)))${NC}"
  fi
fi

echo ""
echo "=================================="
echo "✅ Verificación 5: Datos en Supabase"
echo "=================================="
echo ""

# Instruye al usuario cómo verificar en Supabase
echo "Para verificar los datos en Supabase:"
echo ""
echo "1. Ve a: https://app.supabase.com"
echo "2. Selecciona tu proyecto"
echo "3. Haz clic en 'SQL Editor'"
echo "4. Ejecuta esta query:"
echo ""
echo "SELECT"
echo "  fecha,"
echo "  login_hecho,"
echo "  pildora_completada,"
echo "  (login_hecho AND pildora_completada) as ambas_cumplidas"
echo "FROM racha_daily_progress"
echo "WHERE user_id = '$USER_ID'"
echo "  AND reto_id = '$RETO_ID'"
echo "  AND fecha >= '${ANO}-${MES}-01'"
echo "  AND fecha <= '${ANO}-${MES}-31'"
echo "ORDER BY fecha;"
echo ""

echo "=================================="
echo "✅ Verificación Completa"
echo "=================================="
echo ""
echo "✓ Si todos los checks pasaron, el fix está funcionando correctamente."
echo "✗ Si hay errores, revisa la GUIA_IMPLEMENTAR_FIX.md para solucionar."
echo ""
