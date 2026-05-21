const mongoose = require("mongoose");

const surveyAnswerSchema = new mongoose.Schema(
  {
    questionId: {
      type: String,
      trim: true,
      default: "",
    },

    questionText: {
      type: String,
      trim: true,
      maxlength: [1000, "Question text cannot exceed 1000 characters."],
      default: "",
    },

    answer: {
      type: mongoose.Schema.Types.Mixed,
      default: "",
    },
  },
  {
    _id: false,
  }
);

const surveyResponseSchema = new mongoose.Schema(
  {
    survey: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Survey",
      required: [true, "Survey is required."],
      index: true,
    },

    rhu: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "RHU",
      required: [true, "RHU is required."],
      index: true,
    },

    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: [true, "User is required."],
      index: true,
    },

    respondentName: {
      type: String,
      trim: true,
      required: [true, "Respondent name is required."],
      maxlength: [150, "Respondent name cannot exceed 150 characters."],
    },

    contactNumber: {
      type: String,
      trim: true,
      maxlength: [30, "Contact number cannot exceed 30 characters."],
      default: "",
    },

    email: {
      type: String,
      trim: true,
      lowercase: true,
      maxlength: [150, "Email cannot exceed 150 characters."],
      default: "",
    },

    answers: {
      type: [surveyAnswerSchema],
      default: [],
    },

    submittedAt: {
      type: Date,
      default: Date.now,
      index: true,
    },
  },
  {
    timestamps: true,
  }
);

surveyResponseSchema.index(
  {
    survey: 1,
    user: 1,
  },
  {
    unique: true,
  }
);

surveyResponseSchema.methods.toSafeObject = function () {
  const response = this.toObject();

  delete response.__v;

  return response;
};

module.exports = mongoose.model("SurveyResponse", surveyResponseSchema);