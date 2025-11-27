# Firebase Cloud Functions

This directory contains Firebase Cloud Functions for the Z app.

## Setup

1. Install dependencies:
```bash
npm install
```

2. Build the TypeScript code:
```bash
npm run build
```

## Deployment

Deploy all functions:
```bash
npm run deploy
```

Or deploy from the project root:
```bash
firebase deploy --only functions
```

## Functions

### sendNotificationOnCreate

Triggers when a new notification document is created in Firestore (`notifications/{notificationId}`).

- Fetches FCM tokens for the notification recipient
- Sends push notification based on notification type
- Handles errors gracefully

