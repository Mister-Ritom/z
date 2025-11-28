import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

// Initialize Firebase Admin
admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

/**
 * Fetches FCM token(s) for a given user ID
 * @param userId - The user ID to fetch tokens for
 * @returns Array of FCM tokens, or null if not found
 */
async function fetchFcmTokenForUser(
  userId: string
): Promise<string[] | null> {
  try {
    const tokenDoc = await db.collection("fcm_tokens").doc(userId).get();

    if (!tokenDoc.exists) {
      functions.logger.info(`No FCM token found for user: ${userId}`);
      return null;
    }

    const data = tokenDoc.data();
    if (!data || !data.tokens || !Array.isArray(data.tokens)) {
      functions.logger.warn(
        `Invalid token data structure for user: ${userId}`
      );
      return null;
    }

    const tokens = data.tokens as string[];
    if (tokens.length === 0) {
      functions.logger.info(`Empty tokens array for user: ${userId}`);
      return null;
    }

    return tokens;
  } catch (error) {
    functions.logger.error(
      `Error fetching FCM token for user ${userId}:`,
      error
    );
    return null;
  }
}

/**
 * Resolves notification payload based on notification type
 * @param type - The notification type
 * @param fromUserId - The user who triggered the notification
 * @param notificationData - The full notification document data
 * @returns Object with title, body, and data payload
 */
function resolveNotificationPayload(
  type: string,
  fromUserId: string,
  notificationData: admin.firestore.DocumentData
): {
  title: string;
  body: string;
  data: Record<string, string>;
} {
  const zapId = notificationData.zapId || "";
  const notificationId = notificationData.id || "";

  // Base data payload
  const baseData: Record<string, string> = {
    type: type,
    fromUserId: fromUserId,
    notificationId: notificationId,
  };

  // Add zapId if present
  if (zapId) {
    baseData.zapId = zapId;
  }

  switch (type) {
    case "message": {
      return {
        title: "New Message",
        body: "You have a new message",
        data: {
          ...baseData,
          senderId: fromUserId,
        },
      };
    }

    case "follow": {
      return {
        title: "New Follower",
        body: "Someone started following you",
        data: baseData,
      };
    }

    case "like": {
      return {
        title: "New Like",
        body: "Someone liked your zap",
        data: baseData,
      };
    }

    case "rezap": {
      return {
        title: "New Rezap",
        body: "Someone rezapped your zap",
        data: baseData,
      };
    }

    case "reply": {
      return {
        title: "New Reply",
        body: "Someone replied to your zap",
        data: baseData,
      };
    }

    case "mention": {
      return {
        title: "You were mentioned",
        body: "Someone mentioned you in a zap",
        data: baseData,
      };
    }

    default: {
      functions.logger.warn(`Unknown notification type: ${type}`);
      return {
        title: "New Notification",
        body: "You have a new notification",
        data: baseData,
      };
    }
  }
}

/**
 * Sends FCM message to a single token
 * @param token - The FCM token to send to
 * @param payload - The notification payload
 * @returns Promise that resolves when message is sent
 */
async function sendFcmMessage(
  token: string,
  payload: {
    title: string;
    body: string;
    data: Record<string, string>;
  }
): Promise<void> {
  try {
    const message: admin.messaging.Message = {
      token: token,
      notification: {
        title: payload.title,
        body: payload.body,
      },
      data: Object.fromEntries(
        Object.entries(payload.data).map(([key, value]) => [
          key,
          String(value),
        ])
      ),
      android: {
        priority: "high" as const,
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    };

    await messaging.send(message);
    functions.logger.info(`FCM message sent successfully to token: ${token}`);
  } catch (error) {
    functions.logger.error(
      `Error sending FCM message to token ${token}:`,
      error
    );
    throw error;
  }
}

/**
 * Cloud Function triggered when a notification document is created
 * Sends FCM notification to the user
 */
export const sendNotificationOnCreate = functions.firestore
  .document("notifications/{notificationId}")
  .onCreate(async (snap, context) => {
    const notificationId = context.params.notificationId;
    const notificationData = snap.data();

    functions.logger.info(
      `Processing notification: ${notificationId}`,
      notificationData
    );

    // Extract required fields with failsafes
    const type = notificationData?.type;
    const userId = notificationData?.userId;
    const fromUserId = notificationData?.fromUserId;

    // Validate required fields
    if (!type || !userId || !fromUserId) {
      functions.logger.warn(
        `Missing required fields in notification ${notificationId}. ` +
          `type: ${type}, userId: ${userId}, fromUserId: ${fromUserId}`
      );
      return null;
    }

    // Add notification ID to data for reference
    notificationData.id = notificationId;

    // Fetch FCM token for the user
    const tokens = await fetchFcmTokenForUser(userId);

    if (!tokens || tokens.length === 0) {
      functions.logger.info(
        `No FCM token found for user ${userId}, skipping notification send`
      );
      return null;
    }

    // Resolve notification payload based on type
    const payload = resolveNotificationPayload(
      type,
      fromUserId,
      notificationData
    );

    // Send notification to all tokens for the user
    const sendPromises = tokens.map((token) =>
      sendFcmMessage(token, payload).catch((error) => {
        functions.logger.error(
          `Failed to send FCM to token ${token} for user ${userId}:`,
          error
        );
        // Don't throw - continue with other tokens
        return null;
      })
    );

    await Promise.all(sendPromises);

    functions.logger.info(
      `Notification processing completed for ${notificationId}`
    );

    return null;
  });

// Export recommendation functions
export { generateZapRecommendations } from "./recommendations";
export { updateDailyCuratedZaps } from "./dailyCuratedZaps";
export { generateShortRecommendations } from "./shortRecommendations";
export { updateDailyCuratedShorts } from "./dailyCuratedShorts";
export { generateStoryRecommendations } from "./storyRecommendations";

