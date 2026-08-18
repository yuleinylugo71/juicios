const { Pool } = require('pg');
const pool = new Pool({ host: 'localhost', port: 5432, user: 'postgres', password: '0408', database: 'prueba' });

async function run() {
  const prog = await pool.query('SELECT count(*) as c FROM programa');
  console.log("Programas:", prog.rows[0].c);
  const ap = await pool.query('SELECT count(*) as c FROM aprendiz');
  console.log("Aprendices:", ap.rows[0].c);
  const jui = await pool.query('SELECT count(*) as c FROM juicios_evaluativos');
  console.log("Juicios:", jui.rows[0].c);
  const res = await pool.query(`SELECT * FROM fn_total_aprendices(NULL, NULL, NULL, NULL, NULL) LIMIT 3`);
  console.log("fn_total_aprendices:", res.rows);
  process.exit(0);
}
run().catch(e => { console.error(e.message); process.exit(1); });
