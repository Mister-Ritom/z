import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

const db = admin.firestore();

const SHORTS_COLLECTION = "shorts";
const ANALYTICS_COLLECTION = "analytics";
const DAILY_CURATED_SHORTS_COLLECTION = "daily_curated_shorts";
const CURATED_SHORTS_COUNT = 120;
const MAX_FETCH_LIMIT = 600;

export const updateDailyCuratedShorts = functions
  .region("us-central1")
  .runWith({
    timeoutSeconds: 540,
    memory: "512MB",
  })
  .pubsub.schedule("0 0 * * *")
  .timeZone("UTC")
  .onRun(async () => {
    functions.logger.info("Starting daily curated shorts update");

    try {
      async function scoreShorts(
        shortDocs: admin.firestore.QueryDocumentSnapshot[]
      ): Promise<Array<{ shortId: string; score: number }>> {
        if (shortDocs.length === 0) return [];

        const analyticsDocs = await Promise.all(
          shortDocs.map((doc) =>
            db
              .collection(ANALYTICS_COLLECTION)
              .doc(SHORTS_COLLECTION)
              .collection(SHORTS_COLLECTION)
              .doc(doc.id)
              .get()
          )
        );

        const scored: Array<{ shortId: string; score: number }> = [];

        for (let i = 0; i < shortDocs.length; i++) {
          const shortDoc = shortDocs[i];
          const analyticsDoc = analyticsDocs[i];
          const shortData = shortDoc.data();
          const analyticsData = analyticsDoc.data() || {};

          const likesCount = (shortData.likesCount as number) || 0;
          const rezapsCount = (shortData.rezapsCount as number) || 0;
          const views = (analyticsData.views as number) || 0;
          const createdAt = shortData.createdAt as admin.firestore.Timestamp;

          const ageInHours =
            (Date.now() - createdAt.toMillis()) / (1000 * 60 * 60);
          const freshnessMultiplier = Math.exp(-ageInHours / 48);

          const engagementScore =
            (likesCount * 1.0 + rezapsCount * 1.5 + Math.log1p(views) * 0.5) *
            (1 + freshnessMultiplier * 0.3);

          scored.push({
            shortId: shortDoc.id,
            score: engagementScore,
          });
        }

        return scored;
      }

      const threeDaysAgo = admin.firestore.Timestamp.fromDate(
        new Date(Date.now() - 3 * 24 * 60 * 60 * 1000)
      );

      const recentShortsSnapshot = await db
        .collection(SHORTS_COLLECTION)
        .where("isDeleted", "==", false)
        .where("createdAt", ">=", threeDaysAgo)
        .orderBy("createdAt", "desc")
        .limit(MAX_FETCH_LIMIT)
        .get();

      let scoredShorts = await scoreShorts(recentShortsSnapshot.docs);

      if (scoredShorts.length < CURATED_SHORTS_COUNT) {
        const olderShortsSnapshot = await db
          .collection(SHORTS_COLLECTION)
          .where("isDeleted", "==", false)
          .where("createdAt", "<", threeDaysAgo)
          .orderBy("createdAt", "desc")
          .limit(MAX_FETCH_LIMIT)
          .get();

        const olderScoredShorts = await scoreShorts(olderShortsSnapshot.docs);
        scoredShorts = [...scoredShorts, ...olderScoredShorts];
      }

      scoredShorts.sort((a, b) => b.score - a.score);
      const topShortIds = scoredShorts
        .slice(0, CURATED_SHORTS_COUNT)
        .map((item) => item.shortId);

      const today = new Date();
      const year = today.getUTCFullYear();
      const month = String(today.getUTCMonth() + 1).padStart(2, "0");
      const day = String(today.getUTCDate()).padStart(2, "0");
      const dateString = `${year}-${month}-${day}`;

      await db
        .collection(DAILY_CURATED_SHORTS_COLLECTION)
        .doc(dateString)
        .set({
          shortIds: topShortIds,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          count: topShortIds.length,
          date: dateString,
        });

      functions.logger.info(
        `Successfully updated daily curated shorts: ${topShortIds.length} entries`
      );
      return null;
    } catch (error) {
      functions.logger.error("Error updating daily curated shorts:", error);
      throw error;
    }
  });

