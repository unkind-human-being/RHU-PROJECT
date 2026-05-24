const mongoose = require("mongoose");
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");

const USER_ROLES = {
  IPHO_ADMIN: "ipho_admin",
  RHU_ADMIN: "rhu_admin",
  BARANGAY_HEALTH_WORKER: "barangay_health_worker",
  PHARMACIST: "pharmacist",
  PUBLIC_USER: "public_user",
};

const AUTH_PROVIDERS = {
  LOCAL: "local",
  GOOGLE: "google",
  META: "meta",
  GATEWAY: "gateway",
};

const fcmTokenSchema = new mongoose.Schema(
  {
    token: {
      type: String,
      required: true,
      trim: true,
    },

    platform: {
      type: String,
      trim: true,
      default: "android",
    },

    purpose: {
      type: String,
      trim: true,
      default: "incoming_call",
    },

    lastUsedAt: {
      type: Date,
      default: Date.now,
    },
  },
  {
    _id: false,
  }
);

const userSchema = new mongoose.Schema(
  {
    fullName: {
      type: String,
      required: [true, "Full name is required."],
      trim: true,
      minlength: [2, "Full name must be at least 2 characters."],
      maxlength: [120, "Full name cannot exceed 120 characters."],
    },

    email: {
      type: String,
      required: [true, "Email is required."],
      unique: true,
      lowercase: true,
      trim: true,
      match: [/^\S+@\S+\.\S+$/, "Please provide a valid email address."],
    },

    password: {
      type: String,
      minlength: [8, "Password must be at least 8 characters."],
      select: false,
      required: function () {
        return this.authProvider === AUTH_PROVIDERS.LOCAL;
      },
    },

    role: {
      type: String,
      enum: Object.values(USER_ROLES),
      default: USER_ROLES.PUBLIC_USER,
      index: true,
    },

    authProvider: {
      type: String,
      enum: Object.values(AUTH_PROVIDERS),
      default: AUTH_PROVIDERS.LOCAL,
    },

    googleId: {
      type: String,
      trim: true,
      sparse: true,
      index: true,
    },

    metaId: {
      type: String,
      trim: true,
      sparse: true,
      index: true,
    },

    tawiTawiUserId: {
      type: String,
      trim: true,
      sparse: true,
      index: true,
      default: null,
    },

    linkedFromGateway: {
      type: Boolean,
      default: false,
      index: true,
    },

    gatewayLinkedAt: {
      type: Date,
      default: null,
    },

    rhu: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "RHU",
      default: null,
      index: true,
    },

    barangay: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Barangay",
      default: null,
      index: true,
    },

    position: {
      type: String,
      trim: true,
      maxlength: [120, "Position cannot exceed 120 characters."],
      default: "",
    },

    phoneNumber: {
      type: String,
      trim: true,
      maxlength: [30, "Phone number cannot exceed 30 characters."],
      default: "",
    },

    fcmTokens: {
      type: [fcmTokenSchema],
      default: [],
    },

    isActive: {
      type: Boolean,
      default: true,
      index: true,
    },

    createdBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      default: null,
    },

    lastLoginAt: {
      type: Date,
      default: null,
    },

    passwordChangedAt: {
      type: Date,
      default: null,
    },
  },
  {
    timestamps: true,
  }
);

userSchema.index({ role: 1, rhu: 1 });
userSchema.index({ role: 1, barangay: 1 });

userSchema.pre("save", async function () {
  if (!this.isModified("password")) {
    return;
  }

  if (!this.password) {
    return;
  }

  const salt = await bcrypt.genSalt(12);
  this.password = await bcrypt.hash(this.password, salt);
  this.passwordChangedAt = new Date();
});

userSchema.methods.comparePassword = async function (candidatePassword) {
  if (!this.password) {
    return false;
  }

  return bcrypt.compare(candidatePassword, this.password);
};

userSchema.methods.generateAuthToken = function () {
  if (!process.env.JWT_SECRET) {
    throw new Error("JWT_SECRET is missing in environment variables.");
  }

  const getObjectIdString = (value) => {
    if (!value) {
      return null;
    }

    if (value._id) {
      return value._id.toString();
    }

    return value.toString();
  };

  return jwt.sign(
    {
      id: this._id.toString(),
      role: this.role,
      rhu: getObjectIdString(this.rhu),
      barangay: getObjectIdString(this.barangay),
    },
    process.env.JWT_SECRET,
    {
      expiresIn: process.env.JWT_EXPIRES_IN || "7d",
      issuer: process.env.JWT_ISSUER || "rhu-mobile-portal",
      audience: process.env.JWT_AUDIENCE || "rhu-android-app",
    }
  );
};

userSchema.methods.toSafeObject = function () {
  const user = this.toObject();

  delete user.password;
  delete user.__v;

  return user;
};

userSchema.statics.isRoleValid = function (role) {
  return Object.values(USER_ROLES).includes(role);
};

userSchema.statics.roles = USER_ROLES;
userSchema.statics.authProviders = AUTH_PROVIDERS;

module.exports = mongoose.model("User", userSchema);