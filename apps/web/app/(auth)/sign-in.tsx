import React, { useState } from 'react';
import {
  View, Text, TextInput, TouchableOpacity, StyleSheet,
  KeyboardAvoidingView, Platform, ActivityIndicator, Alert,
} from 'react-native';
import { useRouter } from 'expo-router';
import { useAuth } from '../../src/contexts/AuthContext';

export default function SignInScreen() {
  const [email, setEmail] = useState('');
  const { sendOTPEmail, isLoading, error } = useAuth();
  const router = useRouter();

  const isValid = email.includes('@') && email.includes('.');

  const handleContinue = async () => {
    try {
      await sendOTPEmail(email);
      router.push({ pathname: '/(auth)/verify', params: { email } });
    } catch {}
  };

  return (
    <KeyboardAvoidingView
      style={styles.container}
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
    >
      <View style={styles.inner}>
        <View style={styles.branding}>
          <Text style={styles.icon}>📅</Text>
          <Text style={styles.title}>CalendarSync</Text>
          <Text style={styles.subtitle}>Plan together, effortlessly.</Text>
        </View>

        <View style={styles.form}>
          <TextInput
            style={styles.input}
            placeholder="Email address"
            placeholderTextColor="#999"
            value={email}
            onChangeText={setEmail}
            keyboardType="email-address"
            autoCapitalize="none"
            autoCorrect={false}
            autoComplete="email"
          />

          {error ? <Text style={styles.error}>{error}</Text> : null}

          <TouchableOpacity
            style={[styles.button, !isValid && styles.buttonDisabled]}
            onPress={handleContinue}
            disabled={!isValid || isLoading}
          >
            {isLoading ? (
              <ActivityIndicator color="#fff" />
            ) : (
              <Text style={styles.buttonText}>Continue with Email</Text>
            )}
          </TouchableOpacity>
        </View>
      </View>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#fff' },
  inner: { flex: 1, justifyContent: 'center', paddingHorizontal: 24 },
  branding: { alignItems: 'center', marginBottom: 40 },
  icon: { fontSize: 64, marginBottom: 8 },
  title: { fontSize: 32, fontWeight: '700', color: '#111' },
  subtitle: { fontSize: 16, color: '#666', marginTop: 4 },
  form: { gap: 12 },
  input: {
    borderWidth: 1, borderColor: '#e0e0e0', borderRadius: 12,
    padding: 16, fontSize: 16, backgroundColor: '#fafafa', color: '#111',
  },
  error: { color: '#e53e3e', fontSize: 13 },
  button: {
    backgroundColor: '#007AFF', borderRadius: 12,
    padding: 16, alignItems: 'center',
  },
  buttonDisabled: { backgroundColor: '#aaa' },
  buttonText: { color: '#fff', fontWeight: '600', fontSize: 16 },
});
