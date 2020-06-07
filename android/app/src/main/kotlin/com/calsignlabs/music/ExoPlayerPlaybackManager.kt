package com.calsignlabs.music

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.google.android.exoplayer2.ExoPlayer
import com.google.android.exoplayer2.Player
import com.google.android.exoplayer2.SimpleExoPlayer
import com.google.android.exoplayer2.Timeline
import com.google.android.exoplayer2.extractor.ExtractorsFactory
import com.google.android.exoplayer2.extractor.mp3.Mp3Extractor
import com.google.android.exoplayer2.extractor.mp4.FragmentedMp4Extractor
import com.google.android.exoplayer2.extractor.mp4.Mp4Extractor
import com.google.android.exoplayer2.source.ConcatenatingMediaSource
import com.google.android.exoplayer2.source.MediaSource
import com.google.android.exoplayer2.source.ProgressiveMediaSource
import com.google.android.exoplayer2.upstream.DefaultHttpDataSourceFactory
import com.google.android.exoplayer2.util.Util

class ExoPlayerPlaybackManager(private val context: Context,
                               private val callback: PlaybackManager.Callback)
    : PlaybackManager {

    private val player: ExoPlayer = SimpleExoPlayer.Builder(context).build()
    private val playlist = ConcatenatingMediaSource()

    private val mainHandler = Handler(Looper.getMainLooper())

    init {
        mainHandler.post {
            player.prepare(playlist)
            player.addListener(
                    object : Player.EventListener {
                        var currentTrackId: String? = null

                        override fun onPlayerStateChanged(playWhenReady: Boolean, playbackState: Int) {
                            println(" ======== PLAYER STATE CHANGED: ${state()}")
                            mainHandler.post { callback.onStateChange(state()) }
                        }

                        override fun onIsPlayingChanged(isPlaying: Boolean) {
                            mainHandler.post { callback.onStateChange(state()) }
                        }

                        override fun onSeekProcessed() {
                            mainHandler.post {
                                callback.onSeekComplete(position())
                            }
                        }

                        private fun testTrackChange() {
                            val newTrackId = player.currentTag as String?
                            if (newTrackId != currentTrackId && newTrackId != null) {
                                currentTrackId = newTrackId
                                callback.onTrackChange(newTrackId)
                            }
                        }

                        override fun onPositionDiscontinuity(reason: Int) {
                            testTrackChange()
                        }

                        override fun onTimelineChanged(timeline: Timeline, reason: Int) {
                            testTrackChange()
                        }
                    }
            )
        }
    }

    override fun state(): PlaybackManager.State {
        return when (player.playbackState) {
            Player.STATE_IDLE -> PlaybackManager.State.INITIAL
            Player.STATE_BUFFERING -> PlaybackManager.State.LOADING
            Player.STATE_READY -> {
                if (player.isPlaying) PlaybackManager.State.PLAYING
                else PlaybackManager.State.PAUSED
            }
            Player.STATE_ENDED -> PlaybackManager.State.PAUSED
            else -> PlaybackManager.State.UNKNOWN
        }
    }

    private fun buildMediaSource(item: PlaybackManager.QueueItem): MediaSource {
        val factory = ProgressiveMediaSource.Factory(
                DefaultHttpDataSourceFactory(Util.getUserAgent(context, "music"), 1000, 1000, true),
                ExtractorsFactory { arrayOf(FragmentedMp4Extractor(), Mp4Extractor(), Mp3Extractor()) })
        return factory.setTag(item.id).createMediaSource(item.localUri
                ?: item.remoteUri)
    }

    override fun queueSet(items: Iterable<PlaybackManager.QueueItem>, startIndex: Int) {
        mainHandler.post {
            playlist.clear(mainHandler) {
                playlist.addMediaSources(items.map { item -> buildMediaSource(item) }, mainHandler) {
                    play()
                }
            }
        }
    }

    override fun queueInsert(items: Iterable<PlaybackManager.QueueItem>, index: Int) {
        mainHandler.post {
            playlist.addMediaSources(index, items.map { item -> buildMediaSource(item) })
        }
    }

    override fun queueRemove(startIndex: Int, length: Int) {
        mainHandler.post {
            playlist.removeMediaSourceRange(startIndex, startIndex + length)
        }
    }

    override fun queueMove(fromIndex: Int, toIndex: Int) {
        mainHandler.post {
            playlist.moveMediaSource(fromIndex, toIndex)
        }
    }

    override fun queueSelect(index: Int) {
        mainHandler.post {
            player.seekTo(index, 0)
        }
    }

    override fun play() {
        mainHandler.post { player.playWhenReady = true }
    }

    override fun pause() {
        mainHandler.post { player.playWhenReady = false }
    }

    override fun seek(msec: Long) {
        mainHandler.post { player.seekTo(msec) }
    }

    override fun setRepeatMode(mode: PlaybackManager.RepeatMode) {
        mainHandler.post {
            player.repeatMode = when (mode) {
                PlaybackManager.RepeatMode.NONE -> Player.REPEAT_MODE_OFF
                PlaybackManager.RepeatMode.REPEAT_ONE -> Player.REPEAT_MODE_ONE
                PlaybackManager.RepeatMode.REPEAT_ALL -> Player.REPEAT_MODE_ALL
            }
        }
    }

    override fun position(): Long {
        return player.contentPosition
    }

    override fun duration(): Long {
        return player.contentDuration
    }

    override fun repeatMode(): PlaybackManager.RepeatMode {
        return when (player.repeatMode) {
            Player.REPEAT_MODE_OFF -> PlaybackManager.RepeatMode.NONE
            Player.REPEAT_MODE_ONE -> PlaybackManager.RepeatMode.REPEAT_ONE
            Player.REPEAT_MODE_ALL -> PlaybackManager.RepeatMode.REPEAT_ALL
            else -> PlaybackManager.RepeatMode.NONE
        }
    }

    override fun release() {
        player.release()
    }
}
