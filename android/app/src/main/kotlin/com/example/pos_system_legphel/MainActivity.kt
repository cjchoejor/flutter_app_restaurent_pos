package com.example.pos_system_legphel

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Register the NetworkManager plugin
        flutterEngine.plugins.add(NetworkManagerPlugin())
    }
}
