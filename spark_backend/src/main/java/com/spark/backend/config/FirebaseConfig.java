package com.spark.backend.config;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;

import javax.annotation.PostConstruct;
import java.io.ByteArrayInputStream;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;

@Configuration
public class FirebaseConfig {

    @Value("${spark.firebase.config-path:}")
    private String configPath;

    @Value("${SPARK_FIREBASE_CONFIG_PATH:}")
    private String envConfigPath;

    @Value("${SPARK_FIREBASE_CREDENTIALS_JSON:}")
    private String credentialsJson;

    @PostConstruct
    public void initialize() {
        try {
            boolean hasDefaultApp = FirebaseApp.getApps()
                    .stream()
                    .anyMatch(app -> FirebaseApp.DEFAULT_APP_NAME.equals(app.getName()));
            if (hasDefaultApp) {
                return;
            }

            FirebaseOptions options;
            String effectiveConfigPath = (configPath != null && !configPath.isBlank())
                    ? configPath
                    : envConfigPath;

            if (credentialsJson != null && !credentialsJson.isBlank()) {
                try (InputStream jsonStream = new ByteArrayInputStream(
                        credentialsJson.getBytes(StandardCharsets.UTF_8))) {
                    options = FirebaseOptions.builder()
                            .setCredentials(GoogleCredentials.fromStream(jsonStream))
                            .build();
                }
            } else if (effectiveConfigPath != null && !effectiveConfigPath.isBlank()) {
                try (InputStream serviceAccount = new FileInputStream(effectiveConfigPath)) {
                    options = FirebaseOptions.builder()
                            .setCredentials(GoogleCredentials.fromStream(serviceAccount))
                            .build();
                }
            } else {
                // Initialize with ADC (GOOGLE_APPLICATION_CREDENTIALS or GCP runtime identity)
                options = FirebaseOptions.builder()
                        .setCredentials(GoogleCredentials.getApplicationDefault())
                        .build();
            }

            FirebaseApp.initializeApp(options);
            System.out.println("Firebase Admin initialized successfully.");
        } catch (IOException e) {
            System.err.println("Failed to initialize Firebase Admin: " + e.getMessage());
            throw new IllegalStateException("Firebase Admin initialization failed", e);
        } catch (Exception e) {
            System.err.println("Unexpected Firebase Admin initialization error: " + e.getMessage());
            throw new IllegalStateException("Firebase Admin initialization failed", e);
        }
    }
}
