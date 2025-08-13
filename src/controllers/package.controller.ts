import { Request, Response } from "express";
import {
  ApiResponse,
  PackageInfo,
  SearchResult,
} from "../models/package.model";
import { serverConfig } from "../config";
import { PackageService } from "../services/package.service";

export class PackageController {
  constructor(private packageService: PackageService) {}

  healthCheck(req: Request, res: Response) {
    const response: ApiResponse<any> = {
      success: true,
      data: {
        status: "healthy",
        ...this.packageService.getStats(),
      },
      timestamp: new Date(),
    };
    res.status(200).json(response);
  }

  searchPackages(req: Request, res: Response) {
    try {
      const query = req.query.q as string;
      const page = parseInt(req.query.page as string) || 1;
      const limit = Math.min(
        parseInt(req.query.limit as string) || serverConfig.defaultSearchLimit,
        serverConfig.maxSearchResults
      );

      if (!query || query.trim().length < 2) {
        const response: ApiResponse<SearchResult> = {
          success: false,
          error: "Query must be at least 2 characters long",
          timestamp: new Date(),
        };
        return res.status(400).json(response);
      }

      const searchResult = this.packageService.searchPackages(
        query.trim(),
        page,
        limit
      );

      const response: ApiResponse<SearchResult> = {
        success: true,
        data: searchResult,
        timestamp: new Date(),
      };

      res.status(200).json(response);
    } catch (error) {
      const response: ApiResponse<SearchResult> = {
        success: false,
        error: "Search failed",
        timestamp: new Date(),
      };
      res.status(500).json(response);
    }
  }

  getPackage(req: Request, res: Response) {
    try {
      const { id } = req.params;
      const packageInfo = this.packageService.getPackage(id);

      if (!packageInfo) {
        const response: ApiResponse<PackageInfo> = {
          success: false,
          error: "Package not found",
          timestamp: new Date(),
        };
        return res.status(404).json(response);
      }

      const response: ApiResponse<PackageInfo> = {
        success: true,
        data: packageInfo,
        timestamp: new Date(),
      };

      res.json(response);
    } catch (error) {
      const response: ApiResponse<PackageInfo> = {
        success: false,
        error: "Failed to retrieve package",
        timestamp: new Date(),
      };
      res.status(500).json(response);
    }
  }

  listPackages(req: Request, res: Response) {
    try {
      const page = parseInt(req.query.limit as string) || 1;
      const limit = Math.min(
        parseInt(req.query.limit as string) || serverConfig.defaultSearchLimit,
        serverConfig.maxSearchResults
      );

      const allPackages = this.packageService.getAllPackages();
      const startIndex = (page - 1) * limit;
      const endIndex = startIndex + limit;

      const result: SearchResult = {
        packages: allPackages.slice(startIndex, endIndex),
        total: allPackages.length,
        page,
        limit,
      };

      const response: ApiResponse<SearchResult> = {
        success: true,
        data: result,
        timestamp: new Date(),
      };

      res.status(200).json(response);
    } catch (error) {
      const response: ApiResponse<SearchResult> = {
        success: false,
        error: "Failed to retrieve packages",
        timestamp: new Date(),
      };
      res.status(500).json(response);
    }
  }
}
