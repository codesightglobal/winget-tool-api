import simpleGit, { SimpleGit } from "simple-git";
import * as fs from "fs/promises";
import * as path from "path";
import { RepoConfig } from "../models/repo-config.model";
import { logger } from "../utils/logger";

export class GitService {
  private git: SimpleGit;

  constructor(private config: RepoConfig) {
    this.git = simpleGit();
  }

  private async checkRepoExists(): Promise<boolean> {
    try {
      await fs.access(path.join(this.config.localPath, ".git"));
      return true;
    } catch (error) {
      return false;
    }
  }

  async cloneOrUpdate(): Promise<string[]> {
    try {
      const repoExists = await this.checkRepoExists();

      if (!repoExists) {
        logger.info("Cloning repository...");
        await this.git.clone(this.config.url, this.config.localPath);
        logger.info("Repository cloned successfully");
        return [];
      }

      logger.info("Updating repository...");
      const gitRepo = simpleGit(this.config.localPath);
      const pullRequest = await gitRepo.pull();

      if (pullRequest.summary.changes === 0) {
        logger.info("No changes found");
        return [];
      }
      logger.info(
        `Repository updates with ${pullRequest.summary.changes} changes`
      );
      return await this.getChangedFiles();
    } catch (error) {
      logger.error("Git operation failed:", error);
      throw error;
    }
  }

  private async getChangedFiles(): Promise<string[]> {
    try {
      const gitRepo = simpleGit(this.config.localPath);
      const log = await gitRepo.log({ maxCount: 1 });

      if (log.latest) {
        const diff = await gitRepo.show([
          log.latest.hash,
          "--name-only",
          "--pretty=format",
        ]);
        return diff
          .split("\n")
          .filter((file) => file.trim())
          .filter((file) => file.startsWith(this.config.manifestPath));
      }
      return [];
    } catch (error) {
      logger.warn(`Could not get changed files, will do full scan:`, error);
      return [];
    }
  }
}
