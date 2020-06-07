package com.calsignlabs.music

import android.content.Context
import android.net.Uri
import android.os.AsyncTask
import android.os.Bundle
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

import com.google.android.gms.cast.framework.CastContext
import com.google.android.gms.cast.framework.CastSession
import com.google.android.gms.cast.framework.SessionManagerListener
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

import com.calsignlabs.music.PlaybackManager.State.*

class MainActivity : FlutterActivity(), PlaybackManager.Callback {
    private var status: MethodChannel? = null

    private val youtubeService = YoutubeService(0)
    private val youtubeSearchQueryHandler = YoutubeSearchQueryHandlerFactory.getInstance()
    private val youtubeStreamLinkHandler = YoutubeStreamLinkHandlerFactory.getInstance()

    private lateinit var localPlaybackManager: PlaybackManager
    private var castPlaybackManager: CastPlaybackManager? = null

    private fun getPlaybackManager(): PlaybackManager {
        return castPlaybackManager ?: localPlaybackManager
    }

    override fun onStateChange(state: PlaybackManager.State) {
        runOnUiThread {
            when (state) {
                INITIAL -> invokeStatus("onPause")
                LOADING -> invokeStatus("onBuffering")
                PAUSED -> invokeStatus("onPause")
                PLAYING -> invokeStatus("onPlay")
                UNKNOWN -> {
                }
                ERROR -> {
                }
            }
        }
    }

    override fun onTrackChange(id: String) {
        runOnUiThread {
            invokeStatus("onTrackChange", id)
        }
    }

    override fun onSeekComplete(position: Long) {
        updatePosition()
    }

    private val scheduledExecutorService = Executors.newScheduledThreadPool(1)

    private val routeManager = RouteManager(
            { routes -> invokeStatus("playbackDevices", routes) },
            { selectedRoute ->
                invokeStatus("selectedPlaybackDevice", selectedRoute)
            }
    )

    private fun updatePosition() {
        runOnUiThread {
            var position: Long = -1
            var totalDuration: Long = -1

            val playbackManager = getPlaybackManager()
            if (playbackManager.isState(PLAYING, PAUSED)) {
                position = playbackManager.position()
                totalDuration = playbackManager.duration()
            }

            invokeStatus("playbackProgressUpdate", hashMapOf(
                    "position" to position,
                    "totalDuration" to totalDuration
            ))
        }
    }

    init {
        NewPipe.init(DownloaderImpl.init(null))

        scheduledExecutorService.scheduleAtFixedRate({ updatePosition() },
                1000, 1000, TimeUnit.MILLISECONDS)
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
            updateCallback(routes.values.map { r -> packRouteInfo(r) })
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
                            val uri: String = call.argument("uri") ?: error("missing uri")
                            getYoutubeStreamUri(uri, result)
                        }
                        "searchYoutube" -> {
                            val query: String = call.argument("query") ?: "missing query"
                            searchYoutube(query, result)
                        }
                        "play" -> play(result)
                        "pause" -> pause(result)
                        "skipTo" -> {
                            val position: Int = call.argument("position")
                                    ?: error("missing position")
                            skipTo(position.toLong(), result)
                        }

                        "queueSet" -> {
                            val items = unpackQueueItems(call.argument("items")
                                    ?: error("missing items"))
                            val startIndex: Int = call.argument("startIndex")
                                    ?: error("missing start index")
                            getPlaybackManager().queueSet(items, startIndex)
                            result.success(null)
                        }
                        "queueInsert" -> {
                            val items = unpackQueueItems(call.argument("items")
                                    ?: error("missing items"))
                            val index: Int = call.argument("index") ?: error("missing index")
                            getPlaybackManager().queueInsert(items, index)
                            result.success(null)
                        }
                        "queueRemove" -> {
                            val startIndex: Int = call.argument("startIndex")
                                    ?: error("missing start index")
                            val length: Int = call.argument("length") ?: error("missing length")
                            getPlaybackManager().queueRemove(startIndex, length)
                            result.success(null)
                        }
                        "queueMove" -> {
                            val fromIndex: Int = call.argument("fromIndex")
                                    ?: error("missing from index")
                            val toIndex: Int = call.argument("toIndex") ?: error("missing to index")
                            getPlaybackManager().queueMove(fromIndex, toIndex)
                            result.success(null)
                        }
                        "queueSelect" -> {
                            val index: Int = call.argument("index") ?: error("missing index")
                            getPlaybackManager().queueSelect(index)
                            result.success(null)
                        }

                        "setRepeatMode" -> {
                            // TODO finish implementing repeat mode
                        }

                        "startPlaybackDeviceSearch" -> routeManager.startSearch(context)
                        "stopPlaybackDeviceSearch" -> routeManager.stopSearch(context)
                        "selectPlaybackDevice" -> {
                            val routeId: String = call.argument("device") ?: error("missing device")
                            routeManager.selectRoute(context, routeId)
                            result.success(null)
                        }
                        else -> error("unrecognized platform method: ${call.method}")
                    }
                }
        status = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.calsignlabs.music/status")
    }

    private fun unpackQueueItems(items: List<Map<String, String>>): List<PlaybackManager.QueueItem> {
        return items.map { item ->
            PlaybackManager.QueueItem(
                    id = item["id"] ?: error("item missing id"),
                    localUri = null, // TODO
                    remoteUri = Uri.parse(item["remoteUri"] ?: error("missing item remote uri"))
            )
        }
    }

    private fun updateCastPlayer() {
        castPlaybackManager?.release()
        val remoteMediaClient = CastContext.getSharedInstance(context)
                ?.sessionManager?.currentCastSession?.remoteMediaClient
        if (remoteMediaClient != null) {
            castPlaybackManager = CastPlaybackManager(remoteMediaClient, this)
        } else {
            castPlaybackManager = null
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        localPlaybackManager = ExoPlayerPlaybackManager(context, this)

        CastContext.getSharedInstance(context).sessionManager.addSessionManagerListener(
                object : SessionManagerListener<CastSession> {
                    override fun onSessionStarted(p0: CastSession?, p1: String?) {
                        updateCastPlayer()
                    }

                    override fun onSessionResumeFailed(p0: CastSession?, p1: Int) {
                        updateCastPlayer()
                    }

                    override fun onSessionSuspended(p0: CastSession?, p1: Int) {
                        updateCastPlayer()
                    }

                    override fun onSessionEnded(p0: CastSession?, p1: Int) {
                        updateCastPlayer()
                    }

                    override fun onSessionResumed(p0: CastSession?, p1: Boolean) {
                        updateCastPlayer()
                    }

                    override fun onSessionStarting(p0: CastSession?) {
                        updateCastPlayer()
                    }

                    override fun onSessionResuming(p0: CastSession?, p1: String?) {
                        updateCastPlayer()
                    }

                    override fun onSessionEnding(p0: CastSession?) {
                        updateCastPlayer()
                    }

                    override fun onSessionStartFailed(p0: CastSession?, p1: Int) {
                        updateCastPlayer()
                    }
                }, CastSession::class.java)
    }

    override fun onDestroy() {
        localPlaybackManager.release()
        castPlaybackManager?.release()
        scheduledExecutorService.shutdown()
        routeManager.stopSearch(context)
        super.onDestroy()
    }

    private fun play(result: MethodChannel.Result) {
        val playbackManager = getPlaybackManager()
        if (playbackManager.isState(PAUSED)) {
            playbackManager.play()
            result.success(null)
        } else {
            result.error("Failed to play", playbackManager.state().name, null)
        }
    }

    private fun pause(result: MethodChannel.Result) {
        val playbackManager = getPlaybackManager()
        if (playbackManager.isState(PLAYING)) {
            playbackManager.pause()
            result.success(null)
        } else {
            result.error("Failed to pause", playbackManager.state().name, null)
        }
    }

    private fun skipTo(position: Long, result: MethodChannel.Result) {
        val playbackManager = getPlaybackManager()
        if (playbackManager.isState(PLAYING, PAUSED)) {
            playbackManager.seek(position)
            result.success(null)
        } else {
            result.error("Failed to seek", playbackManager.state().name, null)
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
                var streamUri: Uri? = null
                var count = 0
                // sometimes it fails to get the stream... try again?
                while (count < 3 && streamUri == null) {
                    streamUri = performGetYoutubeStreamUri(uri)
                    count++
                }
                runOnUiThread {
                    if (streamUri != null) {
                        result.success(streamUri.toString())
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

    private fun performGetYoutubeStreamUri(uri: String): Uri? {
        return try {
            val streamExtractor = youtubeService.getStreamExtractor(youtubeStreamLinkHandler.fromUrl(uri))
            streamExtractor.fetchPage()

            if (streamExtractor.audioStreams.isNotEmpty()) {
                streamExtractor.audioStreams.sortBy { stream -> -stream.averageBitrate }
                Uri.parse(streamExtractor.audioStreams[0].url)
            } else {
                null
            }
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }
}
