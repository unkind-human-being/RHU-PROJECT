const User = require("../models/User");
const { verifyToken } = require("../utils/generateToken");
const { ERROR_MESSAGES } = require("../utils/constants");

const getTokenFromHeader = (req) => {
  const authHeader = req.headers.authorization || req.headers.Authorization;

  if (!authHeader) {
    return null;
  }

  if (!authHeader.startsWith("Bearer ")) {
    return null;
  }

  return authHeader.split(" ")[1];
};

const protect = async (req, res, next) => {
  try {
    const token = getTokenFromHeader(req);

    if (!token) {
      return res.status(401).json({
        success: false,
        message: ERROR_MESSAGES.TOKEN_MISSING,
      });
    }

    const decoded = verifyToken(token);

    const user = await User.findById(decoded.id)
      .select("-password")
      .populate("rhu", "name code municipality province")
      .populate("barangay", "name code municipality province");

    if (!user) {
      return res.status(401).json({
        success: false,
        message: ERROR_MESSAGES.TOKEN_INVALID,
      });
    }

    if (!user.isActive) {
      return res.status(403).json({
        success: false,
        message: ERROR_MESSAGES.ACCOUNT_DISABLED,
      });
    }

    req.user = user;
    req.userId = user._id;
    req.userRole = user.role;

    next();
  } catch (error) {
    return res.status(401).json({
      success: false,
      message: ERROR_MESSAGES.TOKEN_INVALID,
    });
  }
};

const optionalAuth = async (req, res, next) => {
  try {
    const token = getTokenFromHeader(req);

    if (!token) {
      req.user = null;
      req.userId = null;
      req.userRole = null;
      return next();
    }

    const decoded = verifyToken(token);

    const user = await User.findById(decoded.id)
      .select("-password")
      .populate("rhu", "name code municipality province")
      .populate("barangay", "name code municipality province");

    if (!user || !user.isActive) {
      req.user = null;
      req.userId = null;
      req.userRole = null;
      return next();
    }

    req.user = user;
    req.userId = user._id;
    req.userRole = user.role;

    next();
  } catch (error) {
    req.user = null;
    req.userId = null;
    req.userRole = null;
    next();
  }
};

const requireActiveUser = (req, res, next) => {
  if (!req.user) {
    return res.status(401).json({
      success: false,
      message: ERROR_MESSAGES.UNAUTHORIZED,
    });
  }

  if (!req.user.isActive) {
    return res.status(403).json({
      success: false,
      message: ERROR_MESSAGES.ACCOUNT_DISABLED,
    });
  }

  next();
};

module.exports = {
  protect,
  optionalAuth,
  requireActiveUser,
};