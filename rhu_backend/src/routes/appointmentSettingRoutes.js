const express = require("express");

const {
  getAppointmentSettingByRHU,
  getMyAppointmentSetting,
  updateMyAppointmentSetting,
  updateAppointmentSettingByRHU,
} = require("../controllers/appointmentSettingController");

const { protect } = require("../middleware/authMiddleware");
const { allowRoles } = require("../middleware/roleMiddleware");
const { USER_ROLES } = require("../utils/constants");

const router = express.Router();

const canViewSettings = allowRoles(
  USER_ROLES.IPHO_ADMIN,
  USER_ROLES.RHU_ADMIN,
  USER_ROLES.BARANGAY_HEALTH_WORKER,
  USER_ROLES.PUBLIC_USER
);

const canManageSettings = allowRoles(
  USER_ROLES.IPHO_ADMIN,
  USER_ROLES.RHU_ADMIN
);

router.get(
  "/my",
  protect,
  canViewSettings,
  getMyAppointmentSetting
);

router.patch(
  "/my",
  protect,
  canManageSettings,
  updateMyAppointmentSetting
);

router.get(
  "/rhu/:rhuId",
  protect,
  canViewSettings,
  getAppointmentSettingByRHU
);

router.patch(
  "/rhu/:rhuId",
  protect,
  canManageSettings,
  updateAppointmentSettingByRHU
);

module.exports = router;