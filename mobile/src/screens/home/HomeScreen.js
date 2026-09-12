import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  SafeAreaView,
  ScrollView,
  TouchableOpacity,
  ActivityIndicator,
  FlatList,
  Alert,
} from 'react-native';
import { retosAPI, usersAPI, progressAPI } from '../../services/api';

export default function HomeScreen({ navigation }) {
  const [user, setUser] = useState(null);
  const [retos, setRetos] = useState([]);
  const [selectedReto, setSelectedReto] = useState(null);
  const [userProgress, setUserProgress] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadData();
  }, []);

  const loadData = async () => {
    try {
      setLoading(true);
      const userRes = await usersAPI.getProfile();
      setUser(userRes.data);

      const retosRes = await retosAPI.getAll();
      setRetos(retosRes.data || []);

      const progressRes = await progressAPI.getUserProgress(userRes.data.id);
      setUserProgress(progressRes.data);

      if (progressRes.data && progressRes.data.reto_activo) {
        setSelectedReto(progressRes.data.reto_activo);
      }
    } catch (error) {
      console.log('Error loading data:', error);
      Alert.alert('Error', 'No se pudieron cargar los datos');
    } finally {
      setLoading(false);
    }
  };

  const handleSelectReto = (reto) => {
    setSelectedReto(reto.id);
    navigation.navigate('Píldoras', { retoId: reto.id, retoName: reto.nombre });
  };

  if (loading) {
    return (
      <SafeAreaView style={styles.container}>
        <ActivityIndicator size="large" color="#007AFF" style={styles.loader} />
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={styles.container}>
      <ScrollView style={styles.scrollView}>
        <View style={styles.header}>
          <Text style={styles.greeting}>¡Hola, {user?.email?.split('@')[0]}! 👋</Text>
          <Text style={styles.subtitle}>Desarrolla tus habilidades hoy</Text>
        </View>

        {userProgress && (
          <View style={styles.statsCard}>
            <View style={styles.statItem}>
              <Text style={styles.statLabel}>🔥 Racha</Text>
              <Text style={styles.statValue}>{userProgress.streak || 0} días</Text>
            </View>
            <View style={styles.divider} />
            <View style={styles.statItem}>
              <Text style={styles.statLabel}>⭐ XP</Text>
              <Text style={styles.statValue}>{userProgress.xp || 0}</Text>
            </View>
            <View style={styles.divider} />
            <View style={styles.statItem}>
              <Text style={styles.statLabel}>📊 Nivel</Text>
              <Text style={styles.statValue}>{Math.floor((userProgress.xp || 0) / 100) + 1}</Text>
            </View>
          </View>
        )}

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Elige tu Reto del mes</Text>
          <Text style={styles.sectionSubtitle}>
            Cada reto tiene 21 píldoras de 3 minutos
          </Text>

          {retos.length === 0 ? (
            <Text style={styles.emptyText}>No hay retos disponibles</Text>
          ) : (
            <FlatList
              scrollEnabled={false}
              data={retos}
              keyExtractor={(item) => item.id.toString()}
              renderItem={({ item }) => (
                <TouchableOpacity
                  style={[
                    styles.retoCard,
                    selectedReto === item.id && styles.retoCardActive,
                  ]}
                  onPress={() => handleSelectReto(item)}
                >
                  <View style={styles.retoHeader}>
                    <Text style={styles.retoEmoji}>{item.emoji || '🎯'}</Text>
                    <View style={styles.retoInfo}>
                      <Text style={styles.retoName}>{item.nombre}</Text>
                      <Text style={styles.retoDesc}>{item.descripcion}</Text>
                    </View>
                  </View>
                  {selectedReto === item.id && (
                    <View style={styles.selectedBadge}>
                      <Text style={styles.selectedBadgeText}>✓ Activo</Text>
                    </View>
                  )}
                </TouchableOpacity>
              )}
            />
          )}
        </View>

        {selectedReto && (
          <TouchableOpacity
            style={styles.primaryButton}
            onPress={() =>
              navigation.navigate('Píldoras', {
                retoId: selectedReto,
                retoName: retos.find((r) => r.id === selectedReto)?.nombre,
              })
            }
          >
            <Text style={styles.primaryButtonText}>Comienza tu píldora hoy →</Text>
          </TouchableOpacity>
        )}

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Más opciones</Text>
          <TouchableOpacity
            style={styles.optionItem}
            onPress={() => navigation.navigate('Perfil')}
          >
            <Text style={styles.optionIcon}>📊</Text>
            <Text style={styles.optionText}>Mi Perfil y Habilidades</Text>
          </TouchableOpacity>
          <TouchableOpacity
            style={styles.optionItem}
            onPress={() => navigation.navigate('Leaderboard')}
          >
            <Text style={styles.optionIcon}>🏆</Text>
            <Text style={styles.optionText}>Leaderboard</Text>
          </TouchableOpacity>
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f8f9fa',
  },
  scrollView: {
    flex: 1,
  },
  loader: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  header: {
    padding: 20,
    paddingTop: 10,
  },
  greeting: {
    fontSize: 28,
    fontWeight: 'bold',
    color: '#1a1a1a',
    marginBottom: 4,
  },
  subtitle: {
    fontSize: 14,
    color: '#666',
  },
  statsCard: {
    margin: 20,
    marginTop: 0,
    backgroundColor: '#fff',
    borderRadius: 12,
    padding: 16,
    flexDirection: 'row',
    justifyContent: 'space-around',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  statItem: {
    flex: 1,
    alignItems: 'center',
  },
  statLabel: {
    fontSize: 12,
    color: '#666',
    marginBottom: 4,
  },
  statValue: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#007AFF',
  },
  divider: {
    width: 1,
    backgroundColor: '#e0e0e0',
  },
  section: {
    padding: 20,
    paddingTop: 0,
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    marginBottom: 4,
    color: '#1a1a1a',
  },
  sectionSubtitle: {
    fontSize: 13,
    color: '#999',
    marginBottom: 16,
  },
  emptyText: {
    textAlign: 'center',
    color: '#999',
    paddingVertical: 20,
  },
  retoCard: {
    backgroundColor: '#fff',
    borderRadius: 12,
    padding: 16,
    marginBottom: 12,
    borderWidth: 2,
    borderColor: '#e0e0e0',
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  retoCardActive: {
    borderColor: '#007AFF',
    backgroundColor: '#f0f8ff',
  },
  retoHeader: {
    flexDirection: 'row',
    flex: 1,
    alignItems: 'center',
  },
  retoEmoji: {
    fontSize: 32,
    marginRight: 12,
  },
  retoInfo: {
    flex: 1,
  },
  retoName: {
    fontSize: 16,
    fontWeight: '600',
    color: '#1a1a1a',
    marginBottom: 2,
  },
  retoDesc: {
    fontSize: 12,
    color: '#999',
  },
  selectedBadge: {
    backgroundColor: '#007AFF',
    borderRadius: 6,
    paddingHorizontal: 12,
    paddingVertical: 6,
  },
  selectedBadgeText: {
    color: '#fff',
    fontSize: 12,
    fontWeight: '600',
  },
  primaryButton: {
    margin: 20,
    marginTop: 0,
    backgroundColor: '#007AFF',
    borderRadius: 12,
    padding: 16,
    alignItems: 'center',
  },
  primaryButtonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
  optionItem: {
    backgroundColor: '#fff',
    borderRadius: 12,
    padding: 16,
    marginBottom: 12,
    flexDirection: 'row',
    alignItems: 'center',
  },
  optionIcon: {
    fontSize: 24,
    marginRight: 12,
  },
  optionText: {
    fontSize: 16,
    color: '#1a1a1a',
    fontWeight: '500',
  },
});