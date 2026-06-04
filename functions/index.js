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

    let targetTime;
    switch (prayerName) {
      case "Imsak": targetTime = times.Imsak; break;
      case "Subuh": targetTime = times.Subuh; break;
      case "Syuruq": targetTime = times.Syuruq; break;
      case "Dzuhur": targetTime = times.Dzuhur; break;
      case "Ashar": targetTime = times.Ashar; break;
      case "Maghrib": targetTime = times.Maghrib; break;
      case "Isya": targetTime = times.Isya; break;
      default:
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

const monthNames = [
  "Muharram", "Safar", "Rabiul Awal", "Rabiul Akhir", "Jumadil Awal", "Jumadil Akhir",
  "Rajab", "Sya'ban", "Ramadhan", "Syawal", "Dzulqadah", "Dzulhijjah"
];
const shortMonthNames = [
  "Muh", "Saf", "Rb1", "Rb2", "Jm1", "Jm2", "Raj", "Syb", "Ram", "Syw", "Dzq", "Dzh"
];

function getMonthName(month) {
  switch (month) {
    case 1: return "Muharram";
    case 2: return "Safar";
    case 3: return "Rabiul Awal";
    case 4: return "Rabiul Akhir";
    case 5: return "Jumadil Awal";
    case 6: return "Jumadil Akhir";
    case 7: return "Rajab";
    case 8: return "Sya'ban";
    case 9: return "Ramadhan";
    case 10: return "Syawal";
    case 11: return "Dzulqadah";
    case 12: return "Dzulhijjah";
    default: return "";
  }
}

function getShortMonthName(month) {
  switch (month) {
    case 1: return "Muh";
    case 2: return "Saf";
    case 3: return "Rb1";
    case 4: return "Rb2";
    case 5: return "Jm1";
    case 6: return "Jm2";
    case 7: return "Raj";
    case 8: return "Syb";
    case 9: return "Ram";
    case 10: return "Syw";
    case 11: return "Dzq";
    case 12: return "Dzh";
    default: return "";
  }
}

function getIslamicEvent(month, day) {
  if (month === 1 && day === 1) return "Tahun Baru Islam";
  if (month === 1 && day === 10) return "Hari Asyura";
  if (month === 3 && day === 12) return "Maulid Nabi ﷺ";
  if (month === 7 && day === 27) return "Isra Mi'raj";
  if (month === 8 && day === 15) return "Nisfu Sya'ban";
  if (month === 9 && day === 1) return "Awal Ramadhan";
  if (month === 9 && day === 17) return "Nuzulul Qur'an";
  if (month === 10 && day === 1) return "Idul Fitri";
  if (month === 10 && day === 2) return "Idul Fitri (Hari 2)";
  if (month === 12 && day === 9) return "Hari Arafah";
  if (month === 12 && day === 10) return "Idul Adha";
  if (month === 12 && day === 11) return "Hari Tasyrik";
  if (month === 12 && day === 12) return "Hari Tasyrik";
  if (month === 12 && day === 13) return "Hari Tasyrik";
  return null;
}

function getMoonAge(date) {
  const epoch = Date.UTC(2000, 0, 6, 18, 14, 0);
  const diffInMs = date.getTime() - epoch;
  const diffInDays = diffInMs / (1000 * 60 * 60 * 24);
  const lunations = diffInDays / 29.530588853;
  const fractional = lunations - Math.floor(lunations);
  return fractional * 29.530588853;
}

function fromGregorianTabular(date) {
  const day = date.getDate();
  let month = date.getMonth() + 1;
  let year = date.getFullYear();

  if (month < 3) {
    year -= 1;
    month += 12;
  }

  const a = Math.floor(year / 100);
  let b = 2 - a + Math.floor(a / 4);
  if (year < 1583) b = 0;

  const jd = Math.floor(365.25 * (year + 4716)) +
      Math.floor(30.6001 * (month + 1)) +
      day +
      b -
      1524;

  const epochastro = 1948084;
  const z = jd - epochastro;
  const cyc = Math.floor(z / 10631);
  const zRem = z - 10631 * cyc;
  const j = Math.floor((zRem - 8.01 / 60) / 354.36667);
  const iy = 30 * cyc + j;

  const zRem2 = zRem - Math.floor(j * 354.36667 + 8.5 / 30);
  let im = Math.floor((zRem2 + 28.5001) / 29.5);
  if (im === 13) im = 12;
  const id = zRem2 - Math.floor(im * 29.5 - 28.99);

  return { year: iy, month: im, day: id };
}

function convertGregorianToHijri(date, method, offset = 0, isbatDateStr = null) {
  const standard = fromGregorianTabular(date);

  // Find the 1st day of this Hijri month in standard tabular (subtract standard.day - 1 days)
  const firstDayOfHijriMonth = new Date(date.getTime() - (standard.day - 1) * 24 * 60 * 60 * 1000);

  const ageAtStart = getMoonAge(firstDayOfHijriMonth);

  let adjustment = 0;

  if (ageAtStart > 29.0) {
    adjustment = -1;
  }

  if (method === "kemenag") {
    const checkDate = ageAtStart > 29.0
        ? new Date(firstDayOfHijriMonth.getTime() + 24 * 60 * 60 * 1000)
        : firstDayOfHijriMonth;

    const checkAge = getMoonAge(checkDate);

    if (checkAge < 0.35) {
      adjustment -= 1;
    }
  }

  let activeOffset = 0;
  if (method === "kemenag" && isbatDateStr && offset !== 0) {
    try {
      const isbatDate = new Date(isbatDateStr);
      const isbatHijri = fromGregorianTabular(isbatDate);
      if (standard.year === isbatHijri.year && standard.month === isbatHijri.month) {
        activeOffset = offset;
      }
    } catch (_) {}
  }

  const finalAdjustment = adjustment + activeOffset;
  if (finalAdjustment !== 0) {
    const adjustedDate = new Date(date.getTime() + finalAdjustment * 24 * 60 * 60 * 1000);
    return fromGregorianTabular(adjustedDate);
  }

  return standard;
}

/**
 * HTTP endpoint exposing the precise Hijri Calendar converter for other webapps.
 */
exports.getHijriCalendar = onRequest({ cors: true }, async (req, res) => {
  const { date, method, offset, isbatDate } = req.method === "POST" ? req.body : req.query;

  try {
    let parsedDate = new Date();
    if (date) {
      parsedDate = new Date(date);
      if (isNaN(parsedDate.getTime())) {
        res.status(400).send({ error: "Invalid date parameter format" });
        return;
      }
    }

    const calcMethod = (method === "muhammadiyah") ? "muhammadiyah" : "kemenag";
    const dayOffset = offset ? parseInt(offset) : 0;
    
    if (isNaN(dayOffset)) {
      res.status(400).send({ error: "Offset parameter must be an integer" });
      return;
    }

    const hijri = convertGregorianToHijri(parsedDate, calcMethod, dayOffset, isbatDate);
    
    if (typeof hijri.month !== "number" || hijri.month < 1 || hijri.month > 12) {
      res.status(500).send({ error: "Calculated Hijri month is out of range" });
      return;
    }
    
    const mName = getMonthName(hijri.month);
    const sName = getShortMonthName(hijri.month);
    const event = getIslamicEvent(hijri.month, hijri.day);

    res.status(200).send({
      success: true,
      gregorianDate: parsedDate.toISOString(),
      hijri: {
        year: hijri.year,
        month: hijri.month,
        day: hijri.day,
        monthName: mName,
        shortMonthName: sName,
        formatted: `${hijri.day} ${mName} ${hijri.year} H`,
        islamicEvent: event,
        isSpecialDay: event !== null
      },
      params: {
        method: calcMethod,
        offset: dayOffset,
        isbatDate: isbatDate || null
      }
    });
  } catch (error) {
    res.status(500).send({ error: error.message });
  }
});

/**
 * HTTP endpoint returning the current server time (UTC and WIB formatted).
 */
exports.getServerTime = onRequest({ cors: true }, async (req, res) => {
  const now = new Date();
  res.status(200).send({
    success: true,
    utcTime: now.toISOString(),
    epoch: now.getTime(),
    formatted: now.toLocaleString("id-ID", { timeZone: "Asia/Jakarta" }) + " (WIB)"
  });
});


