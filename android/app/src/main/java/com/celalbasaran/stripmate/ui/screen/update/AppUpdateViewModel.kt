package com.celalbasaran.stripmate.ui.screen.update

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.celalbasaran.stripmate.service.update.AppUpdateService
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * Thin wrapper around [AppUpdateService] so the Compose UI can collect the
 * service state via Hilt-injected ViewModel without binding to the Activity.
 */
@HiltViewModel
class AppUpdateViewModel @Inject constructor(
    private val service: AppUpdateService
) : ViewModel() {

    val state: StateFlow<AppUpdateService.State> = service.state

    fun startDownload(info: AppUpdateService.VersionInfo) {
        service.startDownload(info)
    }

    fun dismiss() {
        service.dismiss()
    }

    fun checkForUpdates() {
        viewModelScope.launch { service.checkForUpdates() }
    }
}
