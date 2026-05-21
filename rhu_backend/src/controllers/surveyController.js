const Survey = require("../models/Survey");
const RHU = require("../models/RHU");
const Barangay = require("../models/Barangay");
const { asyncHandler } = require("../middleware/errorMiddleware");
const {
  USER_ROLES,
  SURVEY_STATUS,
  AUDIENCE_SCOPE,
} = require("../utils/constants");

const getIdString = (value) => {
  if (!value) return null;
  if (value._id) return value._id.toString();
  return value.toString();
};

const getUserRhuId = (req) => getIdString(req.user?.rhu);
const getUserBarangayId = (req) => getIdString(req.user?.barangay);

const checkSurveyAccess = (req, survey) => {
  if (!req.user) {
    if (
      survey.status === SURVEY_STATUS.OPEN &&
      survey.audienceScope === AUDIENCE_SCOPE.PUBLIC
    ) {
      return {
        allowed: true,
      };
    }

    return {
      allowed: false,
      message: "This survey is not available for public access.",
    };
  }

  if (req.user.role === USER_ROLES.IPHO_ADMIN) {
    return {
      allowed: true,
    };
  }

  const surveyRhuId = getIdString(survey.rhu);
  const surveyBarangayId = getIdString(survey.barangay);

  if (req.user.role === USER_ROLES.RHU_ADMIN) {
    if (getUserRhuId(req) === surveyRhuId) {
      return {
        allowed: true,
      };
    }

    return {
      allowed: false,
      message: "You can only access surveys under your assigned RHU.",
    };
  }

  if (req.user.role === USER_ROLES.BARANGAY_HEALTH_WORKER) {
    if (survey.audienceScope === AUDIENCE_SCOPE.PUBLIC) {
      return {
        allowed: true,
      };
    }

    if (
      getUserRhuId(req) === surveyRhuId &&
      (!surveyBarangayId || getUserBarangayId(req) === surveyBarangayId)
    ) {
      return {
        allowed: true,
      };
    }

    return {
      allowed: false,
      message: "You can only access surveys under your assigned barangay.",
    };
  }

  if (
    req.user.role === USER_ROLES.PUBLIC_USER &&
    survey.status === SURVEY_STATUS.OPEN &&
    survey.audienceScope === AUDIENCE_SCOPE.PUBLIC
  ) {
    return {
      allowed: true,
    };
  }

  return {
    allowed: false,
    message: "You do not have permission to access this survey.",
  };
};

const buildPublicSurveyFilter = (req) => {
  const filter = {
    status: SURVEY_STATUS.OPEN,
    audienceScope: AUDIENCE_SCOPE.PUBLIC,
    isDeleted: false,
  };

  const now = new Date();

  filter.startDate = {
    $lte: now,
  };

  filter.endDate = {
    $gte: now,
  };

  if (req.query.rhu) {
    filter.rhu = req.query.rhu;
  }

  if (req.query.barangay) {
    filter.barangay = req.query.barangay;
  }

  if (req.query.type) {
    filter.type = req.query.type;
  }

  if (req.query.search) {
    const searchRegex = new RegExp(req.query.search.trim(), "i");

    filter.$or = [
      { title: searchRegex },
      { description: searchRegex },
    ];
  }

  return filter;
};

const buildStaffSurveyFilter = (req) => {
  const filter = {
    isDeleted: false,
  };

  if (req.query.status) {
    filter.status = req.query.status;
  }

  if (req.query.type) {
    filter.type = req.query.type;
  }

  if (req.query.audienceScope) {
    filter.audienceScope = req.query.audienceScope;
  }

  if (req.query.active === "true") {
    const now = new Date();

    filter.status = SURVEY_STATUS.OPEN;
    filter.startDate = {
      $lte: now,
    };
    filter.endDate = {
      $gte: now,
    };
  }

  if (req.user.role === USER_ROLES.RHU_ADMIN) {
    filter.rhu = getUserRhuId(req);
  }

  if (req.user.role === USER_ROLES.BARANGAY_HEALTH_WORKER) {
    filter.rhu = getUserRhuId(req);

    filter.$or = [
      { audienceScope: AUDIENCE_SCOPE.PUBLIC },
      { barangay: getUserBarangayId(req) },
      { barangay: null },
    ];
  }

  if (req.user.role === USER_ROLES.IPHO_ADMIN) {
    if (req.query.rhu) {
      filter.rhu = req.query.rhu;
    }

    if (req.query.barangay) {
      filter.barangay = req.query.barangay;
    }
  }

  if (req.query.search) {
    const searchRegex = new RegExp(req.query.search.trim(), "i");

    const searchConditions = [
      { title: searchRegex },
      { description: searchRegex },
    ];

    if (filter.$or) {
      filter.$and = [
        {
          $or: filter.$or,
        },
        {
          $or: searchConditions,
        },
      ];

      delete filter.$or;
    } else {
      filter.$or = searchConditions;
    }
  }

  return filter;
};

const validateSurveyLocation = async ({ rhu, barangay }) => {
  if (!rhu) {
    throw new Error("RHU is required.");
  }

  const existingRHU = await RHU.findById(rhu);

  if (!existingRHU || !existingRHU.isActive) {
    throw new Error("Selected RHU does not exist or is inactive.");
  }

  if (barangay) {
    const existingBarangay = await Barangay.findById(barangay);

    if (!existingBarangay || !existingBarangay.isActive) {
      throw new Error("Selected barangay does not exist or is inactive.");
    }

    if (existingBarangay.rhu.toString() !== rhu.toString()) {
      throw new Error("Selected barangay does not belong to the selected RHU.");
    }
  }
};

const checkLocationAccess = (req, rhu, barangay = null) => {
  if (req.user.role === USER_ROLES.IPHO_ADMIN) {
    return {
      allowed: true,
    };
  }

  if (req.user.role === USER_ROLES.RHU_ADMIN) {
    if (getUserRhuId(req) === rhu.toString()) {
      return {
        allowed: true,
      };
    }

    return {
      allowed: false,
      message: "You can only manage surveys under your assigned RHU.",
    };
  }

  if (req.user.role === USER_ROLES.BARANGAY_HEALTH_WORKER) {
    if (
      getUserRhuId(req) === rhu.toString() &&
      (!barangay || getUserBarangayId(req) === barangay.toString())
    ) {
      return {
        allowed: true,
      };
    }

    return {
      allowed: false,
      message: "You can only manage surveys under your assigned barangay.",
    };
  }

  return {
    allowed: false,
    message: "You do not have permission to manage surveys.",
  };
};

const getPublicSurveys = asyncHandler(async (req, res) => {
  const page = Math.max(parseInt(req.query.page, 10) || 1, 1);
  const limit = Math.min(Math.max(parseInt(req.query.limit, 10) || 20, 1), 100);
  const skip = (page - 1) * limit;

  const filter = buildPublicSurveyFilter(req);

  const [surveys, total] = await Promise.all([
    Survey.find(filter)
      .populate("rhu", "name code municipality province")
      .populate("barangay", "name code municipality province")
      .populate("createdBy", "fullName role")
      .sort({ startDate: -1, createdAt: -1 })
      .skip(skip)
      .limit(limit),
    Survey.countDocuments(filter),
  ]);

  return res.status(200).json({
    success: true,
    message: "Public surveys fetched successfully.",
    count: surveys.length,
    total,
    page,
    pages: Math.ceil(total / limit),
    data: surveys,
  });
});

const getSurveys = asyncHandler(async (req, res) => {
  const page = Math.max(parseInt(req.query.page, 10) || 1, 1);
  const limit = Math.min(Math.max(parseInt(req.query.limit, 10) || 20, 1), 100);
  const skip = (page - 1) * limit;

  const filter = buildStaffSurveyFilter(req);

  const [surveys, total] = await Promise.all([
    Survey.find(filter)
      .populate("rhu", "name code municipality province")
      .populate("barangay", "name code municipality province")
      .populate("createdBy", "fullName email role")
      .populate("updatedBy", "fullName email role")
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit),
    Survey.countDocuments(filter),
  ]);

  return res.status(200).json({
    success: true,
    message: "Surveys fetched successfully.",
    count: surveys.length,
    total,
    page,
    pages: Math.ceil(total / limit),
    data: surveys,
  });
});

const getSurveyById = asyncHandler(async (req, res) => {
  const survey = await Survey.findById(req.params.id)
    .populate("rhu", "name code municipality province")
    .populate("barangay", "name code municipality province")
    .populate("createdBy", "fullName email role")
    .populate("updatedBy", "fullName email role");

  if (!survey || survey.isDeleted) {
    return res.status(404).json({
      success: false,
      message: "Survey not found.",
    });
  }

  const access = checkSurveyAccess(req, {
    ...survey.toObject(),
    rhu: survey.rhu?._id || survey.rhu,
    barangay: survey.barangay?._id || survey.barangay,
  });

  if (!access.allowed) {
    return res.status(403).json({
      success: false,
      message: access.message,
    });
  }

  return res.status(200).json({
    success: true,
    message: "Survey fetched successfully.",
    data: survey,
  });
});

const createSurvey = asyncHandler(async (req, res) => {
  const {
    title,
    description,
    type,
    status,
    audienceScope,
    rhu,
    barangay,
    questions,
    requiresLogin,
    allowMultipleResponses,
    startDate,
    endDate,
  } = req.body;

  try {
    await validateSurveyLocation({ rhu, barangay });
  } catch (error) {
    return res.status(400).json({
      success: false,
      message: error.message,
    });
  }

  const access = checkLocationAccess(req, rhu, barangay);

  if (!access.allowed) {
    return res.status(403).json({
      success: false,
      message: access.message,
    });
  }

  const survey = await Survey.create({
    title,
    description,
    type,
    status,
    audienceScope,
    rhu,
    barangay: barangay || null,
    questions,
    requiresLogin,
    allowMultipleResponses,
    startDate,
    endDate,
    createdBy: req.userId,
  });

  const createdSurvey = await Survey.findById(survey._id)
    .populate("rhu", "name code municipality province")
    .populate("barangay", "name code municipality province")
    .populate("createdBy", "fullName email role");

  return res.status(201).json({
    success: true,
    message: "Survey created successfully.",
    data: createdSurvey,
  });
});

const updateSurvey = asyncHandler(async (req, res) => {
  const survey = await Survey.findById(req.params.id);

  if (!survey || survey.isDeleted) {
    return res.status(404).json({
      success: false,
      message: "Survey not found.",
    });
  }

  const access = checkSurveyAccess(req, survey);

  if (!access.allowed) {
    return res.status(403).json({
      success: false,
      message: access.message,
    });
  }

  if (req.user.role === USER_ROLES.BARANGAY_HEALTH_WORKER) {
    if (survey.createdBy.toString() !== req.userId.toString()) {
      return res.status(403).json({
        success: false,
        message: "Barangay health workers can only update surveys they created.",
      });
    }
  }

  const allowedUpdates = [
    "title",
    "description",
    "type",
    "status",
    "audienceScope",
    "barangay",
    "questions",
    "requiresLogin",
    "allowMultipleResponses",
    "startDate",
    "endDate",
  ];

  const updates = {};

  for (const field of allowedUpdates) {
    if (Object.prototype.hasOwnProperty.call(req.body, field)) {
      updates[field] = req.body[field];
    }
  }

  if (updates.barangay) {
    try {
      await validateSurveyLocation({
        rhu: survey.rhu,
        barangay: updates.barangay,
      });
    } catch (error) {
      return res.status(400).json({
        success: false,
        message: error.message,
      });
    }

    const locationAccess = checkLocationAccess(req, survey.rhu, updates.barangay);

    if (!locationAccess.allowed) {
      return res.status(403).json({
        success: false,
        message: locationAccess.message,
      });
    }
  }

  updates.updatedBy = req.userId;

  const updatedSurvey = await Survey.findByIdAndUpdate(req.params.id, updates, {
    new: true,
    runValidators: true,
  })
    .populate("rhu", "name code municipality province")
    .populate("barangay", "name code municipality province")
    .populate("createdBy", "fullName email role")
    .populate("updatedBy", "fullName email role");

  return res.status(200).json({
    success: true,
    message: "Survey updated successfully.",
    data: updatedSurvey,
  });
});

const openSurvey = asyncHandler(async (req, res) => {
  const survey = await Survey.findById(req.params.id);

  if (!survey || survey.isDeleted) {
    return res.status(404).json({
      success: false,
      message: "Survey not found.",
    });
  }

  const access = checkSurveyAccess(req, survey);

  if (!access.allowed) {
    return res.status(403).json({
      success: false,
      message: access.message,
    });
  }

  survey.status = SURVEY_STATUS.OPEN;
  survey.publishedAt = new Date();
  survey.updatedBy = req.userId;
  await survey.save();

  const openedSurvey = await Survey.findById(survey._id)
    .populate("rhu", "name code municipality province")
    .populate("barangay", "name code municipality province")
    .populate("createdBy", "fullName email role")
    .populate("updatedBy", "fullName email role");

  return res.status(200).json({
    success: true,
    message: "Survey opened successfully.",
    data: openedSurvey,
  });
});

const closeSurvey = asyncHandler(async (req, res) => {
  const survey = await Survey.findById(req.params.id);

  if (!survey || survey.isDeleted) {
    return res.status(404).json({
      success: false,
      message: "Survey not found.",
    });
  }

  const access = checkSurveyAccess(req, survey);

  if (!access.allowed) {
    return res.status(403).json({
      success: false,
      message: access.message,
    });
  }

  survey.status = SURVEY_STATUS.CLOSED;
  survey.closedAt = new Date();
  survey.updatedBy = req.userId;
  await survey.save();

  return res.status(200).json({
    success: true,
    message: "Survey closed successfully.",
  });
});

const archiveSurvey = asyncHandler(async (req, res) => {
  const survey = await Survey.findById(req.params.id);

  if (!survey || survey.isDeleted) {
    return res.status(404).json({
      success: false,
      message: "Survey not found.",
    });
  }

  const access = checkSurveyAccess(req, survey);

  if (!access.allowed) {
    return res.status(403).json({
      success: false,
      message: access.message,
    });
  }

  survey.status = SURVEY_STATUS.ARCHIVED;
  survey.updatedBy = req.userId;
  await survey.save();

  return res.status(200).json({
    success: true,
    message: "Survey archived successfully.",
  });
});

const deleteSurvey = asyncHandler(async (req, res) => {
  const survey = await Survey.findById(req.params.id);

  if (!survey || survey.isDeleted) {
    return res.status(404).json({
      success: false,
      message: "Survey not found.",
    });
  }

  const access = checkSurveyAccess(req, survey);

  if (!access.allowed) {
    return res.status(403).json({
      success: false,
      message: access.message,
    });
  }

  survey.isDeleted = true;
  survey.updatedBy = req.userId;
  await survey.save();

  return res.status(200).json({
    success: true,
    message: "Survey deleted successfully.",
  });
});

const getSurveySummary = asyncHandler(async (req, res) => {
  const survey = await Survey.findById(req.params.id)
    .populate("rhu", "name code municipality province")
    .populate("barangay", "name code municipality province");

  if (!survey || survey.isDeleted) {
    return res.status(404).json({
      success: false,
      message: "Survey not found.",
    });
  }

  const access = checkSurveyAccess(req, {
    ...survey.toObject(),
    rhu: survey.rhu?._id || survey.rhu,
    barangay: survey.barangay?._id || survey.barangay,
  });

  if (!access.allowed) {
    return res.status(403).json({
      success: false,
      message: access.message,
    });
  }

  return res.status(200).json({
    success: true,
    message: "Survey summary fetched successfully.",
    data: {
      surveyId: survey._id,
      title: survey.title,
      status: survey.status,
      type: survey.type,
      audienceScope: survey.audienceScope,
      rhu: survey.rhu,
      barangay: survey.barangay,
      questionCount: survey.questions.length,
      responseCount: survey.responseCount,
      startDate: survey.startDate,
      endDate: survey.endDate,
      isOpenForResponses: survey.isOpenForResponses(),
    },
  });
});

module.exports = {
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
};