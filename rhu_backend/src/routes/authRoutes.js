const express = require("express");

const {
  register,
  login,
  getMe,
  updateMyProfile,
  changeMyPassword,
  logout,
} = require("../controllers/authController");

const { protect } = require("../middleware/authMiddleware");

const router = express.Router();

router.post("/register", register);

router.post("/login", login);

router.get("/me", protect, getMe);

router.patch("/me", protect, updateMyProfile);

router.patch("/change-password", protect, changeMyPassword);

router.post("/logout", protect, logout);

module.exports = router;