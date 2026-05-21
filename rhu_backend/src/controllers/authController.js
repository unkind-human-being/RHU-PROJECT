const User = require("../models/User");
const { generateUserToken } = require("../utils/generateToken");

const {
  ERROR_MESSAGES,
  SUCCESS_MESSAGES,
  USER_ROLES,
} = require("../utils/constants");

const { asyncHandler } = require("../middleware/errorMiddleware");

const buildUserResponse = (user) => {
  const safeUser = user.toObject ? user.toObject() : user;

  delete safeUser.password;
  delete safeUser.__v;

  return safeUser;
};

const sendAuthResponse = (
  res,
  statusCode,
  user,
  message = SUCCESS_MESSAGES.LOGIN_SUCCESS
) => {
  const token = generateUserToken(user);

  return res.status(statusCode).json({
    success: true,
    message,
    token,
    user: buildUserResponse(user),
  });
};

const register = asyncHandler(async (req, res) => {
  const { fullName, email, password, phoneNumber } = req.body;

  if (!fullName || !email || !password) {
    return res.status(400).json({
      success: false,
      message: "Full name, email, and password are required.",
    });
  }

  if (password.length < 8) {
    return res.status(400).json({
      success: false,
      message: "Password must be at least 8 characters.",
    });
  }

  const normalizedEmail = email.toLowerCase().trim();

  const existingUser = await User.findOne({
    email: normalizedEmail,
  });

  if (existingUser) {
    return res.status(409).json({
      success: false,
      message: "Email already exists. Please login instead.",
    });
  }

  const user = await User.create({
    fullName: fullName.trim(),
    email: normalizedEmail,
    password,
    phoneNumber: phoneNumber || "",
    role: USER_ROLES.PUBLIC_USER,
    rhu: null,
    barangay: null,
    position: "Public User",
    isActive: true,
  });

  const createdUser = await User.findById(user._id)
    .select("-password")
    .populate("rhu", "name code municipality province")
    .populate("barangay", "name code municipality province");

  return res.status(201).json({
    success: true,
    message: "Public user account created successfully.",
    user: buildUserResponse(createdUser),
  });
});

const login = asyncHandler(async (req, res) => {
  const { email, password } = req.body;

  if (!email || !password) {
    return res.status(400).json({
      success: false,
      message: "Email and password are required.",
    });
  }

  const user = await User.findOne({
    email: email.toLowerCase().trim(),
  })
    .select("+password")
    .populate("rhu", "name code municipality province")
    .populate("barangay", "name code municipality province");

  if (!user) {
    return res.status(401).json({
      success: false,
      message: ERROR_MESSAGES.INVALID_CREDENTIALS,
    });
  }

  if (!user.isActive) {
    return res.status(403).json({
      success: false,
      message: ERROR_MESSAGES.ACCOUNT_DISABLED,
    });
  }

  const isPasswordCorrect = await user.comparePassword(password);

  if (!isPasswordCorrect) {
    return res.status(401).json({
      success: false,
      message: ERROR_MESSAGES.INVALID_CREDENTIALS,
    });
  }

  user.lastLoginAt = new Date();
  await user.save();

  return sendAuthResponse(res, 200, user);
});

const getMe = asyncHandler(async (req, res) => {
  const user = await User.findById(req.userId)
    .select("-password")
    .populate("rhu", "name code municipality province")
    .populate("barangay", "name code municipality province");

  if (!user) {
    return res.status(404).json({
      success: false,
      message: "User account not found.",
    });
  }

  return res.status(200).json({
    success: true,
    message: "User profile fetched successfully.",
    user: buildUserResponse(user),
  });
});

const updateMyProfile = asyncHandler(async (req, res) => {
  const allowedUpdates = ["fullName", "phoneNumber", "position"];
  const updates = {};

  for (const field of allowedUpdates) {
    if (Object.prototype.hasOwnProperty.call(req.body, field)) {
      updates[field] = req.body[field];
    }
  }

  const user = await User.findByIdAndUpdate(req.userId, updates, {
    new: true,
    runValidators: true,
  })
    .select("-password")
    .populate("rhu", "name code municipality province")
    .populate("barangay", "name code municipality province");

  if (!user) {
    return res.status(404).json({
      success: false,
      message: "User account not found.",
    });
  }

  return res.status(200).json({
    success: true,
    message: "Profile updated successfully.",
    user: buildUserResponse(user),
  });
});

const changeMyPassword = asyncHandler(async (req, res) => {
  const { currentPassword, newPassword } = req.body;

  if (!currentPassword || !newPassword) {
    return res.status(400).json({
      success: false,
      message: "Current password and new password are required.",
    });
  }

  if (newPassword.length < 8) {
    return res.status(400).json({
      success: false,
      message: "New password must be at least 8 characters.",
    });
  }

  const user = await User.findById(req.userId).select("+password");

  if (!user) {
    return res.status(404).json({
      success: false,
      message: "User account not found.",
    });
  }

  const isPasswordCorrect = await user.comparePassword(currentPassword);

  if (!isPasswordCorrect) {
    return res.status(401).json({
      success: false,
      message: "Current password is incorrect.",
    });
  }

  user.password = newPassword;
  await user.save();

  return res.status(200).json({
    success: true,
    message: "Password changed successfully.",
  });
});

const logout = asyncHandler(async (req, res) => {
  return res.status(200).json({
    success: true,
    message: "Logout successful. Please remove the token from the client app.",
  });
});

module.exports = {
  register,
  login,
  getMe,
  updateMyProfile,
  changeMyPassword,
  logout,
};