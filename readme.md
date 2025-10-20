# Ambulance Tracking System (ATS) — Final Year Project

This repository contains the Ambulance Tracking System (ATS) — a final-year project implementing a real-time ambulance tracking and alerting system. The project is split into two main parts:
- backend: Node.js + TypeScript server with Express, Socket.IO, MongoDB and Redis for real-time location handling and proximity alerts.
- frontend: Flutter mobile app (Dart) using `flutter_map` for map UI and `socket_io_client` for realtime communication.

This README describes how the system is organized, how to run it locally, the API and socket contract, and troubleshooting tips.
## Table of contents

- Project overview
- Tech stack
- Repository structure
- Backend — setup & run
	- Environment variables
	- Scripts
- API endpoints
- Socket events
- Redis keys
- Frontend — setup & run
- Development notes & contribution
- Troubleshooting
- License & contact

## Project overview
The system allows two main roles:

- driver (ambulance/ambulance driver): sends periodic GPS location updates to the server.
- police: receives map updates and targeted proximity alerts when an ambulance is nearby.
The backend receives location updates via Socket.IO, stores/matches police locations in Redis (geospatial index) and broadcasts map updates / proximity alerts. Authentication is provided by JWT tokens returned by the backend upon signup/login.

## Tech stack
- Backend: Node.js + TypeScript, Express, Socket.IO, Mongoose (MongoDB), Redis (node redis client), bcrypt, JSON Web Tokens.
- Frontend: Flutter (Dart), flutter_map (OpenStreetMap), socket_io_client, provider, shared_preferences.

## Repository structure
- backend/
	- package.json — Node dependencies & scripts
	- tsconfig.json — TypeScript config
	- src/
		- index.ts — server entry (Express + Socket.IO)
		- redisClient.ts — Redis client initialization
	- routes/routes.ts — Express routes for auth
	- controller/authController.ts — signup/login handlers
	- controller/locationController.ts — socket handlers (join, updateLocation, disconnect)
		- model/userModel.ts — Mongoose user model
- frontend/
	- pubspec.yaml — Flutter deps
	- lib/main.dart — Flutter app entry
	- lib/services/socket_io_service.dart — socket service (referenced in the app)

## Backend — setup & run
Prerequisites:

- Node.js (v16+ recommended)
- MongoDB running locally or reachable via a connection string
- Redis server running locally or reachable via a connection URL
- (Optional) TypeScript installed globally or available as a dependency

From PowerShell (Windows) — commands assume you're in the repository root:
```powershell
cd backend
npm install
# If you don't have typescript installed globally and you see errors for `tsc`, either install it globally:
# npm i -g typescript
# or add it as a devDependency in package.json and install again.

# Set JWT secret for development (PowerShell):
$env:JWT_SECRET = 'changeme'

# Start the backend (development build script compiles TypeScript then runs):
npm run dev
```

Notes:

- The `dev` script runs `tsc -b && node dist/index.js`. If `tsc` is not available, install TypeScript.
- MongoDB connection string is currently hardcoded to `mongodb://localhost:27017/ats` inside `src/index.ts`. Update it if needed.
- Redis client is configured to `redis://localhost:6379` inside `src/redisClient.ts`.

### Environment variables
- JWT_SECRET — secret used to sign/verify JWT tokens (default fallbacks exist in code but you should set this in production).

### API endpoints (Express)
- POST /api/v1/user/signup
	- Request body: { username: string, password: string, role: 'driver' | 'police' }
	- Response: { success, message, token, role, id }
- POST /api/v1/user/login
	- Request body: { username: string, password: string }
	- Response: { success, message, token, role, id }
Example (signup):

```json
POST /api/v1/user/signup
{
	"username": "alice",
	"password": "password123",
	"role": "driver"
}
```

### Socket.IO contract (server side)

Connect to the Socket.IO server at the same host/port as the backend (default: http://localhost:5000). You can provide the JWT token either in the handshake `auth` or as a query parameter; the server will try to verify it and attach user info to the socket.

Client events (emit to server):

- `join` — payload: { userId: string, role: 'police' | 'driver', location?: { lat, lng } }
	- Called when a client wants to identify itself and (optionally) share location.

- `updateLocation` — payload: { ambulanceId: string, lat: number, lng: number }
	- Sent by driver/ambulance to update position.

Server emits (to clients):

- `ambulancePositionUpdate` — broadcast to 'police' room when any ambulance updates location: { ambulanceId, lat, lng }
- `ambulanceProximityAlert` — targeted emit to a police officer socket when an ambulance is found nearby: { ambulanceId, message }

Disconnect handling: the server cleans Redis mappings and removes police locations when sockets disconnect.

### Redis keys used

- `police_locations` — geospatial set used to store police officer positions (Redis GEO commands).
- `user_sockets` — Redis Hash mapping userId -> socket.id for targeted notifications.

## Frontend — setup & run

Prerequisites:

- Flutter SDK (matching project environment; see `frontend/pubspec.yaml` for Dart SDK constraints)
- A connected device or emulator

From PowerShell:

```powershell
cd frontend
flutter pub get
flutter run -d <deviceId>
```

Notes for the frontend:

- The app uses `flutter_map` (OpenStreetMap) for map rendering and `socket_io_client` to connect to the backend Socket.IO server.
- Tokens from login/signup should be stored in `shared_preferences` and included when establishing the socket connection (either as `auth: { token }` or as query param).
- The Flutter entry point is `lib/main.dart` which registers a `SocketService` provider. The socket service path may be `lib/services/socket_io_service.dart` (adjust if your project organizes services differently).

## Development notes & contribution

- The backend TypeScript configuration uses `rootDir: ./src` and `outDir: ./dist` with `tsc -b` in the `dev` script.
- If you add TypeScript-only devDependencies (like `typescript`, `ts-node`, or `nodemon`), update `backend/package.json` accordingly.
- Keep secrets (like production MongoDB/Redis URLs and real JWT secret) out of version control. Use environment variables or a secrets manager.

To contribute:

1. Fork the repository
2. Create a feature branch
3. Add tests where applicable
4. Open a pull request describing your changes

## Troubleshooting

- Socket authentication warnings: The server currently allows unauthenticated sockets but logs verification errors — ensure you send a valid JWT in `auth` or query.
- Redis connection failure: `src/redisClient.ts` will exit the process on connection failure. Make sure Redis is running on `localhost:6379`, or change the URL in that file.
- MongoDB connection issues: ensure MongoDB is running and accessible at the configured URI.
- `tsc` not found when running `npm run dev`: install TypeScript globally (`npm i -g typescript`) or add it as a dev dependency and add a local script (recommended).

## Quick try-it guide (local dev)

1. Start MongoDB and Redis locally (or via Docker):

```powershell
# Example Docker commands (PowerShell):
docker run -d --name ats-mongo -p 27017:27017 mongo:6
docker run -d --name ats-redis -p 6379:6379 redis:7
```

2. Start backend

```powershell
cd backend
npm install
$env:JWT_SECRET = 'dev_secret'
npm run dev
```

3. Start Flutter app

```powershell
cd frontend
flutter pub get
flutter run
```

## License & contact

This project uses packages whose licenses are shown in each package's manifest. The repository license is ISC (or unspecified) — update as appropriate.

If you want changes or want me to add a diagram, CI/CD workflow, or Dockerfiles for the services, tell me what you'd like next and I can add them.

---
Generated: README tailored for this workspace. If you want a shorter README, a README just for the backend or frontend, or additional assets (ER diagram, architecture diagram), say which and I will add them.

