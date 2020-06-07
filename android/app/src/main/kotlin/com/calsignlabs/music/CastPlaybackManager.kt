package com.calsignlabs.music

import android.os.Handler
import android.os.Looper
import com.google.android.gms.cast.MediaInfo
import com.google.android.gms.cast.MediaQueueItem
import com.google.android.gms.cast.MediaStatus
import com.google.android.gms.cast.framework.media.RemoteMediaClient

class CastPlaybackManager(remoteMediaClient: RemoteMediaClient,
                          private val callback: PlaybackManager.Callback)
    : PlaybackManager {

    private val player = remoteMediaClient
    private val mainHandler = Handler(Looper.getMainLooper())

    private var currentState: PlaybackManager.State = PlaybackManager.State.INITIAL
    private var currentId: String? = null

    private var repeatMode = PlaybackManager.RepeatMode.NONE

    private val idToCastIdMap = HashMap<String, Int>()
    private val castIdToIdMap = HashMap<Int, String>()

    init {
        player.registerCallback(
                object : RemoteMediaClient.Callback() {
                    override fun onStatusUpdated() {
                        val newState = state()
                        if (newState != currentState) {
                            currentState = newState
                            callback.onStateChange(newState)
                        }
                    }

                    override fun onQueueStatusUpdated() {
                        if (player.currentItem != null) {
                            val newId = getMediaQueueItemId(player.currentItem)
                            if (newId != currentId) {
                                currentId = newId
                                callback.onTrackChange(newId)
                            }
                        }
                    }
                }
        )
    }

    override fun state(): PlaybackManager.State {
        return when (player.playerState) {
            MediaStatus.PLAYER_STATE_IDLE -> PlaybackManager.State.INITIAL
            MediaStatus.PLAYER_STATE_LOADING -> PlaybackManager.State.LOADING
            MediaStatus.PLAYER_STATE_BUFFERING -> PlaybackManager.State.LOADING
            MediaStatus.PLAYER_STATE_PAUSED -> PlaybackManager.State.PAUSED
            MediaStatus.PLAYER_STATE_PLAYING -> PlaybackManager.State.PLAYING
            MediaStatus.PLAYER_STATE_UNKNOWN -> PlaybackManager.State.UNKNOWN
            else -> PlaybackManager.State.UNKNOWN
        }
    }

    private fun buildQueueItem(item: PlaybackManager.QueueItem): MediaQueueItem {
        val queueItem = MediaQueueItem.Builder(
                MediaInfo.Builder(
                        item.remoteUri.toString())
                        .setEntity(item.id)
                        .setStreamType(MediaInfo.STREAM_TYPE_BUFFERED)
                        .build())
                .build()
        return queueItem
    }

    private fun convertedRepeatMode(mode: PlaybackManager.RepeatMode): Int {
        return when (mode) {
            PlaybackManager.RepeatMode.NONE -> MediaStatus.REPEAT_MODE_REPEAT_OFF
            PlaybackManager.RepeatMode.REPEAT_ONE -> MediaStatus.REPEAT_MODE_REPEAT_SINGLE
            PlaybackManager.RepeatMode.REPEAT_ALL -> MediaStatus.REPEAT_MODE_REPEAT_ALL
        }
    }

    override fun queueSet(items: Iterable<PlaybackManager.QueueItem>, startIndex: Int) {
        mainHandler.post {
            player.queueLoad(
                    items.map { item -> buildQueueItem(item) }
                            .toList().toTypedArray(),
                    startIndex, convertedRepeatMode(repeatMode), 0, null)
                    .addStatusListener { updateCastIds(items, 0) }
        }
    }

    override fun queueInsert(items: Iterable<PlaybackManager.QueueItem>, index: Int) {
        mainHandler.post {
            val castId = getCastIdByQueueIndex(index)
            // OK if castId is invalid, this indicates appending
            player.queueInsertItems(
                    items.map { item -> buildQueueItem(item) }
                            .toList().toTypedArray(),
                    castId, null)
                    .addStatusListener { updateCastIds(items, index) }
        }
    }

    override fun queueRemove(startIndex: Int, length: Int) {
        mainHandler.post {
            val range = startIndex until startIndex + length
            val castIds = range.map { index -> getCastIdByQueueIndex(index) }
            player.queueRemoveItems(castIds.toIntArray(), null)
        }
    }

    override fun queueMove(fromIndex: Int, toIndex: Int) {
        mainHandler.post {
            player.queueMoveItemToNewIndex(getCastIdByQueueIndex(fromIndex), toIndex, null)
        }
    }

    override fun queueSelect(index: Int) {
        mainHandler.post {
            player.queueJumpToItem(getCastIdByQueueIndex(index), null)
        }
    }

    override fun play() {
        mainHandler.post { player.play() }
    }

    override fun pause() {
        mainHandler.post { player.pause() }
    }

    override fun seek(msec: Long) {
        mainHandler.post { player.seek(msec) }
    }

    override fun setRepeatMode(mode: PlaybackManager.RepeatMode) {
        mainHandler.post {
            player.queueSetRepeatMode(convertedRepeatMode(mode), null).addStatusListener { repeatMode = mode }
        }
    }

    override fun position(): Long {
        // note: must be called from main thread
        return player.approximateStreamPosition
    }

    override fun duration(): Long {
        // note: must be called from main thread
        return player.streamDuration
    }

    override fun repeatMode(): PlaybackManager.RepeatMode {
        // note: must be called from main thread
        return repeatMode
    }

    override fun release() {
        mainHandler.post { player.stop() }
    }

    private fun getMediaQueueItemId(item: MediaQueueItem): String {
        val id = item.media?.entity
        if (id != null) {
            return id
        } else {
            error("media queue item is missing id (entity value)")
        }
    }

    private fun updateCastIds(items: Iterable<PlaybackManager.QueueItem>, initial: Int) {
        mainHandler.post {
            items.forEachIndexed { index, item ->
                val id = item.id
                val castId = player.mediaQueue.itemIdAtIndex(initial + index)

                idToCastIdMap[id] = castId
                castIdToIdMap[castId] = id
            }
        }
    }

    private fun getCastIdByQueueIndex(index: Int): Int {
        return player.mediaQueue.itemIdAtIndex(index)
    }
}
