const jwt = require("jsonwebtoken");

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

const getGatewaySecretFromHeader = (req) => {
  return (
    req.headers["x-internal-gateway-secret"] ||
    req.headers["x-gateway-secret"] ||
    req.headers["X-Internal-Gateway-Secret"] ||
    req.headers["X-Gateway-Secret"]
  );
};

const isTrustedGatewayRequest = (req) => {
  const gatewaySecret = getGatewaySecretFromHeader(req);

  if (!gatewaySecret || !process.env.GATEWAY_INTERNAL_SECRET) {
    return false;
  }

  return gatewaySecret === process.env.GATEWAY_INTERNAL_SECRET;
};

const loadRhuUserById = async (userId) => {
  if (!userId) {
    return null;
  }

  return User.findById(userId)
    .select("-password")
    .populate("rhu", "name code municipality province")
    .populate("barangay", "name code municipality province");
};

const loadRhuUserByTawiTawiUserId = async (tawiTawiUserId) => {
  if (!tawiTawiUserId) {
    return null;
  }

  return User.findOne({
    tawiTawiUserId,
  })
    .select("-password")
    .populate("rhu", "name code municipality province")
    .populate("barangay", "name code municipality province");
};

const attachUserToRequest = (req, user, options = {}) => {
  req.user = user;
  req.userId = user._id;
  req.userRole = user.role;

  if (options.isGatewayUser) {
    req.isGatewayUser = true;
  }

  if (options.tawiTawiUserId) {
    req.tawiTawiUserId = options.tawiTawiUserId;
  }
};

const decodeTawiTawiTokenPayload = (token) => {
  const decoded = jwt.decode(token);

  if (!decoded || typeof decoded !== "object") {
    return null;
  }

  if (decoded.exp && Date.now() >= decoded.exp * 1000) {
    return null;
  }

  const tawiTawiUserId = decoded.userId || decoded.id || decoded.sub;

  if (!tawiTawiUserId) {
    return null;
  }

  return {
    tawiTawiUserId,
    decoded,
  };
};

const tryGatewayAuth = async (req, token) => {
  if (!isTrustedGatewayRequest(req)) {
    return {
      success: false,
      statusCode: 401,
      message: ERROR_MESSAGES.TOKEN_INVALID,
    };
  }

  const payload = decodeTawiTawiTokenPayload(token);

  if (!payload) {
    return {
      success: false,
      statusCode: 401,
      message: ERROR_MESSAGES.TOKEN_INVALID,
    };
  }

  const user = await loadRhuUserByTawiTawiUserId(payload.tawiTawiUserId);

  if (!user) {
    return {
      success: false,
      statusCode: 403,
      message:
        "This Tawi-Tawi account is not linked to an RHU Social Health account.",
    };
  }

  if (!user.isActive) {
    return {
      success: false,
      statusCode: 403,
      message: ERROR_MESSAGES.ACCOUNT_DISABLED,
    };
  }

  attachUserToRequest(req, user, {
    isGatewayUser: true,
    tawiTawiUserId: payload.tawiTawiUserId,
  });

  return {
    success: true,
    user,
  };
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

    try {
      const decoded = verifyToken(token);

      const user = await loadRhuUserById(decoded.id);

      if (!user) {
        throw new Error("RHU user not found.");
      }

      if (!user.isActive) {
        return res.status(403).json({
          success: false,
          message: ERROR_MESSAGES.ACCOUNT_DISABLED,
        });
      }

      attachUserToRequest(req, user);

      return next();
    } catch (_) {
      const gatewayAuth = await tryGatewayAuth(req, token);

      if (gatewayAuth.success) {
        return next();
      }

      return res.status(gatewayAuth.statusCode || 401).json({
        success: false,
        message: gatewayAuth.message || ERROR_MESSAGES.TOKEN_INVALID,
      });
    }
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

    try {
      const decoded = verifyToken(token);

      const user = await loadRhuUserById(decoded.id);

      if (!user || !user.isActive) {
        req.user = null;
        req.userId = null;
        req.userRole = null;
        return next();
      }

      attachUserToRequest(req, user);

      return next();
    } catch (_) {
      const gatewayAuth = await tryGatewayAuth(req, token);

      if (gatewayAuth.success) {
        return next();
      }

      req.user = null;
      req.userId = null;
      req.userRole = null;
      return next();
    }
  } catch (error) {
    req.user = null;
    req.userId = null;
    req.userRole = null;
    return next();
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