// server.js
import express from "express";
import { createClient } from "redis";
import dotenv from "dotenv";

// Load environment variables
dotenv.config();

const app = express();
app.use(express.json());

// --- Redis connection ---
const client = createClient({
  username: process.env.REDIS_USERNAME,
  password: process.env.REDIS_PASSWORD,
  socket: {
    host: process.env.REDIS_HOST,
    port: process.env.REDIS_PORT,
  },
});

client.on("error", (err) => console.error("Redis Client Error", err));
await client.connect();

// --- API endpoint to save invite code ---
app.post("/save-deeplink", async (req, res) => {
  const { deviceId, inviteCode } = req.body;

  if (!deviceId || !inviteCode) {
    return res.status(400).json({ error: "deviceId and inviteCode required" });
  }

  await client.setEx(`deeplink:${deviceId}`, 86400, inviteCode); // expire in 1 day
  res.json({ success: true });
});

// --- API endpoint to retrieve invite code ---
app.get("/deeplink/:deviceId", async (req, res) => {
  const deviceId = req.params.deviceId;
  const inviteCode = await client.get(`deeplink:${deviceId}`);

  if (!inviteCode) {
    return res.status(404).json({ error: "No invite code found" });
  }

  res.json({ inviteCode });
});

// Start server
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`🚀 Server running on port ${PORT}`));
