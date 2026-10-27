export class AppError extends Error {
  constructor(
    public status: number,
    public code: string,
    message?: string,
    public details?: unknown,
  ) {
    super(message ?? code);
  }
}

export const badRequest = (code: string, msg?: string, details?: unknown) => new AppError(400, code, msg, details);
export const unauthorized = (code = 'UNAUTHORIZED', msg?: string) => new AppError(401, code, msg);
export const forbidden = (code = 'FORBIDDEN', msg?: string) => new AppError(403, code, msg);
export const notFound = (code = 'NOT_FOUND', msg?: string) => new AppError(404, code, msg);
export const conflict = (code: string, msg?: string, details?: unknown) => new AppError(409, code, msg, details);
export const unprocessable = (code: string, msg?: string, details?: unknown) => new AppError(422, code, msg, details);
export const tooMany = (code = 'RATE_LIMITED', msg?: string) => new AppError(429, code, msg);
