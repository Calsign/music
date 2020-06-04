package com.calsignlabs.music

import android.content.Context
import android.os.AsyncTask
import androidx.mediarouter.media.MediaControlIntent
import androidx.mediarouter.media.MediaRouteSelector
import androidx.mediarouter.media.MediaRouter
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.schabi.newpipe.DownloaderImpl
import org.schabi.newpipe.extractor.NewPipe
import org.schabi.newpipe.extractor.search.SearchExtractor

import org.schabi.newpipe.extractor.services.youtube.YoutubeService
import org.schabi.newpipe.extractor.services.youtube.linkHandler.YoutubeSearchQueryHandlerFactory
import org.schabi.newpipe.extractor.services.youtube.linkHandler.YoutubeStreamLinkHandlerFactory
import org.schabi.newpipe.extractor.stream.StreamInfoItem
import java.util.*

import com.calsignlabs.music.MediaPlayerWrapper.State.*
import com.google.android.gms.cast.framework.CastContext
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

class MainActivity : FlutterActivity() {
    private var status: MethodChannel? = null

    private val youtubeService = YoutubeService(0)
    private val youtubeSearchQueryHandler = YoutubeSearchQueryHandlerFactory.getInstance()
    private val youtubeStreamLinkHandler = YoutubeStreamLinkHandlerFactory.getInstance()

    private val mediaPool = LinkedHashMap<String, MediaPlayerWrapper>()
    private var queue: ArrayList<String> = ArrayList()

    private val scheduledExecutorService = Executors.newScheduledThreadPool(1)

    private val routeManager = RouteManager(
            { routes -> invokeStatus("playbackDevices", routes) },
            { selectedRoute -> invokeStatus("selectedPlaybackDevice", selectedRoute) }
    )

    init {
        NewPipe.init(DownloaderImpl.init(null))

        scheduledExecutorService.scheduleAtFixedRate({
            runOnUiThread {
                var position: Int = -1
                var totalDuration: Int = -1

                val mediaPlayer = getCurrentMediaPlayer()

                if (mediaPlayer != null && mediaPlayer.isState(STARTED, PAUSED, COMPLETED)) {
                    position = mediaPlayer.currentPosition()
                    totalDuration = mediaPlayer.duration()
                }

                invokeStatus("playbackProgressUpdate", hashMapOf(
                        "position" to position,
                        "totalDuration" to totalDuration
                ))
            }
        }, 1000, 1000, TimeUnit.MILLISECONDS)
    }

    class RouteManager(private val updateCallback: (List<Map<String, Any?>>) -> Unit,
                       private val selectedCallback: (String?) -> Unit) : MediaRouter.Callback() {
        private val routes = HashMap<String, MediaRouter.RouteInfo>()
        private var currentRoute: String? = null

        fun startSearch(context: Context) {
            routes.clear()

            val mediaRouter = MediaRouter.getInstance(context)

            // detect phone, bluetooth, etc.
            val normalRouteSelector = MediaRouteSelector.Builder()
                    .addControlCategory(MediaControlIntent.CATEGORY_LIVE_AUDIO)
                    .build()
            // detect Google cast devices
            val castRouteSelector = CastContext.getSharedInstance(context).mergedSelector

            mediaRouter.addCallback(normalRouteSelector, this, MediaRouter.CALLBACK_FLAG_PERFORM_ACTIVE_SCAN)
            mediaRouter.addCallback(castRouteSelector, this, MediaRouter.CALLBACK_FLAG_PERFORM_ACTIVE_SCAN)

            // pick up default route
            for (route in mediaRouter.routes) {
                routes[route.id] = route
            }
            currentRoute = mediaRouter.selectedRoute.id
        }

        fun stopSearch(context: Context) {
            MediaRouter.getInstance(context).removeCallback(this)
        }

        fun selectRoute(context: Context, id: String): Boolean {
            val route = routes[id]
            return if (route != null) {
                val mediaRouter = MediaRouter.getInstance(context)
                // we need to unselect first if we are switching to the default route
                // because we can't actually switch to the default route
                mediaRouter.unselect(MediaRouter.UNSELECT_REASON_ROUTE_CHANGED)
                mediaRouter.selectRoute(route)
                true
            } else {
                false
            }
        }

        private fun invokeUpdate() {
            updateCallback(routes.values.map{r -> packRouteInfo(r)})
        }

        private fun invokeSelected() {
            selectedCallback(currentRoute)
        }

        override fun onRouteAdded(router: MediaRouter?, route: MediaRouter.RouteInfo?) {
            if (route != null) {
                routes[route.id] = route
                invokeUpdate()
            }
        }

        override fun onRouteChanged(router: MediaRouter?, route: MediaRouter.RouteInfo?) {
            if (route != null) {
                routes[route.id] = route
                invokeUpdate()
            }
        }

        override fun onRoutePresentationDisplayChanged(router: MediaRouter?, route: MediaRouter.RouteInfo?) {
            if (route != null) {
                routes[route.id] = route
                invokeUpdate()
            }
        }

        override fun onRouteRemoved(router: MediaRouter?, route: MediaRouter.RouteInfo?) {
            if (route != null) {
                routes.remove(route.id)
                invokeUpdate()
            }
        }

        override fun onRouteSelected(router: MediaRouter?, route: MediaRouter.RouteInfo?) {
            super.onRouteSelected(router, route)
            if (route != null) {
                currentRoute = route.id
                invokeSelected()
            }
        }

        companion object {
            fun packRouteInfo(route: MediaRouter.RouteInfo): Map<String, Any?> {
                return hashMapOf(
                        "id" to route.id,
                        "name" to route.name,
                        "description" to route.description,
                        "deviceType" to route.deviceType
                )
            }
        }
    }

    private fun getCurrentMediaPlayer(): MediaPlayerWrapper? {
        return if (mediaPool.isNotEmpty() && queue.isNotEmpty()) mediaPool[queue[0]] else null
    }

    private fun invokeStatus(method: String, data: Any?) {
        try {
            status?.invokeMethod(method, data)
        } catch (e: Exception) {
            println("Failed to send status update $method, exception: ${e.message}")
        }
    }

    private fun invokeStatus(method: String) {
        invokeStatus(method, null)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.calsignlabs.music/playback")
                .setMethodCallHandler { call, result ->
                    when (call.method) {
                        "getYoutubeStreamUri" -> {
                            val uri: String? = call.argument("uri")
                            if (uri != null) {
                                getYoutubeStreamUri(uri, result)
                            } else {
                                throw Exception("No URI specified to loadYoutubeUri")
                            }
                        }
                        "searchYoutube" -> {
                            val query: String? = call.argument("query")
                            if (query != null) {
                                searchYoutube(query, result)
                            } else {
                                throw Exception("No query specified to searchYoutube")
                            }
                        }
                        "play" -> play(result)
                        "pause" -> pause(result)
                        "setQueue" -> {
                            val newQueue: List<String>? = call.argument("queue")
                            val sweep: Boolean? = call.argument("sweep")
                            val resetCurrent: Boolean? = call.argument("resetCurrent")
                            val startIfPaused: Boolean? = call.argument("startIfPaused")
                            if (newQueue != null) {
                                setQueue(newQueue, sweep ?: true, resetCurrent ?: false,
                                        startIfPaused ?: true, result)
                            } else {
                                throw Exception("No queue specified to setQueue")
                            }
                        }
                        "skipTo" -> {
                            val position: Int? = call.argument("position")
                            if (position != null) {
                                skipTo(position, result)
                            } else {
                                throw Exception("No position specified to skipTo")
                            }
                        }
                        "startPlaybackDeviceSearch" -> routeManager.startSearch(context)
                        "stopPlaybackDeviceSearch" -> routeManager.stopSearch(context)
                        "selectPlaybackDevice" -> {
                            val routeId: String? = call.argument("device")
                            if (routeId != null) {
                                routeManager.selectRoute(context, routeId)
                            } else {
                                throw Exception("No device specified to selectPlaybackDevice")
                            }
                        }
                    }
                }
        status = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.calsignlabs.music/status")
    }

    override fun onDestroy() {
        for (mediaPlayer in mediaPool.values) {
            mediaPlayer.release()
        }
        scheduledExecutorService.shutdown()
        routeManager.stopSearch(context)
        super.onDestroy()
    }

    private fun play(result: MethodChannel.Result) {
        var played = false
        synchronized(this) {
            val currentMediaPlayer = getCurrentMediaPlayer()
            if (currentMediaPlayer != null && currentMediaPlayer.isState(PAUSED, PREPARED, COMPLETED)) {
                try {
                    currentMediaPlayer.start()
                } catch (e: Exception) {
                    e.printStackTrace()
                }
                played = true
            }
        }
        if (played) {
            invokeStatus("onPlay")
            result.success(null)
        } else {
            result.error("Failed", "Already playing: ${getCurrentMediaPlayer()?.state()?.name}", null)
        }
    }

    private fun pause(result: MethodChannel.Result) {
        var paused = false
        synchronized(this) {
            val currentMediaPlayer = getCurrentMediaPlayer()
            if (currentMediaPlayer != null && currentMediaPlayer.isState(STARTED, PREPARED)) {
                try {
                    currentMediaPlayer.pause()
                    paused = true
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }
        }
        if (paused) {
            invokeStatus("onPause")
            result.success(null)
        } else {
            result.error("Failed", "Already paused: ${getCurrentMediaPlayer()?.state()?.name}", null)
        }
    }

    private fun skipTo(position: Int, result: MethodChannel.Result) {
        var skipped = false
        synchronized(this) {
            val currentMediaPlayer = getCurrentMediaPlayer()
            try {
                if (currentMediaPlayer != null) {
                    if (currentMediaPlayer.isState(STARTED, PAUSED)) {
                        currentMediaPlayer.seekTo(position)
                        skipped = true
                    } else if (currentMediaPlayer.isState(COMPLETED)) {
                        currentMediaPlayer.start()
                        currentMediaPlayer.pause()
                        currentMediaPlayer.seekTo(position)
                        skipped = true
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
        if (skipped) {
            result.success(null)
        } else {
            result.error("Failed", "Cannot seek: ${getCurrentMediaPlayer()?.state()?.name}", null)
        }
    }

    private fun searchYoutube(query: String, result: MethodChannel.Result) {
        AsyncTask.execute {
            val results = performSearch(query)
            runOnUiThread { result.success(results) }
        }
    }

    private fun performSearch(query: String): List<Map<String, Any>> {
        val searchExtractor = youtubeService.getSearchExtractor(youtubeSearchQueryHandler.fromQuery(query))
        searchExtractor.fetchPage()

        try {
            return searchExtractor.initialPage.items.map { item ->
                if (item is StreamInfoItem) {
                    hashMapOf(
                            "title" to item.name,
                            "uri" to item.url,
                            "duration" to item.duration,
                            "views" to item.viewCount,
                            "uploader" to item.uploaderName
                    )
                } else {
                    hashMapOf(
                            "title" to item.name,
                            "uri" to item.url,
                            "duration" to -1,
                            "views" to -1,
                            "uploader" to ""
                    )
                }
            }.toList()
        } catch (e: SearchExtractor.NothingFoundException) {
            return Collections.emptyList()
        }
    }

    private fun getYoutubeStreamUri(uri: String, result: MethodChannel.Result) {
        AsyncTask.execute {
            try {
                var streamUri: String? = null
                var count = 0
                // sometimes it fails to get the stream... try again?
                while (count < 3 && streamUri == null) {
                    streamUri = performGetYoutubeStreamUri(uri)
                    count++
                }
                runOnUiThread {
                    if (streamUri != null) {
                        result.success(streamUri)
                    } else {
                        result.error("Failed", "No audio streams found", null)
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
                runOnUiThread { result.error("Failed", e.message, null) }
            }
        }
    }

    private fun performGetYoutubeStreamUri(uri: String): String? {
        return try {
            val streamExtractor = youtubeService.getStreamExtractor(youtubeStreamLinkHandler.fromUrl(uri))
            streamExtractor.fetchPage()

            if (streamExtractor.audioStreams.isNotEmpty()) {
                streamExtractor.audioStreams.sortBy { stream -> -stream.averageBitrate }
                streamExtractor.audioStreams[0].url
            } else {
                null
            }
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    private fun setQueue(newQueue: Iterable<String>, sweep: Boolean, resetCurrent: Boolean, startIfPaused: Boolean, result: MethodChannel.Result) {
        try {
            performSetQueue(newQueue, sweep, resetCurrent, startIfPaused)
            result.success(null)
        } catch (e: Exception) {
            e.printStackTrace()
            result.error("Failed", e.message, null)
        }
    }

    private fun performSetQueue(newQueueIterable: Iterable<String>, sweep: Boolean, resetCurrent: Boolean, startIfPaused: Boolean) {
        val newQueue = newQueueIterable.toList()
        val firstNewTrack = if (newQueue.isNotEmpty()) newQueue[0] else null

        synchronized(this) {
            val wasPlaying = getCurrentMediaPlayer()?.isState(STARTED) ?: false

            if (queue.isNotEmpty() && newQueue.isNotEmpty()) {
                if (queue.first() == firstNewTrack) {
                    if (resetCurrent && getCurrentMediaPlayer()?.isState(STARTED) == true) {
                        getCurrentMediaPlayer()?.seekTo(0)
                    }
                } else {
                    if (getCurrentMediaPlayer()?.isState(STARTED, PAUSED) == true) {
                        if (getCurrentMediaPlayer()?.isState(STARTED) == true) {
                            getCurrentMediaPlayer()?.pause()
                            invokeStatus("onPause")
                        }
                        getCurrentMediaPlayer()?.seekTo(0)
                    }
                }
            }

            val oldSet = LinkedHashSet(queue)
            val newSet = LinkedHashSet(newQueue)

            if (sweep) {
                for (removedYoutubeUri in oldSet - newSet) {
                    val player = mediaPool[removedYoutubeUri]
                    player?.setOnComplete { false }
                    player?.pause()
                    AsyncTask.execute {
                        player?.stop()
                        player?.release()
                    }
                    mediaPool.remove(removedYoutubeUri)
                }
            }

            for (addedYoutubeUri in newSet - oldSet) {
                val player = MediaPlayerWrapper()
                AsyncTask.execute {
                    val rawStreamUri = performGetYoutubeStreamUri(addedYoutubeUri)
                    player.setDataSource(rawStreamUri)
                    player.prepare()
                }
                mediaPool[addedYoutubeUri] = player
            }

            newQueue.foldRight<String, String?>(null) { youtubeUri, nextYoutubeUri ->
                val player = mediaPool[youtubeUri]
                val nextPlayer = mediaPool[nextYoutubeUri]

                player!!.setOnComplete {
                    var valid = true
                    var paused = false
                    var nextTrack = false
                    synchronized(this) {
                        if (queue.isNotEmpty() && youtubeUri != queue.first()) {
                            valid = false
                        } else {
                            if (nextYoutubeUri == null) {
                                paused = true
                            } else {
                                nextPlayer!!.start()
                                queue.removeAt(0)
                                nextTrack = true
                            }
                        }
                    }
                    if (paused) {
                        invokeStatus("onPause")
                    }
                    if (nextTrack) {
                        invokeStatus("onNextTrack")
                    }
                    valid
                }
                youtubeUri
            }

            if (newQueue.isEmpty()) {
                invokeStatus("onPause")
            }

            for (entry in mediaPool.entries) {
                if (entry.key == firstNewTrack && (startIfPaused || wasPlaying)) {
                    entry.value.setOnPrepare {
                        entry.value.start()
                        invokeStatus("onPlay")
                    }
                    if (entry.value.isState(PREPARED, PAUSED, COMPLETED)) {
                        try {
                            entry.value.start()
                            invokeStatus("onPlay")
                        } catch (e: Exception) {
                            // don't think this actually happens
                            e.printStackTrace()
                        }
                    }
                } else {
                    // if we don't do this we might get duplicated playback when this MediaPlayer
                    // is re-used in the future and finishes preparing again
                    entry.value.setOnPrepare { }
                    try {
                        // this is really dumb but sometimes we have issues
                        // so just be safe and make sure it's paused
                        entry.value.pause()
                        if (entry.key != firstNewTrack) {
                            entry.value.seekTo(0)
                        }
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                }
            }

            queue.clear()
            queue.addAll(newQueue)
        }
    }
}
