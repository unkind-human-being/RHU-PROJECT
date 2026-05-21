const express = require("express");

const {
  getAppointments,
  getMyAppointments,
  getAppointmentById,
  createAppointment,
  acceptAppointment,
  rejectAppointment,
  cancelAppointment,
  completeAppointment,
  getAppointmentByQrToken,
  checkInAppointment,
} = require("../controllers/appointmentController");

const { protect } = require("../middleware/authMiddleware");
const { allowRoles } = require("../middleware/roleMiddleware");
const { USER_ROLES } = require("../utils/constants");

const router = express.Router();

const canReadAppointments = allowRoles(
  USER_ROLES.IPHO_ADMIN,
  USER_ROLES.RHU_ADMIN,
  USER_ROLES.PUBLIC_USER
);

const {
  appointmentCooldown,
} = require("../middleware/appointmentCooldownMiddleware");

const canCreateAppointment = allowRoles(USER_ROLES.PUBLIC_USER);

const canManageAppointments = allowRoles(
  USER_ROLES.IPHO_ADMIN,
  USER_ROLES.RHU_ADMIN
);

router.get("/", protect, canReadAppointments, getAppointments);

router.get(
  "/my",
  protect,
  allowRoles(USER_ROLES.PUBLIC_USER),
  getMyAppointments
);

router.post(
  "/",
  protect,
  allowRoles(USER_ROLES.PUBLIC_USER),
  appointmentCooldown,
  createAppointment
);

router.get(
  "/qr/:token",
  protect,
  canReadAppointments,
  getAppointmentByQrToken
);

router.get("/:id", protect, canReadAppointments, getAppointmentById);

router.patch(
  "/:id/accept",
  protect,
  canManageAppointments,
  acceptAppointment
);

router.patch(
  "/:id/reject",
  protect,
  canManageAppointments,
  rejectAppointment
);

router.patch(
  "/:id/cancel",
  protect,
  canReadAppointments,
  cancelAppointment
);

router.patch(
  "/:id/complete",
  protect,
  canManageAppointments,
  completeAppointment
);

router.patch(
  "/:id/check-in",
  protect,
  canManageAppointments,
  checkInAppointment
);

module.exports = router;