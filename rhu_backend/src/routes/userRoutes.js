const express = require("express");

const {
  getUsers,
  getUserById,
  createUser,
  createHealthWorker,
  createPharmacist,
  updateUser,
  deactivateUser,
  reactivateUser,
  deleteUser,
  resetUserPassword,
} = require("../controllers/userController");

const { protect } = require("../middleware/authMiddleware");
const {
  isAdmin,
  isStaff,
  canCreateHealthWorkerAccount,
  canCreatePharmacistAccount,
} = require("../middleware/roleMiddleware");

const router = express.Router();

router.get("/", protect, isStaff, getUsers);

router.post("/", protect, isAdmin, createUser);

router.post(
  "/health-worker",
  protect,
  isAdmin,
  canCreateHealthWorkerAccount,
  createHealthWorker
);

router.post(
  "/pharmacist",
  protect,
  isAdmin,
  canCreatePharmacistAccount,
  createPharmacist
);

router.get("/:id", protect, isStaff, getUserById);

router.patch("/:id", protect, isAdmin, updateUser);

router.patch("/:id/deactivate", protect, isAdmin, deactivateUser);

router.patch("/:id/reactivate", protect, isAdmin, reactivateUser);

router.patch("/:id/reset-password", protect, isAdmin, resetUserPassword);

router.delete("/:id", protect, isAdmin, deleteUser);

module.exports = router;