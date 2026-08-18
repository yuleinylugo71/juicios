const { Pool } = require("pg");

const dbConfig = {
  host: process.env.DB_HOST || "localhost",
  port: Number(process.env.DB_PORT || 5432),
  user: process.env.DB_USER || "postgres",
  password: process.env.DB_PASSWORD || "0408",
  database: process.env.DB_NAME || "prueba",
};

const pool = new Pool(dbConfig);

async function updateFunction() {
  try {
    await pool.query(`DROP FUNCTION IF EXISTS fn_resultados_por_aprendiz(varchar, varchar, integer, integer, varchar)`);
    await pool.query(`DROP FUNCTION IF EXISTS fn_resultados_por_aprendiz`);
    await pool.query(`
      CREATE OR REPLACE FUNCTION fn_resultados_por_aprendiz(
          p_documento VARCHAR DEFAULT NULL,
          p_tipo_documento VARCHAR DEFAULT NULL,
          p_id_ficha INTEGER DEFAULT NULL,
          p_id_programa INTEGER DEFAULT NULL,
          p_nombre_aprendiz VARCHAR DEFAULT NULL
      ) RETURNS TABLE (
          documento VARCHAR, 
          tipo_documento VARCHAR, 
          nombre_completo TEXT, 
          codigo_ficha VARCHAR, 
          programa VARCHAR, 
          estado_matricula VARCHAR, 
          total_resultados BIGINT, 
          aprobados BIGINT, 
          pendientes BIGINT, 
          no_aprobados BIGINT, 
          porcentaje_avance NUMERIC
      ) AS $$
      BEGIN
          RETURN QUERY
          SELECT 
              a.documento, a.tipo_documento, (a.nombres || ' ' || a.apellidos)::TEXT,
              f.codigo_ficha, p.denominacion, ea.descripcion as estado_matricula,
              COUNT(ra.id_resultado),
              COUNT(je.id_juicio) FILTER (WHERE tj.codigo = 'AP'),
              COUNT(ra.id_resultado) - COUNT(je.id_juicio),
              COUNT(je.id_juicio) FILTER (WHERE tj.codigo = 'NA'),
              ROUND(COALESCE(COUNT(je.id_juicio) FILTER (WHERE tj.codigo = 'AP')::NUMERIC / NULLIF(COUNT(ra.id_resultado), 0) * 100, 0), 2)
          FROM aprendiz a
          JOIN matricula m ON a.documento = m.id_aprendiz
          LEFT JOIN estado_aprendiz ea ON m.id_estado = ea.id_estado
          JOIN ficha f ON m.id_ficha = f.id_ficha
          JOIN programa p ON f.id_programa = p.id
          JOIN competencia c ON p.id = c.id_programa
          JOIN resultado_aprendizaje ra ON c.id_competencia = ra.id_competencia
          LEFT JOIN juicios_evaluativos je ON m.id_matricula = je.id_matricula AND ra.id_resultado = je.id_resultado
          LEFT JOIN tipo_juicio tj ON je.id_tipo = tj.id
          WHERE (p_documento IS NULL OR a.documento = p_documento)
            AND (p_id_ficha IS NULL OR f.id_ficha = p_id_ficha)
            AND (p_id_programa IS NULL OR p.id = p_id_programa)
            AND (p_nombre_aprendiz IS NULL OR (a.nombres || ' ' || a.apellidos) ILIKE '%' || p_nombre_aprendiz || '%')
          GROUP BY a.documento, a.tipo_documento, a.nombres, a.apellidos, f.codigo_ficha, p.denominacion, ea.descripcion;
      END;
      $$ LANGUAGE plpgsql;
    `);
    console.log("SQL Function updated successfully.");
  } catch (err) {
    console.error("Error updating function:", err);
  } finally {
    pool.end();
  }
}

updateFunction();
