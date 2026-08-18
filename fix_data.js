const { Pool } = require('pg');
const pool = new Pool({ host: 'localhost', port: 5432, user: 'postgres', password: '0408', database: 'prueba' });

async function fix() {
  try {
    console.log('Iniciando corrección de datos...');
    
    // 1. Asegurar que existan los códigos estándar
    await pool.query("INSERT INTO tipo_juicio (nombre, codigo) VALUES ('Aprobado', 'AP') ON CONFLICT (nombre) DO UPDATE SET codigo = 'AP'");
    await pool.query("INSERT INTO tipo_juicio (nombre, codigo) VALUES ('No aprobado', 'NA') ON CONFLICT (nombre) DO UPDATE SET codigo = 'NA'");
    await pool.query("INSERT INTO tipo_juicio (nombre, codigo) VALUES ('Por evaluar', 'PE') ON CONFLICT (nombre) DO UPDATE SET codigo = 'PE'");
    
    // 2. Mapear juicios con códigos raros a los estándar
    await pool.query("UPDATE juicios_evaluativos SET id_tipo = (SELECT id FROM tipo_juicio WHERE codigo = 'AP') WHERE id_tipo IN (SELECT id FROM tipo_juicio WHERE codigo = 'APROBADO')");
    await pool.query("UPDATE juicios_evaluativos SET id_tipo = (SELECT id FROM tipo_juicio WHERE codigo = 'PE') WHERE id_tipo IN (SELECT id FROM tipo_juicio WHERE codigo = 'POR_EVALUA')");
    
    // 3. Limpiar tipos duplicados (si no tienen juicios asociados)
    await pool.query("DELETE FROM tipo_juicio WHERE codigo IN ('APROBADO', 'POR_EVALUA') AND id NOT IN (SELECT DISTINCT id_tipo FROM juicios_evaluativos)");
    
    console.log('Datos corregidos exitosamente.');
    
    // Verificar resumen
    const { rows } = await pool.query("SELECT * FROM v_resumen_general");
    console.log('Nuevo resumen:', JSON.stringify(rows[0], null, 2));
    
  } catch (e) {
    console.error('Error al corregir datos:', e.message);
  } finally {
    process.exit();
  }
}
fix();
