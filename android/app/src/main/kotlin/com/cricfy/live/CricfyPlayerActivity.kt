package com.cricfy.live

import android.app.Activity
import android.content.Context
import android.content.pm.ActivityInfo
import android.content.res.Configuration
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Base64
import android.util.Log
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.ImageButton
import android.widget.LinearLayout
import android.widget.PopupMenu
import android.widget.TextView
import android.widget.Toast
import androidx.annotation.OptIn
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.drm.DefaultDrmSessionManager
import androidx.media3.exoplayer.drm.FrameworkMediaDrm
import androidx.media3.exoplayer.drm.LocalMediaDrmCallback
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.ui.AspectRatioFrameLayout
import androidx.media3.ui.PlayerView
import org.json.JSONArray
import org.json.JSONObject
import java.nio.charset.StandardCharsets

@OptIn(UnstableApi::class)
class CricfyPlayerActivity : Activity() {

    companion object {
        const val TAG = "CricfyPlayer"
        const val EXTRA_TITLE = "extra_title"
        const val EXTRA_URL = "extra_url"
        const val EXTRA_DRM_KEY = "extra_drm_key"
        const val EXTRA_HEADERS = "extra_headers"
        const val EXTRA_SERVERS_JSON = "extra_servers_json"
    }

    private var player: ExoPlayer? = null
    private var playerView: PlayerView? = null
    private var topBar: View? = null
    private var reconnectBanner: LinearLayout? = null
    private var reconnectText: TextView? = null

    private var currentUrl: String = ""
    private var currentDrmKey: String? = null
    private var currentTitle: String = ""
    private val currentHeaders = HashMap<String, String>()
    private val serversList = ArrayList<ServerItem>()
    private var currentServerIndex = 0

    // Gestion de la reconnexion automatique
    private val mainHandler = Handler(Looper.getMainLooper())
    private var retryCount = 0
    private val maxRetries = 4
    private var isReconnecting = false

    // Aspect Ratio
    private var currentResizeModeIndex = 0
    private val resizeModes = intArrayOf(
        AspectRatioFrameLayout.RESIZE_MODE_FIT,
        AspectRatioFrameLayout.RESIZE_MODE_ZOOM,
        AspectRatioFrameLayout.RESIZE_MODE_FILL
    )
    private val resizeModeLabels = arrayOf("16:9", "ZOOM", "FILL")

    // Plein écran
    private var isFullscreen = true

    data class ServerItem(
        val title: String,
        val streamUrl: String,
        val drmKey: String?,
        val headers: Map<String, String>,
        val isDash: Boolean
    )

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Garder l'écran allumé
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        // Rendu plein écran bord-à-bord fluide sans artefact d'encoche
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P) {
            window.attributes.layoutInDisplayCutoutMode =
                WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        }

        // Détection de Samsung DeX
        val isDex = isSamsungDeX(this)
        if (!isDex) {
            // Sur téléphone : passage automatique en mode paysage sans glitch
            try {
                requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
            } catch (e: Exception) {
                Log.w(TAG, "Impossible de verrouiller l'orientation", e)
            }
        }

        hideSystemUi()
        setContentView(R.layout.activity_cricfy_player)

        playerView = findViewById(R.id.cricfy_player_view)
        topBar = findViewById(R.id.player_top_bar)
        reconnectBanner = findViewById(R.id.reconnect_banner)
        reconnectText = findViewById(R.id.reconnect_text)

        // Récupérer les paramètres d'intention
        currentTitle = intent.getStringExtra(EXTRA_TITLE) ?: "Cricfy Live"
        currentUrl = intent.getStringExtra(EXTRA_URL) ?: ""
        currentDrmKey = intent.getStringExtra(EXTRA_DRM_KEY)

        val headersBundle = intent.getBundleExtra(EXTRA_HEADERS)
        if (headersBundle != null) {
            for (key in headersBundle.keySet()) {
                val v = headersBundle.getString(key)
                if (v != null) currentHeaders[key] = v
            }
        }

        val serversJson = intent.getStringExtra(EXTRA_SERVERS_JSON)
        if (!serversJson.isNullOrEmpty()) {
            try {
                val jarr = JSONArray(serversJson)
                for (i in 0 until jarr.length()) {
                    val obj = jarr.getJSONObject(i)
                    val sTitle = obj.optString("title", "Serveur ${i + 1}")
                    val sUrl = obj.optString("streamUrl", "")
                    val sDrm = if (obj.has("drmKey") && !obj.isNull("drmKey")) obj.getString("drmKey") else null
                    val sDash = obj.optBoolean("isDash", false)
                    val sHeaders = HashMap<String, String>()
                    if (obj.has("headers") && !obj.isNull("headers")) {
                        val hObj = obj.getJSONObject("headers")
                        val it = hObj.keys()
                        while (it.hasNext()) {
                            val k = it.next()
                            sHeaders[k] = hObj.getString(k)
                        }
                    }
                    if (sUrl.isNotEmpty()) {
                        serversList.add(ServerItem(sTitle, sUrl, sDrm, sHeaders, sDash))
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Erreur parsing serveurs", e)
            }
        }

        // Trouver l'index actuel
        for (i in serversList.indices) {
            if (serversList[i].streamUrl == currentUrl) {
                currentServerIndex = i
                break
            }
        }

        setupControls()
        initPlayer(currentUrl, currentDrmKey, currentHeaders)
    }

    private fun isSamsungDeX(context: Context): Boolean {
        val uiMode = context.resources.configuration.uiMode
        if ((uiMode and Configuration.UI_MODE_TYPE_MASK) == Configuration.UI_MODE_TYPE_DESKTOP) {
            return true
        }
        try {
            val config = context.resources.configuration
            val semDesktopModeEnabled = config.javaClass.getField("semDesktopModeEnabled").getInt(config)
            if (semDesktopModeEnabled == 1) return true
        } catch (_: Exception) {}
        return false
    }

    private fun setupControls() {
        val titleView = findViewById<TextView>(R.id.player_title_text)
        titleView?.text = currentTitle

        findViewById<ImageButton>(R.id.player_back_btn)?.setOnClickListener { finish() }

        val serverBtn = findViewById<Button>(R.id.player_servers_btn)
        if (serversList.isNotEmpty()) {
            serverBtn?.visibility = View.VISIBLE
            serverBtn?.setOnClickListener { showServersMenu(it) }
        } else {
            serverBtn?.visibility = View.GONE
        }

        // Bouton Aspect Ratio
        val aspectBtn = findViewById<Button>(R.id.player_aspect_ratio_btn)
        aspectBtn?.text = resizeModeLabels[currentResizeModeIndex]
        aspectBtn?.setOnClickListener {
            currentResizeModeIndex = (currentResizeModeIndex + 1) % resizeModes.size
            val mode = resizeModes[currentResizeModeIndex]
            playerView?.resizeMode = mode
            aspectBtn.text = resizeModeLabels[currentResizeModeIndex]
        }

        // Bouton Rafraîchir
        findViewById<ImageButton>(R.id.player_refresh_btn)?.setOnClickListener {
            retryCount = 0
            Toast.makeText(this, "Actualisation du flux...", Toast.LENGTH_SHORT).show()
            initPlayer(currentUrl, currentDrmKey, currentHeaders)
        }

        // Bouton Plein écran DeX
        findViewById<ImageButton>(R.id.player_fullscreen_btn)?.setOnClickListener {
            isFullscreen = !isFullscreen
            if (isFullscreen) {
                hideSystemUi()
            } else {
                showSystemUi()
            }
        }

        // Auto-masquage de la barre de contrôle
        scheduleAutoHideControls()
        playerView?.setOnClickListener {
            if (topBar?.visibility == View.VISIBLE) {
                topBar?.visibility = View.GONE
            } else {
                topBar?.visibility = View.VISIBLE
                scheduleAutoHideControls()
            }
        }
    }

    private val hideControlsRunnable = Runnable {
        topBar?.visibility = View.GONE
    }

    private fun scheduleAutoHideControls() {
        mainHandler.removeCallbacks(hideControlsRunnable)
        mainHandler.postDelayed(hideControlsRunnable, 4500L)
    }

    private fun showServersMenu(anchor: View) {
        val popup = PopupMenu(this, anchor)
        for (i in serversList.indices) {
            val s = serversList[i]
            val badge = if (!s.drmKey.isNullOrEmpty()) "⚡ [ClearKey DASH]" else if (s.isDash) "[DASH]" else "🟢 [DIRECT HLS]"
            val mark = if (i == currentServerIndex) "✓ " else ""
            popup.menu.add(0, i, i, "$mark$badge ${s.title}")
        }
        popup.setOnMenuItemClickListener { item ->
            val index = item.itemId
            if (index in serversList.indices) {
                switchToServer(index)
            }
            true
        }
        popup.show()
    }

    private fun switchToServer(index: Int) {
        currentServerIndex = index
        val selected = serversList[index]
        Toast.makeText(this, "Serveur : ${selected.title}", Toast.LENGTH_SHORT).show()
        currentUrl = selected.streamUrl
        currentDrmKey = selected.drmKey
        currentHeaders.clear()
        currentHeaders.putAll(selected.headers)

        val titleView = findViewById<TextView>(R.id.player_title_text)
        titleView?.text = "$currentTitle - ${selected.title}"

        retryCount = 0
        initPlayer(currentUrl, currentDrmKey, currentHeaders)
    }

    private fun initPlayer(url: String, drmKey: String?, headers: Map<String, String>) {
        if (url.isEmpty()) {
            Toast.makeText(this, "URL de flux vide", Toast.LENGTH_SHORT).show()
            return
        }

        mainHandler.removeCallbacksAndMessages(null)
        hideReconnectBanner()

        player?.release()
        player = null

        val userAgent = headers["User-Agent"]
            ?: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36"

        val httpDataSourceFactory = DefaultHttpDataSource.Factory()
            .setUserAgent(userAgent)
            .setDefaultRequestProperties(headers)
            .setAllowCrossProtocolRedirects(true)
            .setConnectTimeoutMs(15000)
            .setReadTimeoutMs(15000)

        val mediaSourceFactory = DefaultMediaSourceFactory(httpDataSourceFactory)

        // ClearKey DRM
        val hasClearKey = !drmKey.isNullOrEmpty() && drmKey.contains(":")
        if (hasClearKey) {
            try {
                val parts = drmKey!!.split(":")
                val keyIdHex = parts[0].trim()
                val keyHex = parts[1].trim()

                val keyIdBytes = hexToByteArray(keyIdHex)
                val keyBytes = hexToByteArray(keyHex)

                val b64KeyId = Base64.encodeToString(keyIdBytes, Base64.URL_SAFE or Base64.NO_PADDING or Base64.NO_WRAP)
                val b64Key = Base64.encodeToString(keyBytes, Base64.URL_SAFE or Base64.NO_PADDING or Base64.NO_WRAP)

                val clearKeyJson = """{"keys":[{"kty":"oct","k":"$b64Key","kid":"$b64KeyId"}],"type":"temporary"}"""
                Log.d(TAG, "ClearKey W3C JSON configuré : $clearKeyJson")

                val drmCallback = LocalMediaDrmCallback(clearKeyJson.toByteArray(StandardCharsets.UTF_8))
                val drmSessionManager = DefaultDrmSessionManager.Builder()
                    .setUuidAndExoMediaDrmProvider(C.CLEARKEY_UUID, FrameworkMediaDrm.DEFAULT_PROVIDER)
                    .setMultiSession(true)
                    .build(drmCallback)

                mediaSourceFactory.setDrmSessionManagerProvider { drmSessionManager }
            } catch (e: Exception) {
                Log.e(TAG, "Erreur configuration ClearKey DRM", e)
            }
        }

        val exo = ExoPlayer.Builder(this)
            .setMediaSourceFactory(mediaSourceFactory)
            .build()

        val mediaItemBuilder = MediaItem.Builder().setUri(url)
        if (hasClearKey) {
            mediaItemBuilder.setDrmConfiguration(
                MediaItem.DrmConfiguration.Builder(C.CLEARKEY_UUID).build()
            )
        }

        exo.setMediaItem(mediaItemBuilder.build())
        exo.addListener(object : Player.Listener {
            override fun onPlayerError(error: PlaybackException) {
                Log.w(TAG, "Erreur flux (${error.errorCodeName}): ${error.message}")
                handlePlaybackFailure()
            }

            override fun onPlaybackStateChanged(playbackState: Int) {
                when (playbackState) {
                    Player.STATE_READY -> {
                        hideReconnectBanner()
                        retryCount = 0
                        isReconnecting = false
                        Log.d(TAG, "Flux en lecture avec succès !")
                    }
                    Player.STATE_BUFFERING -> {
                        // Si le buffering reste bloqué plus de 12 secondes, déclencher une reconnexion
                        scheduleBufferingTimeout()
                    }
                    Player.STATE_ENDED -> {
                        // Fin de flux inattendue (coupure réseau sur direct)
                        handlePlaybackFailure()
                    }
                }
            }
        })

        exo.prepare()
        exo.playWhenReady = true

        player = exo
        playerView?.player = exo
        playerView?.resizeMode = resizeModes[currentResizeModeIndex]
    }

    private var bufferingTimeoutRunnable: Runnable? = null
    private fun scheduleBufferingTimeout() {
        bufferingTimeoutRunnable?.let { mainHandler.removeCallbacks(it) }
        bufferingTimeoutRunnable = Runnable {
            if (player?.playbackState == Player.STATE_BUFFERING) {
                Log.w(TAG, "Délai de buffering dépassé -> tentative de reconnexion")
                handlePlaybackFailure()
            }
        }
        mainHandler.postDelayed(bufferingTimeoutRunnable!!, 12000L)
    }

    // Gestion de la reconnexion automatique quand le flux s'arrête
    private fun handlePlaybackFailure() {
        if (isFinishing || isDestroyed) return

        if (retryCount < maxRetries) {
            retryCount++
            isReconnecting = true
            showReconnectBanner("Flux interrompu. Reconnexion automatique ($retryCount/$maxRetries)...")
            mainHandler.postDelayed({
                if (!isFinishing && !isDestroyed) {
                    initPlayer(currentUrl, currentDrmKey, currentHeaders)
                }
            }, 2500L)
        } else {
            // Après épuisement des tentatives sur ce serveur, basculer automatiquement sur le serveur suivant si disponible
            if (serversList.size > 1) {
                val nextIndex = (currentServerIndex + 1) % serversList.size
                showReconnectBanner("Bascule automatique sur le serveur : ${serversList[nextIndex].title}...")
                mainHandler.postDelayed({
                    if (!isFinishing && !isDestroyed) {
                        switchToServer(nextIndex)
                    }
                }, 1500L)
            } else {
                showReconnectBanner("Flux actuellement indisponible. Réessayez dans quelques instants.")
            }
        }
    }

    private fun showReconnectBanner(message: String) {
        reconnectText?.text = message
        reconnectBanner?.visibility = View.VISIBLE
    }

    private fun hideReconnectBanner() {
        reconnectBanner?.visibility = View.GONE
    }

    private fun hexToByteArray(hex: String): ByteArray {
        val clean = hex.trim().replace(" ", "").lowercase()
        val len = clean.length
        val data = ByteArray(len / 2)
        var i = 0
        while (i < len) {
            data[i / 2] = ((Character.digit(clean[i], 16) shl 4) + Character.digit(clean[i + 1], 16)).toByte()
            i += 2
        }
        return data
    }

    private fun hideSystemUi() {
        window.decorView.systemUiVisibility = (
            View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                or View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                or View.SYSTEM_UI_FLAG_FULLSCREEN
        )
    }

    private fun showSystemUi() {
        window.decorView.systemUiVisibility = (
            View.SYSTEM_UI_FLAG_LAYOUT_STABLE
        )
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        // Gestion fluide du redimensionnement (Samsung DeX / mode fenêtré)
        hideSystemUi()
    }

    override fun onResume() {
        super.onResume()
        hideSystemUi()
        player?.play()
    }

    override fun onPause() {
        super.onPause()
        player?.pause()
    }

    override fun onDestroy() {
        super.onDestroy()
        mainHandler.removeCallbacksAndMessages(null)
        player?.release()
        player = null
    }
}
