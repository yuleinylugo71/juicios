const { Pool } = require('pg');
const pool = new Pool({ host: 'localhost', port: 5432, user: 'postgres', password: '0408', database: 'prueba' });

async function fix() {
  try {
    console.log('Mergeando estados de aprendiz...');
    
    // 1. Asegurar estados base
    await pool.query("UPDATE estado_aprendiz SET descripcion = 'En formación', codigo = 'EF' WHERE id_estado = 1");
    await pool.query("UPDATE estado_aprendiz SET descripcion = 'Retirado', codigo = 'RE' WHERE id_estado = 2");
    await pool.query("UPDATE estado_aprendiz SET descripcion = 'Trasladado', codigo = 'TR' WHERE id_estado = 3");

    // 2. Mapear matriculas de duplicados a los base
    await pool.query("UPDATE matricula SET id_estado = 1 WHERE id_estado = 18");
    await pool.query("UPDATE matricula SET id_estado = 2 WHERE id_estado = 17");
    await pool.query("UPDATE matricula SET id_estado = 3 WHERE id_estado = 19");

    // 3. Borrar duplicados
    await pool.query("DELETE FROM estado_aprendiz WHERE id_estado IN (4, 5, 6, 17, 18, 19)");
    
    console.log('Estados mergeados exitosamente.');
  } catch (e) {
    console.error('Error:', e.message);
  } finally {
    process.exit();
  }
}
fix();
