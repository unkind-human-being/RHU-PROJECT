const Survey = require("../models/Survey");
const SurveyResponse = require("../models/SurveyResponse");
const { asyncHandler } = require("../middleware/errorMiddleware");
const { USER_ROLES } = require("../utils/constants");

const {
  createNotification,
  notifyRhuAdmins,
} = require("../services/notificationService");

const getIdString = (value) => {
  if (!value) return null;
  if (value._id) return value._id.toString();
  return value.toString();
};

const getUserRhuId = (req) => getIdString(req.user?.rhu);

const populateSurvey = (query) => {
  return query.populate("rhu", "name code municipality province contactNumber");
};

const populateSurveyResponse = (query) => {
  return query
    .populate("survey", "title name status surveyType")
    .populate("rhu", "name code municipality province contactNumber")
    .populate("user", "fullName email phoneNumber");
};

const getSurveyRhuId = (survey) => {
  return getIdString(survey.rhu);
};

const getSurveyTitle = (survey) => {
  return survey.title || survey.name || "RHU survey";
};

const isSurveyOpen = (survey) => {
  const status = (survey.status || "").toString().toLowerCase();

  if (!status) {
    return true;
  }

  return status === "open" || status === "published" || status === "active";
};

const canManageSurveyResponses = (req, survey) => {
  if (!req.user) {
    return {
      allowed: false,
      message: "You are not authorized to manage survey responses.",
    };
  }

  if (req.user.role === USER_ROLES.IPHO_ADMIN) {
    return {
      allowed: true,
    };
  }

  if (req.user.role === USER_ROLES.RHU_ADMIN) {
    if (getUserRhuId(req) === getSurveyRhuId(survey)) {
      return {
        allowed: true,
      };
    }

    return {
      allowed: false,
      message:
        "RHU Admin can only manage survey responses under their assigned RHU.",
    };
  }

  return {
    allowed: false,
    message: "Only RHU Admin or IPHO Admin can manage survey responses.",
  };
};

const safeCreateSurveyNotifications = async ({
  req,
  survey,
  response,
  respondentName,
}) => {
  try {
    const surveyTitle = getSurveyTitle(survey);
    const surveyRhuId = getSurveyRhuId(survey);

    await createNotification({
      recipient: req.userId,
      actor: req.userId,
      type: "survey_submitted",
      title: "Survey Submitted",
      body: `Your response to ${surveyTitle} was submitted successfully.`,
      targetRoute: "/public-activity-history",
      rhu: surveyRhuId,
      survey: survey._id,
      metadata: {
        responseId: response._id.toString(),
        surveyTitle,
      },
    });

    await notifyRhuAdmins({
      rhu: surveyRhuId,
      actor: req.userId,
      type: "survey_response_received",
      title: "New Survey Response",
      body: `${respondentName} answered ${surveyTitle}.`,
      targetRoute: "/survey-responses",
      survey: survey._id,
      metadata: {
        responseId: response._id.toString(),
        surveyTitle,
        respondentName,
      },
    });
  } catch (error) {
    console.error("Survey notification creation failed:", error.message);
  }
};

const submitSurveyResponse = asyncHandler(async (req, res) => {
  const survey = await populateSurvey(Survey.findById(req.params.surveyId));

  if (!survey) {
    return res.status(404).json({
      success: false,
      message: "Survey not found.",
    });
  }

  if (!isSurveyOpen(survey)) {
    return res.status(400).json({
      success: false,
      message: "This survey is not open for responses.",
    });
  }

  const respondentName = (req.body.respondentName || req.user?.fullName || "")
    .toString()
    .trim();

  if (!respondentName) {
    return res.status(400).json({
      success: false,
      message: "Respondent name is required.",
    });
  }

  if (!Array.isArray(req.body.answers) || req.body.answers.length === 0) {
    return res.status(400).json({
      success: false,
      message: "At least one survey answer is required.",
    });
  }

  const answers = req.body.answers.map((item) => {
    return {
      questionId: item.questionId || item.id || "",
      questionText: item.questionText || item.question || "",
      answer: item.answer ?? "",
    };
  });

  const response = await SurveyResponse.findOneAndUpdate(
    {
      survey: survey._id,
      user: req.userId,
    },
    {
      $set: {
        rhu: getSurveyRhuId(survey),
        respondentName,
        contactNumber: req.body.contactNumber || req.user?.phoneNumber || "",
        email: req.body.email || req.user?.email || "",
        answers,
        submittedAt: new Date(),
      },
    },
    {
      new: true,
      upsert: true,
      runValidators: true,
    }
  );

  await safeCreateSurveyNotifications({
    req,
    survey,
    response,
    respondentName,
  });

  const populatedResponse = await populateSurveyResponse(
    SurveyResponse.findById(response._id)
  );

  return res.status(201).json({
    success: true,
    message: "Survey response submitted successfully.",
    data: populatedResponse.toSafeObject(),
  });
});

const getMySurveyResponses = asyncHandler(async (req, res) => {
  const responses = await populateSurveyResponse(
    SurveyResponse.find({
      user: req.userId,
    }).sort({ submittedAt: -1, createdAt: -1 })
  );

  return res.status(200).json({
    success: true,
    message: "My survey responses fetched successfully.",
    count: responses.length,
    data: responses.map((response) => response.toSafeObject()),
  });
});

const getSurveyResponses = asyncHandler(async (req, res) => {
  const survey = await populateSurvey(Survey.findById(req.params.surveyId));

  if (!survey) {
    return res.status(404).json({
      success: false,
      message: "Survey not found.",
    });
  }

  const access = canManageSurveyResponses(req, survey);

  if (!access.allowed) {
    return res.status(403).json({
      success: false,
      message: access.message,
    });
  }

  const responses = await populateSurveyResponse(
    SurveyResponse.find({
      survey: survey._id,
    }).sort({ submittedAt: -1, createdAt: -1 })
  );

  return res.status(200).json({
    success: true,
    message: "Survey responses fetched successfully.",
    survey: survey.toSafeObject ? survey.toSafeObject() : survey,
    count: responses.length,
    data: responses.map((response) => response.toSafeObject()),
  });
});

module.exports = {
  submitSurveyResponse,
  getMySurveyResponses,
  getSurveyResponses,
};