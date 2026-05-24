// src/routes/internal.routes.js

const express = require("express");

const router = express.Router();

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

function normalizeText(value) {
  return String(value || "").trim();
}

function safeUser(user) {
  if (!user) {
    return null;
  }

  return {
    id: user._id?.toString() || user.id,
    fullName: user.fullName || "RHU User",
    email: user.email,
    role: user.role || User.roles.PUBLIC_USER,
    authProvider: user.authProvider || User.authProviders.GATEWAY,
    status: user.isActive ? "active" : "inactive",
    isActive: user.isActive === true,
    tawiTawiUserId: user.tawiTawiUserId || null,
    linkedFromGateway: user.linkedFromGateway === true,
    gatewayLinkedAt: user.gatewayLinkedAt || null,
  };
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
    const cleanTawiTawiUserId = normalizeText(tawiTawiUserId);

    if (!cleanTawiTawiUserId || !cleanEmail) {
      return res.status(400).json({
        success: false,
        isLinked: false,
        requiresRegistration: false,
        externalUserId: null,
        message: "tawiTawiUserId and email are required.",
      });
    }

    const existingUser = await User.findOne({
      $or: [
        { email: cleanEmail },
        { tawiTawiUserId: cleanTawiTawiUserId },
      ],
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

    let shouldSave = false;

    if (!existingUser.tawiTawiUserId) {
      existingUser.tawiTawiUserId = cleanTawiTawiUserId;
      shouldSave = true;
    }

    if (!existingUser.linkedFromGateway) {
      existingUser.linkedFromGateway = true;
      shouldSave = true;
    }

    if (!existingUser.gatewayLinkedAt) {
      existingUser.gatewayLinkedAt = new Date();
      shouldSave = true;
    }

    if (fullName && !existingUser.fullName) {
      existingUser.fullName = normalizeText(fullName);
      shouldSave = true;
    }

    if (shouldSave) {
      await existingUser.save();
    }

    return res.status(200).json({
      success: true,
      isLinked: true,
      requiresRegistration: false,
      externalUserId: existingUser._id?.toString() || existingUser.id,
      message: "RHU user found. Access granted.",
      user: safeUser(existingUser),
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
    const cleanName = normalizeText(fullName);
    const cleanTawiTawiUserId = normalizeText(tawiTawiUserId);
    const cleanPhoneNumber = normalizeText(phoneNumber);

    if (!cleanTawiTawiUserId || !cleanEmail || !cleanName) {
      return res.status(400).json({
        success: false,
        isLinked: false,
        requiresRegistration: true,
        externalUserId: null,
        message: "tawiTawiUserId, fullName, and email are required.",
      });
    }

    const existingUser = await User.findOne({
      $or: [
        { email: cleanEmail },
        { tawiTawiUserId: cleanTawiTawiUserId },
      ],
    });

    if (existingUser) {
      let shouldSave = false;

      if (!existingUser.tawiTawiUserId) {
        existingUser.tawiTawiUserId = cleanTawiTawiUserId;
        shouldSave = true;
      }

      if (!existingUser.linkedFromGateway) {
        existingUser.linkedFromGateway = true;
        shouldSave = true;
      }

      if (!existingUser.gatewayLinkedAt) {
        existingUser.gatewayLinkedAt = new Date();
        shouldSave = true;
      }

      if (cleanPhoneNumber && !existingUser.phoneNumber) {
        existingUser.phoneNumber = cleanPhoneNumber;
        shouldSave = true;
      }

      if (shouldSave) {
        await existingUser.save();
      }

      return res.status(200).json({
        success: true,
        isLinked: true,
        requiresRegistration: false,
        externalUserId: existingUser._id?.toString() || existingUser.id,
        message: "Existing RHU user linked successfully.",
        user: safeUser(existingUser),
      });
    }

    const createdUser = await User.create({
      fullName: cleanName,
      email: cleanEmail,
      role: User.roles.PUBLIC_USER,
      authProvider: User.authProviders.GATEWAY,
      phoneNumber: cleanPhoneNumber,
      isActive: true,
      tawiTawiUserId: cleanTawiTawiUserId,
      linkedFromGateway: true,
      gatewayLinkedAt: new Date(),
    });

    return res.status(201).json({
      success: true,
      isLinked: true,
      requiresRegistration: false,
      externalUserId: createdUser._id?.toString() || createdUser.id,
      message: "RHU user created and linked successfully.",
      user: safeUser(createdUser),
    });
  } catch (error) {
    console.error("Internal register-user error:", error);

    if (error && error.code === 11000) {
      return res.status(409).json({
        success: false,
        isLinked: false,
        requiresRegistration: false,
        externalUserId: null,
        message: "An RHU user with this email already exists.",
      });
    }

    return res.status(500).json({
      success: false,
      isLinked: false,
      requiresRegistration: false,
      externalUserId: null,
      message: "Failed to register RHU user.",
    });
  }
});

module.exports = router;