import React, { useState, useRef } from 'react';
import {
  View, Text, TextInput, TouchableOpacity, StyleSheet,
  KeyboardAvoidingView, Platform, ActivityIndicator,
} from 'react-native';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { useAuth } from '../../src/contexts/AuthContext';

export default function VerifyScreen() {
  const { email } = useLocalSearchParams<{ email: string }>();
  const [token, setToken] = useState('');
  const { verifyOTPCode, isLoading, error } = useAuth();
  const router = useRouter();

  const handleVerify = async () => {
    try {
      await verifyOTPCode(email, token.trim());
      // Navigation handled by RootLayoutNav
    } catch {}
  };

  return (
    <KeyboardAvoidingView
      style={styles.container}
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
    >
      <View style={styles.inner}>
        <TouchableOpacity style={styles.back} onPress={() => router.back()}>
          <Text style={styles.backText}>← Back</Text>
        </TouchableOpacity>

        <View style={styles.header}>
          <Text style={styles.icon}>✉️</Text>
          <Text style={styles.title}>Check your email</Text>
          <Text style={styles.subtitle}>
            We sent a 6-digit code to{'\n'}<Text style={styles.email}>{email}</Text>
          </Text>
        </View>

        <View style={styles.form}>
          <TextInput
            style={styles.input}
            placeholder="000000"
            placeholderTextColor="#bbb"
            value={token}
            onChangeText={setToken}
            keyboardType="number-pad"
            maxLength={6}
            textAlign="center"
          />

          {error ? <Text style={styles.error}>{error}</Text> : null}

          <TouchableOpacity
            style={[styles.button, token.length < 6 && styles.buttonDisabled]}
            onPress={handleVerify}
            disabled={token.length < 6 || isLoading}
          >
            {isLoading ? (
              <ActivityIndicator color="#fff" />
            ) : (
              <Text style={styles.buttonText}>Verify</Text>
            )}
          </TouchableOpacity>
        </View>
      </View>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#fff' },
  inner: { flex: 1, paddingHorizontal: 24, paddingTop: 60 },
  back: { marginBottom: 32 },
  backText: { color: '#007AFF', fontSize: 16 },
  header: { alignItems: 'center', marginBottom: 40 },
  icon: { fontSize: 56, marginBottom: 12 },
  title: { fontSize: 26, fontWeight: '700', color: '#111' },
  subtitle: { fontSize: 15, color: '#666', marginTop: 8, textAlign: 'center', lineHeight: 22 },
  email: { fontWeight: '600', color: '#111' },
  form: { gap: 12 },
  input: {
    borderWidth: 1, borderColor: '#e0e0e0', borderRadius: 12,
    padding: 20, fontSize: 32, fontWeight: '700',
    letterSpacing: 8, backgroundColor: '#fafafa', color: '#111',
  },
  error: { color: '#e53e3e', fontSize: 13, textAlign: 'center' },
  button: {
    backgroundColor: '#007AFF', borderRadius: 12,
    padding: 16, alignItems: 'center',
  },
  buttonDisabled: { backgroundColor: '#aaa' },
  buttonText: { color: '#fff', fontWeight: '600', fontSize: 16 },
});
