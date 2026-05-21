const express = require("express");

const {
  submitSurveyResponse,
  getMySurveyResponses,
  getSurveyResponses,
} = require("../controllers/surveyResponseController");

const { protect } = require("../middleware/authMiddleware");
const { allowRoles } = require("../middleware/roleMiddleware");
const { USER_ROLES } = require("../utils/constants");

const router = express.Router();

router.post(
  "/survey/:surveyId",
  protect,
  allowRoles(USER_ROLES.PUBLIC_USER),
  submitSurveyResponse
);

router.get(
  "/my",
  protect,
  allowRoles(USER_ROLES.PUBLIC_USER),
  getMySurveyResponses
);

router.get(
  "/survey/:surveyId",
  protect,
  allowRoles(USER_ROLES.IPHO_ADMIN, USER_ROLES.RHU_ADMIN),
  getSurveyResponses
);

module.exports = router;