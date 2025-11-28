import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

const db = admin.firestore();

const STORIES_COLLECTION = "stories";
const STORIES_ANALYTICS_COLLECTION = "stories";
const CACHED_STORY_RECOMMENDATIONS_COLLECTION = "cached_story_recommendations";
const MAX_STORY_RESULTS = 200;
const STORY_EXPIRY_HOURS = 24;
const CACHE_EXPIRATION_MS = 6 * 60 * 60 * 1000; // 6 hours (stories expire in 24h, so shorter cache)

/**
 * Get cached story recommendations
 */
async function getCachedStoryRecommendations(): Promise<string[] | null> {
  try {
    const cacheDoc = await db
      .collection(CACHED_STORY_RECOMMENDATIONS_COLLECTION)
      .doc("global")
      .get();

    if (!cacheDoc.exists) return null;

    const data = cacheDoc.data();
    const updatedAt = data?.updatedAt as admin.firestore.Timestamp | undefined;

    if (!updatedAt) return null;

    const cacheAge = Date.now() - updatedAt.toMillis();

    if (cacheAge < CACHE_EXPIRATION_MS) {
      return (data?.storyIds as string[]) || [];
    }

    return null; // Cache expired
  } catch (error) {
    functions.logger.warn("Error fetching story cache:", error);
    return null;
  }
}

/**
 * Save story recommendations to cache
 */
async function saveStoryRecommendationsToCache(
  storyIds: string[]
): Promise<void> {
  try {
    await db
      .collection(CACHED_STORY_RECOMMENDATIONS_COLLECTION)
      .doc("global")
      .set({
        storyIds,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        count: storyIds.length,
      });
  } catch (error) {
    functions.logger.error("Error saving story cache:", error);
  }
}

/**
 * Generate story recommendations by sorting public stories by likes
 */
async function generateStoryRecommendationsList(
  limit: number
): Promise<string[]> {
  const cutoff = admin.firestore.Timestamp.fromDate(
    new Date(Date.now() - STORY_EXPIRY_HOURS * 60 * 60 * 1000)
  );

  const snapshot = await db
    .collection(STORIES_COLLECTION)
    .where("visibility", "==", "public")
    .where("createdAt", ">=", cutoff)
    .orderBy("createdAt", "desc")
    .get();

  if (snapshot.empty) return [];

  const analyticsDocs = await Promise.all(
    snapshot.docs.map((doc) =>
      db
        .collection("analytics")
        .doc(STORIES_ANALYTICS_COLLECTION)
        .collection(STORIES_ANALYTICS_COLLECTION)
        .doc(doc.id)
        .get()
    )
  );

  const stories = snapshot.docs.map((doc, index) => {
    const analytics = analyticsDocs[index].data() || {};
    const likesFromAnalytics = (analytics.likes as number) || 0;
    const docData = doc.data();
    const likesFromDoc = (docData.likes as number) || 0;

    return {
      storyId: doc.id,
      likes: likesFromAnalytics || likesFromDoc,
      createdAt: docData.createdAt as admin.firestore.Timestamp,
    };
  });

  stories.sort((a, b) => {
    if (b.likes === a.likes) {
      return b.createdAt.toMillis() - a.createdAt.toMillis();
    }
    return b.likes - a.likes;
  });

  return stories.map((story) => story.storyId).slice(0, limit);
}

export const generateStoryRecommendations = functions
  .region("us-central1")
  .runWith({
    timeoutSeconds: 30, // Increased for larger story datasets
    memory: "512MB",
  })
  .https.onCall(async (data, context) => {
    const limitParam = (data?.limit as number) || MAX_STORY_RESULTS;
    const limit = Math.min(Math.max(limitParam, 1), MAX_STORY_RESULTS);

    // Try to return cached recommendations first
    const cached = await getCachedStoryRecommendations();

    if (cached && cached.length > 0) {
      const sliced = cached.slice(0, limit);

      functions.logger.info(
        `Returning cached story recommendations (${sliced.length}/${cached.length} stories)`
      );

      // Refresh cache in background if it's getting stale
      const cacheDoc = await db
        .collection(CACHED_STORY_RECOMMENDATIONS_COLLECTION)
        .doc("global")
        .get();
      const cacheData = cacheDoc.data();
      const updatedAt = cacheData?.updatedAt as admin.firestore.Timestamp;
      const cacheAge = Date.now() - updatedAt.toMillis();

      // Refresh if cache is older than 3 hours (half of expiration)
      if (cacheAge > CACHE_EXPIRATION_MS / 2) {
        generateStoryRecommendationsList(MAX_STORY_RESULTS)
          .then((storyIds) => {
            if (storyIds.length > 0) {
              return saveStoryRecommendationsToCache(storyIds);
            }
            return null;
          })
          .catch((error) => {
            functions.logger.error(
              "Background story cache refresh failed:",
              error
            );
          });
      }

      return {
        storyIds: sliced,
        total: cached.length,
        hasMore: cached.length > limit,
        source: "cache",
        generatedAt: new Date().toISOString(),
      };
    }

    // No valid cache: generate recommendations synchronously
    functions.logger.info("Generating story recommendations synchronously");

    const storyIds = await generateStoryRecommendationsList(MAX_STORY_RESULTS);
    const sliced = storyIds.slice(0, limit);

    // Save to cache for next time
    if (storyIds.length > 0) {
      await saveStoryRecommendationsToCache(storyIds);
    }

    return {
      storyIds: sliced,
      total: storyIds.length,
      hasMore: storyIds.length > limit,
      source: "generated",
      generatedAt: new Date().toISOString(),
    };
  });

