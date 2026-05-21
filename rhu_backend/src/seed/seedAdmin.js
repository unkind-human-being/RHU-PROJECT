const dotenv = require("dotenv");
const mongoose = require("mongoose");

dotenv.config();

const User = require("../models/User");
const { connectDatabase, closeDatabase } = require("../config/db");
const { USER_ROLES } = require("../utils/constants");

const adminData = {
  fullName: process.env.SEED_ADMIN_NAME || "IPHO System Administrator",
  email: process.env.SEED_ADMIN_EMAIL || "admin@rhu-tawitawi.local",
  password: process.env.SEED_ADMIN_PASSWORD || "AdminPassword123",
  role: USER_ROLES.IPHO_ADMIN,
  rhu: null,
  barangay: null,
  position: "IPHO Administrator",
  phoneNumber: "",
  isActive: true,
};

const seedAdmin = async () => {
  try {
    await connectDatabase();

    console.log("Starting admin seed process...");

    const existingAdmin = await User.findOne({
      email: adminData.email.toLowerCase().trim(),
    }).select("+password");

    if (existingAdmin) {
      existingAdmin.fullName = adminData.fullName;
      existingAdmin.role = USER_ROLES.IPHO_ADMIN;
      existingAdmin.rhu = null;
      existingAdmin.barangay = null;
      existingAdmin.position = adminData.position;
      existingAdmin.phoneNumber = adminData.phoneNumber;
      existingAdmin.isActive = true;

      if (process.env.RESET_SEED_ADMIN_PASSWORD === "true") {
        existingAdmin.password = adminData.password;
      }

      await existingAdmin.save();

      console.log("Existing IPHO admin account updated.");
      console.log(`Email: ${existingAdmin.email}`);

      if (process.env.RESET_SEED_ADMIN_PASSWORD === "true") {
        console.log("Password was reset from SEED_ADMIN_PASSWORD.");
      } else {
        console.log("Password was not changed.");
      }

      await closeDatabase();
      process.exit(0);
    }

    const admin = await User.create(adminData);

    console.log("----------------------------------------");
    console.log("IPHO admin account created successfully.");
    console.log(`Name: ${admin.fullName}`);
    console.log(`Email: ${admin.email}`);
    console.log("----------------------------------------");

    await closeDatabase();
    process.exit(0);
  } catch (error) {
    console.error("Admin seed failed.");
    console.error(error.message);

    if (error.errors) {
      for (const field of Object.keys(error.errors)) {
        console.error(`${field}: ${error.errors[field].message}`);
      }
    }

    await mongoose.connection.close();
    process.exit(1);
  }
};

seedAdmin();