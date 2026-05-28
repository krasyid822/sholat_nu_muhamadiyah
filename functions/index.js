const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const { CalculationParameters, Coordinates, PrayerTimes, Madhab } = require("adhan");

admin.initializeApp();

/**
 * Scheduled function running every minute to check active adhan topics,
 * compute their exact local prayer times, and broadcast FCM pushes if there is a match.
 */
exports.checkAndSendAdhanNotifications = onSchedule("* * * * *", async (event) => {
  const db = admin.firestore();
  const messaging = admin.messaging();
  
  const now = new Date();
  
  // 1. Fetch active topics
  const snapshot = await db.collection("active_topics").get();
  if (snapshot.empty) {
    console.log("No active topics found.");
    return;
  }
  
  console.log(`Checking ${snapshot.size} active topics at ${now.toISOString()}`);
  
  const promises = [];
  
  snapshot.forEach((doc) => {
    const topic = doc.id;
    const match = topic.match(/^adzan_lat_(neg|pos)(\d+)_(\d+)_lon_(neg|pos)?(\d+)_(\d+)_(kemenag|muhammadiyah)_(yes|no)$/);
    if (!match) {
      console.log(`Topic format mismatch: ${topic}`);
      return;
    }
    
    const latSign = match[1] === "neg" ? -1 : 1;
    const latInt = parseInt(match[2]);
    const latDec = parseInt(match[3]);
    const lat = latSign * (latInt + latDec / 10);
    
    const lonSign = match[4] === "neg" ? -1 : 1;
    const lonInt = parseInt(match[5]);
    const lonDec = parseInt(match[6]);
    const lon = lonSign * (lonInt + lonDec / 10);
    
    const method = match[7];
    const ihtiyati = match[8] === "yes";
    
    // 2. Calculate prayer times for these coordinates
    const coordinates = new Coordinates(lat, lon);
    const params = new CalculationParameters("Custom", method === "kemenag" ? 20.0 : 18.0, 18.0);
    params.madhab = Madhab.Shafi;
    
    if (ihtiyati) {
      params.adjustments.fajr = 2;
      params.adjustments.dhuhr = 2;
      params.adjustments.asr = 2;
      params.adjustments.maghrib = 2;
      params.adjustments.isha = 2;
    } else {
      params.adjustments.fajr = 0;
      params.adjustments.dhuhr = 0;
      params.adjustments.asr = 0;
      params.adjustments.maghrib = 0;
      params.adjustments.isha = 0;
    }
    
    const today = new Date();
    const prayerTimes = new PrayerTimes(coordinates, today, params);
    const imsak = new Date(prayerTimes.fajr.getTime() - 10 * 60 * 1000);
    
    const times = {
      Imsak: imsak,
      Subuh: prayerTimes.fajr,
      Syuruq: prayerTimes.sunrise,
      Dzuhur: prayerTimes.dhuhr,
      Ashar: prayerTimes.asr,
      Maghrib: prayerTimes.maghrib,
      Isya: prayerTimes.isha
    };
    
    // Check if any prayer time falls in the current 1-minute window
    for (const [prayerName, prayerTime] of Object.entries(times)) {
      const diffMs = Math.abs(now.getTime() - prayerTime.getTime());
      const diffMinutes = diffMs / (60 * 1000);
      
      // If difference is less than 45 seconds, trigger push notification
      if (diffMinutes < 0.75) {
        console.log(`MATCH! Sending notification for ${prayerName} to topic ${topic}`);
        
        const title = `Waktu ${prayerName} Telah Tiba`;
        const body = prayerName === "Imsak" 
          ? "Waktu Imsak telah masuk. Silakan bersiap-siap untuk berpuasa."
          : `Waktunya menunaikan ibadah shalat ${prayerName} untuk wilayah Anda.`;
          
        const message = {
          notification: {
            title: title,
            body: body
          },
          android: {
            notification: {
              sound: "default",
              clickAction: "FLUTTER_NOTIFICATION_CLICK"
            }
          },
          webpush: {
            headers: {
              Urgency: "high"
            },
            fcmOptions: {
              link: "https://al-waqt-9cdb7.web.app/"
            },
            notification: {
              title: title,
              body: body,
              icon: "/icons/Icon-192.png",
              badge: "/icons/Icon-192.png",
              requireInteraction: true
            }
          },
          topic: topic
        };
        
        promises.push(
          messaging.send(message)
            .then((response) => {
              console.log(`Successfully sent message to topic ${topic}:`, response);
            })
            .catch((error) => {
              console.error(`Error sending to topic ${topic}:`, error);
            })
        );
      }
    }
  });
  
  await Promise.all(promises);
});

const { onRequest } = require("firebase-functions/v2/https");

/**
 * HTTP endpoint for testing push notifications directly from the client.
 */
exports.testPushNotification = onRequest({ cors: true }, async (req, res) => {
  const messaging = admin.messaging();
  const { token, title, body } = req.method === "POST" ? req.body : req.query;
  
  if (!token) {
    res.status(400).send("Missing token parameter");
    return;
  }
  
  try {
    const message = {
      notification: {
        title: title || "🕌 Tes Push Server-Side",
        body: body || "Ini adalah push notification asli dari Firebase Cloud Functions!"
      },
      webpush: {
        headers: {
          Urgency: "high"
        },
        fcmOptions: {
          link: "https://al-waqt-9cdb7.web.app/"
        },
        notification: {
          title: title || "🕌 Tes Push Server-Side",
          body: body || "Ini adalah push notification asli dari Firebase Cloud Functions!",
          icon: "/icons/Icon-192.png",
          badge: "/icons/Icon-192.png",
          requireInteraction: true
        }
      },
      token: token
    };
    
    const response = await messaging.send(message);
    res.status(200).send({ success: true, messageId: response });
  } catch (error) {
    res.status(500).send({ error: error.message });
  }
});

/**
 * HTTP endpoint for simulating the adhan scheduler on a specific topic and prayer.
 */
exports.simulateScheduler = onRequest({ cors: true }, async (req, res) => {
  const messaging = admin.messaging();
  const { topic, prayerName } = req.method === "POST" ? req.body : req.query;

  if (!topic || !prayerName) {
    res.status(400).send("Missing topic or prayerName parameter");
    return;
  }

  try {
    const match = topic.match(/^adzan_lat_(neg|pos)(\d+)_(\d+)_lon_(neg|pos)?(\d+)_(\d+)_(kemenag|muhammadiyah)_(yes|no)$/);
    if (!match) {
      res.status(400).send("Invalid topic format");
      return;
    }

    const latSign = match[1] === "neg" ? -1 : 1;
    const latInt = parseInt(match[2]);
    const latDec = parseInt(match[3]);
    const lat = latSign * (latInt + latDec / 10);

    const lonSign = match[4] === "neg" ? -1 : 1;
    const lonInt = parseInt(match[5]);
    const lonDec = parseInt(match[6]);
    const lon = lonSign * (lonInt + lonDec / 10);

    const method = match[7];
    const ihtiyati = match[8] === "yes";

    const coordinates = new Coordinates(lat, lon);
    const params = new CalculationParameters("Custom", method === "kemenag" ? 20.0 : 18.0, 18.0);
    params.madhab = Madhab.Shafi;

    if (ihtiyati) {
      params.adjustments.fajr = 2;
      params.adjustments.dhuhr = 2;
      params.adjustments.asr = 2;
      params.adjustments.maghrib = 2;
      params.adjustments.isha = 2;
    }

    const today = new Date();
    const prayerTimes = new PrayerTimes(coordinates, today, params);
    const imsak = new Date(prayerTimes.fajr.getTime() - 10 * 60 * 1000);

    const times = {
      Imsak: imsak,
      Subuh: prayerTimes.fajr,
      Syuruq: prayerTimes.sunrise,
      Dzuhur: prayerTimes.dhuhr,
      Ashar: prayerTimes.asr,
      Maghrib: prayerTimes.maghrib,
      Isya: prayerTimes.isha
    };

    const targetTime = times[prayerName];
    if (!targetTime) {
      res.status(400).send(`Invalid prayerName: ${prayerName}`);
      return;
    }

    const title = `Waktu ${prayerName} Telah Tiba (Simulasi)`;
    const body = prayerName === "Imsak"
      ? "Waktu Imsak telah masuk. Silakan bersiap-siap untuk berpuasa."
      : `Waktunya menunaikan ibadah shalat ${prayerName} untuk wilayah Anda.`;

    const message = {
      notification: {
        title: title,
        body: body
      },
      webpush: {
        headers: {
          Urgency: "high"
        },
        fcmOptions: {
          link: "https://al-waqt-9cdb7.web.app/"
        },
        notification: {
          title: title,
          body: body,
          icon: "/icons/Icon-192.png",
          badge: "/icons/Icon-192.png",
          requireInteraction: true
        }
      },
      topic: topic
    };

    const response = await messaging.send(message);
    res.status(200).send({ 
      success: true, 
      simulatedTime: targetTime.toISOString(),
      messageId: response 
    });
  } catch (error) {
    res.status(500).send({ error: error.message });
  }
});

/**
 * HTTP endpoint for subscribing a web client token to an FCM topic.
 */
exports.subscribeToTopic = onRequest({ cors: true }, async (req, res) => {
  const messaging = admin.messaging();
  const { token, topic } = req.method === "POST" ? req.body : req.query;
  
  if (!token || !topic) {
    res.status(400).send("Missing token or topic parameter");
    return;
  }
  
  try {
    const response = await messaging.subscribeToTopic(token, topic);
    res.status(200).send({ success: true, response });
  } catch (error) {
    res.status(500).send({ error: error.message });
  }
});

/**
 * HTTP endpoint for unsubscribing a web client token from an FCM topic.
 */
exports.unsubscribeFromTopic = onRequest({ cors: true }, async (req, res) => {
  const messaging = admin.messaging();
  const { token, topic } = req.method === "POST" ? req.body : req.query;
  
  if (!token || !topic) {
    res.status(400).send("Missing token or topic parameter");
    return;
  }
  
  try {
    const response = await messaging.unsubscribeFromTopic(token, topic);
    res.status(200).send({ success: true, response });
  } catch (error) {
    res.status(500).send({ error: error.message });
  }
});
