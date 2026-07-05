package com.dominictatakis.calendarsync.ui.friends

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.dominictatakis.calendarsync.data.model.Friend

@Composable
fun FriendsScreen(viewModel: FriendsViewModel = hiltViewModel()) {
    val friends by viewModel.friends.collectAsState()
    val pendingRequests by viewModel.pendingRequests.collectAsState()
    val isLoading by viewModel.isLoading.collectAsState()
    var addEmail by remember { mutableStateOf("") }

    LaunchedEffect(Unit) { viewModel.load() }

    LazyColumn(
        modifier = Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        // Add friend
        item {
            Text("Add a Friend", style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Spacer(Modifier.height(8.dp))
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(
                    value = addEmail,
                    onValueChange = { addEmail = it },
                    label = { Text("friend@example.com") },
                    modifier = Modifier.weight(1f),
                    singleLine = true,
                )
                Button(onClick = {
                    viewModel.addFriend(addEmail.trim())
                    addEmail = ""
                }) {
                    Text("Add")
                }
            }
        }

        // Pending requests
        if (pendingRequests.isNotEmpty()) {
            item {
                Spacer(Modifier.height(8.dp))
                Text("Friend Requests", style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            items(pendingRequests) { request ->
                Card(modifier = Modifier.fillMaxWidth()) {
                    Row(
                        modifier = Modifier.padding(12.dp).fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.SpaceBetween,
                    ) {
                        Text("Friend request from ${request.requesterId}", fontSize = 14.sp)
                        Button(onClick = { viewModel.acceptRequest(request.id) }, contentPadding = PaddingValues(horizontal = 12.dp, vertical = 4.dp)) {
                            Text("Accept", fontSize = 13.sp)
                        }
                    }
                }
            }
        }

        // Friends list
        item {
            Spacer(Modifier.height(8.dp))
            Text("Friends (${friends.size})", style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }

        if (isLoading) {
            item { CircularProgressIndicator(modifier = Modifier.padding(16.dp)) }
        } else if (friends.isEmpty()) {
            item {
                Text(
                    "No friends yet -- add someone above",
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    fontSize = 14.sp,
                    modifier = Modifier.padding(vertical = 12.dp),
                )
            }
        } else {
            items(friends) { friend ->
                FriendRow(friend)
            }
        }
    }
}

@Composable
private fun FriendRow(friend: Friend) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier.padding(12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Box(
                modifier = Modifier.size(42.dp).clip(CircleShape).background(MaterialTheme.colorScheme.primaryContainer),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = friend.user.displayName.take(1).uppercase(),
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onPrimaryContainer,
                )
            }
            Column {
                Text(friend.user.displayName, fontWeight = FontWeight.Medium)
                Text(friend.user.email, fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}
