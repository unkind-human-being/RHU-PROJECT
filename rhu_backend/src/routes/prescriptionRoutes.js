const express = require("express");

const {
  getPrescriptions,
  getMyPrescriptions,
  getPrescriptionById,
  getPrescriptionByQrToken,
  createPrescription,
  cancelPrescription,
  claimPrescription,
} = require("../controllers/prescriptionController");

const { protect } = require("../middleware/authMiddleware");
const { allowRoles } = require("../middleware/roleMiddleware");
const { USER_ROLES } = require("../utils/constants");

const router = express.Router();

const canReadPrescriptions = allowRoles(
  USER_ROLES.IPHO_ADMIN,
  USER_ROLES.RHU_ADMIN,
  USER_ROLES.PHARMACIST,
  USER_ROLES.PUBLIC_USER
);

const canCreatePrescriptions = allowRoles(
  USER_ROLES.IPHO_ADMIN,
  USER_ROLES.RHU_ADMIN
);

const canClaimPrescriptions = allowRoles(USER_ROLES.PHARMACIST);

router.get("/", protect, canReadPrescriptions, getPrescriptions);

router.get(
  "/my",
  protect,
  allowRoles(USER_ROLES.PUBLIC_USER),
  getMyPrescriptions
);

router.post("/", protect, canCreatePrescriptions, createPrescription);

router.get(
  "/qr/:token",
  protect,
  canReadPrescriptions,
  getPrescriptionByQrToken
);

router.get("/:id", protect, canReadPrescriptions, getPrescriptionById);

router.patch(
  "/:id/cancel",
  protect,
  canCreatePrescriptions,
  cancelPrescription
);

router.patch(
  "/:id/claim",
  protect,
  canClaimPrescriptions,
  claimPrescription
);

module.exports = router;