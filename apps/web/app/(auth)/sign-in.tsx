import React, { useState } from 'react';
import {
  View, Text, TextInput, TouchableOpacity, StyleSheet,
  KeyboardAvoidingView, Platform, ActivityIndicator,
} from 'react-native';
import { useRouter } from 'expo-router';
import { useAuth } from '../../src/contexts/AuthContext';
import { colors, radius, shadow } from '../../src/theme';

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
        <View style={styles.card}>
          <View style={styles.branding}>
            <View style={styles.logoBadge}>
              <Text style={styles.logoEmoji}>📅</Text>
            </View>
            <Text style={styles.title}>CalendarSync</Text>
            <Text style={styles.subtitle}>
              One calendar for you and your friends.{'\n'}See who's free, plan together.
            </Text>
          </View>

          <View style={styles.form}>
            <Text style={styles.inputLabel}>Email address</Text>
            <TextInput
              style={styles.input}
              placeholder="you@example.com"
              placeholderTextColor={colors.inkTertiary}
              value={email}
              onChangeText={setEmail}
              keyboardType="email-address"
              autoCapitalize="none"
              autoCorrect={false}
              autoComplete="email"
              onSubmitEditing={() => isValid && handleContinue()}
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
                <Text style={styles.buttonText}>Continue</Text>
              )}
            </TouchableOpacity>

            <Text style={styles.hint}>
              No password needed — we'll email you a 6-digit code.
            </Text>
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
    paddingVertical: 40,
    paddingHorizontal: 32,
    ...shadow.card,
  },
  branding: { alignItems: 'center', marginBottom: 32 },
  logoBadge: {
    width: 72,
    height: 72,
    borderRadius: 20,
    backgroundColor: colors.accentSoft,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 16,
  },
  logoEmoji: { fontSize: 36 },
  title: {
    fontSize: 28,
    fontWeight: '800',
    color: colors.ink,
    letterSpacing: -0.5,
  },
  subtitle: {
    fontSize: 15,
    color: colors.inkSecondary,
    marginTop: 8,
    textAlign: 'center',
    lineHeight: 22,
  },
  form: { gap: 12 },
  inputLabel: {
    fontSize: 13,
    fontWeight: '600',
    color: colors.inkSecondary,
    marginBottom: -4,
  },
  input: {
    borderWidth: 1,
    borderColor: colors.border,
    borderRadius: radius.md,
    padding: 16,
    fontSize: 16,
    backgroundColor: colors.background,
    color: colors.ink,
  },
  error: { color: colors.danger, fontSize: 13 },
  button: {
    backgroundColor: colors.accent,
    borderRadius: radius.md,
    padding: 16,
    alignItems: 'center',
    marginTop: 4,
  },
  buttonDisabled: { backgroundColor: '#C7CAF5' },
  buttonText: { color: '#fff', fontWeight: '700', fontSize: 16 },
  hint: {
    fontSize: 13,
    color: colors.inkTertiary,
    textAlign: 'center',
    marginTop: 8,
  },
});
