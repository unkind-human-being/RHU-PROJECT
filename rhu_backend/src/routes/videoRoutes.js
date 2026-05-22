const express = require("express");

const {
  getAgoraToken,
  markVideoCallJoined,
  markVideoCallEnded,
  getAppointmentVideoCallLogs,
  startVideoCall,
  getIncomingCall,
  acceptVideoCall,
  declineVideoCall,
  endVideoCall,
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

router.post("/calls/start", protect, startVideoCall);
router.get("/calls/incoming", protect, getIncomingCall);
router.patch("/calls/:callId/accept", protect, acceptVideoCall);
router.patch("/calls/:callId/decline", protect, declineVideoCall);
router.patch("/calls/:callId/end", protect, endVideoCall);

module.exports = router;