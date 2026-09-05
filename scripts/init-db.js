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
    .filter((line) => {
      const trimmed = line.trimStart();
      return !trimmed.startsWith("\\") && !trimmed.startsWith("--");
    })
    .join("\n");
}

function makeSchemaSqlRepeatable(sql) {
  return sql
    .replace(/\bCREATE FUNCTION\b/g, "CREATE OR REPLACE FUNCTION")
    .replace(/\bCREATE VIEW\b/g, "CREATE OR REPLACE VIEW");
}

function splitSqlStatements(sql) {
  const statements = [];
  let current = "";
  let singleQuoted = false;
  let doubleQuoted = false;
  let dollarTag = null;

  for (let i = 0; i < sql.length; i++) {
    const char = sql[i];
    const rest = sql.slice(i);

    if (!singleQuoted && !doubleQuoted) {
      const dollarMatch = rest.match(/^\$[A-Za-z0-9_]*\$/);
      if (dollarMatch) {
        const tag = dollarMatch[0];
        if (dollarTag === tag) {
          dollarTag = null;
        } else if (!dollarTag) {
          dollarTag = tag;
        }
        current += tag;
        i += tag.length - 1;
        continue;
      }
    }

    if (!dollarTag && !doubleQuoted && char === "'" && sql[i - 1] !== "\\") {
      singleQuoted = !singleQuoted;
    } else if (!dollarTag && !singleQuoted && char === '"') {
      doubleQuoted = !doubleQuoted;
    }

    if (!singleQuoted && !doubleQuoted && !dollarTag && char === ";") {
      const statement = current.trim();
      if (statement) statements.push(`${statement};`);
      current = "";
      continue;
    }

    current += char;
  }

  const tail = current.trim();
  if (tail) statements.push(tail);
  return statements;
}

function isIgnorableSchemaError(error) {
  return [
    "42701", // duplicate_column
    "42710", // duplicate_object
    "42723", // duplicate_function
    "42P07", // duplicate_table
    "42P16", // invalid_table_definition, e.g. multiple primary keys
  ].includes(error.code);
}

async function main() {
  loadLocalEnv();

  const sqlPath = path.join(__dirname, "..", "init-db", "respaldo.sql");
  const rawSql = fs.readFileSync(sqlPath, "utf8");
  const sql = makeSchemaSqlRepeatable(stripPsqlMetaCommands(rawSql));
  const statements = splitSqlStatements(sql);
  const pool = new Pool(buildDbConfig());
  let executed = 0;
  let skipped = 0;

  try {
    console.log(`Cargando esquema desde ${sqlPath}`);
    for (const statement of statements) {
      try {
        await pool.query(statement);
        executed++;
      } catch (error) {
        if (!isIgnorableSchemaError(error)) throw error;
        skipped++;
      }
    }
    console.log(`Esquema cargado correctamente. Ejecutadas: ${executed}. Omitidas por existir: ${skipped}.`);
  } finally {
    await pool.end();
  }
}

main().catch((error) => {
  console.error("No se pudo cargar el esquema:", error.message);
  process.exitCode = 1;
});
