package com.dominictatakis.calendarsync.ui.friends

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.dominictatakis.calendarsync.data.model.Friend
import com.dominictatakis.calendarsync.data.model.Friendship
import com.dominictatakis.calendarsync.data.repository.SupabaseRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class FriendsViewModel @Inject constructor(
    private val repo: SupabaseRepository,
) : ViewModel() {

    private val _friends = MutableStateFlow<List<Friend>>(emptyList())
    val friends: StateFlow<List<Friend>> = _friends

    private val _pendingRequests = MutableStateFlow<List<Friendship>>(emptyList())
    val pendingRequests: StateFlow<List<Friendship>> = _pendingRequests

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading

    fun load() {
        viewModelScope.launch {
            val user = repo.getCurrentUser() ?: return@launch
            _isLoading.value = true
            try {
                _friends.value = repo.fetchFriends(user.id)
                _pendingRequests.value = repo.fetchPendingRequests(user.id)
            } catch (_: Exception) { }
            _isLoading.value = false
        }
    }

    fun addFriend(email: String) {
        viewModelScope.launch {
            val user = repo.getCurrentUser() ?: return@launch
            val target = repo.findUserByEmail(email) ?: return@launch
            try {
                repo.sendFriendRequest(user.id, target.id)
                load()
            } catch (_: Exception) { }
        }
    }

    fun acceptRequest(friendshipId: String) {
        viewModelScope.launch {
            try {
                repo.acceptFriendRequest(friendshipId)
                load()
            } catch (_: Exception) { }
        }
    }
}
