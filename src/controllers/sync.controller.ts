import { Request, Response } from "express";
import { PackageService } from "../services/package.service";
import { ApiResponse } from "../models/package.model";

export class SyncController {
  constructor(private packageService: PackageService) {}

  async triggerSync(req: Request, res: Response) {
    try {
      await this.packageService.syncRepository();
      const response: ApiResponse<any> = {
        success: true,
        data: {
          message: "Sync completed",
          ...this.packageService.getStats(),
        },
        timestamp: new Date(),
      };
      res.status(200).json(response);
    } catch (error) {
      const response: ApiResponse<any> = {
        success: false,
        error: "Sync failed",
        timestamp: new Date(),
      };
      res.status(500).json(response);
    }
  }
}
