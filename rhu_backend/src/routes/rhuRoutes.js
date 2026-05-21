const express = require("express");

const {
  getAllRHUs,
  getRHUById,
  createRHU,
  updateRHU,
  deactivateRHU,
  getRHUSummary,
} = require("../controllers/rhuController");

const { protect } = require("../middleware/authMiddleware");
const {
  isAdmin,
  isIPHOAdmin,
  canManageRHU,
} = require("../middleware/roleMiddleware");

const router = express.Router();

// Allow all logged-in users to view RHU list.
// Public users need this for appointment application.
router.get("/", protect, getAllRHUs);

router.post("/", protect, isIPHOAdmin, createRHU);

router.get("/:id", protect, isAdmin, canManageRHU, getRHUById);

router.get("/:id/summary", protect, isAdmin, canManageRHU, getRHUSummary);

router.patch("/:id", protect, isAdmin, canManageRHU, updateRHU);

router.delete("/:id", protect, isIPHOAdmin, deactivateRHU);

module.exports = router;