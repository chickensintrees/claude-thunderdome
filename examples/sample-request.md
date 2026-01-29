# Request: Add health check endpoint

## Intent
Add a `/health` endpoint that returns server status for monitoring and load balancer health checks.

## Context
- Express server exists at `src/server.ts`
- No existing health check endpoint
- Should return JSON
- No authentication required

## Tasks
- Add GET /health route to server
- Return JSON with status, timestamp, and version
- Add basic test for the endpoint

## Done When
- GET /health returns 200 with JSON body
- Response includes: `{ "status": "ok", "timestamp": "...", "version": "..." }`
- Test exists and passes
