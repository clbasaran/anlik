package com.celalbasaran.stripmate.ui.screen.guard

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.celalbasaran.stripmate.service.guard.AppGuardRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

sealed class GuardState {
    data object Loading : GuardState()
    data object Clear : GuardState()
    data class Banned(val reason: String) : GuardState()
    data class Suspended(val until: java.util.Date, val reason: String) : GuardState()
    data class Maintenance(val message: String) : GuardState()
}

@HiltViewModel
class GuardViewModel @Inject constructor(
    private val guardRepository: AppGuardRepository
) : ViewModel() {

    private val _guardState = MutableStateFlow<GuardState>(GuardState.Loading)
    val guardState: StateFlow<GuardState> = _guardState.asStateFlow()

    init {
        checkGuard()
    }

    fun checkGuard(forceRefresh: Boolean = false) {
        viewModelScope.launch {
            // Check maintenance first
            val maintenance = guardRepository.checkMaintenance(forceRefresh)
            if (maintenance.isActive) {
                _guardState.value = GuardState.Maintenance(maintenance.message)
                return@launch
            }

            // Then check user status
            when (val status = guardRepository.checkUserStatus(forceRefresh)) {
                is AppGuardRepository.UserStatus.Banned -> {
                    _guardState.value = GuardState.Banned(status.reason)
                }
                is AppGuardRepository.UserStatus.Suspended -> {
                    _guardState.value = GuardState.Suspended(status.until, status.reason)
                }
                is AppGuardRepository.UserStatus.Active -> {
                    _guardState.value = GuardState.Clear
                }
            }
        }
    }
}
