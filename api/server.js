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
app.use(cors());

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

// --- API endpoint to save session → code mapping ---
app.post("/api/store-session", async (req, res) => {
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type");

  // ✅ Handle OPTIONS preflight
  if (req.method === "OPTIONS") {
    return res.status(200).end();
  }

  const { sessionId, code } = req.body;
  console.log("📩 Save session request:", { sessionId, code });

  if (!sessionId || !code) {
    console.warn("⚠️ Missing sessionId or code");
    return res.status(400).json({ error: "sessionId and code required" });
  }

  try {
    // Store with 24-hour expiration (86400 seconds)
    await client.setEx(`session:${sessionId}`, 86400, code);
    console.log(`✅ Saved code=${code} for session=${sessionId}`);

    res.json({ 
      success: true, 
      sessionId: sessionId,
      expiresIn: "24 hours"
    });

  } catch (error) {
    console.error("❌ Redis error:", error);
    res.status(500).json({ error: "Failed to store session" });
  }
});

// --- API endpoint to retrieve code by session ID ---
app.get("/api/get-code/:sessionId", async (req, res) => {
  const sessionId = req.params.sessionId;
  console.log("🔍 Lookup request for session:", sessionId);

  try {
    const code = await client.get(`session:${sessionId}`);

    if (!code) {
      console.warn(`⚠️ No code found for session=${sessionId}`);
      return res.status(404).json({ 
        error: "Session not found or expired",
        expired: true 
      });
    }

    console.log(`✅ Found code=${code} for session=${sessionId}`);
    res.json({ 
      success: true, 
      code: code,
      sessionId: sessionId
    });

  } catch (error) {
    console.error("❌ Redis error:", error);
    res.status(500).json({ error: "Failed to retrieve code" });
  }
});

// --- Health check route ---
app.get("/api/health", (req, res) => {
  console.log("💓 Health check ping");
  res.json({ 
    status: "ok", 
    timestamp: new Date().toISOString(),
    service: "deeplink-session-api"
  });
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