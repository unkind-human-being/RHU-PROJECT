const express = require("express");

const {
  getPublicSurveys,
  getSurveys,
  getSurveyById,
  createSurvey,
  updateSurvey,
  openSurvey,
  closeSurvey,
  archiveSurvey,
  deleteSurvey,
  getSurveySummary,
} = require("../controllers/surveyController");

const { protect, optionalAuth } = require("../middleware/authMiddleware");
const { isStaff } = require("../middleware/roleMiddleware");

const router = express.Router();

router.get("/public", getPublicSurveys);

router.get("/", protect, isStaff, getSurveys);

router.post("/", protect, isStaff, createSurvey);

router.get("/:id", optionalAuth, getSurveyById);

router.get("/:id/summary", protect, isStaff, getSurveySummary);

router.patch("/:id", protect, isStaff, updateSurvey);

router.patch("/:id/open", protect, isStaff, openSurvey);

router.patch("/:id/close", protect, isStaff, closeSurvey);

router.patch("/:id/archive", protect, isStaff, archiveSurvey);

router.delete("/:id", protect, isStaff, deleteSurvey);

module.exports = router;