import * as admin from "firebase-admin";
import express from "express";
import cors from "cors";
import {setGlobalOptions} from "firebase-functions/v2";
import {onRequest} from "firebase-functions/v2/https";
import {requireAuth} from "./middleware/auth";

// Initialize Firebase Admin (exactly once)
if (!admin.apps.length) {
  admin.initializeApp();
}

// Set global options
setGlobalOptions({maxInstances: 10});

// Create Express app
const app = express();

// Enable CORS
app.use(cors());

// Health endpoint with auth
app.get("/health/auth", requireAuth({requireAppCheck: false}), (req, res) => {
  res.json({
    ok: true,
    uid: req.user?.uid,
    orgId: req.user?.orgId,
    role: req.user?.role,
  });
});

// Export API function
export const api = onRequest({cors: true}, app);
