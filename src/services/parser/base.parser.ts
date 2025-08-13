import { PackageInfo } from "../../models/package.model";

export abstract class BaseParser {
  abstract parseManifest(filePath: string, content: string): PackageInfo | null;

  protected isValidPackageFile(filePath: string): boolean {
    return filePath.endsWith(".yaml") || filePath.endsWith(".yml");
  }

  protected extractPackageId(filePath: string): string {
    const parts = filePath.split("/");
    return parts.slice(-3, -1).join(".");
  }
}
