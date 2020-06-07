package com.calsignlabs.music

import android.annotation.SuppressLint
import android.content.Context
import android.os.Handler
import android.os.Looper
import androidx.media.AudioAttributesCompat
import androidx.media2.common.MediaItem
import androidx.media2.common.MediaMetadata
import androidx.media2.common.SessionPlayer
import androidx.media2.common.UriMediaItem
import androidx.media2.player.MediaPlayer
import com.google.common.util.concurrent.ListenableFuture
import java.util.concurrent.Executors

@Deprecated("the playlist features don't seem to work")
class MediaPlayer2PlaybackManager(context: Context,
                                  private val callback: PlaybackManager.Callback)
    : PlaybackManager {

    private val player = MediaPlayer(context)
    private val executor = Executors.newFixedThreadPool(1)
    private val mainHandler = Handler(Looper.getMainLooper())

    init {
        player.registerPlayerCallback(executor,
                object : SessionPlayer.PlayerCallback() {
                    override fun onPlayerStateChanged(player: SessionPlayer, playerState: Int) {
                        mainHandler.post { callback.onStateChange(state()) }
                    }

                    override fun onSeekCompleted(player: SessionPlayer, position: Long) {
                        mainHandler.post { callback.onSeekComplete(position) }
                    }

                    @SuppressLint("RestrictedApi")
                    override fun onCurrentMediaItemChanged(player: SessionPlayer, item: MediaItem) {
                        val id = item.mediaId
                        if (id != null) {
                            mainHandler.post { callback.onTrackChange(id) }
                        }
                    }
                }
        )
        // this is very important, without it the output is muted
        player.setAudioAttributes(AudioAttributesCompat.Builder()
                .setContentType(AudioAttributesCompat.CONTENT_TYPE_MUSIC)
                .setUsage(AudioAttributesCompat.USAGE_MEDIA).build())
    }

    override fun state(): PlaybackManager.State {
        return when (player.playerState) {
            SessionPlayer.PLAYER_STATE_IDLE -> PlaybackManager.State.INITIAL
            SessionPlayer.PLAYER_STATE_PAUSED -> PlaybackManager.State.PAUSED
            SessionPlayer.PLAYER_STATE_PLAYING -> PlaybackManager.State.PLAYING
            SessionPlayer.PLAYER_STATE_ERROR -> PlaybackManager.State.ERROR
            else -> PlaybackManager.State.UNKNOWN
        }
    }

    private fun buildQueueItem(item: PlaybackManager.QueueItem): MediaItem {
        val uri = item.localUri ?: item.remoteUri
        return UriMediaItem.Builder(uri)
                .setMetadata(MediaMetadata.Builder()
                        .putString(MediaMetadata.METADATA_KEY_MEDIA_ID, item.id)
                        .build())
                .build()
    }

    override fun queueSet(items: Iterable<PlaybackManager.QueueItem>, startIndex: Int) {
        player.setPlaylist(
                items.map { item -> buildQueueItem(item) }.toList(),
                null).addListener(Runnable {
            when (state()) {
                PlaybackManager.State.INITIAL -> {
                    // TODO select startIndex
                    player.prepare().addListener(Runnable {
                        //queueSelectInternal(startIndex) { play() }
                        play()
                    }, executor)
                }
                PlaybackManager.State.PAUSED -> forcePlay() // TODO select currentIndex
                PlaybackManager.State.PLAYING -> forcePlay() // TODO select currentIndex
                else -> {
                    // *shrug*
                }
            }
        }, executor)
    }

    private fun forcePlay() {
        // this is remarkably dumb but it does the trick
        player.pause().addListener(Runnable {
            player.play().addListener(Runnable {
                player.pause().addListener(Runnable {
                    player.play()
                }, executor)
            }, executor)
        }, executor)
    }

    override fun queueInsert(items: Iterable<PlaybackManager.QueueItem>, index: Int) {
        var future: ListenableFuture<SessionPlayer.PlayerResult>? = null
        // this isn't as elegant as it could be *shakes head*
        items
                .map { item -> buildQueueItem(item) }
                .forEachIndexed { pos, item ->
                    if (future == null) {
                        println(" ======== inserting into queue, index: $index, pos: $pos")
                        future = player.addPlaylistItem(index + pos, item)
                        future!!.addListener(Runnable { println(" ======== finished adding index: $index, pos: $pos, internal size: ${player.playlist?.size}") }, executor)
                    } else {
                        future!!.addListener(Runnable {
                            future = player.addPlaylistItem(index + pos, item)
                        }, executor)
                    }
                }
    }

    override fun queueRemove(startIndex: Int, length: Int) {
        var future: ListenableFuture<SessionPlayer.PlayerResult>? = null
        // this isn't as elegant as it could be *shakes head*
        for (pos in 0 until length) {
            if (future == null) {
                future = player.removePlaylistItem(pos)
            } else {
                future.addListener(Runnable {
                    future = player.removePlaylistItem(pos)
                }, executor)
            }
        }
    }

    override fun queueMove(fromIndex: Int, toIndex: Int) {
        val item = player.playlist?.get(fromIndex)
        if (item != null) {
            player.removePlaylistItem(fromIndex).addListener(Runnable {
                player.addPlaylistItem(if (fromIndex < toIndex) toIndex - 1 else toIndex, item)
            }, executor)
        } else {
            throw Exception("attempt to move non-existent queue item")
        }
    }

    @SuppressLint("RestrictedApi")
    private fun queueSelectInternal(index: Int, onComplete: (() -> Unit)? = null) {
        player.skipToPlaylistItem(index).addListener(Runnable {
            val id = player.currentMediaItem?.mediaId
            if (id != null) {
                mainHandler.post {
                    callback.onTrackChange(id)
                    onComplete?.invoke()
                }
            }
        }, executor)
    }

    override fun queueSelect(index: Int) {
        queueSelectInternal(index)
    }

    override fun play() {
        player.play()
    }

    override fun pause() {
        player.pause()
    }

    override fun seek(msec: Long) {
        player.seekTo(msec)
    }

    override fun setRepeatMode(mode: PlaybackManager.RepeatMode) {
        player.repeatMode = when (mode) {
            PlaybackManager.RepeatMode.NONE -> SessionPlayer.REPEAT_MODE_NONE
            PlaybackManager.RepeatMode.REPEAT_ONE -> SessionPlayer.REPEAT_MODE_ONE
            PlaybackManager.RepeatMode.REPEAT_ALL -> SessionPlayer.REPEAT_MODE_ALL
        }
    }

    override fun position(): Long {
        return player.currentPosition
    }

    override fun duration(): Long {
        return player.duration
    }

    override fun repeatMode(): PlaybackManager.RepeatMode {
        return when (player.repeatMode) {
            SessionPlayer.REPEAT_MODE_NONE -> PlaybackManager.RepeatMode.NONE
            SessionPlayer.REPEAT_MODE_ONE -> PlaybackManager.RepeatMode.REPEAT_ONE
            SessionPlayer.REPEAT_MODE_ALL -> PlaybackManager.RepeatMode.REPEAT_ALL
            else -> PlaybackManager.RepeatMode.NONE
        }
    }

    override fun release() {
        player.close()
    }
}
