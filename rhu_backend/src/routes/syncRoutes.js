const express = require("express");

const {
  syncMedicineTransactions,
  getSyncLogs,
  getSyncLogById,
  getSyncStatus,
} = require("../controllers/syncController");

const { protect } = require("../middleware/authMiddleware");
const { isStaff } = require("../middleware/roleMiddleware");

const router = express.Router();

router.post("/medicine-transactions", protect, isStaff, syncMedicineTransactions);

router.get("/logs", protect, isStaff, getSyncLogs);

router.get("/status", protect, isStaff, getSyncStatus);

router.get("/logs/:id", protect, isStaff, getSyncLogById);

module.exports = router;