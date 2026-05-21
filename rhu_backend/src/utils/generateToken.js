const jwt = require("jsonwebtoken");

const getObjectIdString = (value) => {
  if (!value) {
    return null;
  }

  if (value._id) {
    return value._id.toString();
  }

  return value.toString();
};

const generateToken = (payload, options = {}) => {
  if (!process.env.JWT_SECRET) {
    throw new Error("JWT_SECRET is missing in environment variables.");
  }

  if (!payload || typeof payload !== "object") {
    throw new Error("Token payload must be a valid object.");
  }

  const defaultOptions = {
    expiresIn: process.env.JWT_EXPIRES_IN || "7d",
    issuer: process.env.JWT_ISSUER || "rhu-mobile-portal",
    audience: process.env.JWT_AUDIENCE || "rhu-android-app",
  };

  return jwt.sign(payload, process.env.JWT_SECRET, {
    ...defaultOptions,
    ...options,
  });
};

const verifyToken = (token) => {
  if (!process.env.JWT_SECRET) {
    throw new Error("JWT_SECRET is missing in environment variables.");
  }

  if (!token || typeof token !== "string") {
    throw new Error("Token is required.");
  }

  return jwt.verify(token, process.env.JWT_SECRET, {
    issuer: process.env.JWT_ISSUER || "rhu-mobile-portal",
    audience: process.env.JWT_AUDIENCE || "rhu-android-app",
  });
};

const generateUserToken = (user) => {
  if (!user || !user._id) {
    throw new Error("Valid user is required to generate token.");
  }

  return generateToken({
    id: user._id.toString(),
    role: user.role,
    rhu: getObjectIdString(user.rhu),
    barangay: getObjectIdString(user.barangay),
  });
};

module.exports = {
  generateToken,
  verifyToken,
  generateUserToken,
};