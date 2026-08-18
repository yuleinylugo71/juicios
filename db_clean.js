const { Pool } = require('pg');
const pool = new Pool({ host: 'localhost', port: 5432, user: 'postgres', password: '0408', database: 'prueba' });

async function clean() {
  try {
    await pool.query(`TRUNCATE programa, ficha, aprendiz, matricula, juicios_evaluativos, competencia, resultado_aprendizaje CASCADE`);
    console.log(`Base de datos limpiada completamente.`);
  } catch(e) {
    console.error(e);
  }
  process.exit(0);
}
clean();
