package com.cricfy.live

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.cricfy.live/player"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "openPlayer") {
                val title = call.argument<String>("title") ?: "Cricfy Live"
                val url = call.argument<String>("url") ?: ""
                val drmKey = call.argument<String>("drmKey")
                val headersMap = call.argument<Map<String, String>>("headers") ?: emptyMap()
                val serversList = call.argument<List<Map<String, Any>>>("servers") ?: emptyList()

                val intent = Intent(this, CricfyPlayerActivity::class.java).apply {
                    putExtra(CricfyPlayerActivity.EXTRA_TITLE, title)
                    putExtra(CricfyPlayerActivity.EXTRA_URL, url)
                    putExtra(CricfyPlayerActivity.EXTRA_DRM_KEY, drmKey)

                    val headersBundle = Bundle()
                    for ((k, v) in headersMap) {
                        headersBundle.putString(k, v)
                    }
                    putExtra(CricfyPlayerActivity.EXTRA_HEADERS, headersBundle)

                    // Convertir la liste des serveurs en JSON
                    val jarr = JSONArray()
                    for (s in serversList) {
                        val jobj = JSONObject()
                        for ((k, v) in s) {
                            if (v is Map<*, *>) {
                                val nestedObj = JSONObject()
                                for ((nk, nv) in v) {
                                    if (nk != null && nv != null) nestedObj.put(nk.toString(), nv.toString())
                                }
                                jobj.put(k, nestedObj)
                            } else {
                                jobj.put(k, v)
                            }
                        }
                        jarr.put(jobj)
                    }
                    putExtra(CricfyPlayerActivity.EXTRA_SERVERS_JSON, jarr.toString())
                }

                startActivity(intent)
                result.success(true)
            } else {
                result.notImplemented()
            }
        }
    }
}
