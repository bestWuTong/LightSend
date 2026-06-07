package com.lightsend.lightsend

import android.content.Context

object OneDriveAuthBridge {
    const val EXTRA_REDIRECT = "com.lightsend.lightsend.ONEDRIVE_AUTH_REDIRECT"

    private const val PREFS_NAME = "lightsend_onedrive_auth"
    private const val KEY_PENDING_REDIRECT = "pending_redirect"

    fun storePendingRedirect(context: Context, redirect: String) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_PENDING_REDIRECT, redirect)
            .apply()
    }

    fun consumePendingRedirect(context: Context): String? {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val redirect = prefs.getString(KEY_PENDING_REDIRECT, null)
        if (redirect != null) {
            prefs.edit().remove(KEY_PENDING_REDIRECT).apply()
        }
        return redirect
    }

    fun clearPendingRedirect(context: Context) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .remove(KEY_PENDING_REDIRECT)
            .apply()
    }
}
