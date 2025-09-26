package com.example.codeissance_project;

import android.content.Intent;
import android.util.Log;

import androidx.annotation.NonNull;

import java.util.Map;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "ar_navigator_channel";

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
                .setMethodCallHandler(
                        (call, result) -> {
                            switch (call.method) {
                                case "launchAR": { // Added braces for good practice
                                    Intent intent = new Intent(MainActivity.this, ARActivity.class);
                                    startActivity(intent);
                                    result.success(null);
                                    break;
                                }

                                case "updateAR": { // Added braces for good practice
                                    if (call.arguments instanceof Map) {
                                        Map<String, Object> args = (Map<String, Object>) call.arguments;
                                        ARActivity.updateARData(args);
                                        result.success(null);
                                    } else {
                                        result.error("INVALID_ARGUMENT", "Argument must be a Map", null);
                                    }
                                    break;
                                }
                                default: { // Added braces for good practice
                                    result.notImplemented();
                                    break;
                                }
                            }
                        }
                );
    }
}