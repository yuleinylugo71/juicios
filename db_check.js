const { Pool } = require('pg');
const pool = new Pool({ host: 'localhost', port: 5432, user: 'postgres', password: '0408', database: 'prueba' });

async function run() {
  const q = `
    SELECT
      tc.table_name, c.column_name, tc.constraint_type
    FROM information_schema.table_constraints tc
    JOIN information_schema.constraint_column_usage AS ccu USING (constraint_schema, constraint_name)
    JOIN information_schema.columns AS c ON c.table_schema = tc.constraint_schema
      AND tc.table_name = c.table_name AND ccu.column_name = c.column_name
    WHERE constraint_type = 'PRIMARY KEY' OR constraint_type = 'UNIQUE';
  `;
  const res = await pool.query(q);
  console.table(res.rows);
  process.exit(0);
}
run();
