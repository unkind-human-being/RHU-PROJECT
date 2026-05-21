const mongoose = require("mongoose");

const sendErrorResponse = (res, statusCode, message, errors = null) => {
  const response = {
    success: false,
    message,
  };

  if (errors) {
    response.errors = errors;
  }

  return res.status(statusCode).json(response);
};

const notFound = (req, res, next) => {
  return sendErrorResponse(
    res,
    404,
    "API route not found.",
    {
      path: req.originalUrl,
      method: req.method,
    }
  );
};

const errorHandler = (error, req, res, next) => {
  console.error("Error:", error);

  let statusCode = res.statusCode && res.statusCode !== 200 ? res.statusCode : 500;
  let message = error.message || "Internal server error.";
  let errors = null;

  if (error instanceof mongoose.Error.ValidationError) {
    statusCode = 400;
    message = "Validation error.";

    errors = Object.values(error.errors).map((item) => ({
      field: item.path,
      message: item.message,
    }));
  }

  if (error instanceof mongoose.Error.CastError) {
    statusCode = 400;
    message = "Invalid ID format.";

    errors = {
      field: error.path,
      value: error.value,
    };
  }

  if (error.code === 11000) {
    statusCode = 409;
    message = "Duplicate record found.";

    const duplicateFields = Object.keys(error.keyValue || {});

    errors = duplicateFields.map((field) => ({
      field,
      value: error.keyValue[field],
      message: `${field} already exists.`,
    }));
  }

  if (error.name === "JsonWebTokenError") {
    statusCode = 401;
    message = "Authentication token is invalid.";
  }

  if (error.name === "TokenExpiredError") {
    statusCode = 401;
    message = "Authentication token has expired.";
  }

  if (error.name === "SyntaxError" && error.type === "entity.parse.failed") {
    statusCode = 400;
    message = "Invalid JSON request body.";
  }

  return sendErrorResponse(res, statusCode, message, errors);
};

const asyncHandler = (controllerFunction) => {
  return (req, res, next) => {
    Promise.resolve(controllerFunction(req, res, next)).catch(next);
  };
};

module.exports = {
  notFound,
  errorHandler,
  asyncHandler,
};