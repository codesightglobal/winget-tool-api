import * as yaml from "js-yaml";
import { PackageInfo } from "../../models/package.model";
import { BaseParser } from "./base.parser";
import { logger } from "../../utils/logger";

export class WingetParser extends BaseParser {
  parseManifest(filePath: string, content: string): PackageInfo | null {
    try {
      if (!this.isValidPackageFile(filePath) || !content.trim()) {
        return null;
      }

      const manifest = yaml.load(content) as any;

      if (!manifest || typeof manifest !== "object") {
        return null;
      }

      const packageIdentifier = manifest.PackageIdentifier;
      const packageName =
        manifest.PackageName || manifest.DefaultLocale?.PackageName;
      const packageVersion = manifest.PackageVersion;
      const publisher = manifest.Publisher || manifest.DefaultLocale?.Publisher;

      if (!packageIdentifier) {
        return null;
      }

      return {
        id: packageIdentifier,
        name: packageName || packageIdentifier,
        version: packageVersion,
        publisher,
        lastUpdated: new Date(),
      };
    } catch (error) {
      logger.warn(`Failed to parse manifest ${filePath}:`, error);
      return null;
    }
  }

  protected isValidPackageFile(filePath: string): boolean {
    return (
      super.isValidPackageFile(filePath) &&
      !filePath.includes(".validation") &&
      !filePath.includes("schema")
    );
  }
}
