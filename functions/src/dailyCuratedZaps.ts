import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

const db = admin.firestore();

const ZAPS_COLLECTION = "zaps";
const ANALYTICS_COLLECTION = "analytics";
const DAILY_CURATED_ZAPS_COLLECTION = "daily_curated_zaps";
const CURATED_COUNT = 100;
const MAX_FETCH_LIMIT = 500; // Maximum zaps to fetch per query

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
      /**
       * Helper function to score zaps by engagement
       */
      async function scoreZaps(
        zapDocs: admin.firestore.QueryDocumentSnapshot[]
      ): Promise<Array<{ zapId: string; score: number }>> {
        if (zapDocs.length === 0) return [];

        // Batch fetch analytics data
        const analyticsPromises = zapDocs.map((doc) =>
          db
            .collection(ANALYTICS_COLLECTION)
            .doc(ZAPS_COLLECTION)
            .collection(ZAPS_COLLECTION)
            .doc(doc.id)
            .get()
        );

        const analyticsDocs = await Promise.all(analyticsPromises);
        const scoredZaps: Array<{ zapId: string; score: number }> = [];

        for (let i = 0; i < zapDocs.length; i++) {
          const zapDoc = zapDocs[i];
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

        return scoredZaps;
      }

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
        .limit(MAX_FETCH_LIMIT)
        .get();

      functions.logger.info(
        `Fetched ${recentZapsSnapshot.docs.length} recent zaps for curation`
      );

      // Score recent zaps
      let scoredZaps = await scoreZaps(recentZapsSnapshot.docs);

      // If we don't have enough zaps, fetch older posts
      if (scoredZaps.length < CURATED_COUNT) {
        functions.logger.info(
          `Only found ${scoredZaps.length} zaps from last 7 days, fetching older posts to reach ${CURATED_COUNT}`
        );

        // Fetch older zaps (older than 7 days)
        const olderZapsSnapshot = await db
          .collection(ZAPS_COLLECTION)
          .where("isDeleted", "==", false)
          .where("parentZapId", "==", null) // Only top-level zaps
          .where("createdAt", "<", sevenDaysAgo)
          .orderBy("createdAt", "desc")
          .limit(MAX_FETCH_LIMIT)
          .get();

        functions.logger.info(
          `Fetched ${olderZapsSnapshot.docs.length} older zaps for curation`
        );

        // Score older zaps
        const olderScoredZaps = await scoreZaps(olderZapsSnapshot.docs);

        // Combine recent and older zaps
        scoredZaps = [...scoredZaps, ...olderScoredZaps];

        functions.logger.info(
          `Combined total: ${scoredZaps.length} zaps (${recentZapsSnapshot.docs.length} recent + ${olderZapsSnapshot.docs.length} older)`
        );
      }

      // Sort by score and take top N
      scoredZaps.sort((a, b) => b.score - a.score);
      const topZapIds = scoredZaps
        .slice(0, CURATED_COUNT)
        .map((item) => item.zapId);

      // Get today's date in YYYY-MM-DD format (UTC)
      const today = new Date();
      const year = today.getUTCFullYear();
      const month = String(today.getUTCMonth() + 1).padStart(2, "0");
      const day = String(today.getUTCDate()).padStart(2, "0");
      const dateString = `${year}-${month}-${day}`;

      // Save to daily curated zaps collection with today's date as document ID
      await db.collection(DAILY_CURATED_ZAPS_COLLECTION).doc(dateString).set({
        zapIds: topZapIds,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        count: topZapIds.length,
        date: dateString,
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
