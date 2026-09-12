import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  SafeAreaView,
  ScrollView,
  ActivityIndicator,
  Alert,
  FlatList,
  RefreshControl,
} from 'react-native';
import { usersAPI, progressAPI } from '../../services/api';

export default function LeaderboardScreen() {
  const [leaderboard, setLeaderboard] = useState([]);
  const [userRank, setUserRank] = useState(null);
  const [currentUser, setCurrentUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);

  useEffect(() => {
    loadLeaderboard();
  }, []);

  const loadLeaderboard = async () => {
    try {
      setLoading(true);

      // Cargar perfil actual
      const userRes = await usersAPI.getProfile();
      setCurrentUser(userRes.data);

      // Cargar leaderboard
      const leaderRes = await progressAPI.getLeaderboard();
      setLeaderboard(leaderRes.data || []);

      // Encontrar la posición del usuario actual
      if (leaderRes.data) {
        const userPosition = leaderRes.data.findIndex(
          (user) => user.id === userRes.data.id
        );
        setUserRank(userPosition + 1);
      }
    } catch (error) {
      console.log('Error loading leaderboard:', error);
      Alert.alert('Error', 'No se pudo cargar el ranking');
    } finally {
      setLoading(false);
    }
  };

  const onRefresh = async () => {
    setRefreshing(true);
    await loadLeaderboard();
    setRefreshing(false);
  };

  const getMedalEmoji = (position) => {
    if (position === 1) return '🥇';
    if (position === 2) return '🥈';
    if (position === 3) return '🥉';
    return position.toString();
  };

  const isCurrentUser = (userId) => currentUser && userId === currentUser.id;

  if (loading) {
    return (
      <SafeAreaView style={styles.container}>
        <ActivityIndicator size="large" color="#007AFF" />
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={styles.container}>
      {/* Header */}
      <View style={styles.header}>
        <Text style={styles.title}>Ranking Global 🏆</Text>
        <Text style={styles.subtitle}>
          Los mejores desarrolladores de habilidades
        </Text>
      </View>

      {/* Tu Posición */}
      {userRank && (
        <View style={styles.userRankCard}>
          <View style={styles.userRankContent}>
            <Text style={styles.userRankLabel}>Tu Posición</Text>
            <View style={styles.userRankRow}>
              <Text style={styles.userRankPosition}>#{userRank}</Text>
              <Text style={styles.userRankXP}>
                {currentUser?.total_xp || 0} XP
              </Text>
            </View>
          </View>
          <View style={styles.userRankIcon}>
            <Text style={styles.userRankIconText}>
              {getMedalEmoji(userRank)}
            </Text>
          </View>
        </View>
      )}

      {/* Leaderboard List */}
      <FlatList
        data={leaderboard}
        keyExtractor={(item, index) => index.toString()}
        renderItem={({ item, index }) => (
          <View
            style={[
              styles.rankItem,
              isCurrentUser(item.id) && styles.rankItemHighlight,
            ]}
          >
            {/* Posición */}
            <View style={styles.positionBadge}>
              <Text style={styles.positionText}>
                {getMedalEmoji(index + 1)}
              </Text>
            </View>

            {/* Info del usuario */}
            <View style={styles.userDetails}>
              <Text style={styles.userName}>
                {item.anonymous_name ||
                  item.email?.split('@')[0] ||
                  `Usuario ${index + 1}`}
                {isCurrentUser(item.id) && ' (Tú)'}
              </Text>
              <Text style={styles.userLevel}>
                Nivel {Math.floor((item.xp || 0) / 100) + 1}
              </Text>
            </View>

            {/* XP */}
            <View style={styles.xpContainer}>
              <Text style={styles.xpValue}>{item.xp || 0}</Text>
              <Text style={styles.xpLabel}>XP</Text>
            </View>
          </View>
        )}
        scrollEnabled={false}
        refreshControl={
          <RefreshControl refreshing={refreshing} onRefresh={onRefresh} />
        }
      />

      {/* Info adicional */}
      <View style={styles.infoSection}>
        <View style={styles.infoBox}>
          <Text style={styles.infoTitle}>¿Cómo subir en el ranking?</Text>
          <Text style={styles.infoText}>
            • Completa píldoras diariamente (+10 XP cada una)
          </Text>
          <Text style={styles.infoText}>
            • Mantén una racha activa (+bonus XP)
          </Text>
          <Text style={styles.infoText}>
            • Desarrolla múltiples habilidades
          </Text>
          <Text style={styles.infoText}>
            • Participa en nominaciones colaborativas
          </Text>
        </View>
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
    backgroundColor: '#fff',
    padding: 20,
    borderBottomWidth: 1,
    borderBottomColor: '#e0e0e0',
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#1a1a1a',
    marginBottom: 4,
  },
  subtitle: {
    fontSize: 13,
    color: '#999',
  },
  userRankCard: {
    margin: 16,
    marginBottom: 0,
    backgroundColor: '#fff',
    borderRadius: 12,
    padding: 16,
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    borderLeftWidth: 4,
    borderLeftColor: '#007AFF',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  userRankContent: {
    flex: 1,
  },
  userRankLabel: {
    fontSize: 12,
    color: '#999',
    marginBottom: 8,
  },
  userRankRow: {
    flexDirection: 'row',
    alignItems: 'baseline',
    gap: 12,
  },
  userRankPosition: {
    fontSize: 28,
    fontWeight: 'bold',
    color: '#007AFF',
  },
  userRankXP: {
    fontSize: 16,
    fontWeight: '600',
    color: '#1a1a1a',
  },
  userRankIcon: {
    width: 60,
    height: 60,
    borderRadius: 30,
    backgroundColor: '#f0f8ff',
    justifyContent: 'center',
    alignItems: 'center',
  },
  userRankIconText: {
    fontSize: 32,
  },
  rankItem: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#fff',
    marginHorizontal: 16,
    marginVertical: 6,
    paddingVertical: 12,
    paddingHorizontal: 12,
    borderRadius: 8,
    borderBottomWidth: 1,
    borderBottomColor: '#f0f0f0',
  },
  rankItemHighlight: {
    backgroundColor: '#f0f8ff',
    borderLeftWidth: 3,
    borderLeftColor: '#007AFF',
  },
  positionBadge: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: '#f0f0f0',
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 12,
  },
  positionText: {
    fontSize: 20,
  },
  userDetails: {
    flex: 1,
  },
  userName: {
    fontSize: 14,
    fontWeight: '600',
    color: '#1a1a1a',
    marginBottom: 2,
  },
  userLevel: {
    fontSize: 12,
    color: '#999',
  },
  xpContainer: {
    alignItems: 'center',
  },
  xpValue: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#007AFF',
  },
  xpLabel: {
    fontSize: 10,
    color: '#999',
  },
  infoSection: {
    padding: 16,
    paddingTop: 24,
  },
  infoBox: {
    backgroundColor: '#fff',
    borderRadius: 12,
    padding: 16,
    borderLeftWidth: 4,
    borderLeftColor: '#34C759',
  },
  infoTitle: {
    fontSize: 14,
    fontWeight: '600',
    color: '#1a1a1a',
    marginBottom: 8,
  },
  infoText: {
    fontSize: 12,
    color: '#666',
    lineHeight: 18,
    marginBottom: 4,
  },
});