import React, { useReducer, useEffect } from 'react';
import AsyncStorage from '@react-native-async-storage/async-storage';
// import * as SplashScreen from 'expo-splash-screen'; // ← Comentado para evitar conflicto con Expo 57
import { AuthContext } from './src/context/AuthContext';
import { authAPI, storeToken, removeToken } from './src/services/api';
import LoginScreen from './src/screens/auth/LoginScreen';
import RegisterScreen from './src/screens/auth/RegisterScreen';
import MainNavigator from './src/navigation/MainNavigator';
import { NavigationContainer } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';

const Stack = createNativeStackNavigator();

// Mantener el splash screen visible mientras se carga
// SplashScreen.preventAutoHideAsync(); // ← Comentado

// Estados iniciales
const initialState = {
  isLoading: true,
  isSignout: false,
  userToken: null,
};

// Reducer para manejar acciones de autenticación
const authReducer = (state, action) => {
  switch (action.type) {
    case 'RESTORE_TOKEN':
      return {
        ...state,
        userToken: action.payload,
        isLoading: false,
      };
    case 'SIGN_IN':
      return {
        ...state,
        isSignout: false,
        userToken: action.payload,
      };
    case 'SIGN_UP':
      return {
        ...state,
        isSignout: false,
        userToken: action.payload,
      };
    case 'SIGN_OUT':
      return {
        ...state,
        isSignout: true,
        userToken: null,
      };
    default:
      return state;
  }
};

export default function App() {
  const [state, dispatch] = useReducer(authReducer, initialState);

  // Restaurar token al iniciar la app
  useEffect(() => {
    const bootstrapAsync = async () => {
      try {
        const token = await AsyncStorage.getItem('userToken');
        if (token) {
          dispatch({ type: 'RESTORE_TOKEN', payload: token });
        } else {
          dispatch({ type: 'RESTORE_TOKEN', payload: null });
        }
      } catch (e) {
        console.log('Failed to restore token', e);
        dispatch({ type: 'RESTORE_TOKEN', payload: null });
      }
    };

    bootstrapAsync();
  }, []);

  // Ocultar splash screen cuando termine de cargar
  useEffect(() => {
    if (!state.isLoading) {
      // SplashScreen.hideAsync(); // ← Comentado
    }
  }, [state.isLoading]);

  // Contexto de autenticación
  const authContext = {
    signIn: async (email, password) => {
      try {
        const response = await authAPI.login(email, password);
        const token = response.data.token;

        // Guardar token
        await storeToken(token);
        dispatch({ type: 'SIGN_IN', payload: token });

        return { success: true };
      } catch (error) {
        console.log('Login error:', error.response?.data?.message || error.message);
        return {
          success: false,
          error: error.response?.data?.message || 'Error al iniciar sesión',
        };
      }
    },

    signUp: async (email, password) => {
      try {
        const response = await authAPI.register(email, password);
        const token = response.data.token;

        // Guardar token
        await storeToken(token);
        dispatch({ type: 'SIGN_UP', payload: token });

        return { success: true };
      } catch (error) {
        console.log('Register error:', error.response?.data?.message || error.message);
        return {
          success: false,
          error: error.response?.data?.message || 'Error al registrarse',
        };
      }
    },

    signOut: async () => {
      try {
        await authAPI.logout();
      } catch (error) {
        console.log('Logout error:', error);
      } finally {
        // Remover token incluso si falla el logout en el servidor
        await removeToken();
        dispatch({ type: 'SIGN_OUT' });
      }
    },
  };

  return (
    <AuthContext.Provider value={authContext}>
      <NavigationContainer>
        <Stack.Navigator
          screenOptions={{
            headerShown: false,
          }}
        >
          {state.isLoading ? (
            // Pantalla de carga
            <Stack.Screen
              name="Splash"
              component={() => null}
              options={{
                animationEnabled: false,
              }}
            />
          ) : state.userToken == null ? (
            // Pantallas de autenticación
            <Stack.Group
              screenOptions={{
                animationEnabled: false,
              }}
            >
              <Stack.Screen
                name="Login"
                component={LoginScreen}
                options={{
                  animationEnabled: false,
                }}
              />
              <Stack.Screen
                name="Register"
                component={RegisterScreen}
              />
            </Stack.Group>
          ) : (
            // Pantallas de la app autenticada
            <Stack.Screen
              name="Main"
              component={MainNavigator}
              options={{
                animationEnabled: false,
              }}
            />
          )}
        </Stack.Navigator>
      </NavigationContainer>
    </AuthContext.Provider>
  );
}