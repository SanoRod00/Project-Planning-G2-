export const config = {
  port: Number(process.env.PORT || 3000),
  databaseUrl: process.env.DATABASE_URL,
  slipAfterMinutes: Number(process.env.SLIP_AFTER_MINUTES || 5),
  noShowAfterMinutes: Number(process.env.NO_SHOW_AFTER_MINUTES || 10)
};