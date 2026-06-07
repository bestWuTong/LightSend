package com.lightsend.lightsend

import android.app.Activity
import android.content.Intent
import android.os.Bundle

class OneDriveAuthRedirectActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        forwardRedirect()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        forwardRedirect()
    }

    private fun forwardRedirect() {
        intent?.data?.toString()?.let { redirect ->
            OneDriveAuthBridge.storePendingRedirect(this, redirect)
            val mainIntent = Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                putExtra(OneDriveAuthBridge.EXTRA_REDIRECT, redirect)
            }
            startActivity(mainIntent)
        }
        finish()
    }
}
