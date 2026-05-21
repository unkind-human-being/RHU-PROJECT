const swaggerDocument = {
  openapi: "3.0.0",
  info: {
    title: "Tawi-Tawi RHU Mobile Portal API",
    version: "1.0.0",
    description:
      "Backend API for Tawi-Tawi RHU Mobile Portal: health updates, events, surveys, medicine supply monitoring, and offline sync.",
  },
  servers: [
    {
      url: "http://localhost:5000",
      description: "Local development server",
    },
  ],
  tags: [
    { name: "Health", description: "Server health check" },
    { name: "Auth", description: "Authentication endpoints" },
    { name: "RHUs", description: "RHU office node management" },
    { name: "Barangays", description: "Barangay operating node management" },
    { name: "Users", description: "User and health worker accounts" },
    { name: "Medicines", description: "Medicine inventory and transactions" },
    { name: "Sync", description: "Offline sync endpoints" },
    { name: "Posts", description: "RHU public posts and announcements" },
    { name: "Events", description: "Health events and registrations" },
    { name: "Surveys", description: "Survey management" },
  ],
  components: {
    securitySchemes: {
      bearerAuth: {
        type: "http",
        scheme: "bearer",
        bearerFormat: "JWT",
      },
    },
    schemas: {
      LoginRequest: {
        type: "object",
        required: ["email", "password"],
        properties: {
          email: {
            type: "string",
            example: "admin@rhu-tawitawi.local",
          },
          password: {
            type: "string",
            example: "AdminPassword123",
          },
        },
      },
      CreateRHURequest: {
        type: "object",
        required: ["name", "code", "municipality", "barangayCount"],
        properties: {
          name: {
            type: "string",
            example: "Bongao Rural Health Unit",
          },
          code: {
            type: "string",
            example: "rhu_bongao",
          },
          municipality: {
            type: "string",
            example: "Bongao",
          },
          province: {
            type: "string",
            example: "Tawi-Tawi",
          },
          barangayCount: {
            type: "number",
            example: 35,
          },
          address: {
            type: "string",
            example: "Bongao, Tawi-Tawi",
          },
          contactNumber: {
            type: "string",
            example: "09123456789",
          },
          email: {
            type: "string",
            example: "bongao-rhu@example.com",
          },
        },
      },
      CreateBarangayRequest: {
        type: "object",
        required: ["name", "code", "rhu"],
        properties: {
          name: {
            type: "string",
            example: "Poblacion",
          },
          code: {
            type: "string",
            example: "brgy_poblacion",
          },
          rhu: {
            type: "string",
            example: "MongoDB_RHU_ID_HERE",
          },
          municipality: {
            type: "string",
            example: "Bongao",
          },
          province: {
            type: "string",
            example: "Tawi-Tawi",
          },
          address: {
            type: "string",
            example: "Poblacion, Bongao",
          },
          contactNumber: {
            type: "string",
            example: "09123456789",
          },
        },
      },
      CreateUserRequest: {
        type: "object",
        required: ["fullName", "email", "password", "role"],
        properties: {
          fullName: {
            type: "string",
            example: "Juan Dela Cruz",
          },
          email: {
            type: "string",
            example: "juan@example.com",
          },
          password: {
            type: "string",
            example: "Password123",
          },
          role: {
            type: "string",
            enum: [
              "ipho_admin",
              "rhu_admin",
              "barangay_health_worker",
              "public_user",
            ],
            example: "rhu_admin",
          },
          rhu: {
            type: "string",
            example: "MongoDB_RHU_ID_HERE",
          },
          barangay: {
            type: "string",
            example: "MongoDB_BARANGAY_ID_HERE",
          },
          position: {
            type: "string",
            example: "RHU Admin",
          },
          phoneNumber: {
            type: "string",
            example: "09123456789",
          },
        },
      },
      CreateMedicineRequest: {
        type: "object",
        required: ["name", "unit", "rhu", "barangay"],
        properties: {
          name: {
            type: "string",
            example: "Paracetamol",
          },
          genericName: {
            type: "string",
            example: "Paracetamol",
          },
          brandName: {
            type: "string",
            example: "Generic",
          },
          dosageForm: {
            type: "string",
            example: "tablet",
          },
          strength: {
            type: "string",
            example: "500mg",
          },
          unit: {
            type: "string",
            example: "pcs",
          },
          category: {
            type: "string",
            example: "Pain reliever",
          },
          rhu: {
            type: "string",
            example: "MongoDB_RHU_ID_HERE",
          },
          barangay: {
            type: "string",
            example: "MongoDB_BARANGAY_ID_HERE",
          },
          currentStock: {
            type: "number",
            example: 100,
          },
          minimumStockLevel: {
            type: "number",
            example: 20,
          },
          maximumStockLevel: {
            type: "number",
            example: 500,
          },
          batchNumber: {
            type: "string",
            example: "BATCH-2026-001",
          },
          expirationDate: {
            type: "string",
            format: "date",
            example: "2027-04-30",
          },
          supplier: {
            type: "string",
            example: "DOH Supply",
          },
          remarks: {
            type: "string",
            example: "Initial stock",
          },
        },
      },
      MedicineTransactionRequest: {
        type: "object",
        required: ["medicine", "transactionType", "quantity"],
        properties: {
          medicine: {
            type: "string",
            example: "MongoDB_MEDICINE_ID_HERE",
          },
          transactionType: {
            type: "string",
            enum: ["received", "dispensed", "adjusted"],
            example: "received",
          },
          quantity: {
            type: "number",
            example: 50,
          },
          reason: {
            type: "string",
            example: "New stock received",
          },
          remarks: {
            type: "string",
            example: "Delivered by RHU office",
          },
          patientReference: {
            type: "string",
            example: "",
          },
          source: {
            type: "string",
            example: "RHU Supply",
          },
          clientGeneratedId: {
            type: "string",
            example: "device123-transaction-001",
          },
          deviceId: {
            type: "string",
            example: "device123",
          },
          offlineCreatedAt: {
            type: "string",
            format: "date-time",
            example: "2026-04-30T09:00:00.000Z",
          },
        },
      },
      CreatePostRequest: {
        type: "object",
        required: ["title", "content", "rhu"],
        properties: {
          title: {
            type: "string",
            example: "Free Medical Checkup",
          },
          content: {
            type: "string",
            example: "There will be a free medical checkup this Friday.",
          },
          type: {
            type: "string",
            example: "announcement",
          },
          status: {
            type: "string",
            example: "published",
          },
          audienceScope: {
            type: "string",
            example: "public",
          },
          rhu: {
            type: "string",
            example: "MongoDB_RHU_ID_HERE",
          },
          barangay: {
            type: "string",
            example: "MongoDB_BARANGAY_ID_HERE",
          },
          tags: {
            type: "array",
            items: {
              type: "string",
            },
            example: ["health", "announcement"],
          },
        },
      },
      CreateEventRequest: {
        type: "object",
        required: ["title", "description", "rhu", "locationName", "startDate", "endDate"],
        properties: {
          title: {
            type: "string",
            example: "Deworming Program",
          },
          description: {
            type: "string",
            example: "Community deworming program for children.",
          },
          type: {
            type: "string",
            example: "deworming",
          },
          status: {
            type: "string",
            example: "open",
          },
          audienceScope: {
            type: "string",
            example: "public",
          },
          rhu: {
            type: "string",
            example: "MongoDB_RHU_ID_HERE",
          },
          barangay: {
            type: "string",
            example: "MongoDB_BARANGAY_ID_HERE",
          },
          locationName: {
            type: "string",
            example: "Barangay Hall",
          },
          address: {
            type: "string",
            example: "Poblacion, Bongao",
          },
          startDate: {
            type: "string",
            format: "date-time",
            example: "2026-05-01T08:00:00.000Z",
          },
          endDate: {
            type: "string",
            format: "date-time",
            example: "2026-05-01T12:00:00.000Z",
          },
          registrationRequired: {
            type: "boolean",
            example: true,
          },
          maxParticipants: {
            type: "number",
            example: 100,
          },
        },
      },
      CreateSurveyRequest: {
        type: "object",
        required: ["title", "description", "rhu", "questions", "startDate", "endDate"],
        properties: {
          title: {
            type: "string",
            example: "Community Health Survey",
          },
          description: {
            type: "string",
            example: "Survey about local health needs.",
          },
          type: {
            type: "string",
            example: "community_needs",
          },
          status: {
            type: "string",
            example: "open",
          },
          audienceScope: {
            type: "string",
            example: "public",
          },
          rhu: {
            type: "string",
            example: "MongoDB_RHU_ID_HERE",
          },
          barangay: {
            type: "string",
            example: "MongoDB_BARANGAY_ID_HERE",
          },
          requiresLogin: {
            type: "boolean",
            example: true,
          },
          allowMultipleResponses: {
            type: "boolean",
            example: false,
          },
          startDate: {
            type: "string",
            format: "date-time",
            example: "2026-05-01T00:00:00.000Z",
          },
          endDate: {
            type: "string",
            format: "date-time",
            example: "2026-05-31T23:59:59.000Z",
          },
          questions: {
            type: "array",
            items: {
              type: "object",
              properties: {
                questionText: {
                  type: "string",
                  example: "What health service do you need most?",
                },
                type: {
                  type: "string",
                  example: "short_text",
                },
                options: {
                  type: "array",
                  items: {
                    type: "string",
                  },
                  example: [],
                },
                isRequired: {
                  type: "boolean",
                  example: true,
                },
                order: {
                  type: "number",
                  example: 1,
                },
              },
            },
          },
        },
      },
    },
  },
  paths: {
    "/api/health": {
      get: {
        tags: ["Health"],
        summary: "Check backend health",
        responses: {
          200: {
            description: "Backend is healthy",
          },
        },
      },
    },

    "/api/auth/login": {
      post: {
        tags: ["Auth"],
        summary: "Login user",
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                $ref: "#/components/schemas/LoginRequest",
              },
            },
          },
        },
        responses: {
          200: {
            description: "Login successful",
          },
          401: {
            description: "Invalid credentials",
          },
        },
      },
    },

    "/api/auth/me": {
      get: {
        tags: ["Auth"],
        summary: "Get current user profile",
        security: [{ bearerAuth: [] }],
        responses: {
          200: {
            description: "User profile fetched",
          },
          401: {
            description: "Unauthorized",
          },
        },
      },
      patch: {
        tags: ["Auth"],
        summary: "Update current user profile",
        security: [{ bearerAuth: [] }],
        requestBody: {
          content: {
            "application/json": {
              schema: {
                type: "object",
                properties: {
                  fullName: { type: "string", example: "Updated Name" },
                  phoneNumber: { type: "string", example: "09123456789" },
                  position: { type: "string", example: "Health Worker" },
                },
              },
            },
          },
        },
        responses: {
          200: {
            description: "Profile updated",
          },
        },
      },
    },

    "/api/rhus": {
      get: {
        tags: ["RHUs"],
        summary: "Get all RHUs",
        security: [{ bearerAuth: [] }],
        responses: {
          200: {
            description: "RHUs fetched",
          },
        },
      },
      post: {
        tags: ["RHUs"],
        summary: "Create RHU",
        security: [{ bearerAuth: [] }],
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                $ref: "#/components/schemas/CreateRHURequest",
              },
            },
          },
        },
        responses: {
          201: {
            description: "RHU created",
          },
        },
      },
    },

    "/api/rhus/{id}": {
      get: {
        tags: ["RHUs"],
        summary: "Get RHU by ID",
        security: [{ bearerAuth: [] }],
        parameters: [
          {
            name: "id",
            in: "path",
            required: true,
            schema: { type: "string" },
          },
        ],
        responses: {
          200: {
            description: "RHU fetched",
          },
        },
      },
      patch: {
        tags: ["RHUs"],
        summary: "Update RHU",
        security: [{ bearerAuth: [] }],
        parameters: [
          {
            name: "id",
            in: "path",
            required: true,
            schema: { type: "string" },
          },
        ],
        requestBody: {
          content: {
            "application/json": {
              schema: {
                $ref: "#/components/schemas/CreateRHURequest",
              },
            },
          },
        },
        responses: {
          200: {
            description: "RHU updated",
          },
        },
      },
      delete: {
        tags: ["RHUs"],
        summary: "Deactivate RHU",
        security: [{ bearerAuth: [] }],
        parameters: [
          {
            name: "id",
            in: "path",
            required: true,
            schema: { type: "string" },
          },
        ],
        responses: {
          200: {
            description: "RHU deactivated",
          },
        },
      },
    },

    "/api/barangays": {
      get: {
        tags: ["Barangays"],
        summary: "Get barangays",
        security: [{ bearerAuth: [] }],
        parameters: [
          {
            name: "rhu",
            in: "query",
            schema: { type: "string" },
          },
        ],
        responses: {
          200: {
            description: "Barangays fetched",
          },
        },
      },
      post: {
        tags: ["Barangays"],
        summary: "Create barangay",
        security: [{ bearerAuth: [] }],
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                $ref: "#/components/schemas/CreateBarangayRequest",
              },
            },
          },
        },
        responses: {
          201: {
            description: "Barangay created",
          },
        },
      },
    },

    "/api/users": {
      get: {
        tags: ["Users"],
        summary: "Get users",
        security: [{ bearerAuth: [] }],
        parameters: [
          {
            name: "role",
            in: "query",
            schema: { type: "string" },
          },
          {
            name: "rhu",
            in: "query",
            schema: { type: "string" },
          },
          {
            name: "barangay",
            in: "query",
            schema: { type: "string" },
          },
        ],
        responses: {
          200: {
            description: "Users fetched",
          },
        },
      },
      post: {
        tags: ["Users"],
        summary: "Create user account",
        security: [{ bearerAuth: [] }],
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                $ref: "#/components/schemas/CreateUserRequest",
              },
            },
          },
        },
        responses: {
          201: {
            description: "User created",
          },
        },
      },
    },

    "/api/users/health-worker": {
      post: {
        tags: ["Users"],
        summary: "Create barangay health worker account",
        security: [{ bearerAuth: [] }],
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                allOf: [{ $ref: "#/components/schemas/CreateUserRequest" }],
              },
            },
          },
        },
        responses: {
          201: {
            description: "Health worker account created",
          },
        },
      },
    },

    "/api/medicines": {
      get: {
        tags: ["Medicines"],
        summary: "Get medicines",
        security: [{ bearerAuth: [] }],
        parameters: [
          {
            name: "rhu",
            in: "query",
            schema: { type: "string" },
          },
          {
            name: "barangay",
            in: "query",
            schema: { type: "string" },
          },
          {
            name: "stockStatus",
            in: "query",
            schema: { type: "string" },
          },
          {
            name: "search",
            in: "query",
            schema: { type: "string" },
          },
        ],
        responses: {
          200: {
            description: "Medicines fetched",
          },
        },
      },
      post: {
        tags: ["Medicines"],
        summary: "Create medicine stock record",
        security: [{ bearerAuth: [] }],
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                $ref: "#/components/schemas/CreateMedicineRequest",
              },
            },
          },
        },
        responses: {
          201: {
            description: "Medicine created",
          },
        },
      },
    },

    "/api/medicines/summary": {
      get: {
        tags: ["Medicines"],
        summary: "Get medicine stock summary",
        security: [{ bearerAuth: [] }],
        responses: {
          200: {
            description: "Medicine summary fetched",
          },
        },
      },
    },

    "/api/medicines/transactions": {
      get: {
        tags: ["Medicines"],
        summary: "Get medicine transactions",
        security: [{ bearerAuth: [] }],
        responses: {
          200: {
            description: "Medicine transactions fetched",
          },
        },
      },
      post: {
        tags: ["Medicines"],
        summary: "Record medicine transaction",
        security: [{ bearerAuth: [] }],
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                $ref: "#/components/schemas/MedicineTransactionRequest",
              },
            },
          },
        },
        responses: {
          201: {
            description: "Medicine transaction recorded",
          },
        },
      },
    },

    "/api/sync/medicine-transactions": {
      post: {
        tags: ["Sync"],
        summary: "Sync offline medicine transactions",
        security: [{ bearerAuth: [] }],
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                type: "object",
                required: ["transactions"],
                properties: {
                  deviceId: {
                    type: "string",
                    example: "device123",
                  },
                  appVersion: {
                    type: "string",
                    example: "1.0.0",
                  },
                  platform: {
                    type: "string",
                    example: "android",
                  },
                  transactions: {
                    type: "array",
                    items: {
                      $ref: "#/components/schemas/MedicineTransactionRequest",
                    },
                  },
                },
              },
            },
          },
        },
        responses: {
          200: {
            description: "Sync completed",
          },
        },
      },
    },

        "/api/sync/logs": {
      get: {
        tags: ["Sync"],
        summary: "Get sync logs",
        security: [{ bearerAuth: [] }],
        parameters: [
          {
            name: "entityType",
            in: "query",
            schema: { type: "string" },
            example: "medicine_transaction",
          },
          {
            name: "status",
            in: "query",
            schema: { type: "string" },
            example: "success",
          },
          {
            name: "deviceId",
            in: "query",
            schema: { type: "string" },
            example: "poblacion-phone-001",
          },
          {
            name: "rhu",
            in: "query",
            schema: { type: "string" },
            example: "69f2466c70e984963d58aa0a",
          },
          {
            name: "barangay",
            in: "query",
            schema: { type: "string" },
            example: "69f24c6701a878aede5a79d7",
          },
        ],
        responses: {
          200: {
            description: "Sync logs fetched successfully",
          },
          401: {
            description: "Authentication token is missing or invalid",
          },
        },
      },
    },

    "/api/sync/status": {
      get: {
        tags: ["Sync"],
        summary: "Get sync status summary",
        security: [{ bearerAuth: [] }],
        parameters: [
          {
            name: "rhu",
            in: "query",
            schema: { type: "string" },
            example: "69f2466c70e984963d58aa0a",
          },
          {
            name: "barangay",
            in: "query",
            schema: { type: "string" },
            example: "69f24c6701a878aede5a79d7",
          },
        ],
        responses: {
          200: {
            description: "Sync status fetched successfully",
          },
          401: {
            description: "Authentication token is missing or invalid",
          },
        },
      },
    },

    "/api/sync/logs/{id}": {
      get: {
        tags: ["Sync"],
        summary: "Get sync log by ID",
        security: [{ bearerAuth: [] }],
        parameters: [
          {
            name: "id",
            in: "path",
            required: true,
            schema: { type: "string" },
            example: "69f6ab3c67d99a1e3bd697a8",
          },
        ],
        responses: {
          200: {
            description: "Sync log fetched successfully",
          },
          404: {
            description: "Sync log not found",
          },
          401: {
            description: "Authentication token is missing or invalid",
          },
        },
      },
    },

    "/api/posts/public": {
      get: {
        tags: ["Posts"],
        summary: "Get public posts",
        responses: {
          200: {
            description: "Public posts fetched",
          },
        },
      },
    },

    "/api/posts": {
      get: {
        tags: ["Posts"],
        summary: "Get staff posts",
        security: [{ bearerAuth: [] }],
        responses: {
          200: {
            description: "Posts fetched",
          },
        },
      },
      post: {
        tags: ["Posts"],
        summary: "Create post",
        security: [{ bearerAuth: [] }],
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                $ref: "#/components/schemas/CreatePostRequest",
              },
            },
          },
        },
        responses: {
          201: {
            description: "Post created",
          },
        },
      },
    },

    "/api/events/public": {
      get: {
        tags: ["Events"],
        summary: "Get public events",
        responses: {
          200: {
            description: "Public events fetched",
          },
        },
      },
    },

    "/api/events": {
      get: {
        tags: ["Events"],
        summary: "Get staff events",
        security: [{ bearerAuth: [] }],
        responses: {
          200: {
            description: "Events fetched",
          },
        },
      },
      post: {
        tags: ["Events"],
        summary: "Create event",
        security: [{ bearerAuth: [] }],
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                $ref: "#/components/schemas/CreateEventRequest",
              },
            },
          },
        },
        responses: {
          201: {
            description: "Event created",
          },
        },
      },
    },

    "/api/surveys/public": {
      get: {
        tags: ["Surveys"],
        summary: "Get public surveys",
        responses: {
          200: {
            description: "Public surveys fetched",
          },
        },
      },
    },

    "/api/surveys": {
      get: {
        tags: ["Surveys"],
        summary: "Get staff surveys",
        security: [{ bearerAuth: [] }],
        responses: {
          200: {
            description: "Surveys fetched",
          },
        },
      },
      post: {
        tags: ["Surveys"],
        summary: "Create survey",
        security: [{ bearerAuth: [] }],
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                $ref: "#/components/schemas/CreateSurveyRequest",
              },
            },
          },
        },
        responses: {
          201: {
            description: "Survey created",
          },
        },
      },
    },
  },
};

module.exports = swaggerDocument;