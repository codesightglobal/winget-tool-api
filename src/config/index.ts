import { RepoConfig } from "../models/repo-config.model";

export const defaultConfig: RepoConfig = {
  url: process.env.REPO_URL || "https://github.com/microsoft/winget-pkgs.git",
  localPath: process.env.LOCAL_PATH || "./repos/winget-pkgs",
  manifestPath: process.env.MANIFESTS_PATH || "manifests",
  updateInterval: process.env.UPDATE_INTERVAL || "*/30 * * * *",
  parser: (process.env.PARSER as "winget") || "winget",
};

export const serverConfig = {
  port: parseInt(process.env.PORT || "3000"),
  corsOrigins: process.env.CORS_ORIGINS?.split(",") || ["*"],
  maxSearchResults: 100,
  defaultSearchLimit: 20,
};
