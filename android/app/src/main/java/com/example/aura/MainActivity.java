package com.example.aura;

import android.app.Activity;
import android.content.Intent;
import android.net.Uri;


import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;

/**
 * Aura's Android host: plain FlutterActivity (no AppCompat) + three tiny
 * MethodChannels so Dart stays plugin-free (no Gradle plugin resolution):
 *  - aura/files: getFilesDir (same filesDir as v8, so aura.json carries over),
 *    openUrl, mailto, pickImage (copies the picked image into filesDir and
 *    returns that path, since Dart cannot read content:// URIs directly).
 * Splash (v9.15): the animated-picture splash lives entirely in Dart
 * (assets/videos/splash.webp shown by the app root for ~2s). No native
 * video code remains here: the v9.12 VideoView overlay, v9.13 SplashActivity
 * and v9.14 TextureView/MediaPlayer approaches all failed to show video on
 * the user's phone, so Android MediaPlayer is no longer used at all.
 */
public class MainActivity extends FlutterActivity {
    private static final int PICK_IMAGE = 101;
    private MethodChannel.Result pendingPick;

    @Override
    public void configureFlutterEngine(FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), "aura/files")
            .setMethodCallHandler(new MethodChannel.MethodCallHandler() {
                @Override
                public void onMethodCall(MethodCall call, MethodChannel.Result result) {
                    switch (call.method) {
                        case "getFilesDir":
                            result.success(getFilesDir().getAbsolutePath());
                            break;
                        case "openUrl": {
                            try {
                                String url = call.argument("url");
                                if (url == null) url = (String) call.arguments;
                                Intent intent = new Intent(Intent.ACTION_VIEW, Uri.parse(url));
                                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                                startActivity(intent);
                                result.success(null);
                            } catch (Exception e) {
                                result.error("OPEN_URL_FAILED", e.getMessage(), null);
                            }
                            break;
                        }
                        case "mailto": {
                            try {
                                String email = call.argument("email");
                                if (email == null) email = (String) call.arguments;
                                try {
                                    startActivity(new Intent(Intent.ACTION_SENDTO, Uri.parse("mailto:" + email)));
                                    result.success(null);
                                } catch (android.content.ActivityNotFoundException e) {
                                    // No mail app on the phone: fall back to Gmail
                                    // compose in the browser instead of doing nothing.
                                    Intent web = new Intent(Intent.ACTION_VIEW, Uri.parse("https://mail.google.com/mail/?view=cm&to=" + Uri.encode(email)));
                                    web.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                                    startActivity(web);
                                    result.success(null);
                                }
                            } catch (Exception e) {
                                result.error("MAILTO_FAILED", e.getMessage(), null);
                            }
                            break;
                        }
                        case "pickImage": {
                            pendingPick = result;
                            Intent intent = new Intent(Intent.ACTION_GET_CONTENT);
                            intent.setType("image/*");
                            intent.addCategory(Intent.CATEGORY_OPENABLE);
                            startActivityForResult(Intent.createChooser(intent, "Choose image"), PICK_IMAGE);
                            break;
                        }
                        default:
                            result.notImplemented();
                            break;
                    }
                }
            });
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode == PICK_IMAGE && pendingPick != null) {
            MethodChannel.Result r = pendingPick;
            pendingPick = null;
            if (resultCode == Activity.RESULT_OK && data != null && data.getData() != null) {
                try {
                    Uri uri = data.getData();
                    File out = new File(getFilesDir(), "bg_image.jpg");
                    InputStream in = getContentResolver().openInputStream(uri);
                    OutputStream os = new FileOutputStream(out);
                    byte[] buf = new byte[8192];
                    int n;
                    while ((n = in.read(buf)) != -1) os.write(buf, 0, n);
                    os.close();
                    in.close();
                    r.success(out.getAbsolutePath());
                } catch (Exception e) {
                    r.success(null);
                }
            } else {
                r.success(null);
            }
        }
    }
}
