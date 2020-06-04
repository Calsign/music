package com.calsignlabs.music

import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build

class MediaPlayerWrapper {
    private val mediaPlayer = MediaPlayer()
    private var state = State.IDLE
    private var onComplete: (() -> Boolean)? = null
    private var onPrepare: (() -> Unit)? = null

    enum class State {
        IDLE,
        INITIALIZED,
        PREPARED,
        STARTED,
        PAUSED,
        COMPLETED,
        STOPPED,
        END,
    }

    fun state(): State {
        return state
    }

    fun isState(vararg states: State): Boolean {
        return states.contains(state)
    }

    fun setOnComplete(onComplete: () -> Boolean) {
        this.onComplete = onComplete
    }

    fun setOnPrepare(onPrepare: () -> Unit) {
        this.onPrepare = onPrepare
    }

    init {
        mediaPlayer.setOnCompletionListener {
            if (onComplete?.invoke() == true) {
                state = State.COMPLETED
            }
        }

        if (Build.VERSION.SDK_INT >= 21) {
            val builder = AudioAttributes.Builder()
            builder.setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
            builder.setUsage(AudioAttributes.USAGE_MEDIA)
            mediaPlayer.setAudioAttributes(builder.build())
        } else {
            @Suppress("DEPRECATION")
            mediaPlayer.setAudioStreamType(AudioManager.STREAM_MUSIC)
        }
    }

    fun setDataSource(dataSource: String?) {
        mediaPlayer.setDataSource(dataSource)
        state = State.INITIALIZED
    }

    fun prepare() {
        mediaPlayer.setOnPreparedListener { onPrepare?.invoke() }
        mediaPlayer.prepare()
        state = State.PREPARED
    }

    fun start() {
        mediaPlayer.start()
        state = State.STARTED
    }

    fun pause() {
        mediaPlayer.pause()
        state = State.PAUSED
    }

    fun stop() {
        mediaPlayer.stop()
        state = State.STOPPED
    }

    fun seekTo(msec: Int) {
        mediaPlayer.seekTo(msec)
    }

    fun release() {
        mediaPlayer.release()
        state = State.END
    }

    fun currentPosition(): Int {
        return mediaPlayer.currentPosition
    }

    fun duration(): Int {
        return mediaPlayer.duration
    }
}
