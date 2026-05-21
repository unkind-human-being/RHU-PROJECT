const express = require("express");

const {
  getAgoraToken,
  markVideoCallJoined,
  markVideoCallEnded,
  getAppointmentVideoCallLogs,
} = require("../controllers/videoController");

const { protect } = require("../middleware/authMiddleware");

const router = express.Router();

router.get("/agora-token", protect, getAgoraToken);

router.post("/calls/joined", protect, markVideoCallJoined);

router.post("/calls/ended", protect, markVideoCallEnded);

router.get(
  "/calls/appointment/:appointmentId",
  protect,
  getAppointmentVideoCallLogs
);

module.exports = router;