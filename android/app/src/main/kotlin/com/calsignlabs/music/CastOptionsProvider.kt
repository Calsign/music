package com.calsignlabs.music

import android.content.Context
import com.google.android.gms.cast.CastMediaControlIntent
import com.google.android.gms.cast.framework.CastOptions
import com.google.android.gms.cast.framework.OptionsProvider
import com.google.android.gms.cast.framework.SessionProvider

/// this is required by the cast API and is referenced in the manifest
class CastOptionsProvider : OptionsProvider {
    override fun getCastOptions(context: Context?): CastOptions {
        return CastOptions.Builder()
                .setReceiverApplicationId(
                        CastMediaControlIntent.DEFAULT_MEDIA_RECEIVER_APPLICATION_ID)
                .build()
    }

    override fun getAdditionalSessionProviders(context: Context?): MutableList<SessionProvider>? {
        return null
    }
}
