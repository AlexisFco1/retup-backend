import React from 'react';

export const AuthContext = React.createContext({
  signIn: async () => {},
  signUp: async () => {},
  signOut: async () => {},
});