package com.spark.backend.service;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.spark.backend.config.SparkAiProperties;
import org.springframework.stereotype.Service;

import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.List;
import java.util.Locale;
import java.util.Map;

@Service
public class AiModerationService {
    private static final List<String> BLOCKED_WORD_HINTS = List.of(
            "kill", "bomb", "hate", "terror", "abuse", "slur", "nude", "sex", "drug"
    );

    private final SparkAiProperties aiProperties;
    private final ObjectMapper objectMapper;
    private final HttpClient httpClient;

    public AiModerationService(SparkAiProperties aiProperties, ObjectMapper objectMapper) {
        this.aiProperties = aiProperties;
        this.objectMapper = objectMapper;
        this.httpClient = HttpClient.newBuilder()
                .connectTimeout(Duration.ofSeconds(6))
                .build();
    }

    public ModerationResult moderateSparkContent(String title, String note) {
        final String normalizedTitle = title == null ? "" : title.trim();
        final String normalizedNote = note == null ? "" : note.trim();
        if (normalizedTitle.isBlank()) {
            return new ModerationResult(false, "Title is required.", normalizedTitle, normalizedNote, "validation");
        }

        ModerationResult ai = tryGeminiModeration(normalizedTitle, normalizedNote);
        if (ai != null) {
            return ai;
        }
        return heuristicModeration(normalizedTitle, normalizedNote);
    }

    private ModerationResult tryGeminiModeration(String title, String note) {
        if (!aiProperties.enabled()) return null;
        if (!"gemini".equalsIgnoreCase(aiProperties.provider())) return null;
        if (aiProperties.geminiApiKey() == null || aiProperties.geminiApiKey().isBlank()) return null;

        try {
            final String model = (aiProperties.model() == null || aiProperties.model().isBlank())
                    ? "gemini-2.5-flash-lite"
                    : aiProperties.model();
            final String prompt = """
                    You are moderating user content for a hyperlocal real-time meetup app.
                    Allow only neutral event coordination text.
                    Block content that includes profanity, hate, harassment, explicit sexual content,
                    illegal activity coordination, self-harm promotion, and provocative religious/political mobilization.

                    Return JSON only:
                    {
                      "allowed": true/false,
                      "reason": "short reason",
                      "safeTitle": "sanitized neutral title",
                      "safeNote": "sanitized neutral note"
                    }

                    Keep edits minimal and preserve intent.
                    If blocked, safeTitle/safeNote may be empty.

                    title: %s
                    note: %s
                    """.formatted(title, note == null ? "" : note);

            final Map<String, Object> payload = Map.of(
                    "generationConfig", Map.of(
                            "temperature", 0.0,
                            "responseMimeType", "application/json"
                    ),
                    "contents", new Object[]{
                            Map.of("parts", new Object[]{Map.of("text", prompt)})
                    }
            );

            final String body = objectMapper.writeValueAsString(payload);
            final String apiUrl = "https://generativelanguage.googleapis.com/v1beta/models/"
                    + URLEncoder.encode(model, StandardCharsets.UTF_8)
                    + ":generateContent?key="
                    + URLEncoder.encode(aiProperties.geminiApiKey(), StandardCharsets.UTF_8);

            final HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(apiUrl))
                    .timeout(Duration.ofMillis(Math.max(aiProperties.timeoutMillis(), 2500)))
                    .header("Content-Type", "application/json")
                    .POST(HttpRequest.BodyPublishers.ofString(body))
                    .build();

            final HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() < 200 || response.statusCode() >= 300) {
                return null;
            }

            Map<String, Object> root = objectMapper.readValue(response.body(), new TypeReference<>() {});
            String text = extractGeminiText(root);
            if (text == null || text.isBlank()) return null;
            String normalized = stripCodeFence(text);
            Map<String, Object> parsed = objectMapper.readValue(normalized, new TypeReference<>() {});

            boolean allowed = asBoolean(parsed.get("allowed"), true);
            String reason = asText(parsed.get("reason"));
            String safeTitle = asText(parsed.get("safeTitle"));
            String safeNote = asText(parsed.get("safeNote"));

            if (safeTitle.isBlank()) safeTitle = title;
            if (safeNote.isBlank()) safeNote = note == null ? "" : note;
            if (reason.isBlank()) reason = allowed ? "Allowed" : "Content policy violation";

            return new ModerationResult(allowed, reason, safeTitle, safeNote, "gemini");
        } catch (Exception ignored) {
            return null;
        }
    }

    private ModerationResult heuristicModeration(String title, String note) {
        String joined = (title + " " + note).toLowerCase(Locale.ENGLISH);
        for (String blocked : BLOCKED_WORD_HINTS) {
            if (joined.contains(blocked)) {
                return new ModerationResult(
                        false,
                        "Please keep spark text safe and neutral.",
                        title,
                        note,
                        "heuristic"
                );
            }
        }
        return new ModerationResult(true, "Allowed", title, note, "heuristic");
    }

    private String extractGeminiText(Map<String, Object> root) {
        Object cands = root.get("candidates");
        if (!(cands instanceof Iterable<?> iterable)) return null;
        for (Object c : iterable) {
            if (!(c instanceof Map<?, ?> cand)) continue;
            Object contentObj = cand.get("content");
            if (!(contentObj instanceof Map<?, ?> content)) continue;
            Object partsObj = content.get("parts");
            if (!(partsObj instanceof Iterable<?> parts)) continue;
            for (Object p : parts) {
                if (!(p instanceof Map<?, ?> part)) continue;
                Object text = part.get("text");
                if (text != null) return text.toString();
            }
        }
        return null;
    }

    private String stripCodeFence(String text) {
        String out = text.trim();
        if (out.startsWith("```")) {
            out = out.replaceFirst("^```(?:json)?", "");
            out = out.replaceFirst("```\\s*$", "");
        }
        return out.trim();
    }

    private String asText(Object value) {
        return value == null ? "" : value.toString().trim();
    }

    private boolean asBoolean(Object value, boolean fallback) {
        if (value instanceof Boolean b) return b;
        if (value == null) return fallback;
        String text = value.toString().trim().toLowerCase(Locale.ENGLISH);
        if ("true".equals(text)) return true;
        if ("false".equals(text)) return false;
        return fallback;
    }

    public record ModerationResult(
            boolean allowed,
            String reason,
            String safeTitle,
            String safeNote,
            String source
    ) {
    }
}
