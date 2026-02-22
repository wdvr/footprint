package com.footprintmaps.android.ui.screens.friends

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.footprintmaps.android.data.remote.dto.FriendDto
import com.footprintmaps.android.data.repository.FriendsRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

data class FriendsUiState(
    val friends: List<FriendDto> = emptyList(),
    val isLoading: Boolean = false,
    val error: String? = null
)

@HiltViewModel
class FriendsViewModel @Inject constructor(
    private val friendsRepository: FriendsRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(FriendsUiState())
    val uiState: StateFlow<FriendsUiState> = _uiState.asStateFlow()

    init {
        loadFriends()
    }

    fun loadFriends() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true)
            friendsRepository.getFriends().fold(
                onSuccess = { friends ->
                    _uiState.value = _uiState.value.copy(friends = friends, isLoading = false)
                },
                onFailure = { error ->
                    _uiState.value = _uiState.value.copy(error = error.message, isLoading = false)
                }
            )
        }
    }
}
