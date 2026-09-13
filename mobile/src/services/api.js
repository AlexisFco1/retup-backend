import axios from 'axios';
import AsyncStorage from '@react-native-async-storage/async-storage';

const API_BASE_URL = 'https://retup-backend.onrender.com/api';

// Crear instancia de axios
const axiosInstance = axios.create({
  baseURL: API_BASE_URL,
  timeout: 10000,
});

// Interceptor para agregar el token JWT en cada request
axiosInstance.interceptors.request.use(
  async (config) => {
    try {
      const token = await AsyncStorage.getItem('userToken');
      if (token) {
        config.headers.Authorization = `Bearer ${token}`;
      }
    } catch (error) {
      console.log('Error getting token from storage:', error);
    }
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

// Interceptor para manejar errores globales
axiosInstance.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      // Token expirado o inválido
      AsyncStorage.removeItem('userToken');
      // Aquí podrías redirigir a login
    }
    return Promise.reject(error);
  }
);

// ====== AUTH API ======
export const authAPI = {
  login: (email, password) =>
    axiosInstance.post('/auth/login', { email, password }),

  register: (email, password) =>
    axiosInstance.post('/auth/register', { email, password }),

  logout: () =>
    axiosInstance.post('/auth/logout'),

  refreshToken: () =>
    axiosInstance.post('/auth/refresh'),
};

// ====== USERS API ======
export const usersAPI = {
  // Obtener perfil del usuario autenticado
  getProfile: () =>
    axiosInstance.get('/users/profile'),

  // Actualizar perfil del usuario
  updateProfile: (data) =>
    axiosInstance.put('/users/profile', data),

  // Obtener todas las habilidades de un usuario
  getUserSkills: (userId) =>
    axiosInstance.get(`/users/${userId}/skills`),

  // Obtener estadísticas del usuario
  getUserStats: (userId) =>
    axiosInstance.get(`/users/${userId}/stats`),

  // Actualizar nombre anónimo del usuario
  updateAnonymousName: (anonymousName) =>
    axiosInstance.put('/users/profile', { anonymous_name: anonymousName }),
};

// ====== RETOS API ======
export const retosAPI = {
  // Obtener todos los retos
  getAll: () =>
    axiosInstance.get('/retos'),

  // Obtener un reto específico
  getById: (retoId) =>
    axiosInstance.get(`/retos/${retoId}`),

  // Obtener retos activos del usuario
  getActive: () =>
    axiosInstance.get('/retos/active'),

  // Obtener detalles de un reto con sus píldoras
  getWithPills: (retoId) =>
    axiosInstance.get(`/retos/${retoId}/pills`),
};

// ====== PÍLDORAS API ======
export const pillorasAPI = {
  // Obtener todas las píldoras de un reto
  getByReto: (retoId) =>
    axiosInstance.get(`/pills/reto/${retoId}`),

  // Obtener la píldora del día para un reto
  getDailyPill: (retoId) =>
    axiosInstance.get(`/pills/reto/${retoId}/daily`),

  // Obtener una píldora específica
  getById: (pillId) =>
    axiosInstance.get(`/pills/${pillId}`),

  // Obtener todas las píldoras del usuario
  getUserPills: () =>
    axiosInstance.get('/pills/user'),

  // Obtener píldoras completadas
  getCompleted: () =>
    axiosInstance.get('/pills/completed'),
};

// ====== PROGRESS API ======
export const progressAPI = {
  // Obtener progreso general del usuario
  getUserProgress: (userId) =>
    axiosInstance.get(`/progress/user/${userId}`),

  // Completar una píldora
  completePill: (data) =>
    axiosInstance.post('/progress/complete-pill', data),

  // Obtener progreso en una habilidad específica
  getSkillProgress: (skillId) =>
    axiosInstance.get(`/progress/skill/${skillId}`),

  // Obtener historico de progreso
  getHistory: (userId, limit = 30) =>
    axiosInstance.get(`/progress/user/${userId}/history?limit=${limit}`),

  // Obtener leaderboard
  getLeaderboard: (limit = 50) =>
    axiosInstance.get(`/progress/leaderboard?limit=${limit}`),

  // Obtener leaderboard por habilidad
  getSkillLeaderboard: (skillId, limit = 50) =>
    axiosInstance.get(`/progress/leaderboard/skill/${skillId}?limit=${limit}`),
};

// ====== NOMINACIONES API ======
export const nominacionesAPI = {
  // Enviar una nominación
  submit: (data) =>
    axiosInstance.post('/nominations', data),

  // Obtener nominaciones recibidas por el usuario
  getReceived: () =>
    axiosInstance.get('/nominations/received'),

  // Obtener nominaciones enviadas por el usuario
  getSent: () =>
    axiosInstance.get('/nominations/sent'),

  // Obtener nominaciones por píldora
  getByPill: (pillId) =>
    axiosInstance.get(`/nominations/pill/${pillId}`),

  // Obtener nominaciones por habilidad
  getBySkill: (skillId) =>
    axiosInstance.get(`/nominations/skill/${skillId}`),
};

// ====== UTILS ======
export const storeToken = async (token) => {
  try {
    await AsyncStorage.setItem('userToken', token);
  } catch (error) {
    console.log('Error storing token:', error);
  }
};

export const getToken = async () => {
  try {
    return await AsyncStorage.getItem('userToken');
  } catch (error) {
    console.log('Error retrieving token:', error);
    return null;
  }
};

export const removeToken = async () => {
  try {
    await AsyncStorage.removeItem('userToken');
  } catch (error) {
    console.log('Error removing token:', error);
  }
};

export default axiosInstance;