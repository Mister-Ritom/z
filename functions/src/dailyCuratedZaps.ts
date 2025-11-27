import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

const db = admin.firestore();

const ZAPS_COLLECTION = "zaps";
const ANALYTICS_COLLECTION = "analytics";
const DAILY_CURATED_ZAPS_COLLECTION = "daily_curated_zaps";
const CURATED_COUNT = 100;

/**
 * Scheduled function to update daily curated zaps
 * Runs once per day to precompute top 100 zaps
 */
export const updateDailyCuratedZaps = functions
  .region("us-central1")
  .runWith({
    timeoutSeconds: 540, // 9 minutes for batch processing
    memory: "512MB",
  })
  .pubsub.schedule("0 0 * * *") // Run daily at midnight UTC
  .timeZone("UTC")
  .onRun(async (context) => {
    functions.logger.info("Starting daily curated zaps update");

    try {
      // Fetch top zaps from the last 7 days by engagement
      const sevenDaysAgo = admin.firestore.Timestamp.fromDate(
        new Date(Date.now() - 7 * 24 * 60 * 60 * 1000)
      );

      // Get recent zaps
      const recentZapsSnapshot = await db
        .collection(ZAPS_COLLECTION)
        .where("isDeleted", "==", false)
        .where("parentZapId", "==", null) // Only top-level zaps
        .where("createdAt", ">=", sevenDaysAgo)
        .orderBy("createdAt", "desc")
        .limit(500) // Fetch more to score and filter
        .get();

      functions.logger.info(
        `Fetched ${recentZapsSnapshot.docs.length} recent zaps for curation`
      );

      // Score zaps by engagement
      const scoredZaps: Array<{
        zapId: string;
        score: number;
      }> = [];

      // Batch fetch analytics data
      const analyticsPromises = recentZapsSnapshot.docs.map((doc) =>
        db
          .collection(ANALYTICS_COLLECTION)
          .doc(ZAPS_COLLECTION)
          .collection(ZAPS_COLLECTION)
          .doc(doc.id)
          .get()
      );

      const analyticsDocs = await Promise.all(analyticsPromises);

      for (let i = 0; i < recentZapsSnapshot.docs.length; i++) {
        const zapDoc = recentZapsSnapshot.docs[i];
        const analyticsDoc = analyticsDocs[i];
        const zapData = zapDoc.data();
        const analyticsData = analyticsDoc.data() || {};

        const likesCount = (zapData.likesCount as number) || 0;
        const rezapsCount = (zapData.rezapsCount as number) || 0;
        const views = (analyticsData.views as number) || 0;
        const createdAt = zapData.createdAt as admin.firestore.Timestamp;

        // Calculate engagement score
        // Weight: likes (1.0), rezaps (1.5), views (0.5), freshness (0.3)
        const ageInHours =
          (Date.now() - createdAt.toMillis()) / (1000 * 60 * 60);
        const freshnessMultiplier = Math.exp(-ageInHours / 48); // Decay over 48 hours

        const engagementScore =
          (likesCount * 1.0 + rezapsCount * 1.5 + Math.log1p(views) * 0.5) *
          (1 + freshnessMultiplier * 0.3);

        scoredZaps.push({
          zapId: zapDoc.id,
          score: engagementScore,
        });
      }

      // Sort by score and take top N
      scoredZaps.sort((a, b) => b.score - a.score);
      const topZapIds = scoredZaps
        .slice(0, CURATED_COUNT)
        .map((item) => item.zapId);

      // Save to daily curated zaps collection
      await db.collection(DAILY_CURATED_ZAPS_COLLECTION).doc("today").set({
        zapIds: topZapIds,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        count: topZapIds.length,
      });

      functions.logger.info(
        `Successfully updated daily curated zaps: ${topZapIds.length} zaps`
      );

      return null;
    } catch (error) {
      functions.logger.error("Error updating daily curated zaps:", error);
      throw error;
    }
  });

