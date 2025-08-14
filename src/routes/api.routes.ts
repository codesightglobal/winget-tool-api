import { Router } from "express";
import { PackageController } from "../controllers/package.controller";
import { SyncController } from "../controllers/sync.controller";
import { TemplateController } from "../controllers/template.contoller";

export function createApiRoutes(
  packageController: PackageController,
  syncController: SyncController,
  templateController: TemplateController
): Router {
  const router = Router();

  // Health check
  router.get("/health", packageController.healthCheck.bind(packageController));

  // Search packages
  router.get(
    "/search",
    packageController.searchPackages.bind(packageController)
  );

  // Get package by ID
  router.get(
    "/package/:id",
    packageController.getPackage.bind(packageController)
  );

  // List all packages
  router.get(
    "/packages",
    packageController.listPackages.bind(packageController)
  );

  // Trigger manual sync
  router.post("/sync", syncController.triggerSync.bind(syncController));

  // Download edited template
  router.post(
    "/template",
    templateController.downloadEditedTemplate.bind(templateController)
  );

  return router;
}
