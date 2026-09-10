# SharijaVuba

SharijaVuba is a queue management platform for battery-swap riders and station attendants. It connects the rider experience, the station operations dashboard, and the backend systems that track queue events, notifications, and transaction activity.

## What this repository contains

The project is organised into a few clear parts:

- `rider-pwa`: the rider-facing web app for joining and tracking a queue.
- `station-dashboard`: the attendant dashboard used to manage queue flow and service actions.
- `backend-api`: the main API, queue logic, and event storage.
- `notification-lambda`: the AWS Lambda service responsible for notifications and communication events.
- `infra`: Terraform code for infrastructure provisioning.
- `docs/architecture`: architecture notes and design documentation.
- `ERD design file`: the MoMo XML data-model diagram that defines the event and transaction structure behind the platform.

## The MoMo data structure behind the system

The core data model in this project is built around incoming MoMo SMS messages and the way they are converted into meaningful payment and transaction events. The design is centered on these entities:

- `Users`: people who send, receive, or process money.
- `SMS_Raw`: the original inbound MoMo SMS messages before any parsing or validation.
- `Transactions`: the cleaned, structured financial records created from SMS data.
- `Transaction_Categories`: a lookup for transaction types such as deposits, transfers, payments, or airtime.
- `Transaction_Participants`: the relationship between transactions and users, including roles like sender or receiver.
- `System_Logs`: operational events such as OTPs, reversals, and other processing events.

In simple terms, the flow is:

Incoming MoMo SMS -> raw message capture -> transaction parsing -> categorisation -> participant mapping -> operational logging.

This creates a reliable foundation for tracking financial activity, queue-related events, and system operations in a structured way.

## Local development

Prerequisites: Node.js 20+, Docker, and Terraform for infrastructure work.

```bash
npm install
docker compose up -d
npm run dev
```

## Links

- `High-Level System Architecture`: [Miro](https://miro.com/app/board/uXjVGA8fXmU=/?share_link_id=926089005134)
- `Board Setup`: [Trello](https://trello.com/invite/b/6a9bbeaa0d6c81f1fee0e953/ATTIaa8f1d3d5cd4f826621fe387297fb3d9D4FF2364/sharijavubabatteryqueue)
- `Project Files and Assets`: [Google Drive](https://drive.google.com/file/d/1EixXPlCT5E-BhVtw5jWc8uf2n2ZKBZig/view?usp=sharing) — shared project documents, diagrams, and supporting materials

See each service folder's `package.json` and relevant configuration files for service-specific setup details.
