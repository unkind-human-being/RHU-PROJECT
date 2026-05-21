const express = require("express");

const {
  registerForEvent,
  getMyEventRegistrations,
  getEventRegistrations,
  updateEventRegistrationStatus,
} = require("../controllers/eventRegistrationController");

const { protect } = require("../middleware/authMiddleware");
const { allowRoles } = require("../middleware/roleMiddleware");
const { USER_ROLES } = require("../utils/constants");

const router = express.Router();

router.post(
  "/event/:eventId",
  protect,
  allowRoles(USER_ROLES.PUBLIC_USER),
  registerForEvent
);

router.get(
  "/my",
  protect,
  allowRoles(USER_ROLES.PUBLIC_USER),
  getMyEventRegistrations
);

router.get(
  "/event/:eventId",
  protect,
  allowRoles(USER_ROLES.IPHO_ADMIN, USER_ROLES.RHU_ADMIN),
  getEventRegistrations
);

router.patch(
  "/:id/status",
  protect,
  allowRoles(USER_ROLES.IPHO_ADMIN, USER_ROLES.RHU_ADMIN),
  updateEventRegistrationStatus
);

module.exports = router;