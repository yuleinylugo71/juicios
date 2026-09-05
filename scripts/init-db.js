const fs = require("fs");
const path = require("path");
const { Pool } = require("pg");

function loadLocalEnv() {
  const envPath = path.join(__dirname, "..", ".env");
  if (!fs.existsSync(envPath)) return;

  const lines = fs.readFileSync(envPath, "utf8").split(/\r?\n/);
  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#") || !trimmed.includes("=")) continue;
    const [key, ...rest] = trimmed.split("=");
    if (!process.env[key]) process.env[key] = rest.join("=").trim();
  }
}

function buildDbConfig() {
  if (process.env.DATABASE_URL) {
    const url = new URL(process.env.DATABASE_URL);
    const isLocalHost = ["localhost", "127.0.0.1", "::1"].includes(url.hostname);
    return {
      connectionString: process.env.DATABASE_URL,
      ssl: process.env.DB_SSL === "false" || isLocalHost ? false : { rejectUnauthorized: false },
    };
  }

  return {
    host: process.env.DB_HOST || "localhost",
    port: Number(process.env.DB_PORT || 5432),
    user: process.env.DB_USER || "postgres",
    password: process.env.DB_PASSWORD || "",
    database: process.env.DB_NAME || "prueba",
    ssl: process.env.DB_SSL === "true" ? { rejectUnauthorized: false } : false,
  };
}

function stripPsqlMetaCommands(sql) {
  return sql
    .split(/\r?\n/)
    .filter((line) => !line.trimStart().startsWith("\\"))
    .join("\n");
}

async function main() {
  loadLocalEnv();

  const sqlPath = path.join(__dirname, "..", "init-db", "respaldo.sql");
  const rawSql = fs.readFileSync(sqlPath, "utf8");
  const sql = stripPsqlMetaCommands(rawSql);
  const pool = new Pool(buildDbConfig());

  try {
    console.log(`Cargando esquema desde ${sqlPath}`);
    await pool.query(sql);
    console.log("Esquema cargado correctamente.");
  } finally {
    await pool.end();
  }
}

main().catch((error) => {
  console.error("No se pudo cargar el esquema:", error.message);
  process.exitCode = 1;
});
