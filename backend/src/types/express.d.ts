declare namespace Express {
  interface Locals {
    requestId?: string;
    auth?: {
      userId: string;
      sessionId: string;
    };
  }
}
