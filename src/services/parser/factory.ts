import { BaseParser } from "./base.parser";
import { WingetParser } from "./winget.parser";
import { RepoConfig } from "../../models/repo-config.model";

export class ParserFactory {
  static createParser(config: RepoConfig): BaseParser {
    switch (config.parser) {
      case "winget":
        return new WingetParser();
      default:
        throw new Error(`Unsupported parser type: ${config.parser}`);
    }
  }
}
