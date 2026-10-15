package com.cricfy.live

import android.app.Activity
import android.os.Bundle
import android.util.Base64
import android.util.Log
import android.view.View
import android.view.WindowManager
import android.widget.ImageButton
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
    private var currentUrl: String = ""
    private var currentDrmKey: String? = null
    private var currentTitle: String = ""
    private val currentHeaders = HashMap<String, String>()
    private val serversList = ArrayList<ServerItem>()

    data class ServerItem(
        val title: String,
        val streamUrl: String,
        val drmKey: String?,
        val headers: Map<String, String>,
        val isDash: Boolean
    )

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Plein écran et maintien de l'écran allumé
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        hideSystemUi()

        setContentView(R.layout.activity_cricfy_player)

        playerView = findViewById(R.id.cricfy_player_view)

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

        setupCustomControls()
        initPlayer(currentUrl, currentDrmKey, currentHeaders)
    }

    private fun setupCustomControls() {
        val titleView = findViewById<TextView>(R.id.player_title_text)
        titleView?.text = currentTitle

        val backBtn = findViewById<ImageButton>(R.id.player_back_btn)
        backBtn?.setOnClickListener { finish() }

        val serverBtn = findViewById<ImageButton>(R.id.player_servers_btn)
        if (serversList.isNotEmpty()) {
            serverBtn?.visibility = View.VISIBLE
            serverBtn?.setOnClickListener { showServersMenu(it) }
        } else {
            serverBtn?.visibility = View.GONE
        }
    }

    private fun showServersMenu(anchor: View) {
        val popup = PopupMenu(this, anchor)
        for (i in serversList.indices) {
            val s = serversList[i]
            val badge = if (!s.drmKey.isNullOrEmpty()) "[ClearKey DASH]" else if (s.isDash) "[DASH]" else "[HLS]"
            popup.menu.add(0, i, i, "$badge ${s.title}")
        }
        popup.setOnMenuItemClickListener { item ->
            val index = item.itemId
            if (index in serversList.indices) {
                val selected = serversList[index]
                Toast.makeText(this, "Connexion à : ${selected.title}", Toast.LENGTH_SHORT).show()
                currentUrl = selected.streamUrl
                currentDrmKey = selected.drmKey
                currentHeaders.clear()
                currentHeaders.putAll(selected.headers)
                initPlayer(currentUrl, currentDrmKey, currentHeaders)
            }
            true
        }
        popup.show()
    }

    private fun initPlayer(url: String, drmKey: String?, headers: Map<String, String>) {
        if (url.isEmpty()) {
            Toast.makeText(this, "URL de flux vide", Toast.LENGTH_SHORT).show()
            return
        }

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

        // Configuration ClearKey DRM
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
                Log.e(TAG, "Erreur lecture ExoPlayer: ${error.errorCodeName} - ${error.message}", error)
                Toast.makeText(
                    this@CricfyPlayerActivity,
                    "Échec de lecture sur ce serveur (${error.errorCodeName}). Essayez un autre serveur.",
                    Toast.LENGTH_LONG
                ).show()
            }

            override fun onPlaybackStateChanged(playbackState: Int) {
                if (playbackState == Player.STATE_READY) {
                    Log.d(TAG, "Flux prêt et décodé avec succès !")
                }
            }
        })

        exo.prepare()
        exo.playWhenReady = true

        player = exo
        playerView?.player = exo
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
        player?.release()
        player = null
    }
}
