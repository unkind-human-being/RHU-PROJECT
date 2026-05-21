const express = require("express");

const {
  getPublicEvents,
  getEvents,
  getEventById,
  createEvent,
  updateEvent,
  openEvent,
  closeEvent,
  completeEvent,
  cancelEvent,
  deleteEvent,
  registerForEvent,
  cancelMyRegistration,
  updateRegistrationStatus,
} = require("../controllers/eventController");

const { protect, optionalAuth } = require("../middleware/authMiddleware");
const { isStaff } = require("../middleware/roleMiddleware");

const router = express.Router();

router.get("/public", getPublicEvents);

router.get("/", protect, isStaff, getEvents);

router.post("/", protect, isStaff, createEvent);

router.get("/:id", optionalAuth, getEventById);

router.patch("/:id", protect, isStaff, updateEvent);

router.patch("/:id/open", protect, isStaff, openEvent);

router.patch("/:id/close", protect, isStaff, closeEvent);

router.patch("/:id/complete", protect, isStaff, completeEvent);

router.patch("/:id/cancel", protect, isStaff, cancelEvent);

router.post("/:id/register", protect, registerForEvent);

router.patch("/:id/cancel-registration", protect, cancelMyRegistration);

router.patch(
  "/:id/registration-status",
  protect,
  isStaff,
  updateRegistrationStatus
);

router.delete("/:id", protect, isStaff, deleteEvent);

module.exports = router;