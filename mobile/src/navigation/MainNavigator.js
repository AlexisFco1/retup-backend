import React from 'react';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { createNativeStackNavigator } from '@react-navigation/stack';
import { Text, View } from 'react-native';

import HomeScreen from '../screens/home/HomeScreen';
import PillScreen from '../screens/pill/PillScreen';
import ProfileScreen from '../screens/profile/ProfileScreen';
import LeaderboardScreen from '../screens/leaderboard/LeaderboardScreen';

const Tab = createBottomTabNavigator();
const Stack = createNativeStackNavigator();

function HomeStack() {
  return (
    <Stack.Navigator screenOptions={{ headerShown: false }}>
      <Stack.Screen name="HomeScreen" component={HomeScreen} />
    </Stack.Navigator>
  );
}

function PillStack() {
  return (
    <Stack.Navigator screenOptions={{ headerShown: false }}>
      <Stack.Screen name="PillScreen" component={PillScreen} />
    </Stack.Navigator>
  );
}

function ProfileStack() {
  return (
    <Stack.Navigator screenOptions={{ headerShown: false }}>
      <Stack.Screen name="ProfileScreen" component={ProfileScreen} />
    </Stack.Navigator>
  );
}

function LeaderboardStack() {
  return (
    <Stack.Navigator screenOptions={{ headerShown: false }}>
      <Stack.Screen name="LeaderboardScreen" component={LeaderboardScreen} />
    </Stack.Navigator>
  );
}

export default function MainNavigator() {
  return (
    <Tab.Navigator
      screenOptions={({ route }) => ({
        headerShown: false,
        tabBarActiveTintColor: '#007AFF',
        tabBarInactiveTintColor: '#999',
        tabBarStyle: {
          backgroundColor: '#fff',
          borderTopColor: '#e0e0e0',
          paddingBottom: 8,
          paddingTop: 8,
          height: 60,
        },
        tabBarLabel: ({ focused, color }) => {
          let label = '';
          if (route.name === 'Home') label = 'Inicio';
          else if (route.name === 'Pill') label = 'Píldora';
          else if (route.name === 'Profile') label = 'Perfil';
          else if (route.name === 'Leaderboard') label = 'Ranking';

          return (
            <Text
              style={{
                color: color,
                fontSize: 11,
                fontWeight: '600',
                marginTop: 4,
              }}
            >
              {label}
            </Text>
          );
        },
        tabBarIcon: ({ focused, color, size }) => {
          let icon = '';
          if (route.name === 'Home') icon = '🏠';
          else if (route.name === 'Pill') icon = '🎯';
          else if (route.name === 'Profile') icon = '📊';
          else if (route.name === 'Leaderboard') icon = '🏆';

          return (
            <Text
              style={{
                fontSize: size + 8,
              }}
            >
              {icon}
            </Text>
          );
        },
      })}
    >
      <Tab.Screen name="Home" component={HomeStack} />
      <Tab.Screen name="Pill" component={PillStack} />
      <Tab.Screen name="Profile" component={ProfileStack} />
      <Tab.Screen name="Leaderboard" component={LeaderboardStack} />
    </Tab.Navigator>
  );
}