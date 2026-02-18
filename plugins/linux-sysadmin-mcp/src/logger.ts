import pino from "pino";

export const logger = pino({
  name: "linux-sysadmin",
  level: process.env.LOG_LEVEL ?? "info",
  transport:
    process.env.NODE_ENV === "development"
      ? { target: "pino/file", options: { destination: 2 } }
      : undefined,
});
