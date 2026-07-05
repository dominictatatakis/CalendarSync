import React, { useState } from 'react';
import { View, Text, TouchableOpacity, StyleSheet, useWindowDimensions, Platform } from 'react-native';
import { Slot, useRouter, useSegments } from 'expo-router';
import { useFriends } from '../../src/contexts/FriendsContext';

const BREAKPOINT = 768;

const NAV_ITEMS = [
  { key: 'calendar', label: 'Calendar', icon: '\u{1F4C5}', route: '/(tabs)/calendar' },
  { key: 'friends', label: 'Friends', icon: '\u{1F465}', route: '/(tabs)/friends' },
  { key: 'settings', label: 'Settings', icon: '\u2699\uFE0F', route: '/(tabs)/settings' },
] as const;

export default function TabLayout() {
  const { width } = useWindowDimensions();
  const isDesktop = width >= BREAKPOINT;
  const { invites, pendingRequests } = useFriends();
  const badge = invites.length + pendingRequests.length;
  const segments = useSegments();
  const router = useRouter();
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);

  const activeTab = segments[1] ?? 'calendar';

  const navigateTo = (route: string) => {
    router.push(route as any);
    setMobileMenuOpen(false);
  };

  if (isDesktop) {
    return (
      <View style={styles.desktopRoot}>
        {/* Sidebar */}
        <View style={styles.sidebar}>
          <Text style={styles.sidebarLogo}>CalendarSync</Text>
          {NAV_ITEMS.map(item => {
            const isActive = activeTab === item.key;
            const showBadge = item.key === 'friends' && badge > 0;
            return (
              <TouchableOpacity
                key={item.key}
                style={[styles.sidebarItem, isActive && styles.sidebarItemActive]}
                onPress={() => navigateTo(item.route)}
              >
                <Text style={styles.sidebarIcon}>{item.icon}</Text>
                <Text style={[styles.sidebarLabel, isActive && styles.sidebarLabelActive]}>
                  {item.label}
                </Text>
                {showBadge && (
                  <View style={styles.sidebarBadge}>
                    <Text style={styles.sidebarBadgeText}>{badge}</Text>
                  </View>
                )}
              </TouchableOpacity>
            );
          })}
        </View>

        {/* Main content */}
        <View style={styles.desktopContent}>
          <Slot />
        </View>
      </View>
    );
  }

  // Mobile layout: bottom tabs
  return (
    <View style={styles.mobileRoot}>
      <View style={styles.mobileContent}>
        <Slot />
      </View>

      {/* Bottom tab bar */}
      <View style={styles.bottomBar}>
        {NAV_ITEMS.map(item => {
          const isActive = activeTab === item.key;
          const showBadge = item.key === 'friends' && badge > 0;
          return (
            <TouchableOpacity
              key={item.key}
              style={styles.bottomTab}
              onPress={() => navigateTo(item.route)}
            >
              <Text style={styles.bottomTabIcon}>{item.icon}</Text>
              <Text style={[styles.bottomTabLabel, isActive && styles.bottomTabLabelActive]}>
                {item.label}
              </Text>
              {showBadge && (
                <View style={styles.bottomBadge}>
                  <Text style={styles.bottomBadgeText}>{badge}</Text>
                </View>
              )}
            </TouchableOpacity>
          );
        })}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  // Desktop
  desktopRoot: {
    flex: 1,
    flexDirection: 'row',
    backgroundColor: '#f5f5f7',
  },
  sidebar: {
    width: 220,
    backgroundColor: '#1c1c1e',
    paddingTop: 24,
    paddingHorizontal: 12,
  },
  sidebarLogo: {
    color: '#fff',
    fontSize: 18,
    fontWeight: '700',
    paddingHorizontal: 12,
    paddingBottom: 24,
    paddingTop: 8,
    letterSpacing: -0.3,
  },
  sidebarItem: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 10,
    paddingHorizontal: 12,
    borderRadius: 8,
    marginBottom: 2,
  },
  sidebarItemActive: {
    backgroundColor: 'rgba(255,255,255,0.12)',
  },
  sidebarIcon: {
    fontSize: 18,
    marginRight: 10,
  },
  sidebarLabel: {
    color: 'rgba(255,255,255,0.65)',
    fontSize: 14,
    fontWeight: '500',
    flex: 1,
  },
  sidebarLabelActive: {
    color: '#fff',
    fontWeight: '600',
  },
  sidebarBadge: {
    backgroundColor: '#ff3b30',
    borderRadius: 10,
    minWidth: 20,
    height: 20,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 6,
  },
  sidebarBadgeText: {
    color: '#fff',
    fontSize: 11,
    fontWeight: '700',
  },
  desktopContent: {
    flex: 1,
  },

  // Mobile
  mobileRoot: {
    flex: 1,
    backgroundColor: '#f5f5f7',
  },
  mobileContent: {
    flex: 1,
  },
  bottomBar: {
    flexDirection: 'row',
    backgroundColor: '#fff',
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: '#d1d1d6',
    paddingBottom: Platform.OS === 'web' ? 8 : 20,
    paddingTop: 6,
  },
  bottomTab: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 4,
    position: 'relative',
  },
  bottomTabIcon: {
    fontSize: 22,
  },
  bottomTabLabel: {
    fontSize: 10,
    color: '#8e8e93',
    marginTop: 2,
    fontWeight: '500',
  },
  bottomTabLabelActive: {
    color: '#007AFF',
    fontWeight: '600',
  },
  bottomBadge: {
    position: 'absolute',
    top: 0,
    right: '25%',
    backgroundColor: '#ff3b30',
    borderRadius: 8,
    minWidth: 16,
    height: 16,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 4,
  },
  bottomBadgeText: {
    color: '#fff',
    fontSize: 10,
    fontWeight: '700',
  },
});
