declare namespace Express {
  interface Locals {
    auth?: {
      userId: string;
      sessionId: string;
    };
  }
}
