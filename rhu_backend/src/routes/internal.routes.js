// src/routes/internal.routes.js

const express = require("express");
const router = express.Router();

// IMPORTANT:
// Change this import if your user model file has another name.
// Example alternatives:
// const User = require("../models/userModel");
// const User = require("../models/UserModel");
const User = require("../models/User");

function verifyGatewaySecret(req, res, next) {
  const gatewaySecret =
    req.headers["x-internal-gateway-secret"] ||
    req.headers["x-gateway-secret"];

  if (!gatewaySecret || gatewaySecret !== process.env.GATEWAY_INTERNAL_SECRET) {
    return res.status(401).json({
      success: false,
      message: "Unauthorized backend request",
      isLinked: false,
      requiresRegistration: false,
      externalUserId: null,
    });
  }

  next();
}

function normalizeEmail(email) {
  return String(email || "").trim().toLowerCase();
}

router.get("/handshake", verifyGatewaySecret, (req, res) => {
  res.json({
    success: true,
    message: "RHU backend handshake successful",
    service: "rhu-backend",
    status: "online",
    timestamp: new Date().toISOString(),
  });
});

// Called by Tawi-Tawi backend:
// POST https://rhu-project.onrender.com/verify-user
router.post("/verify-user", verifyGatewaySecret, async (req, res) => {
  try {
    const { tawiTawiUserId, email, fullName } = req.body;

    const cleanEmail = normalizeEmail(email);

    if (!tawiTawiUserId || !cleanEmail) {
      return res.status(400).json({
        success: false,
        isLinked: false,
        requiresRegistration: false,
        externalUserId: null,
        message: "tawiTawiUserId and email are required.",
      });
    }

    const existingUser = await User.findOne({
      email: cleanEmail,
    });

    if (!existingUser) {
      return res.status(200).json({
        success: true,
        isLinked: false,
        requiresRegistration: true,
        externalUserId: null,
        message: "RHU user not found. Registration is required.",
      });
    }

    return res.status(200).json({
      success: true,
      isLinked: true,
      requiresRegistration: false,
      externalUserId: existingUser._id?.toString() || existingUser.id,
      message: "RHU user found. Access granted.",
      user: {
        id: existingUser._id?.toString() || existingUser.id,
        fullName:
          existingUser.fullName ||
          existingUser.name ||
          fullName ||
          "RHU User",
        email: existingUser.email,
        role: existingUser.role || "public_user",
        status: existingUser.status || "active",
      },
    });
  } catch (error) {
    console.error("Internal verify-user error:", error);

    return res.status(500).json({
      success: false,
      isLinked: false,
      requiresRegistration: false,
      externalUserId: null,
      message: "Failed to verify RHU user.",
    });
  }
});

// Called by Tawi-Tawi backend:
// POST https://rhu-project.onrender.com/register-user
router.post("/register-user", verifyGatewaySecret, async (req, res) => {
  try {
    const { tawiTawiUserId, email, fullName, phoneNumber } = req.body;

    const cleanEmail = normalizeEmail(email);

    if (!tawiTawiUserId || !cleanEmail || !fullName) {
      return res.status(400).json({
        success: false,
        isLinked: false,
        externalUserId: null,
        message: "tawiTawiUserId, fullName, and email are required.",
      });
    }

    const existingUser = await User.findOne({
      email: cleanEmail,
    });

    if (existingUser) {
      return res.status(200).json({
        success: true,
        isLinked: true,
        externalUserId: existingUser._id?.toString() || existingUser.id,
        message: "Existing RHU user linked successfully.",
      });
    }

    // For now, do not auto-create until we confirm your exact User schema.
    // This prevents creating broken users if your model requires specific fields.
    return res.status(200).json({
      success: true,
      isLinked: false,
      requiresRegistration: true,
      externalUserId: null,
      message:
        "RHU user does not exist yet. Add create-user logic after confirming the User schema.",
    });
  } catch (error) {
    console.error("Internal register-user error:", error);

    return res.status(500).json({
      success: false,
      isLinked: false,
      externalUserId: null,
      message: "Failed to register RHU user.",
    });
  }
});

module.exports = router;