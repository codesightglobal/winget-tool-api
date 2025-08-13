import * as fs from "fs/promises";
import * as path from "path";

import { PackageInfo, SearchResult } from "../models/package.model";
import { RepoConfig } from "../models/repo-config.model";

import { BaseParser } from "./parser/base.parser";
import { ParserFactory } from "./parser/factory";
import { GitService } from "./git.service";
import { logger } from "../utils/logger";

export class PackageService {
  private packages = new Map<string, PackageInfo>();
  private parser: BaseParser;
  private getService: GitService;
  private lastSync: Date | null = null;

  constructor(private config: RepoConfig) {
    this.parser = ParserFactory.createParser(config);
    this.getService = new GitService(config);
  }

  async initialize(): Promise<void> {
    logger.info("Initializing package service...");
    await this.syncRepository();
    logger.info(`Loaded ${this.packages.size} packages`);
  }

  async syncRepository(): Promise<void> {
    try {
      const changedFiles = await this.getService.cloneOrUpdate();

      if (changedFiles.length === 0 && this.packages.size > 0) {
        return;
      }

      if (changedFiles.length > 0) {
        await this.parseFiles(changedFiles);
      } else {
        await this.fullScan();
      }

      this.lastSync = new Date();
    } catch (error) {
      logger.error(`Repository sync failed`, error);
      throw error;
    }
  }

  private async fullScan(): Promise<void> {
    logger.info("Performing full manifest scan...");
    const manifestPath = path.join(
      this.config.localPath,
      this.config.manifestPath
    );
    const files = await this.getAllManifestFiles(manifestPath);

    this.packages.clear();
    await this.parseFiles(
      files.map((f) => path.relative(this.config.localPath, f))
    );
  }

  private async getAllManifestFiles(dir: string): Promise<string[]> {
    const files: string[] = [];

    try {
      const entries = await fs.readdir(dir, { withFileTypes: true });

      for (const entry of entries) {
        const fullPath = path.join(dir, entry.name);

        if (entry.isDirectory()) {
          files.push(...(await this.getAllManifestFiles(fullPath)));
        } else if (
          entry.name.endsWith(".yaml") ||
          entry.name.endsWith(".yml")
        ) {
          files.push(fullPath);
        }
      }
    } catch (error) {
      logger.warn(`Could not read directory ${dir}`, error);
    }

    return files;
  }

  private async parseFiles(files: string[]): Promise<void> {
    let processed = 0;
    const batchSize = 500;

    for (let i = 0; i < files.length; i += batchSize) {
      const batch = files.slice(i, i + batchSize);
      await Promise.all(
        batch.map(async (file) => {
          try {
            const fullPath = path.join(this.config.localPath, file);
            const content = await fs.readFile(fullPath, "utf-8");
            const packageInfo = this.parser.parseManifest(file, content);

            if (packageInfo) {
              this.packages.set(packageInfo.id, packageInfo);
            }
          } catch (error) {
            logger.warn(`Failed to process file ${file}:`, error);
          }
        })
      );

      processed += batch.length;
      logger.info(`Processed ${processed}/${files.length} files...`);
    }

    logger.info(
      `Processed ${processed} files, found ${this.packages.size} packages`
    );
  }

  getPackage(id: string): PackageInfo | null {
    return this.packages.get(id) || null;
  }

  searchPackages(query: string, page = 1, limit = 20): SearchResult {
    const normalizedQuery = query.toLocaleLowerCase();
    const matches: PackageInfo[] = [];

    for (const pkg of this.packages.values()) {
      if (
        pkg.name.toLowerCase().includes(normalizedQuery) ||
        pkg.id.toLowerCase().includes(normalizedQuery)
      ) {
        matches.push(pkg);
      }
    }

    matches.sort((a, b) => {
      const aExact = a.name.toLowerCase() === normalizedQuery ? 1 : 0;
      const bExact = a.name.toLowerCase() === normalizedQuery ? 1 : 0;

      return bExact - aExact || a.name.length - b.name.length;
    });

    const startIndex = (page - 1) * limit;
    const endIndex = startIndex + limit;

    return {
      packages: matches.slice(startIndex, endIndex),
      total: matches.length,
      page,
      limit,
    };
  }

  getAllPackages(): PackageInfo[] {
    return Array.from(this.packages.values());
  }

  getStats() {
    return {
      totalPackages: this.packages.size,
      lastSync: this.lastSync,
    };
  }
}
