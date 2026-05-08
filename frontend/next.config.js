/**
 * Next.js config: set turbopack root to frontend directory so Turbopack
 * resolves the `next` package correctly when started from src/app.
 */
module.exports = {
  experimental: {
    turbo: {
      root: __dirname,
    },
  },
};
