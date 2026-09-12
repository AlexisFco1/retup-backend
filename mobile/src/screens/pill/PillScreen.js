import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  SafeAreaView,
  ScrollView,
  TouchableOpacity,
  ActivityIndicator,
  TextInput,
  Alert,
  Dimensions,
} from 'react-native';
import { pillorasAPI, nominacionesAPI, progressAPI } from '../../services/api';

const screenWidth = Dimensions.get('window').width;

export default function PillScreen({ navigation, route }) {
  const { retoId, retoName } = route.params;
  
  // Estados para píldora actual
  const [currentPill, setCurrentPill] = useState(null);
  const [currentScreen, setCurrentScreen] = useState(1); // 1-9
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);

  // Estados para respuestas del usuario
  const [responses, setResponses] = useState({
    nominacion1: '', // Pantalla 3
    autopercepcion: '', // Pantalla 5 (1-5)
    aprendizaje: '', // Pantalla 6
    nominacion2: '', // Pantalla 7
    practica: '', // Pantalla 8
  });

  // Cargar píldora del día
  useEffect(() => {
    loadDailyPill();
  }, [retoId]);

  const loadDailyPill = async () => {
    try {
      setLoading(true);
      // Obtener píldora del día para este reto
      const response = await pillorasAPI.getDailyPill(retoId);
      setCurrentPill(response.data);
    } catch (error) {
      console.log('Error loading pill:', error);
      Alert.alert('Error', 'No se pudo cargar la píldora');
      navigation.goBack();
    } finally {
      setLoading(false);
    }
  };

  const handleNext = () => {
    if (currentScreen < 9) {
      setCurrentScreen(currentScreen + 1);
    }
  };

  const handlePrevious = () => {
    if (currentScreen > 1) {
      setCurrentScreen(currentScreen - 1);
    }
  };

  const handleSaveResponse = async (field, value) => {
    setResponses(prev => ({
      ...prev,
      [field]: value,
    }));
  };

  const handleCompletePill = async () => {
    try {
      setSubmitting(true);
      
      // Enviar respuestas al backend
      await progressAPI.completePill({
        retoId,
        pilloraId: currentPill.id,
        responses: {
          nominacion1: responses.nominacion1,
          autopercepcion: parseInt(responses.autopercepcion) || 0,
          aprendizaje: responses.aprendizaje,
          nominacion2: responses.nominacion2,
          practica: responses.practica,
        },
      });

      Alert.alert(
        '¡Felicitaciones!',
        '¡Completaste la píldora del día! 🎉',
        [
          {
            text: 'OK',
            onPress: () => navigation.goBack(),
          },
        ]
      );
    } catch (error) {
      console.log('Error completing pill:', error);
      Alert.alert('Error', 'No se pudo guardar tu progreso');
    } finally {
      setSubmitting(false);
    }
  };

  if (loading) {
    return (
      <SafeAreaView style={styles.container}>
        <ActivityIndicator size="large" color="#007AFF" />
      </SafeAreaView>
    );
  }

  if (!currentPill) {
    return (
      <SafeAreaView style={styles.container}>
        <Text>No hay píldoras disponibles</Text>
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={styles.container}>
      {/* Header con progreso */}
      <View style={styles.header}>
        <TouchableOpacity onPress={() => navigation.goBack()}>
          <Text style={styles.backButton}>← Atrás</Text>
        </TouchableOpacity>
        <Text style={styles.title}>{retoName}</Text>
        <Text style={styles.progress}>Paso {currentScreen}/9</Text>
      </View>

      {/* Barra de progreso */}
      <View style={styles.progressBar}>
        <View
          style={[
            styles.progressFill,
            { width: `${(currentScreen / 9) * 100}%` },
          ]}
        />
      </View>

      <ScrollView style={styles.content}>
        {/* PANTALLA 1: Bienvenida */}
        {currentScreen === 1 && (
          <View style={styles.screen}>
            <Text style={styles.emoji}>🎯</Text>
            <Text style={styles.screenTitle}>
              ¡Bienvenido a la píldora del día!
            </Text>
            <Text style={styles.screenSubtitle}>
              {currentPill.nombre}
            </Text>
            <Text style={styles.description}>
              {currentPill.descripcion}
            </Text>
            <Text style={styles.motivationalPhrase}>
              💡 "{currentPill.frase_motivante || 'Recuerda: pequeños pasos, grandes cambios'}"
            </Text>
          </View>
        )}

        {/* PANTALLA 2: Dato histórico/evento */}
        {currentScreen === 2 && (
          <View style={styles.screen}>
            <Text style={styles.emoji}>📚</Text>
            <Text style={styles.screenTitle}>Un dato interesante</Text>
            <View style={styles.infoBox}>
              <Text style={styles.infoText}>
                {currentPill.dato_historico ||
                  'Fact: Los estudios muestran que las microlearning mejoran la retención en un 80%'}
              </Text>
            </View>
            <Text style={styles.hint}>
              Este dato es relevante para la habilidad que estás desarrollando.
            </Text>
          </View>
        )}

        {/* PANTALLA 3: Nominación 1 - ¿Quién lo hace mejor? */}
        {currentScreen === 3 && (
          <View style={styles.screen}>
            <Text style={styles.emoji}>🌟</Text>
            <Text style={styles.screenTitle}>
              ¿Quién lo hace mejor?
            </Text>
            <Text style={styles.screenSubtitle}>
              Nomina a alguien de tu equipo (anónimo)
            </Text>
            <TextInput
              style={styles.textInput}
              placeholder="Escribe un nombre o descripción (ej: 'Mi compañero de mesa')"
              placeholderTextColor="#ccc"
              value={responses.nominacion1}
              onChangeText={(text) =>
                handleSaveResponse('nominacion1', text)
              }
              multiline
            />
            <Text style={styles.hint}>
              Tu respuesta es anónima. Ayudará a crear un ranking colaborativo.
            </Text>
          </View>
        )}

        {/* PANTALLA 4: Por qué importa */}
        {currentScreen === 4 && (
          <View style={styles.screen}>
            <Text style={styles.emoji}>💪</Text>
            <Text style={styles.screenTitle}>¿Por qué importa?</Text>
            <View style={styles.infoBox}>
              <Text style={styles.infoText}>
                {currentPill.por_que_importa ||
                  'Esta habilidad es fundamental en el mundo profesional actual. Te abrirá puertas en tu carrera.'}
              </Text>
            </View>
            <Text style={styles.hint}>
              Reflexiona sobre cómo esta habilidad te puede ayudar en tu día a día.
            </Text>
          </View>
        )}

        {/* PANTALLA 5: Autopercepción */}
        {currentScreen === 5 && (
          <View style={styles.screen}>
            <Text style={styles.emoji}>🪞</Text>
            <Text style={styles.screenTitle}>¿Qué tan bueno crees que eres?</Text>
            <Text style={styles.screenSubtitle}>
              Califica tu nivel en esta habilidad
            </Text>
            <View style={styles.ratingContainer}>
              {[1, 2, 3, 4, 5].map((rating) => (
                <TouchableOpacity
                  key={rating}
                  style={[
                    styles.ratingButton,
                    responses.autopercepcion === rating.toString() &&
                      styles.ratingButtonActive,
                  ]}
                  onPress={() =>
                    handleSaveResponse(
                      'autopercepcion',
                      rating.toString()
                    )
                  }
                >
                  <Text style={styles.ratingText}>{rating}</Text>
                </TouchableOpacity>
              ))}
            </View>
            <View style={styles.scaleLabels}>
              <Text>Principiante</Text>
              <Text>Experto</Text>
            </View>
          </View>
        )}

        {/* PANTALLA 6: Qué aprendiste */}
        {currentScreen === 6 && (
          <View style={styles.screen}>
            <Text style={styles.emoji}>✨</Text>
            <Text style={styles.screenTitle}>
              ¿Qué aprendiste hoy?
            </Text>
            <TextInput
              style={styles.textInput}
              placeholder="Comparte uno o dos aprendizajes clave..."
              placeholderTextColor="#ccc"
              value={responses.aprendizaje}
              onChangeText={(text) =>
                handleSaveResponse('aprendizaje', text)
              }
              multiline
            />
            <Text style={styles.hint}>
              Escribir tus aprendizajes ayuda a solidificar el conocimiento.
            </Text>
          </View>
        )}

        {/* PANTALLA 7: Nominación 2 - ¿Quién necesita mejorar? */}
        {currentScreen === 7 && (
          <View style={styles.screen}>
            <Text style={styles.emoji}>📈</Text>
            <Text style={styles.screenTitle}>
              ¿Quién necesita mejorar?
            </Text>
            <Text style={styles.screenSubtitle}>
              Nomina a alguien que te gustaría ver mejorar (anónimo)
            </Text>
            <TextInput
              style={styles.textInput}
              placeholder="Escribe un nombre o descripción"
              placeholderTextColor="#ccc"
              value={responses.nominacion2}
              onChangeText={(text) =>
                handleSaveResponse('nominacion2', text)
              }
              multiline
            />
            <Text style={styles.hint}>
              Es una forma constructiva de dar feedback. Todas las nominaciones son anónimas.
            </Text>
          </View>
        )}

        {/* PANTALLA 8: Práctica social */}
        {currentScreen === 8 && (
          <View style={styles.screen}>
            <Text style={styles.emoji}>👥</Text>
            <Text style={styles.screenTitle}>
              Practica con tus compañeros
            </Text>
            <View style={styles.infoBox}>
              <Text style={styles.infoText}>
                {currentPill.practica_social ||
                  'Hoy, intenta practicar esta habilidad con al menos un compañero. Puede ser en una conversación informal.'}
              </Text>
            </View>
            <TextInput
              style={styles.textInput}
              placeholder="¿Con quién practicarás? (opcional)"
              placeholderTextColor="#ccc"
              value={responses.practica}
              onChangeText={(text) =>
                handleSaveResponse('practica', text)
              }
            />
          </View>
        )}

        {/* PANTALLA 9: Cierre gratificante */}
        {currentScreen === 9 && (
          <View style={styles.screen}>
            <Text style={styles.emoji}>🏆</Text>
            <Text style={styles.screenTitle}>
              ¡Lo hiciste! 🎉
            </Text>
            <View style={styles.infoBox}>
              <Text style={styles.infoText}>
                Completaste la píldora del día. Tu esfuerzo en desarrollar habilidades blandas te diferencia en el mercado.
              </Text>
            </View>
            <Text style={styles.xpGain}>+10 XP</Text>
            <Text style={styles.hint}>
              Vuelve mañana para tu próxima píldora. El cambio es progresivo. ¡Sigue adelante! 💪
            </Text>
          </View>
        )}
      </ScrollView>

      {/* Botones de navegación */}
      <View style={styles.buttonContainer}>
        <TouchableOpacity
          style={[styles.button, currentScreen === 1 && styles.buttonDisabled]}
          onPress={handlePrevious}
          disabled={currentScreen === 1}
        >
          <Text style={styles.buttonText}>← Anterior</Text>
        </TouchableOpacity>

        {currentScreen === 9 ? (
          <TouchableOpacity
            style={[styles.button, styles.completeButton]}
            onPress={handleCompletePill}
            disabled={submitting}
          >
            <Text style={styles.buttonText}>
              {submitting ? 'Guardando...' : '✓ Completar'}
            </Text>
          </TouchableOpacity>
        ) : (
          <TouchableOpacity
            style={[styles.button, styles.nextButton]}
            onPress={handleNext}
          >
            <Text style={styles.buttonText}>Siguiente →</Text>
          </TouchableOpacity>
        )}
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f8f9fa',
  },
  header: {
    padding: 16,
    backgroundColor: '#fff',
    borderBottomWidth: 1,
    borderBottomColor: '#e0e0e0',
  },
  backButton: {
    fontSize: 16,
    color: '#007AFF',
    marginBottom: 8,
  },
  title: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#1a1a1a',
  },
  progress: {
    fontSize: 12,
    color: '#999',
    marginTop: 4,
  },
  progressBar: {
    height: 4,
    backgroundColor: '#e0e0e0',
  },
  progressFill: {
    height: 4,
    backgroundColor: '#007AFF',
  },
  content: {
    flex: 1,
    padding: 20,
  },
  screen: {
    alignItems: 'center',
    marginBottom: 20,
  },
  emoji: {
    fontSize: 48,
    marginBottom: 16,
  },
  screenTitle: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#1a1a1a',
    textAlign: 'center',
    marginBottom: 12,
  },
  screenSubtitle: {
    fontSize: 16,
    color: '#666',
    textAlign: 'center',
    marginBottom: 16,
  },
  description: {
    fontSize: 14,
    color: '#666',
    textAlign: 'center',
    marginBottom: 16,
    lineHeight: 20,
  },
  motivationalPhrase: {
    fontSize: 14,
    color: '#007AFF',
    fontWeight: '500',
    fontStyle: 'italic',
    textAlign: 'center',
  },
  infoBox: {
    backgroundColor: '#f0f8ff',
    borderLeftWidth: 4,
    borderLeftColor: '#007AFF',
    padding: 16,
    borderRadius: 8,
    marginVertical: 12,
  },
  infoText: {
    fontSize: 14,
    color: '#1a1a1a',
    lineHeight: 20,
  },
  hint: {
    fontSize: 12,
    color: '#999',
    marginTop: 12,
    fontStyle: 'italic',
    textAlign: 'center',
  },
  textInput: {
    backgroundColor: '#fff',
    borderWidth: 1,
    borderColor: '#ddd',
    borderRadius: 8,
    padding: 12,
    fontSize: 14,
    color: '#1a1a1a',
    minHeight: 80,
    marginVertical: 12,
    textAlignVertical: 'top',
  },
  ratingContainer: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    marginVertical: 20,
  },
  ratingButton: {
    width: 50,
    height: 50,
    borderRadius: 25,
    backgroundColor: '#fff',
    borderWidth: 2,
    borderColor: '#ddd',
    justifyContent: 'center',
    alignItems: 'center',
  },
  ratingButtonActive: {
    backgroundColor: '#007AFF',
    borderColor: '#007AFF',
  },
  ratingText: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#1a1a1a',
  },
  scaleLabels: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    width: '100%',
    paddingHorizontal: 0,
  },
  xpGain: {
    fontSize: 32,
    fontWeight: 'bold',
    color: '#007AFF',
    marginVertical: 16,
  },
  buttonContainer: {
    flexDirection: 'row',
    padding: 16,
    gap: 12,
    backgroundColor: '#fff',
    borderTopWidth: 1,
    borderTopColor: '#e0e0e0',
  },
  button: {
    flex: 1,
    paddingVertical: 12,
    borderRadius: 8,
    backgroundColor: '#007AFF',
    alignItems: 'center',
  },
  nextButton: {
    backgroundColor: '#007AFF',
  },
  completeButton: {
    backgroundColor: '#34C759',
  },
  buttonDisabled: {
    backgroundColor: '#ccc',
  },
  buttonText: {
    color: '#fff',
    fontSize: 14,
    fontWeight: '600',
  },
});