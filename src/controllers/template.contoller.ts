import path from "path";
import fs from "fs-extra";
import { Request, Response } from "express";
import { TemplateFilesService } from "../services/template.service";
import { getSixDigitNoZero } from "../utils/random";
import { logger } from "../utils/logger";

interface TemplateRequestBody {
  id: string;
  organization: string;
  version?: string;
  customCommands?: string;
}

export class TemplateController {
  constructor(private templateService: TemplateFilesService) {}

  async downloadEditedTemplate(req: Request, res: Response) {
    try {
      const { id, organization, version, customCommands } =
        req.body as TemplateRequestBody;

      if (!id || !organization) {
        return res
          .status(400)
          .json({ error: "ID and Organization are required" });
      }

      if (typeof id !== "string" || typeof organization !== "string") {
        return res.status(400).json({ error: "Invalid data types" });
      }

      if (version && typeof version !== "string") {
        return res.status(400).json({ error: "Invalid version" });
      }

      if (customCommands && typeof customCommands !== "string") {
        return res.status(400).json({ error: "Invalid custom commands" });
      }

      const tempDir = await this.templateService.copyTemplateToTemp();

      if (customCommands) {
        const replacements = {
          "<Replace me:Id>": `${id}`,
          "<Replace me:Organization>": `${organization}`,
          "<Replace me:Version>": version ? version : "Latest",
          "<Replace me:CustomFileInstall>": customCommands,
          "<Replace me:CustomFileUninstall>": customCommands,
        };
        await this.templateService.editTemplateFiles(tempDir, replacements);
      } else {
        const replacements = {
          "<Replace me:Id>": `${id}`,
          "<Replace me:Organization>": `${organization}`,
          "<Replace me:Version>": version ? version : "Latest",
        };
        await this.templateService.editTemplateFiles(tempDir, replacements);
      }

      const zipPath = path.join(
        __dirname,
        `../../tmp/${getSixDigitNoZero()}.zip`
      );
      await this.templateService.createZip(tempDir, zipPath);

      res.download(zipPath, "template.zip", async (err) => {
        await fs.remove(tempDir);
        await fs.remove(zipPath);
      });
    } catch (error) {
      logger.error("Failed to download", error);
      res.status(500).json({ error: "Failed to process template" });
    }
  }
}
