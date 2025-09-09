// server.js
const express = require("express");
const cors = require("cors"); 
const { createClient } = require("redis");
const dotenv = require("dotenv");

// Load environment variables from root .env
dotenv.config({ path: ".env" });
console.log("✅ Environment variables loaded");

// Create Express app
const app = express();
app.use(express.json());

// --- CORS setup ---
// Allow all origins (for testing/development)
app.use(cors());

// OR restrict to your frontend origin:
// app.use(cors({ origin: "https://your-frontend-domain.com" }));

// Handle preflight OPTIONS requests globally
app.options("*", cors());

// --- Redis connection ---
const client = createClient({
  username: process.env.REDIS_USERNAME,
  password: process.env.REDIS_PASSWORD,
  socket: {
    host: process.env.REDIS_HOST,
    port: process.env.REDIS_PORT,
  },
});

client.on("error", (err) => console.error("❌ Redis Client Error:", err));
client.on("connect", () => console.log("🔌 Connecting to Redis..."));
client.on("ready", () => console.log("✅ Redis is ready!"));
client.on("end", () => console.log("🔒 Redis connection closed"));

// --- API endpoint to save invite code ---
app.post("/api/save-deeplink", async (req, res) => {
  const { deviceId, inviteCode } = req.body;
  console.log("📩 Save request:", { deviceId, inviteCode });

  if (!deviceId || !inviteCode) {
    console.warn("⚠️ Missing deviceId or inviteCode");
    return res.status(400).json({ error: "deviceId and inviteCode required" });
  }

  await client.setEx(`deeplink:${deviceId}`, 86400, inviteCode); // expire in 1 day
  console.log(`✅ Saved inviteCode=${inviteCode} for deviceId=${deviceId}`);

  res.json({ success: true });
});

// --- API endpoint to retrieve invite code ---
app.get("/api/deeplink/:deviceId", async (req, res) => {
  const deviceId = req.params.deviceId;
  console.log("🔍 Lookup request for deviceId:", deviceId);

  const inviteCode = await client.get(`deeplink:${deviceId}`);

  if (!inviteCode) {
    console.warn(`⚠️ No invite code found for deviceId=${deviceId}`);
    return res.status(404).json({ error: "No invite code found" });
  }

  console.log(`✅ Found inviteCode=${inviteCode} for deviceId=${deviceId}`);
  res.json({ inviteCode });
});

// --- Health check route ---
app.get("/api", (req, res) => {
  console.log("💓 Health check ping");
  res.json({ status: "ok" });
});

// --- Start server only after Redis connects ---
async function startServer() {
  try {
    await client.connect();
    const PORT = process.env.PORT || 3000;
    app.listen(PORT, () =>
      console.log(`🚀 Server running on port ${PORT}`)
    );
  } catch (err) {
    console.error("❌ Failed to connect to Redis:", err);
    process.exit(1);
  }
}

startServer();
