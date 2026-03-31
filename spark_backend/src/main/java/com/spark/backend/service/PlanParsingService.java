package com.spark.backend.service;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.spark.backend.config.SparkAiProperties;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.Locale;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

@Service
public class PlanParsingService {
    private static final ZoneId DEFAULT_ZONE = ZoneId.of("Asia/Kolkata");
    private static final Pattern IN_MINUTES = Pattern.compile("in\\s+(\\d{1,3})\\s*(m|min|mins|minute|minutes)");
    private static final Pattern IN_HOURS = Pattern.compile("in\\s+(\\d{1,2})\\s*(h|hr|hrs|hour|hours)");
    private static final Pattern EXPLICIT_TIME = Pattern.compile("(?:at\\s*)?(\\d{1,2})(?::(\\d{2}))?\\s*(am|pm)?");
    private static final Pattern NEAR_LOCATION = Pattern.compile(
            "near\\s+(.+?)(?=\\s+(?:in\\s+\\d|at\\s+\\d|today|tonight|tomorrow)\\b|$)",
            Pattern.CASE_INSENSITIVE
    );
    private static final Pattern TITLE_REMOVE_RELATIVE_TIME = Pattern.compile(
            "\\b(in\\s+\\d{1,3}\\s*(?:m|min|mins|minute|minutes|h|hr|hrs|hour|hours))\\b",
            Pattern.CASE_INSENSITIVE
    );
    private static final Pattern TITLE_REMOVE_EXPLICIT_TIME = Pattern.compile(
            "\\b(at\\s*\\d{1,2}(?::\\d{2})?\\s*(?:am|pm)?)\\b",
            Pattern.CASE_INSENSITIVE
    );
    private static final Pattern TITLE_REMOVE_TIME_WORDS = Pattern.compile(
            "\\b(today|tonight|tomorrow|now)\\b",
            Pattern.CASE_INSENSITIVE
    );
    private static final Pattern TITLE_REMOVE_NEAR_BLOCK = Pattern.compile(
            "\\bnear\\s+.+$",
            Pattern.CASE_INSENSITIVE
    );

    private final SparkAiProperties aiProperties;
    private final ObjectMapper objectMapper;
    private final HttpClient httpClient;

    public PlanParsingService(SparkAiProperties aiProperties, ObjectMapper objectMapper) {
        this.aiProperties = aiProperties;
        this.objectMapper = objectMapper;
        this.httpClient = HttpClient.newBuilder()
                .connectTimeout(Duration.ofSeconds(6))
                .build();
    }

    public ParsePlanResult parsePlan(String input, String locationHint) {
        if (input == null || input.isBlank()) {
            throw new IllegalArgumentException("Plan input is required.");
        }
        if (aiProperties.enabled() && "gemini".equalsIgnoreCase(aiProperties.provider())) {
            ParsePlanResult ai = tryGemini(input, locationHint);
            if (ai != null) {
                return ai;
            }
        }
        return heuristicParse(input, locationHint);
    }

    private ParsePlanResult tryGemini(String input, String locationHint) {
        if (aiProperties.geminiApiKey() == null || aiProperties.geminiApiKey().isBlank()) {
            return null;
        }
        try {
            String prompt = """
                    Convert this nearby-plan text into strict JSON:
                    {
                      "title": "string",
                      "category": "sports|study|ride|events|hangout",
                      "locationName": "string",
                      "startsAtIso": "ISO-8601 timestamp in Asia/Kolkata timezone, within next 24 hours, or empty if missing/ambiguous",
                      "maxSpots": integer 1..20,
                      "confidence": number 0..1
                    }
                    Rules:
                    - Keep it concise and practical.
                    - If time is missing or ambiguous (e.g. 'at 6' without AM/PM), keep startsAtIso empty.
                    - If missing location, use location hint.
                    - Output JSON only, no markdown.

                    location_hint: %s
                    user_input: %s
                    """.formatted(locationHint, input);

            Map<String, Object> payload = Map.of(
                    "generationConfig", Map.of(
                            "temperature", 0.1,
                            "responseMimeType", "application/json"
                    ),
                    "contents", new Object[]{
                            Map.of("parts", new Object[]{Map.of("text", prompt)})
                    }
            );

            String body = objectMapper.writeValueAsString(payload);
            String model = (aiProperties.model() == null || aiProperties.model().isBlank())
                    ? "gemini-2.5-flash-lite"
                    : aiProperties.model();
            String apiUrl = "https://generativelanguage.googleapis.com/v1beta/models/"
                    + URLEncoder.encode(model, StandardCharsets.UTF_8)
                    + ":generateContent?key="
                    + URLEncoder.encode(aiProperties.geminiApiKey(), StandardCharsets.UTF_8);

            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(apiUrl))
                    .timeout(Duration.ofMillis(Math.max(aiProperties.timeoutMillis(), 2500)))
                    .header("Content-Type", "application/json")
                    .POST(HttpRequest.BodyPublishers.ofString(body))
                    .build();

            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() < 200 || response.statusCode() >= 300) {
                return null;
            }

            Map<String, Object> root = objectMapper.readValue(response.body(), new TypeReference<>() {});
            String text = extractGeminiText(root);
            if (text == null || text.isBlank()) {
                return null;
            }
            String normalized = stripCodeFence(text).trim();
            Map<String, Object> parsed = objectMapper.readValue(normalized, new TypeReference<>() {});

            String title = asText(parsed.get("title"));
            String category = normalizeCategory(asText(parsed.get("category")));
            String location = asText(parsed.get("locationName"));
            String startsAtIso = asText(parsed.get("startsAtIso"));
            double confidence = asDouble(parsed.get("confidence"), 0.65);
            int maxSpots = asInt(parsed.get("maxSpots"), defaultSpots(category));

            if (title.isBlank()) title = fallbackTitle(input, category);
            title = canonicalTitle(title, category);
            if (location.isBlank()) location = fallbackLocation(input, locationHint);
            Instant startsAt = parseStartsAt(startsAtIso);
            if (startsAt == null) {
                startsAt = inferStartsAt(input);
            }

            return new ParsePlanResult(
                    title,
                    category,
                    location,
                    startsAt,
                    clampSpots(maxSpots),
                    Math.max(0.0, Math.min(1.0, confidence)),
                    "gemini"
            );
        } catch (Exception ignored) {
            return null;
        }
    }

    private ParsePlanResult heuristicParse(String input, String locationHint) {
        String lower = input.toLowerCase(Locale.ENGLISH);
        String category = inferCategory(lower);
        String location = fallbackLocation(input, locationHint);
        Instant startsAt = inferStartsAt(input);
        int maxSpots = inferSpots(lower, category);
        String title = canonicalTitle(fallbackTitle(input, category), category);
        return new ParsePlanResult(
                title,
                category,
                location,
                startsAt,
                clampSpots(maxSpots),
                0.55,
                "heuristic"
        );
    }

    private String fallbackTitle(String input, String category) {
        String trimmed = input.trim();
        if (!trimmed.isEmpty()) {
            String clean = canonicalTitle(trimmed, category);
            return clean.substring(0, 1).toUpperCase(Locale.ENGLISH) + clean.substring(1);
        }
        return switch (category) {
            case "study" -> "Study session";
            case "ride" -> "Ride share";
            case "events" -> "Nearby event";
            case "hangout" -> "Hangout plan";
            default -> "Quick sports plan";
        };
    }

    private String fallbackLocation(String input, String locationHint) {
        Matcher near = NEAR_LOCATION.matcher(input.toLowerCase(Locale.ENGLISH));
        if (near.find()) {
            String raw = near.group(1).trim();
            if (!raw.isBlank()) {
                return toTitleCase(raw);
            }
        }
        return (locationHint == null || locationHint.isBlank()) ? "Nearby" : locationHint;
    }

    private String canonicalTitle(String raw, String category) {
        String text = raw == null ? "" : raw.trim();
        if (text.isEmpty()) return defaultTitleForCategory(category);

        text = TITLE_REMOVE_RELATIVE_TIME.matcher(text).replaceAll("");
        text = TITLE_REMOVE_EXPLICIT_TIME.matcher(text).replaceAll("");
        text = TITLE_REMOVE_TIME_WORDS.matcher(text).replaceAll("");
        text = TITLE_REMOVE_NEAR_BLOCK.matcher(text).replaceAll("");
        text = text.replaceAll("\\s{2,}", " ").trim();
        text = text.replaceAll("[\\s,.;:-]+$", "").trim();

        if (text.isEmpty()) return defaultTitleForCategory(category);
        return text;
    }

    private String defaultTitleForCategory(String category) {
        return switch (category) {
            case "study" -> "Study session";
            case "ride" -> "Ride share";
            case "events" -> "Nearby event";
            case "hangout" -> "Hangout plan";
            default -> "Quick sports plan";
        };
    }

    private Instant inferStartsAt(String input) {
        String lower = input.toLowerCase(Locale.ENGLISH);
        Instant now = Instant.now();

        Matcher mins = IN_MINUTES.matcher(lower);
        if (mins.find()) {
            int value = safeInt(mins.group(1), 30);
            return now.plusSeconds(Math.max(1, Math.min(value, 24 * 60)) * 60L);
        }

        Matcher hours = IN_HOURS.matcher(lower);
        if (hours.find()) {
            int value = safeInt(hours.group(1), 1);
            return now.plusSeconds(Math.max(1, Math.min(value, 24)) * 3600L);
        }

        Matcher explicit = EXPLICIT_TIME.matcher(lower);
        if (explicit.find()) {
            int hour = safeInt(explicit.group(1), -1);
            int minute = safeInt(explicit.group(2), 0);
            String ampm = explicit.group(3);
            if (hour >= 1 && hour <= 12 && minute >= 0 && minute <= 59) {
                if (ampm == null || ampm.isBlank()) {
                    return null;
                }
                int hour24;
                if ("am".equals(ampm)) {
                    hour24 = (hour == 12) ? 0 : hour;
                } else {
                    hour24 = (hour == 12) ? 12 : hour + 12;
                }
                LocalDateTime candidate = LocalDateTime.now(DEFAULT_ZONE)
                        .withHour(hour24)
                        .withMinute(minute)
                        .withSecond(0)
                        .withNano(0);
                if (candidate.atZone(DEFAULT_ZONE).toInstant().isBefore(now.plusSeconds(60))) {
                    candidate = candidate.plusDays(1);
                }
                Instant ts = candidate.atZone(DEFAULT_ZONE).toInstant();
                if (Duration.between(now, ts).toHours() <= 24) {
                    return ts;
                }
            }
        }
        return null;
    }

    private String inferCategory(String lower) {
        if (containsAny(lower, "study", "dsa", "interview", "library", "prep")) return "study";
        if (containsAny(lower, "ride", "airport", "cab", "metro")) return "ride";
        if (containsAny(lower, "event", "show", "open mic", "comedy", "story")) return "events";
        if (containsAny(lower, "coffee", "chai", "hangout", "meetup")) return "hangout";
        return "sports";
    }

    private int inferSpots(String lower, String category) {
        Matcher m = Pattern.compile("(\\d{1,2})\\s*(spots|spot|people|ppl)").matcher(lower);
        if (m.find()) return clampSpots(safeInt(m.group(1), defaultSpots(category)));
        return defaultSpots(category);
    }

    private int defaultSpots(String category) {
        return switch (category) {
            case "ride" -> 2;
            case "study", "hangout" -> 4;
            case "events" -> 6;
            default -> 5;
        };
    }

    private int clampSpots(int value) {
        return Math.max(1, Math.min(value, 20));
    }

    private boolean containsAny(String text, String... keys) {
        for (String key : keys) {
            if (text.contains(key)) return true;
        }
        return false;
    }

    private String normalizeCategory(String raw) {
        if (raw == null) return "sports";
        String c = raw.trim().toLowerCase(Locale.ENGLISH);
        return switch (c) {
            case "sports", "study", "ride", "events", "hangout" -> c;
            default -> inferCategory(c);
        };
    }

    private Instant parseStartsAt(String value) {
        if (value == null || value.isBlank()) return null;
        try {
            return Instant.parse(value);
        } catch (Exception ignored) {
            try {
                LocalDateTime local = LocalDateTime.parse(value, DateTimeFormatter.ISO_LOCAL_DATE_TIME);
                return local.atZone(DEFAULT_ZONE).toInstant();
            } catch (Exception ignoredAgain) {
                return null;
            }
        }
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
        String out = text;
        if (out.startsWith("```")) {
            out = out.replaceFirst("^```(?:json)?", "");
            out = out.replaceFirst("```\\s*$", "");
        }
        return out.trim();
    }

    private String toTitleCase(String text) {
        String[] words = text.trim().split("\\s+");
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < words.length; i++) {
            String w = words[i];
            if (w.isBlank()) continue;
            sb.append(Character.toUpperCase(w.charAt(0)));
            if (w.length() > 1) sb.append(w.substring(1));
            if (i < words.length - 1) sb.append(' ');
        }
        return sb.toString().trim();
    }

    private int safeInt(String raw, int fallback) {
        try {
            return Integer.parseInt(raw);
        } catch (Exception ignored) {
            return fallback;
        }
    }

    private String asText(Object value) {
        return value == null ? "" : value.toString().trim();
    }

    private int asInt(Object value, int fallback) {
        if (value instanceof Number n) return n.intValue();
        try {
            return Integer.parseInt(asText(value));
        } catch (Exception ignored) {
            return fallback;
        }
    }

    private double asDouble(Object value, double fallback) {
        if (value instanceof Number n) return n.doubleValue();
        try {
            return Double.parseDouble(asText(value));
        } catch (Exception ignored) {
            return fallback;
        }
    }

    public record ParsePlanResult(
            String title,
            String category,
            String locationName,
            Instant startsAt,
            int maxSpots,
            double confidence,
            String source
    ) {
    }
}
