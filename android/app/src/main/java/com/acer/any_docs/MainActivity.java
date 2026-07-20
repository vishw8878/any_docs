package com.acer.any_docs;

import android.content.ContentResolver;
import android.database.Cursor;
import android.net.Uri;
import android.provider.OpenableColumns;

import androidx.annotation.NonNull;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;

public class MainActivity extends FlutterActivity {

    private static final String CHANNEL = "any_docs/share_intent";

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        new MethodChannel(
                flutterEngine.getDartExecutor().getBinaryMessenger(),
                CHANNEL
        ).setMethodCallHandler((call, result) -> {
            if ("resolveContentUri".equals(call.method)) {
                String uriString = call.argument("uri");
                if (uriString == null || uriString.isEmpty()) {
                    result.error("invalid_uri", "URI is empty", null);
                    return;
                }

                try {
                    result.success(resolveContentUri(uriString));
                } catch (Exception e) {
                    result.error("resolve_failed", e.getMessage(), null);
                }
                return;
            }

            result.notImplemented();
        });
    }

    private String resolveContentUri(String uriString) throws IOException {
        Uri uri = Uri.parse(uriString);

        if ("file".equalsIgnoreCase(uri.getScheme())) {
            return uri.getPath();
        }

        if (!"content".equalsIgnoreCase(uri.getScheme())) {
            return uriString;
        }

        String displayName = queryDisplayName(uri);
        if (displayName == null || displayName.isEmpty()) {
            displayName = "shared_document";
            String mimeType = getContentResolver().getType(uri);
            if (mimeType != null) {
                if (mimeType.contains("word") || mimeType.contains("msword") || mimeType.contains("officedocument.wordprocessingml")) {
                    displayName += ".docx";
                } else if (mimeType.contains("excel") || mimeType.contains("spreadsheet") || mimeType.contains("vnd.ms-excel")) {
                    displayName += ".xlsx";
                } else {
                    displayName += ".pdf";
                }
            } else {
                displayName += ".pdf";
            }
        } else {
            String lowerName = displayName.toLowerCase();
            if (!lowerName.endsWith(".pdf") && 
                !lowerName.endsWith(".docx") && 
                !lowerName.endsWith(".doc") && 
                !lowerName.endsWith(".xls") && 
                !lowerName.endsWith(".xlsx")) {
                String mimeType = getContentResolver().getType(uri);
                if (mimeType != null) {
                    if (mimeType.contains("word") || mimeType.contains("msword") || mimeType.contains("officedocument.wordprocessingml")) {
                        displayName += ".docx";
                    } else if (mimeType.contains("excel") || mimeType.contains("spreadsheet") || mimeType.contains("vnd.ms-excel")) {
                        displayName += ".xlsx";
                    } else {
                        displayName += ".pdf";
                    }
                } else {
                    displayName += ".pdf";
                }
            }
        }

        File outputDir = new File(getCacheDir(), "shared_documents");
        if (!outputDir.exists()) {
            outputDir.mkdirs();
        }

        File outputFile = new File(outputDir, System.currentTimeMillis() + "_" + displayName);

        try (InputStream inputStream = getContentResolver().openInputStream(uri);
             FileOutputStream outputStream = new FileOutputStream(outputFile)) {
            if (inputStream == null) {
                throw new IOException("Unable to open content URI");
            }

            byte[] buffer = new byte[8192];
            int read;
            while ((read = inputStream.read(buffer)) != -1) {
                outputStream.write(buffer, 0, read);
            }
            outputStream.flush();
        }

        return outputFile.getAbsolutePath();
    }

    private String queryDisplayName(Uri uri) {
        Cursor cursor = null;
        try {
            cursor = getContentResolver().query(uri, null, null, null, null);
            if (cursor != null && cursor.moveToFirst()) {
                int nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME);
                if (nameIndex >= 0) {
                    return cursor.getString(nameIndex);
                }
            }
        } finally {
            if (cursor != null) {
                cursor.close();
            }
        }

        return null;
    }
}
