import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  SafeAreaView,
  ScrollView,
  TouchableOpacity,
  ActivityIndicator,
  Alert,
  Dimensions,
} from 'react-native';
import { usersAPI, progressAPI } from '../../services/api';

const screenWidth = Dimensions.get('window').width;

export default function ProfileScreen({ navigation }) {
  const [userProfile, setUserProfile] = useState(null);
  const [userProgress, setUserProgress] = useState(null);
  const [skillsData, setSkillsData] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadProfile();
  }, []);

  const loadProfile = async () => {
    try {
      setLoading(true);
      const profileRes = await usersAPI.getProfile();
      setUserProfile(profileRes.data);

      const progressRes = await progressAPI.getUserProgress(
        profileRes.data.id
      );
      setUserProgress(progressRes.data);

      // Cargar habilidades del usuario
      const skillsRes = await usersAPI.getUserSkills(profileRes.data.id);
      setSkillsData(skillsRes.data || []);
    } catch (error) {
      console.log('Error loading profile:', error);
      Alert.alert('Error', 'No se pudo cargar el perfil');
    } finally {
      setLoading(false);
    }
  };

  const handleLogout = async () => {
    Alert.alert(
      'Cerrar sesión',
      '¿Estás seguro de que quieres cerrar sesión?',
      [
        { text: 'Cancelar', style: 'cancel' },
        {
          text: 'Cerrar sesión',
          style: 'destructive',
          onPress: async () => {
            try {
              // Aquí iría la lógica de logout si es necesaria
              navigation.navigate('Auth');
            } catch (error) {
              Alert.alert('Error', 'Error al cerrar sesión');
            }
          },
        },
      ]
    );
  };

  if (loading) {
    return (
      <SafeAreaView style={styles.container}>
        <ActivityIndicator size="large" color="#007AFF" />
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={styles.container}>
      <ScrollView style={styles.scrollView}>
        {/* Header con foto/avatar */}
        <View style={styles.header}>
          <View style={styles.avatar}>
            <Text style={styles.avatarText}>
              {userProfile?.email?.[0]?.toUpperCase()}
            </Text>
          </View>
          <View style={styles.userInfo}>
            <Text style={styles.userName}>
              {userProfile?.email?.split('@')[0]}
            </Text>
            <Text style={styles.userEmail}>{userProfile?.email}</Text>
          </View>
        </View>

        {/* Stats generales */}
        {userProgress && (
          <View style={styles.statsSection}>
            <View style={styles.statCard}>
              <Text style={styles.statIcon}>⭐</Text>
              <Text style={styles.statLabel}>XP Total</Text>
              <Text style={styles.statValue}>{userProgress.xp || 0}</Text>
            </View>
            <View style={styles.statCard}>
              <Text style={styles.statIcon}>🔥</Text>
              <Text style={styles.statLabel}>Racha</Text>
              <Text style={styles.statValue}>
                {userProgress.streak || 0} días
              </Text>
            </View>
            <View style={styles.statCard}>
              <Text style={styles.statIcon}>📊</Text>
              <Text style={styles.statLabel}>Nivel</Text>
              <Text style={styles.statValue}>
                {Math.floor((userProgress.xp || 0) / 100) + 1}
              </Text>
            </View>
          </View>
        )}

        {/* Sección de habilidades */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Tus Habilidades</Text>
          <Text style={styles.sectionSubtitle}>
            Progreso en las habilidades blandas que estás desarrollando
          </Text>

          {skillsData.length === 0 ? (
            <Text style={styles.emptyText}>
              Aún no has completado píldoras. ¡Empieza hoy!
            </Text>
          ) : (
            skillsData.map((skill, index) => (
              <View key={index} style={styles.skillCard}>
                <View style={styles.skillHeader}>
                  <Text style={styles.skillName}>{skill.nombre}</Text>
                  <Text style={styles.skillScore}>
                    {Math.round(skill.score || 0)}%
                  </Text>
                </View>

                {/* Barra de progreso */}
                <View style={styles.progressBarContainer}>
                  <View
                    style={[
                      styles.progressBarFill,
                      { width: `${skill.score || 0}%` },
                    ]}
                  />
                </View>

                {/* Información de la habilidad */}
                <View style={styles.skillInfo}>
                  <View style={styles.infoItem}>
                    <Text style={styles.infoLabel}>Autopercepción</Text>
                    <Text style={styles.infoValue}>
                      {skill.self_perception || 0}/5
                    </Text>
                  </View>
                  <View style={styles.infoItem}>
                    <Text style={styles.infoLabel}>Nominaciones (+)</Text>
                    <Text style={styles.infoValue}>
                      {skill.positive_nominations || 0}
                    </Text>
                  </View>
                  <View style={styles.infoItem}>
                    <Text style={styles.infoLabel}>Nominaciones (-)</Text>
                    <Text style={styles.infoValue}>
                      {skill.negative_nominations || 0}
                    </Text>
                  </View>
                </View>

                {/* Brecha de percepción */}
                {skill.perception_gap && (
                  <View style={styles.gapWarning}>
                    <Text style={styles.gapIcon}>⚠️</Text>
                    <Text style={styles.gapText}>
                      Brecha de percepción: {skill.perception_gap}%
                    </Text>
                  </View>
                )}
              </View>
            ))
          )}
        </View>

        {/* Logros (badges) */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Logros Desbloqueados</Text>
          <View style={styles.badgesContainer}>
            {userProgress && userProgress.streak >= 7 && (
              <View style={styles.badge}>
                <Text style={styles.badgeIcon}>🔥</Text>
                <Text style={styles.badgeLabel}>Racha de 7 días</Text>
              </View>
            )}
            {userProgress && userProgress.xp >= 100 && (
              <View style={styles.badge}>
                <Text style={styles.badgeIcon}>⭐</Text>
                <Text style={styles.badgeLabel}>100 XP</Text>
              </View>
            )}
            {userProgress && userProgress.xp >= 500 && (
              <View style={styles.badge}>
                <Text style={styles.badgeIcon}>🏆</Text>
                <Text style={styles.badgeLabel}>500 XP</Text>
              </View>
            )}
            {skillsData.length >= 5 && (
              <View style={styles.badge}>
                <Text style={styles.badgeIcon}>📚</Text>
                <Text style={styles.badgeLabel}>5 Habilidades</Text>
              </View>
            )}
          </View>
        </View>

        {/* Detalles de actividad */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Actividad Reciente</Text>
          {userProgress && (
            <View style={styles.activityBox}>
              <Text style={styles.activityLabel}>
                Última píldora completada
              </Text>
              <Text style={styles.activityDate}>
                {userProgress.last_pill_date
                  ? new Date(
                      userProgress.last_pill_date
                    ).toLocaleDateString('es-ES')
                  : 'Aún no completada'}
              </Text>
            </View>
          )}
          <View style={styles.activityBox}>
            <Text style={styles.activityLabel}>
              Píldoras completadas
            </Text>
            <Text style={styles.activityDate}>
              {userProgress?.pills_completed || 0}
            </Text>
          </View>
        </View>

        {/* Botón de logout */}
        <TouchableOpacity
          style={styles.logoutButton}
          onPress={handleLogout}
        >
          <Text style={styles.logoutButtonText}>Cerrar Sesión</Text>
        </TouchableOpacity>

        <View style={{ height: 20 }} />
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
  header: {
    backgroundColor: '#fff',
    padding: 20,
    flexDirection: 'row',
    alignItems: 'center',
    borderBottomWidth: 1,
    borderBottomColor: '#e0e0e0',
  },
  avatar: {
    width: 60,
    height: 60,
    borderRadius: 30,
    backgroundColor: '#007AFF',
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 16,
  },
  avatarText: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#fff',
  },
  userInfo: {
    flex: 1,
  },
  userName: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#1a1a1a',
  },
  userEmail: {
    fontSize: 12,
    color: '#999',
    marginTop: 4,
  },
  statsSection: {
    flexDirection: 'row',
    padding: 16,
    gap: 12,
  },
  statCard: {
    flex: 1,
    backgroundColor: '#fff',
    borderRadius: 12,
    padding: 12,
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  statIcon: {
    fontSize: 24,
    marginBottom: 4,
  },
  statLabel: {
    fontSize: 11,
    color: '#999',
    marginBottom: 4,
  },
  statValue: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#007AFF',
  },
  section: {
    padding: 20,
    paddingTop: 16,
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#1a1a1a',
    marginBottom: 4,
  },
  sectionSubtitle: {
    fontSize: 12,
    color: '#999',
    marginBottom: 16,
  },
  emptyText: {
    textAlign: 'center',
    color: '#999',
    paddingVertical: 20,
  },
  skillCard: {
    backgroundColor: '#fff',
    borderRadius: 12,
    padding: 16,
    marginBottom: 12,
    borderLeftWidth: 4,
    borderLeftColor: '#007AFF',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 2,
  },
  skillHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 12,
  },
  skillName: {
    fontSize: 16,
    fontWeight: '600',
    color: '#1a1a1a',
  },
  skillScore: {
    fontSize: 14,
    fontWeight: 'bold',
    color: '#007AFF',
  },
  progressBarContainer: {
    height: 8,
    backgroundColor: '#e0e0e0',
    borderRadius: 4,
    overflow: 'hidden',
    marginBottom: 12,
  },
  progressBarFill: {
    height: 8,
    backgroundColor: '#007AFF',
  },
  skillInfo: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    paddingTop: 12,
    borderTopWidth: 1,
    borderTopColor: '#f0f0f0',
  },
  infoItem: {
    alignItems: 'center',
  },
  infoLabel: {
    fontSize: 11,
    color: '#999',
    marginBottom: 4,
  },
  infoValue: {
    fontSize: 14,
    fontWeight: '600',
    color: '#1a1a1a',
  },
  gapWarning: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 12,
    paddingTop: 12,
    borderTopWidth: 1,
    borderTopColor: '#ffe0e0',
    backgroundColor: '#fff5f5',
    padding: 8,
    borderRadius: 6,
  },
  gapIcon: {
    fontSize: 16,
    marginRight: 8,
  },
  gapText: {
    fontSize: 12,
    color: '#d9534f',
  },
  badgesContainer: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 12,
  },
  badge: {
    backgroundColor: '#fff',
    borderRadius: 12,
    padding: 16,
    alignItems: 'center',
    width: '48%',
    borderWidth: 2,
    borderColor: '#ffd700',
  },
  badgeIcon: {
    fontSize: 32,
    marginBottom: 8,
  },
  badgeLabel: {
    fontSize: 12,
    color: '#1a1a1a',
    textAlign: 'center',
    fontWeight: '600',
  },
  activityBox: {
    backgroundColor: '#fff',
    borderRadius: 12,
    padding: 16,
    marginBottom: 12,
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  activityLabel: {
    fontSize: 14,
    color: '#666',
  },
  activityDate: {
    fontSize: 14,
    fontWeight: '600',
    color: '#007AFF',
  },
  logoutButton: {
    marginHorizontal: 20,
    paddingVertical: 12,
    backgroundColor: '#f0f0f0',
    borderRadius: 8,
    alignItems: 'center',
    marginBottom: 20,
  },
  logoutButtonText: {
    fontSize: 14,
    fontWeight: '600',
    color: '#d9534f',
  },
});