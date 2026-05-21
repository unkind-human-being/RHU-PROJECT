const express = require("express");

const {
  getPublicPosts,
  getPosts,
  getPostById,
  createPost,
  updatePost,
  publishPost,
  archivePost,
  deletePost,
  incrementPostView,
} = require("../controllers/postController");

const { protect, optionalAuth } = require("../middleware/authMiddleware");
const { isStaff } = require("../middleware/roleMiddleware");

const router = express.Router();

router.get("/public", getPublicPosts);

router.get("/", protect, isStaff, getPosts);

router.post("/", protect, isStaff, createPost);

router.get("/:id", optionalAuth, getPostById);

router.patch("/:id", protect, isStaff, updatePost);

router.patch("/:id/publish", protect, isStaff, publishPost);

router.patch("/:id/archive", protect, isStaff, archivePost);

router.patch("/:id/view", incrementPostView);

router.delete("/:id", protect, isStaff, deletePost);

module.exports = router;