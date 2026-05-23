// src/routes/internal.routes.js

const express = require("express");
const router = express.Router();

function verifyGatewaySecret(req, res, next) {
  const gatewaySecret = req.headers["x-gateway-secret"];

  if (!gatewaySecret || gatewaySecret !== process.env.GATEWAY_INTERNAL_SECRET) {
    return res.status(401).json({
      success: false,
      message: "Unauthorized backend request",
    });
  }

  next();
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

module.exports = router;