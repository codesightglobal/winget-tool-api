export interface PackageInfo {
  id: string;
  name: string;
  version?: string;
  publisher?: string;
  lastUpdated?: Date;
}

export interface SearchResult {
  packages: PackageInfo[];
  total: number;
  page: number;
  limit: number;
}

export interface ApiResponse<T> {
  success: boolean;
  data?: T;
  error?: string;
  timestamp: Date;
}
