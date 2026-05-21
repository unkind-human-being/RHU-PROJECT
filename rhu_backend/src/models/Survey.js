const mongoose = require("mongoose");

const SURVEY_STATUS = {
  DRAFT: "draft",
  OPEN: "open",
  CLOSED: "closed",
  ARCHIVED: "archived",
};

const SURVEY_TYPES = {
  HEALTH_FEEDBACK: "health_feedback",
  EVENT_FEEDBACK: "event_feedback",
  COMMUNITY_NEEDS: "community_needs",
  MEDICINE_AVAILABILITY: "medicine_availability",
  GENERAL: "general",
};

const QUESTION_TYPES = {
  SHORT_TEXT: "short_text",
  LONG_TEXT: "long_text",
  MULTIPLE_CHOICE: "multiple_choice",
  CHECKBOX: "checkbox",
  YES_NO: "yes_no",
  NUMBER: "number",
  DATE: "date",
};

const AUDIENCE_SCOPE = {
  PUBLIC: "public",
  RHU_ONLY: "rhu_only",
  BARANGAY_ONLY: "barangay_only",
};

const surveyQuestionSchema = new mongoose.Schema(
  {
    questionText: {
      type: String,
      required: [true, "Question text is required."],
      trim: true,
      maxlength: [500, "Question text cannot exceed 500 characters."],
    },

    type: {
      type: String,
      enum: Object.values(QUESTION_TYPES),
      required: [true, "Question type is required."],
    },

    options: [
      {
        type: String,
        trim: true,
        maxlength: [150, "Option cannot exceed 150 characters."],
      },
    ],

    isRequired: {
      type: Boolean,
      default: true,
    },

    order: {
      type: Number,
      min: [0, "Question order cannot be negative."],
      default: 0,
    },
  },
  {
    _id: true,
  }
);

const surveySchema = new mongoose.Schema(
  {
    title: {
      type: String,
      required: [true, "Survey title is required."],
      trim: true,
      maxlength: [180, "Survey title cannot exceed 180 characters."],
      index: true,
    },

    description: {
      type: String,
      required: [true, "Survey description is required."],
      trim: true,
      maxlength: [3000, "Survey description cannot exceed 3000 characters."],
    },

    type: {
      type: String,
      enum: Object.values(SURVEY_TYPES),
      default: SURVEY_TYPES.GENERAL,
      index: true,
    },

    status: {
      type: String,
      enum: Object.values(SURVEY_STATUS),
      default: SURVEY_STATUS.DRAFT,
      index: true,
    },

    audienceScope: {
      type: String,
      enum: Object.values(AUDIENCE_SCOPE),
      default: AUDIENCE_SCOPE.PUBLIC,
      index: true,
    },

    rhu: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "RHU",
      required: [true, "Survey must belong to an RHU."],
      index: true,
    },

    barangay: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Barangay",
      default: null,
      index: true,
    },

    questions: {
      type: [surveyQuestionSchema],
      validate: {
        validator: function (questions) {
          return Array.isArray(questions) && questions.length > 0;
        },
        message: "Survey must have at least one question.",
      },
    },

    requiresLogin: {
      type: Boolean,
      default: true,
      index: true,
    },

    allowMultipleResponses: {
      type: Boolean,
      default: false,
    },

    startDate: {
      type: Date,
      required: [true, "Survey start date is required."],
      index: true,
    },

    endDate: {
      type: Date,
      required: [true, "Survey end date is required."],
      index: true,
    },

    responseCount: {
      type: Number,
      min: [0, "Response count cannot be negative."],
      default: 0,
    },

    publishedAt: {
      type: Date,
      default: null,
      index: true,
    },

    closedAt: {
      type: Date,
      default: null,
    },

    createdBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: [true, "Survey creator is required."],
      index: true,
    },

    updatedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      default: null,
    },

    isDeleted: {
      type: Boolean,
      default: false,
      index: true,
    },
  },
  {
    timestamps: true,
  }
);

surveySchema.index({
  status: 1,
  audienceScope: 1,
  startDate: 1,
  endDate: 1,
});

surveySchema.index({
  rhu: 1,
  status: 1,
  startDate: 1,
});

surveySchema.index({
  rhu: 1,
  barangay: 1,
  status: 1,
  startDate: 1,
});

surveySchema.index({
  title: "text",
  description: "text",
});

surveySchema.pre("validate", function () {
  if (this.startDate && this.endDate && this.endDate < this.startDate) {
    throw new Error("Survey end date cannot be earlier than start date.");
  }

  for (const question of this.questions || []) {
    const needsOptions =
      question.type === QUESTION_TYPES.MULTIPLE_CHOICE ||
      question.type === QUESTION_TYPES.CHECKBOX;

    if (needsOptions && (!question.options || question.options.length < 2)) {
      throw new Error(
        "Multiple choice and checkbox questions must have at least two options."
      );
    }
  }
});

surveySchema.pre("save", function () {
  if (this.status === SURVEY_STATUS.OPEN && !this.publishedAt) {
    this.publishedAt = new Date();
  }

  if (this.status === SURVEY_STATUS.CLOSED && !this.closedAt) {
    this.closedAt = new Date();
  }
});

surveySchema.methods.isOpenForResponses = function () {
  const now = new Date();

  if (this.status !== SURVEY_STATUS.OPEN) {
    return false;
  }

  if (this.startDate && now < this.startDate) {
    return false;
  }

  if (this.endDate && now > this.endDate) {
    return false;
  }

  return true;
};

surveySchema.statics.surveyStatuses = SURVEY_STATUS;
surveySchema.statics.surveyTypes = SURVEY_TYPES;
surveySchema.statics.questionTypes = QUESTION_TYPES;
surveySchema.statics.audienceScopes = AUDIENCE_SCOPE;

module.exports = mongoose.model("Survey", surveySchema);