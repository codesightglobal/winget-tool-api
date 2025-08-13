import * as cron from "node-cron";
import { PackageService } from "../services/package.service";
import { logger } from "../utils/logger";
import { defaultConfig } from "../config";

export function setupScheduledSync(packageService: PackageService) {
  cron.schedule(defaultConfig.updateInterval, async () => {
    logger.info("Scheduled repository sync starting...");
    try {
      await packageService.syncRepository();
      logger.info("Scheduled sync completed");
    } catch (error) {
      logger.error("Scheduled sync failed:", error);
    }
  });

  logger.info(
    `Scheduled sync configured with interval: ${defaultConfig.updateInterval}`
  );
}
