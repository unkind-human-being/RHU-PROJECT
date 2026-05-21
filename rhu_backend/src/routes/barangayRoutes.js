const express = require("express");

const {
  getAllBarangays,
  getBarangaysByRHU,
  getBarangayById,
  createBarangay,
  updateBarangay,
  deactivateBarangay,
  assignHealthWorkerToBarangay,
  removeHealthWorkerFromBarangay,
  getBarangaySummary,
} = require("../controllers/barangayController");

const { protect } = require("../middleware/authMiddleware");
const {
  isStaff,
  isAdmin,
  canManageBarangay,
} = require("../middleware/roleMiddleware");

const router = express.Router();

router.get("/", protect, isStaff, getAllBarangays);

router.get("/rhu/:rhuId", protect, isStaff, getBarangaysByRHU);

router.post("/", protect, isAdmin, createBarangay);

router.post(
  "/assign-health-worker",
  protect,
  isAdmin,
  assignHealthWorkerToBarangay
);

router.post(
  "/remove-health-worker",
  protect,
  isAdmin,
  removeHealthWorkerFromBarangay
);

router.get("/:id", protect, isStaff, canManageBarangay, getBarangayById);

router.get(
  "/:id/summary",
  protect,
  isStaff,
  canManageBarangay,
  getBarangaySummary
);

router.patch("/:id", protect, isAdmin, canManageBarangay, updateBarangay);

router.delete("/:id", protect, isAdmin, canManageBarangay, deactivateBarangay);

module.exports = router;