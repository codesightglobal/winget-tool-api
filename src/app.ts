import express from "express";
import cors from "cors";
import helmet from "helmet";
import compression from "compression";
import { PackageService } from "./services/package.service";
import { defaultConfig, serverConfig } from "./config";
import { createApiRoutes } from "./routes/api.routes";
import { PackageController } from "./controllers/package.controller";
import { SyncController } from "./controllers/sync.controller";
import { setupScheduledSync } from "./tasks/sync.task";
import { logger } from "./utils/logger";
import { TemplateFilesService } from "./services/template.service";
import { TemplateController } from "./controllers/template.contoller";

async function startServer() {
  const app = express();

  // Middleware
  app.use(helmet());
  app.use(compression());
  app.use(
    cors({
      origin: serverConfig.corsOrigins, // array from env
      credentials: true, // if you need cookies
    })
  );
  app.use(express.json());

  // Initialize services
  const packageService = new PackageService(defaultConfig);
  const packageController = new PackageController(packageService);
  const syncController = new SyncController(packageService);

  const templateService = new TemplateFilesService();
  const templateController = new TemplateController(templateService);

  // Setup routes
  app.use(
    "/api",
    createApiRoutes(packageController, syncController, templateController)
  );

  // Root endpoint
  app.get("/", (req, res) => {
    res.json({
      name: "Package Repository Sync API",
      version: "1.0.0",
      endpoints: {
        health: "/api/health",
        search: "/api/search?q=query&page=1&limit=20",
        package: "/api/package/:id",
        packages: "/api/packages?page=1&limit=20",
        sync: "POST /api/sync",
      },
    });
  });

  // Error handling
  app.use((err: any, req: any, res: any, next: any) => {
    console.log("Unhandled error:", err);
    res.status(500).json({
      success: false,
      error: "Internal server error",
      timestamp: new Date(),
    });
  });

  try {
    console.log("Initializing application...");
    await packageService.initialize();

    // Setup scheduled sync
    setupScheduledSync(packageService);

    // Start server
    const server = app.listen(serverConfig.port, () => {
      console.log(`Server running on port ${serverConfig.port}`);
      console.log(`Repository: ${defaultConfig.url}`);
    });

    // Graceful shutdown
    process.on("SIGTERM", () => {
      console.log("SIGTERM received, shutting down gracefully");
      server.close(() => {
        console.log("Server closed");
        process.exit(0);
      });
    });

    process.on("SIGINT", () => {
      console.log("SIGINT received, shutting down gracefully");
      server.close(() => {
        console.log("Server closed");
        process.exit(0);
      });
    });
  } catch (error) {
    console.log("Failed to start server:", error);
    process.exit(1);
  }
}

startServer();

// force new deploy
