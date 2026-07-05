package com.dominictatakis.calendarsync.ui

import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.DateRange
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.dominictatakis.calendarsync.ui.auth.AuthViewModel
import com.dominictatakis.calendarsync.ui.auth.SignInScreen
import com.dominictatakis.calendarsync.ui.auth.VerifyScreen
import com.dominictatakis.calendarsync.ui.calendar.CalendarScreen
import com.dominictatakis.calendarsync.ui.friends.FriendsScreen
import com.dominictatakis.calendarsync.ui.settings.SettingsScreen

sealed class Screen(val route: String, val title: String, val icon: ImageVector) {
    data object Calendar : Screen("calendar", "Calendar", Icons.Default.DateRange)
    data object Friends : Screen("friends", "Friends", Icons.Default.Person)
    data object Settings : Screen("settings", "Settings", Icons.Default.Settings)
}

private val tabs = listOf(Screen.Calendar, Screen.Friends, Screen.Settings)

@Composable
fun CalendarSyncNavHost() {
    val authViewModel: AuthViewModel = hiltViewModel()
    val isAuthenticated by authViewModel.isAuthenticated.collectAsState()
    val navController = rememberNavController()

    if (!isAuthenticated) {
        AuthNavHost(authViewModel)
    } else {
        MainScaffold(navController, authViewModel)
    }
}

@Composable
private fun AuthNavHost(authViewModel: AuthViewModel) {
    val navController = rememberNavController()
    NavHost(navController, startDestination = "sign-in") {
        composable("sign-in") { SignInScreen(authViewModel, navController) }
        composable("verify/{email}") { backStackEntry ->
            val email = backStackEntry.arguments?.getString("email") ?: ""
            VerifyScreen(authViewModel, email, navController)
        }
    }
}

@Composable
private fun MainScaffold(navController: NavHostController, authViewModel: AuthViewModel) {
    val currentEntry by navController.currentBackStackEntryAsState()
    val currentRoute = currentEntry?.destination?.route

    Scaffold(
        bottomBar = {
            NavigationBar {
                tabs.forEach { screen ->
                    NavigationBarItem(
                        icon = { Icon(screen.icon, contentDescription = screen.title) },
                        label = { Text(screen.title) },
                        selected = currentRoute == screen.route,
                        onClick = {
                            navController.navigate(screen.route) {
                                popUpTo(navController.graph.startDestinationId) { saveState = true }
                                launchSingleTop = true
                                restoreState = true
                            }
                        }
                    )
                }
            }
        }
    ) { padding ->
        NavHost(navController, startDestination = Screen.Calendar.route, Modifier.padding(padding)) {
            composable(Screen.Calendar.route) { CalendarScreen() }
            composable(Screen.Friends.route) { FriendsScreen() }
            composable(Screen.Settings.route) { SettingsScreen(authViewModel) }
        }
    }
}
