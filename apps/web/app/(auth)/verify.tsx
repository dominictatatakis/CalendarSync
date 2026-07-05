import React, { useState } from 'react';
import {
  View, Text, TextInput, TouchableOpacity, StyleSheet,
  KeyboardAvoidingView, Platform, ActivityIndicator,
} from 'react-native';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { useAuth } from '../../src/contexts/AuthContext';
import { colors, radius, shadow } from '../../src/theme';

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
        <View style={styles.card}>
          <TouchableOpacity style={styles.back} onPress={() => router.back()}>
            <Text style={styles.backText}>← Back</Text>
          </TouchableOpacity>

          <View style={styles.header}>
            <View style={styles.logoBadge}>
              <Text style={styles.logoEmoji}>✉️</Text>
            </View>
            <Text style={styles.title}>Check your email</Text>
            <Text style={styles.subtitle}>
              We sent a 6-digit code to{'\n'}<Text style={styles.email}>{email}</Text>
            </Text>
          </View>

          <View style={styles.form}>
            <TextInput
              style={styles.input}
              placeholder="000000"
              placeholderTextColor={colors.inkTertiary}
              value={token}
              onChangeText={setToken}
              keyboardType="number-pad"
              maxLength={6}
              textAlign="center"
              onSubmitEditing={() => token.length === 6 && handleVerify()}
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
      </View>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  inner: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: 24,
  },
  card: {
    width: '100%',
    maxWidth: 420,
    backgroundColor: colors.surface,
    borderRadius: radius.xl,
    paddingVertical: 32,
    paddingHorizontal: 32,
    ...shadow.card,
  },
  back: { marginBottom: 16 },
  backText: { color: colors.accent, fontSize: 15, fontWeight: '600' },
  header: { alignItems: 'center', marginBottom: 28 },
  logoBadge: {
    width: 72,
    height: 72,
    borderRadius: 20,
    backgroundColor: colors.accentSoft,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 16,
  },
  logoEmoji: { fontSize: 34 },
  title: { fontSize: 24, fontWeight: '800', color: colors.ink, letterSpacing: -0.3 },
  subtitle: {
    fontSize: 15,
    color: colors.inkSecondary,
    marginTop: 8,
    textAlign: 'center',
    lineHeight: 22,
  },
  email: { fontWeight: '600', color: colors.ink },
  form: { gap: 12 },
  input: {
    borderWidth: 1,
    borderColor: colors.border,
    borderRadius: radius.md,
    padding: 18,
    fontSize: 30,
    fontWeight: '700',
    letterSpacing: 10,
    backgroundColor: colors.background,
    color: colors.ink,
  },
  error: { color: colors.danger, fontSize: 13, textAlign: 'center' },
  button: {
    backgroundColor: colors.accent,
    borderRadius: radius.md,
    padding: 16,
    alignItems: 'center',
    marginTop: 4,
  },
  buttonDisabled: { backgroundColor: '#C7CAF5' },
  buttonText: { color: '#fff', fontWeight: '700', fontSize: 16 },
});
