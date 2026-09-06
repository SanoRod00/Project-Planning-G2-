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

## Links

- `High-Level System Architecture`: [Miro](https://miro.com/app/board/uXjVGA8fXmU=/?share_link_id=926089005134).
- `Board Setup`: [Trello](https://trello.com/invite/b/6a9bbeaa0d6c81f1fee0e953/ATTIaa8f1d3d5cd4f826621fe387297fb3d9D4FF2364/sharijavubabatteryqueue).


See each container's `package.json` and `.env.example` for service-specific configuration.
