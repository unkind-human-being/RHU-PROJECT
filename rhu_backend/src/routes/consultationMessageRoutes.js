const express = require("express");

const {
  getAppointmentMessages,
  sendTextMessage,
  sendVideoCallMessage,
  sendPrescriptionQrMessage,
  markMessageAsRead,
} = require("../controllers/consultationMessageController");

const { protect } = require("../middleware/authMiddleware");
const { allowRoles } = require("../middleware/roleMiddleware");
const { USER_ROLES } = require("../utils/constants");

const router = express.Router();

const canViewMessages = allowRoles(
  USER_ROLES.IPHO_ADMIN,
  USER_ROLES.RHU_ADMIN,
  USER_ROLES.PUBLIC_USER
);

const canSendMessages = allowRoles(USER_ROLES.RHU_ADMIN);

router.get(
  "/appointment/:appointmentId",
  protect,
  canViewMessages,
  getAppointmentMessages
);

router.post(
  "/appointment/:appointmentId/text",
  protect,
  canSendMessages,
  sendTextMessage
);

router.post(
  "/appointment/:appointmentId/video-call",
  protect,
  canSendMessages,
  sendVideoCallMessage
);

router.post(
  "/appointment/:appointmentId/prescription",
  protect,
  canSendMessages,
  sendPrescriptionQrMessage
);

router.patch(
  "/:id/read",
  protect,
  allowRoles(USER_ROLES.PUBLIC_USER),
  markMessageAsRead
);

module.exports = router;