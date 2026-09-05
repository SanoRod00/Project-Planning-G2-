# SharijaVuba

Queue management for riders and battery-swap station attendants.

## Workspace

- `rider-pwa`: Rider-facing React progressive web app.
- `station-dashboard`: Station attendant React dashboard.
- `backend-api`: Node.js/Express API and event store.
- `notification-lambda`: AWS Lambda notification worker.
- `infra`: Terraform infrastructure definitions.
- `docs/architecture`: Architecture diagrams and supporting documentation.

## Local development

Prerequisites: Node.js 20+, Docker, and Terraform for infrastructure work.

```bash
npm install
docker compose up -d
npm run dev
```

See each container's `package.json` and `.env.example` for service-specific configuration.