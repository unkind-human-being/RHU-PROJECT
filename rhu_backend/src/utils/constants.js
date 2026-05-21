const USER_ROLES = Object.freeze({
  IPHO_ADMIN: "ipho_admin",
  RHU_ADMIN: "rhu_admin",
  BARANGAY_HEALTH_WORKER: "barangay_health_worker",
  PHARMACIST: "pharmacist",
  PUBLIC_USER: "public_user",
});

const AUTH_PROVIDERS = Object.freeze({
  LOCAL: "local",
  GOOGLE: "google",
});

const TRANSACTION_TYPES = Object.freeze({
  RECEIVED: "received",
  DISPENSED: "dispensed",
  ADJUSTED: "adjusted",
});

const STOCK_STATUS = Object.freeze({
  IN_STOCK: "in_stock",
  LOW_STOCK: "low_stock",
  OUT_OF_STOCK: "out_of_stock",
  EXPIRED: "expired",
});

const SYNC_STATUS = Object.freeze({
  SYNCED: "synced",
  PENDING: "pending",
  FAILED: "failed",
});

const POST_TYPES = Object.freeze({
  ANNOUNCEMENT: "announcement",
  HEALTH_UPDATE: "health_update",
  EVENT_NOTICE: "event_notice",
  PUBLIC_ADVISORY: "public_advisory",
  ACHIEVEMENT: "achievement",
});

const POST_STATUS = Object.freeze({
  DRAFT: "draft",
  PUBLISHED: "published",
  ARCHIVED: "archived",
});

const EVENT_STATUS = Object.freeze({
  DRAFT: "draft",
  OPEN: "open",
  CLOSED: "closed",
  COMPLETED: "completed",
  CANCELLED: "cancelled",
});

const EVENT_TYPES = Object.freeze({
  HEALTH_PROGRAM: "health_program",
  VACCINATION: "vaccination",
  MEDICAL_MISSION: "medical_mission",
  DEWORMING: "deworming",
  FREE_CIRCUMCISION: "free_circumcision",
  COMMUNITY_MEETING: "community_meeting",
  OTHER: "other",
});

const SURVEY_STATUS = Object.freeze({
  DRAFT: "draft",
  OPEN: "open",
  CLOSED: "closed",
  ARCHIVED: "archived",
});

const SURVEY_TYPES = Object.freeze({
  HEALTH_FEEDBACK: "health_feedback",
  EVENT_FEEDBACK: "event_feedback",
  COMMUNITY_NEEDS: "community_needs",
  MEDICINE_AVAILABILITY: "medicine_availability",
  GENERAL: "general",
});

const QUESTION_TYPES = Object.freeze({
  SHORT_TEXT: "short_text",
  LONG_TEXT: "long_text",
  MULTIPLE_CHOICE: "multiple_choice",
  CHECKBOX: "checkbox",
  YES_NO: "yes_no",
  NUMBER: "number",
  DATE: "date",
});

const AUDIENCE_SCOPE = Object.freeze({
  PUBLIC: "public",
  RHU_ONLY: "rhu_only",
  BARANGAY_ONLY: "barangay_only",
});

const SYNC_ENTITY_TYPES = Object.freeze({
  MEDICINE: "medicine",
  MEDICINE_TRANSACTION: "medicine_transaction",
  POST: "post",
  EVENT: "event",
  SURVEY: "survey",
  USER: "user",
  BARANGAY: "barangay",
});

const SYNC_ACTIONS = Object.freeze({
  CREATE: "create",
  UPDATE: "update",
  DELETE: "delete",
  BULK_SYNC: "bulk_sync",
});

const SYNC_LOG_STATUS = Object.freeze({
  SUCCESS: "success",
  FAILED: "failed",
  PARTIAL: "partial",
});

const ACCOUNT_STATUS = Object.freeze({
  ACTIVE: true,
  INACTIVE: false,
});

const DEFAULT_PROVINCE = "Tawi-Tawi";

const RHU_CODES = Object.freeze({
  BONGAO: "rhu_bongao",
  SIBUTU: "rhu_sibutu",
  PANGLIMA_SUGALA: "rhu_panglima_sugala",
  SAPA_SAPA: "rhu_sapa_sapa",
  SIMUNUL: "rhu_simunul",
  TANDUBAS: "rhu_tandubas",
  TURTLE_ISLAND: "rhu_turtle_island",
  SOUTH_UBIAN: "rhu_south_ubian",
  SITANGKAI: "rhu_sitangkai",
  LANGUYAN: "rhu_languyan",
  MAPUN: "rhu_mapun",
});

const PAGINATION = Object.freeze({
  DEFAULT_PAGE: 1,
  DEFAULT_LIMIT: 20,
  MAX_LIMIT: 100,
});

const PASSWORD_RULES = Object.freeze({
  MIN_LENGTH: 8,
});

const TOKEN_TYPES = Object.freeze({
  ACCESS: "access",
});

const ERROR_MESSAGES = Object.freeze({
  UNAUTHORIZED: "You are not authorized to access this resource.",
  FORBIDDEN: "You do not have permission to perform this action.",
  NOT_FOUND: "Resource not found.",
  VALIDATION_ERROR: "Validation error.",
  SERVER_ERROR: "Internal server error.",
  INVALID_CREDENTIALS: "Invalid email or password.",
  ACCOUNT_DISABLED: "This account is disabled.",
  TOKEN_MISSING: "Authentication token is missing.",
  TOKEN_INVALID: "Authentication token is invalid or expired.",
});

const SUCCESS_MESSAGES = Object.freeze({
  LOGIN_SUCCESS: "Login successful.",
  CREATED: "Record created successfully.",
  UPDATED: "Record updated successfully.",
  DELETED: "Record deleted successfully.",
  FETCHED: "Record fetched successfully.",
  SYNC_SUCCESS: "Sync completed successfully.",
});

module.exports = {
  USER_ROLES,
  AUTH_PROVIDERS,
  TRANSACTION_TYPES,
  STOCK_STATUS,
  SYNC_STATUS,
  POST_TYPES,
  POST_STATUS,
  EVENT_STATUS,
  EVENT_TYPES,
  SURVEY_STATUS,
  SURVEY_TYPES,
  QUESTION_TYPES,
  AUDIENCE_SCOPE,
  SYNC_ENTITY_TYPES,
  SYNC_ACTIONS,
  SYNC_LOG_STATUS,
  ACCOUNT_STATUS,
  DEFAULT_PROVINCE,
  RHU_CODES,
  PAGINATION,
  PASSWORD_RULES,
  TOKEN_TYPES,
  ERROR_MESSAGES,
  SUCCESS_MESSAGES,
};