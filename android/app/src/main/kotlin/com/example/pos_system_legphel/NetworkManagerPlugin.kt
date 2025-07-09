package com.example.pos_system_legphel

import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.*
import java.net.InetAddress

class NetworkManagerPlugin: FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var connectivityManager: ConnectivityManager? = null
    private var mobileNetwork: Network? = null
    private var networkCallback: ConnectivityManager.NetworkCallback? = null
    private var bindingJob: Job? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "network_manager")
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
        connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "bindToMobileNetwork" -> {
                bindToMobileNetwork(result)
            }
            "releaseNetworkBinding" -> {
                releaseNetworkBinding(result)
            }
            "checkWriteSettingsPermission" -> {
                checkWriteSettingsPermission(result)
            }
            "requestWriteSettingsPermission" -> {
                requestWriteSettingsPermission(result)
            }
            "testNetworkBinding" -> {
                testNetworkBinding(result)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun checkWriteSettingsPermission(result: Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val hasPermission = Settings.System.canWrite(context)
            result.success(hasPermission)
        } else {
            result.success(true)
        }
    }

    private fun requestWriteSettingsPermission(result: Result) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val intent = Intent(Settings.ACTION_MANAGE_WRITE_SETTINGS).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                context.startActivity(intent)
            }
            result.success(true)
        } catch (e: Exception) {
            println("❌ Error requesting WRITE_SETTINGS permission: ${e.message}")
            result.success(false)
        }
    }

    private fun forceTrafficThroughCellular(network: Network): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                // First, unbind from any existing network
                connectivityManager?.bindProcessToNetwork(null)
                
                // Wait a moment
                Thread.sleep(1000)
                
                // Now bind to cellular network
                val success = connectivityManager?.bindProcessToNetwork(network) ?: false
                
                if (success) {
                    println("✅ Process successfully bound to cellular network: $network")
                    
                    // Verify the binding worked by testing through this specific network
                    val testResult = testNetworkDirectly(network)
                    println("🧪 Direct network test result: $testResult")
                    
                    return testResult
                } else {
                    println("❌ Failed to bind process to network")
                    return false
                }
            }
            false
        } catch (e: Exception) {
            println("❌ Error forcing traffic through cellular: ${e.message}")
            false
        }
    }

    private fun testNetworkDirectly(network: Network): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                // Test DNS resolution through the specific network
                val addresses = network.getAllByName("8.8.8.8")
                val hasConnectivity = addresses.isNotEmpty()
                println("📡 Direct network test via $network: $hasConnectivity")
                hasConnectivity
            } else {
                false
            }
        } catch (e: Exception) {
            println("❌ Direct network test failed: ${e.message}")
            false
        }
    }

    private fun bindToMobileNetwork(result: Result) {
    // Cancel any existing binding job
        bindingJob?.cancel()
        
        bindingJob = CoroutineScope(Dispatchers.IO).launch {
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    println("🔄 Starting mobile network binding process...")
                    
                    // MODIFIED: Remove NET_CAPABILITY_VALIDATED to avoid permission issues
                    val networkRequest = NetworkRequest.Builder()
                        .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                        // REMOVED: .addCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
                        .addTransportType(NetworkCapabilities.TRANSPORT_CELLULAR)
                        .build()

                    // Use CompletableDeferred to handle async callback properly
                    val bindingResult = CompletableDeferred<Boolean>()
                    var callbackHandled = false

                    networkCallback = object : ConnectivityManager.NetworkCallback() {
                        override fun onAvailable(network: Network) {
                            super.onAvailable(network)
                            if (callbackHandled) return
                            
                            println("📱 Mobile network available: $network")
                            mobileNetwork = network
                            
                            // Launch verification in coroutine
                            CoroutineScope(Dispatchers.IO).launch {
                                try {
                                    // Wait a bit for network to stabilize
                                    delay(3000)
                                    
                                    // Bind the process to use this network FIRST
                                    connectivityManager?.bindProcessToNetwork(network)
                                    println("🔗 Process bound to mobile network: $network")
                                    
                                    // Wait and then verify binding worked
                                    delay(5000)
                                    
                                    if (testInternetConnectivity()) {
                                        println("✅ Successfully bound to mobile network with internet access")
                                        if (!callbackHandled) {
                                            callbackHandled = true
                                            bindingResult.complete(true)
                                        }
                                    } else {
                                        println("⚠️ Mobile network bound but internet test failed - trying longer wait...")
                                        // Try waiting longer
                                        delay(5000)
                                        if (testInternetConnectivity()) {
                                            println("✅ Mobile network internet confirmed after longer wait")
                                            if (!callbackHandled) {
                                                callbackHandled = true
                                                bindingResult.complete(true)
                                            }
                                        } else {
                                            println("❌ Mobile network has no internet connectivity")
                                            if (!callbackHandled) {
                                                callbackHandled = true
                                                bindingResult.complete(false)
                                            }
                                        }
                                    }
                                } catch (e: Exception) {
                                    println("❌ Exception during network binding verification: ${e.message}")
                                    if (!callbackHandled) {
                                        callbackHandled = true
                                        bindingResult.complete(false)
                                    }
                                }
                            }
                        }

                        override fun onUnavailable() {
                            super.onUnavailable()
                            if (callbackHandled) return
                            
                            println("❌ Mobile network unavailable")
                            callbackHandled = true
                            bindingResult.complete(false)
                        }

                        override fun onLost(network: Network) {
                            super.onLost(network)
                            println("⚠️ Mobile network lost: $network")
                            if (mobileNetwork == network) {
                                mobileNetwork = null
                            }
                        }

                        override fun onCapabilitiesChanged(network: Network, networkCapabilities: NetworkCapabilities) {
                            super.onCapabilitiesChanged(network, networkCapabilities)
                            val hasInternet = networkCapabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                            println("📊 Mobile network capabilities changed - Internet capability: $hasInternet")
                        }
                    }

                    // Request network with timeout
                    println("📡 Requesting cellular network...")
                    connectivityManager?.requestNetwork(networkRequest, networkCallback!!)
                    
                    // Wait for result with timeout
                    val success = withTimeoutOrNull(45000) { // 45 second timeout
                        bindingResult.await()
                    } ?: false
                    
                    if (!success && !callbackHandled) {
                        println("⏰ Network binding timed out")
                        releaseNetworkBindingInternal()
                    }
                    
                    withContext(Dispatchers.Main) {
                        result.success(success)
                    }
                } else {
                    println("⚠️ Network binding requires Android 6.0+")
                    withContext(Dispatchers.Main) {
                        result.success(false)
                    }
                }
            } catch (e: Exception) {
                println("❌ Error in bindToMobileNetwork: ${e.message}")
                withContext(Dispatchers.Main) {
                    result.success(false)
                }
            }
        }
    }


    private fun verifyNetworkConnectivity(network: Network): Boolean {
        return try {
            println("🔍 Verifying network connectivity...")
            
            // Test DNS resolution through specific network
            val addresses = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                network.getAllByName("8.8.8.8")
            } else {
                InetAddress.getAllByName("8.8.8.8")
            }
            
            val hasConnectivity = addresses.isNotEmpty()
            println("📡 Network connectivity test: $hasConnectivity")
            hasConnectivity
        } catch (e: Exception) {
            println("❌ Network connectivity verification failed: ${e.message}")
            false
        }
    }

    private fun testInternetConnectivity(): Boolean {
        return try {
            println("🌐 Testing internet connectivity...")
            
            // Test multiple endpoints
            val testHosts = listOf("8.8.8.8", "1.1.1.1", "google.com")
            
            for (host in testHosts) {
                try {
                    val addresses = InetAddress.getAllByName(host)
                    if (addresses.isNotEmpty()) {
                        println("✅ Internet test successful via $host")
                        return true
                    }
                } catch (e: Exception) {
                    println("❌ Internet test failed for $host: ${e.message}")
                }
            }
            
            println("❌ All internet connectivity tests failed")
            false
        } catch (e: Exception) {
            println("❌ Internet connectivity test error: ${e.message}")
            false
        }
    }

    private fun testNetworkBinding(result: Result) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                println("🧪 Testing current network binding...")
                
                val hasInternet = testInternetConnectivity()
                val bindingActive = mobileNetwork != null
                
                val testResult = mapOf(
                    "hasInternet" to hasInternet,
                    "bindingActive" to bindingActive,
                    "mobileNetwork" to (mobileNetwork?.toString() ?: "null")
                )
                
                println("🧪 Test results: $testResult")
                
                withContext(Dispatchers.Main) {
                    result.success(testResult)
                }
            } catch (e: Exception) {
                println("❌ Network binding test error: ${e.message}")
                withContext(Dispatchers.Main) {
                    result.success(mapOf("error" to e.message))
                }
            }
        }
    }

    private fun releaseNetworkBinding(result: Result) {
        bindingJob?.cancel()
        val success = releaseNetworkBindingInternal()
        result.success(success)
    }

    private fun releaseNetworkBindingInternal(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                println("🔓 Releasing network binding...")
                
                // Release process binding
                connectivityManager?.bindProcessToNetwork(null)
                
                // Unregister network callback
                networkCallback?.let {
                    connectivityManager?.unregisterNetworkCallback(it)
                }
                
                mobileNetwork = null
                networkCallback = null
                
                println("✅ Network binding released")
                true
            } else {
                false
            }
        } catch (e: Exception) {
            println("❌ Error releasing network binding: ${e.message}")
            false
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        bindingJob?.cancel()
        releaseNetworkBindingInternal()
    }
}
