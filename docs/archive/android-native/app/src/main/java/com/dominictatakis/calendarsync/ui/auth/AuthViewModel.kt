package com.dominictatakis.calendarsync.ui.auth

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.dominictatakis.calendarsync.data.model.AppUser
import com.dominictatakis.calendarsync.data.repository.SupabaseRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class AuthViewModel @Inject constructor(
    private val repo: SupabaseRepository,
) : ViewModel() {

    private val _isAuthenticated = MutableStateFlow(false)
    val isAuthenticated: StateFlow<Boolean> = _isAuthenticated

    private val _currentUser = MutableStateFlow<AppUser?>(null)
    val currentUser: StateFlow<AppUser?> = _currentUser

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading

    private val _error = MutableStateFlow<String?>(null)
    val error: StateFlow<String?> = _error

    init {
        viewModelScope.launch {
            val user = repo.getCurrentUser()
            if (user != null) {
                _currentUser.value = user
                _isAuthenticated.value = true
            }
        }
    }

    fun sendOTP(email: String) {
        viewModelScope.launch {
            _isLoading.value = true
            _error.value = null
            try {
                repo.sendOTP(email)
            } catch (e: Exception) {
                _error.value = e.message
            } finally {
                _isLoading.value = false
            }
        }
    }

    fun verifyOTP(email: String, token: String) {
        viewModelScope.launch {
            _isLoading.value = true
            _error.value = null
            try {
                val user = repo.verifyOTP(email, token)
                _currentUser.value = user
                _isAuthenticated.value = true
            } catch (e: Exception) {
                _error.value = e.message
            } finally {
                _isLoading.value = false
            }
        }
    }

    fun signInWithGoogle(idToken: String, accessToken: String) {
        viewModelScope.launch {
            _isLoading.value = true
            _error.value = null
            try {
                val user = repo.signInWithGoogleIdToken(idToken, accessToken)
                _currentUser.value = user
                _isAuthenticated.value = true
            } catch (e: Exception) {
                _error.value = e.message
            } finally {
                _isLoading.value = false
            }
        }
    }

    fun signOut() {
        viewModelScope.launch {
            repo.signOut()
            _currentUser.value = null
            _isAuthenticated.value = false
        }
    }

    fun clearError() { _error.value = null }
}
