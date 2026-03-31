# Spark Backend (Spring Boot)

Production-oriented backend starter for Spark with:
- **Redis** for live sparks (TTL + geo-nearby reads)
- **PostgreSQL** for durable data (events, participants, history)

## Stack
- Java 21
- Spring Boot 3
- Spring Data JPA + PostgreSQL
- Spring Data Redis (Lettuce)
- Flyway migrations

## Run locally

1. Start infra:
```bash
cd /Users/saurav/Documents/Playground/spark_backend
docker compose up -d
```

2. Run app:
```bash
cd /Users/saurav/Documents/Playground/spark_backend
./mvnw spring-boot:run
```

If `mvnw` is missing, use your local Maven:
```bash
mvn spring-boot:run
```

## Environment
Use `.env.example` values or export env vars:
- `POSTGRES_URL`
- `POSTGRES_USER`
- `POSTGRES_PASSWORD`
- `REDIS_URL`
- `SPARK_TTL_SECONDS`

## APIs

### Create spark
`POST /api/v1/sparks`
```json
{
  "hostUserId": "u_1",
  "category": "sports",
  "title": "Cricket at 6 near park",
  "note": "Bring bat if possible",
  "locationName": "Kudlu Gate",
  "latitude": 12.8914,
  "longitude": 77.6387,
  "startsAt": "2026-03-29T13:30:00Z",
  "endsAt": "2026-03-29T15:00:00Z",
  "maxSpots": 8
}
```

### Nearby sparks (paginated)
`GET /api/v1/sparks/nearby?lat=12.89&lng=77.63&radiusKm=5&page=0&size=20`

### Join spark
`POST /api/v1/sparks/{sparkId}/join`
```json
{"userId":"u_2"}
```

### Leave spark
`POST /api/v1/sparks/{sparkId}/leave`
```json
{"userId":"u_2"}
```

### Get spark
`GET /api/v1/sparks/{sparkId}`

## Design notes
- Redis key per live spark: `spark:live:{id}` with TTL (default 24h)
- Redis geo index key: `sparks:geo`
- Postgres remains source of truth for analytics/history
- Nearby feed uses Redis geo for low-latency read path
