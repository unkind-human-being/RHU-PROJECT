const express = require("express");

const {
  getMedicines,
  getMedicineById,
  createMedicine,
  updateMedicine,
  deactivateMedicine,
  recordMedicineTransaction,
  getMedicineTransactions,
  getMedicineStockSummary,
} = require("../controllers/medicineController");

const { protect } = require("../middleware/authMiddleware");
const { isStaff } = require("../middleware/roleMiddleware");

const router = express.Router();

router.get("/", protect, isStaff, getMedicines);

router.get("/summary", protect, isStaff, getMedicineStockSummary);

router.get("/transactions", protect, isStaff, getMedicineTransactions);

router.post("/", protect, isStaff, createMedicine);

router.post("/transactions", protect, isStaff, recordMedicineTransaction);

router.get("/:id", protect, isStaff, getMedicineById);

router.patch("/:id", protect, isStaff, updateMedicine);

router.delete("/:id", protect, isStaff, deactivateMedicine);

module.exports = router;