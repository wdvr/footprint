package com.footprintmaps.android.ui.screens.feedback

import android.content.Context
import android.os.Build
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.footprintmaps.android.data.repository.FriendsRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

data class FeedbackUiState(
    val selectedType: String = "bug",
    val title: String = "",
    val message: String = "",
    val isSubmitting: Boolean = false,
    val isSubmitted: Boolean = false,
    val error: String? = null
)

@HiltViewModel
class FeedbackViewModel @Inject constructor(
    private val friendsRepository: FriendsRepository,
    @ApplicationContext private val context: Context
) : ViewModel() {

    private val _uiState = MutableStateFlow(FeedbackUiState())
    val uiState: StateFlow<FeedbackUiState> = _uiState.asStateFlow()

    fun setType(type: String) {
        _uiState.value = _uiState.value.copy(selectedType = type)
    }

    fun setTitle(title: String) {
        _uiState.value = _uiState.value.copy(title = title)
    }

    fun setMessage(message: String) {
        _uiState.value = _uiState.value.copy(message = message)
    }

    fun submit() {
        if (_uiState.value.message.isBlank()) return

        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isSubmitting = true, error = null)

            val fullMessage = buildString {
                if (_uiState.value.title.isNotBlank()) {
                    appendLine("Title: ${_uiState.value.title}")
                    appendLine()
                }
                append(_uiState.value.message)
                appendLine()
                appendLine()
                appendLine("--- Device Info ---")
                appendLine("Device: ${Build.MANUFACTURER} ${Build.MODEL}")
                appendLine("Android: ${Build.VERSION.RELEASE} (SDK ${Build.VERSION.SDK_INT})")
                try {
                    val packageInfo = context.packageManager.getPackageInfo(context.packageName, 0)
                    appendLine("App Version: ${packageInfo.versionName}")
                } catch (_: Exception) {}
            }

            friendsRepository.submitFeedback(
                type = _uiState.value.selectedType,
                message = fullMessage
            ).fold(
                onSuccess = {
                    _uiState.value = _uiState.value.copy(isSubmitting = false, isSubmitted = true)
                },
                onFailure = { error ->
                    _uiState.value = _uiState.value.copy(
                        isSubmitting = false,
                        error = error.message
                    )
                }
            )
        }
    }

    fun reset() {
        _uiState.value = FeedbackUiState()
    }
}
