package com.calsignlabs.music

import android.net.Uri

interface PlaybackManager {
    enum class State {
        INITIAL,
        LOADING,
        PAUSED,
        PLAYING,
        ERROR,
        UNKNOWN
    }

    enum class RepeatMode {
        NONE,
        REPEAT_ONE,
        REPEAT_ALL
    }

    interface Callback {
        fun onStateChange(state: State)
        fun onSeekComplete(position: Long)
        fun onTrackChange(id: String)
    }

    data class QueueItem(val id: String, val localUri: Uri?, val remoteUri: Uri)

    fun state(): State

    fun isState(vararg states: State): Boolean {
        return states.contains(state())
    }

    fun queueSet(items: Iterable<QueueItem>, startIndex: Int)
    fun queueInsert(items: Iterable<QueueItem>, index: Int)
    fun queueRemove(startIndex: Int, length: Int)
    fun queueMove(fromIndex: Int, toIndex: Int)
    fun queueSelect(index: Int)

    fun play()
    fun pause()
    fun seek(msec: Long)
    fun setRepeatMode(mode: RepeatMode)

    fun position(): Long
    fun duration(): Long
    fun repeatMode(): RepeatMode

    fun release()
}
