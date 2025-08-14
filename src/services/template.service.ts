import fs from "fs-extra";
import * as path from "path";
import archiver from "archiver";
import { logger } from "../utils/logger";

import { getSixDigitNoZero } from "../utils/random";

export class TemplateFilesService {
  private templateDir: string;
  private tempDir: string;

  constructor() {
    this.templateDir = path.join(__dirname, "../template");
    this.tempDir = path.join(__dirname, "../../tmp");
  }

  async copyTemplateToTemp(): Promise<string> {
    const targetDir = path.join(this.tempDir, getSixDigitNoZero().toString());
    await fs.ensureDir(targetDir);
    await fs.copy(this.templateDir, targetDir);
    return targetDir;
  }

  async editTemplateFiles(
    targetDir: string,
    replacements: Record<string, string>
  ): Promise<void> {
    const files = await fs.readdir(targetDir);

    for (const file of files) {
      if (file.endsWith(".ps1") || file.endsWith(".vbs")) {
        const filePath = path.join(targetDir, file);
        let content = await fs.readFile(filePath, "utf-8");

        for (const [placeholder, value] of Object.entries(replacements)) {
          content = content.replace(new RegExp(placeholder, "g"), value);
        }

        await fs.writeFile(filePath, content, "utf-8");
      }
    }
  }

  async createZip(sourceDir: string, outputFile: string): Promise<string> {
    await fs.ensureDir(path.dirname(outputFile));

    const output = fs.createWriteStream(outputFile);
    const archive = archiver("zip", { zlib: { level: 9 } });

    return new Promise((resolve, reject) => {
      output.on("close", () => resolve(outputFile));
      archive.on("error", reject);

      archive.pipe(output);
      archive.directory(sourceDir, false);
      archive.finalize();
    });
  }
}
